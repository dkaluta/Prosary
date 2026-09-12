#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["beautifulsoup4>=4.12,<5", "requests>=2.32,<3"]
# ///
"""Inventory USCCB NABRE verse identifiers without retaining Scripture or notes.

HTTP bodies are parsed in memory and discarded. Only numeric/letter reference labels,
canonical book identifiers, public source URLs and SHA-256 provenance are written.
This is an inventory, not evidence that equally numbered verses in two Bibles agree.

Run with --fetch to fetch missing pages, --refresh to revisit recorded pages, or
--check for offline validation. The default is an offline check. A failed/blocked
fetch writes an explicitly incomplete, resumable inventory and returns nonzero.
HTTP 401/403 and connection-check pages are never retried or bypassed.
"""
from __future__ import annotations

import argparse
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import re
import threading
import time
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup, NavigableString, Tag
import requests

OUTPUT = Path(__file__).resolve().parent / "versification/nabre/structure.json"
INDEX_URL = "https://bible.usccb.org/bible"
BOOK_NAMES = (
    "Genesis|Exodus|Leviticus|Numbers|Deuteronomy|Joshua|Judges|Ruth|1 Samuel|2 Samuel|"
    "1 Kings|2 Kings|1 Chronicles|2 Chronicles|Ezra|Nehemiah|Tobit|Judith|Esther|"
    "1 Maccabees|2 Maccabees|Job|Psalms|Proverbs|Ecclesiastes|Song of Songs|Wisdom|"
    "Sirach|Isaiah|Jeremiah|Lamentations|Baruch|Ezekiel|Daniel|Hosea|Joel|Amos|"
    "Obadiah|Jonah|Micah|Nahum|Habakkuk|Zephaniah|Haggai|Zechariah|Malachi|"
    "Matthew|Mark|Luke|John|Acts of the Apostles|Romans|1 Corinthians|2 Corinthians|"
    "Galatians|Ephesians|Philippians|Colossians|1 Thessalonians|2 Thessalonians|"
    "1 Timothy|2 Timothy|Titus|Philemon|Hebrews|James|1 Peter|2 Peter|1 John|2 John|"
    "3 John|Jude|Revelation"
).split("|")
BOOK_CODES = (
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH TOB JDT EST "
    "1MA 2MA JOB PSA PRO ECC SNG WIS SIR ISA JER LAM BAR EZK DAN HOS JOL AMO OBA JON "
    "MIC NAM HAB ZEP HAG ZEC MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL "
    "1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV"
).split()
NAME_TO_CODE = dict(zip(BOOK_NAMES, BOOK_CODES, strict=True))
CHAPTER = re.compile(r"(?:[1-9][0-9]{0,2}|[A-F])\Z")
VERSE = re.compile(r"[1-9][0-9]{0,2}[a-z]?(?:-[1-9][0-9]{0,2}[a-z]?)?\Z")
HEADING = re.compile(r"(?:CHAPTER|PSALM|ADDITION)\s+([1-9][0-9]{0,2}|[A-F])\Z", re.I)
SHA256 = re.compile(r"[a-f0-9]{64}\Z")
MARKER_CLASSES = {"bcv"}
EXCLUDED_CLASSES = {"footnotes", "footnote", "crossreferences", "cross-references", "notes", "fn", "en"}


class InventoryError(ValueError):
    """A fixed diagnostic code, never an HTTP body or Scripture fragment."""


def digest(body: bytes) -> str:
    return hashlib.sha256(body).hexdigest()


def source_url(value: str) -> str:
    parsed = urlparse(value)
    if (parsed.scheme != "https" or parsed.hostname != "bible.usccb.org"
            or parsed.username or parsed.password or parsed.query or parsed.fragment
            or not re.fullmatch(r"/bible(?:/[a-z0-9-]+(?:/(?:[0-9]+|[A-F]))?)?/?", parsed.path)):
        raise InventoryError("invalid-source-url")
    return value


def parse_book_index(body: bytes, url: str = INDEX_URL) -> dict:
    soup = BeautifulSoup(body, "html.parser")
    result = {}
    for anchor in soup.find_all("a", href=True):
        name = anchor.get_text(" ", strip=True)
        if name not in NAME_TO_CODE:
            continue
        target = urlparse(urljoin(url, anchor["href"]))
        path = re.fullmatch(r"/bible/([a-z0-9-]+)/([01])/?", target.path)
        if target.hostname != "bible.usccb.org" or not path:
            continue
        code = NAME_TO_CODE[name]
        slug = path[1]
        if code in result and result[code]["slug"] != slug:
            raise InventoryError("conflicting-book-slug")
        result[code] = {
            "slug": slug, "chapterOrder": [], "chapters": {}, "pageOrder": [],
            "pageSources": {}, "indexSource": {"url": source_url(target._replace(query="", fragment="").geturl()), "sha256": None},
        }
    if set(result) != set(BOOK_CODES):
        raise InventoryError("incomplete-book-index")
    # Website display order is authoritative; alphabetic duplicate links do not reorder it.
    return result


def parse_chapter_index(body: bytes, slug: str, url: str) -> list[str]:
    soup = BeautifulSoup(body, "html.parser")
    pages = []
    for anchor in soup.find_all("a", href=True):
        label = anchor.get_text(strip=True)
        if not CHAPTER.fullmatch(label):
            continue
        target = urlparse(urljoin(url, anchor["href"]))
        if (target.hostname == "bible.usccb.org"
                and target.path.rstrip("/") == f"/bible/{slug}/{label}"
                and not target.query and not target.fragment and label not in pages):
            pages.append(label)
    selected = urlparse(url).path.rstrip("/").rsplit("/", 1)[-1]
    if CHAPTER.fullmatch(selected) and selected not in pages:
        # The selected chapter is plain text in navigation, not an anchor. Its
        # identity comes from the observed index URL, never an invented chapter.
        headings = {_heading(tag) for tag in soup.find_all(["h1", "h2", "h3", "h4", "p"])}
        # A one-chapter book can label its heading simply CHAPTER. The already
        # observed /1 link plus real chapter markers identifies this page; it is
        # not evidence for inventing /2 or any unobserved chapter URL.
        single_chapter = (selected == "1" and not pages and any(
            tag.get_text(" ", strip=True).upper() == "CHAPTER" and not _excluded(tag)
            for tag in soup.find_all(["h1", "h2", "h3", "h4", "p"])) and any(
            _marker(tag) is not None for tag in soup.select(".bcv")))
        if selected not in headings and not single_chapter:
            raise InventoryError("selected-index-chapter-missing")
        pages.insert(0, selected)
    if not pages:
        raise InventoryError("empty-chapter-index")
    return pages


def _excluded(tag: Tag) -> bool:
    for parent in [tag, *tag.parents]:
        if not isinstance(parent, Tag):
            continue
        if parent.name in {"nav", "footer", "header", "script", "style", "sup"}:
            return True
        if set(parent.get("class", [])) & EXCLUDED_CLASSES:
            return True
    return False


def _heading(tag: Tag) -> str | None:
    if ((tag.name not in {"h1", "h2", "h3", "h4"} and "chapterhead" not in tag.get("class", []))
            or _excluded(tag)):
        return None
    match = HEADING.fullmatch(tag.get_text(" ", strip=True))
    return match[1].upper() if match else None


def _marker(tag: Tag) -> str | None:
    if _excluded(tag):
        return None
    classes = {str(value).lower() for value in tag.get("class", [])}
    if not classes & MARKER_CLASSES:
        return None
    # Only labels matching the reference grammar may leave this parser.
    label = re.sub(r"\s+", "", tag.get_text()).strip("[]").replace("–", "-")
    if not VERSE.fullmatch(label) and not re.fullmatch(r"[1-9][0-9]*:[1-9][0-9]*", label):
        raise InventoryError("unsupported-verse-label")
    return label


def _reference_anchor(tag: Tag) -> tuple[str, str] | None:
    name = tag.get("name", "") if tag.name == "a" else ""
    if not re.fullmatch(r"\d{8}", name):
        return None
    chapter, verse = int(name[2:5]), int(name[5:])
    return (str(chapter), str(verse)) if chapter and verse else None


def _body_present(scope: Tag, marker: Tag | None = None, reference: tuple[str, str] | None = None) -> bool:
    """Inspect only body presence between markers, never return body strings.

    USCCB has .txt spans, plain named-anchor bodies, and verse-table cells.
    Restrict inspection to the enclosing verse/anchor/paragraph/table row and
    stop before another verse. Annotation labels cannot count as Scripture.
    """
    started = marker is None
    for node in scope.descendants:
        if node is marker:
            started = True
            continue
        if not started:
            continue
        if isinstance(node, Tag):
            if _excluded(node):
                continue
            if marker is not None and "bcv" in node.get("class", []):
                return False
            if marker is not None and _reference_anchor(node) is not None:
                if _reference_anchor(node) != reference:
                    return False
            continue
        if not isinstance(node, NavigableString) or not any(c.isalpha() for c in node):
            continue
        if _excluded(node.parent):
            continue
        if any("bcv" in parent.get("class", []) or
               (parent.name == "a" and parent.has_attr("href") and _reference_anchor(parent) is None)
               for parent in node.parents if isinstance(parent, Tag)):
            continue
        return True
    return False


def _marker_body_present(marker: Tag, reference: tuple[str, str]) -> bool:
    parents = [parent for parent in marker.parents if isinstance(parent, Tag)]
    row = next((parent for parent in parents if parent.name == "tr"), None)
    verse = next((parent for parent in parents if "verse" in parent.get("class", [])), None)
    anchor = next((parent for parent in parents if _reference_anchor(parent) is not None), None)
    paragraph = next((parent for parent in parents if parent.name == "p"), None)
    scope = row or verse or anchor or paragraph or marker.parent
    chapter, verse_label = reference
    anchor_chapter = str(ord(chapter) - ord("A") + 41) if chapter in "ABCDEF" else chapter
    return isinstance(scope, Tag) and _body_present(scope, marker, (anchor_chapter, verse_label))


def parse_chapter_page(body: bytes, url: str, page_label: str) -> dict:
    """Extract numeric structure; text is examined only for a text-presence boolean.

    Empty verse markers are recorded separately from text-bearing identifiers. Number
    gaps alone never establish omission. Repeated/moved/subverse labels are preserved.
    A chapter can have several letter/numeric sections, as in Esther's Greek additions.
    """
    source_url(url)
    if not CHAPTER.fullmatch(page_label):
        raise InventoryError("invalid-page-label")
    soup = BeautifulSoup(body, "html.parser")
    root = soup.select_one(".contentarea") or soup
    chapters: dict[str, dict] = {}
    current_chapter = page_label
    plain_markers = set()
    observations = []
    page_hash = digest(body)

    def add(chapter: str, verse: str, present: bool, plain: bool = False) -> None:
        record = chapters.setdefault(chapter, {"verseOrder": [], "omittedVerses": [],
            "duplicateVerses": [], "sourcePages": [{"url": url, "sha256": page_hash}]})
        reference = (chapter, verse)
        if reference in plain_markers:
            if plain:
                return  # Some unwrapped anchors repeat the same identifier.
            record["verseOrder"].remove(verse)
            plain_markers.remove(reference)
        record["verseOrder" if present else "omittedVerses"].append(verse)
        if plain:
            plain_markers.add(reference)

    # The site mixes normal verse spans, table-cell spans and older unwrapped
    # named anchors. Anchor chapter IDs also disambiguate verses printed across
    # a page boundary and resumptions after an Esther addition.
    for tag in root.find_all():
        if _excluded(tag):
            continue
        heading = _heading(tag)
        if heading:
            current_chapter = heading
            continue
        name = tag.get("name", "") if tag.name == "a" else ""
        if re.fullmatch(r"\d{8}", name):
            chapter, verse = int(name[2:5]), int(name[5:])
            if not chapter or not verse:
                continue
            current_chapter = chr(65 + chapter - 41) if "/esther/" in url and 41 <= chapter <= 46 else str(chapter)
            if _body_present(tag):
                observations.append((current_chapter, str(verse), True, True))
            continue
        marker = _marker(tag)
        if marker is None:
            continue
        chapter = current_chapter
        if ":" in marker:
            chapter, marker = marker.split(":")
            current_chapter = chapter
        observations.append((chapter, marker, _marker_body_present(tag, (chapter, marker)), False))
    normal_references = {(chapter, verse) for chapter, verse, _, plain in observations if not plain}
    for chapter, verse, present, plain in observations:
        # Some paragraphs repeat the named anchor for a continuation of the
        # same verse. A .bcv on either side of that anchor remains authoritative.
        if plain and (chapter, verse) in normal_references:
            continue
        add(chapter, verse, present, plain=plain)
    if page_label not in chapters or any(not chapter["verseOrder"] for chapter in chapters.values()):
        raise InventoryError("missing-text-bearing-chapter")
    for chapter in chapters.values():
        counts = Counter(chapter["verseOrder"])
        chapter["duplicateVerses"] = [verse for verse in counts if counts[verse] > 1]
    return {"chapterOrder": list(chapters), "chapters": chapters}


class Fetcher:
    def __init__(self, delay: float = 0.5, retries: int = 2):
        self.delay, self.retries = delay, retries
        self.lock = threading.Lock()
        self.last_request = 0.0
        self.blocked = threading.Event()

    def get(self, url: str) -> bytes:
        source_url(url)
        for attempt in range(self.retries + 1):
            with self.lock:
                if self.blocked.is_set():
                    raise InventoryError("fetch-stopped-after-access-block")
                remaining = self.delay - (time.monotonic() - self.last_request)
                if remaining > 0:
                    time.sleep(remaining)
                self.last_request = time.monotonic()
            try:
                response = requests.get(
                    url, headers={"User-Agent": "Prosary numeric verse inventory (+https://prayers.prosary.app)"},
                    timeout=(10, 30), allow_redirects=False,
                )
            except requests.RequestException:
                if attempt == self.retries:
                    raise InventoryError("fetch-network-error") from None
                time.sleep(2 ** attempt)
                continue
            if response.status_code in {401, 403}:
                self.blocked.set()
                raise InventoryError(f"fetch-http-{response.status_code}")
            if response.status_code == 200:
                if "html" not in response.headers.get("Content-Type", ""):
                    raise InventoryError("fetch-unexpected-content-type")
                return response.content
            if response.status_code == 429 or response.status_code >= 500:
                if attempt < self.retries:
                    retry_after = response.headers.get("Retry-After", "")
                    pause = min(int(retry_after), 30) if retry_after.isdigit() else 2 ** attempt
                    time.sleep(max(1, pause))
                    continue
            raise InventoryError(f"fetch-http-{response.status_code}")
        raise InventoryError("fetch-retries-exhausted")


def empty_inventory() -> dict:
    return {"schemaVersion": 1, "edition": "NABRE", "complete": False,
            "source": {"indexURL": INDEX_URL, "indexSHA256": None,
                       "hashKind": "sha256-decoded-http-body"}, "books": {}, "errors": []}


def metadata_digest(value: object) -> str:
    return digest(json.dumps(value, ensure_ascii=True, sort_keys=True, separators=(",", ":")).encode())


def import_browser_inventory(compact: dict) -> dict:
    """Accept only numeric DOM observations, never exported HTML or browser text.

    Browser observations can use ``maximum`` only after comparing every observed
    text-bearing label with the complete sequence 1..N. Irregular orders must supply
    ``verseOrder`` explicitly. Provenance hashes cover normalized numeric metadata,
    not unavailable HTTP response bodies; this distinction is recorded in the file.
    """
    inventory = empty_inventory()
    inventory["source"]["indexURL"] = source_url(compact["indexURL"])
    inventory["source"]["hashKind"] = "sha256-normalized-numeric-metadata-v1"
    for observed in compact["books"]:
        code, slug = observed["code"], observed["slug"]
        if code not in BOOK_CODES or code in inventory["books"] or not re.fullmatch(r"[a-z0-9-]+", slug):
            raise InventoryError("invalid-browser-book")
        page_order = observed["pageOrder"]
        if not page_order or len(page_order) != len(set(page_order)) or any(not CHAPTER.fullmatch(v) for v in page_order):
            raise InventoryError("invalid-browser-page-order")
        index_url = source_url(observed["indexURL"])
        if not re.fullmatch(rf"/bible/{re.escape(slug)}/[01]/?", urlparse(index_url).path):
            raise InventoryError("browser-index-book-mismatch")
        book = {"slug": slug, "chapterOrder": [], "chapters": {}, "pageOrder": page_order,
                "pageSources": {}, "indexSource": {
                    "url": index_url,
                    "sha256": metadata_digest({"slug": slug, "pageOrder": page_order}),
                }}
        # A browser batch may finish out of order. Merge in the source's actual
        # page-navigation order so cross-page fragments remain in reading order.
        pages = observed["pages"]
        if (not isinstance(pages, list) or any(page.get("label") not in page_order for page in pages)
                or len({page["label"] for page in pages}) != len(pages)):
            raise InventoryError("invalid-browser-page")
        for page in sorted(pages, key=lambda value: page_order.index(value["label"])):
            label, url = page["label"], source_url(page["url"])
            if urlparse(url).path.rstrip("/") != f"/bible/{slug}/{label}":
                raise InventoryError("browser-page-label-mismatch")
            if label not in page_order or label in book["pageSources"]:
                raise InventoryError("invalid-browser-page")
            chapters = {}
            for section in page["chapters"]:
                chapter = section["label"]
                if not CHAPTER.fullmatch(chapter) or chapter in chapters:
                    raise InventoryError("invalid-browser-chapter")
                if "maximum" in section:
                    maximum = section["maximum"]
                    if type(maximum) is not int or not 1 <= maximum <= 999 or "verseOrder" in section:
                        raise InventoryError("invalid-browser-maximum")
                    order = [str(number) for number in range(1, maximum + 1)]
                else:
                    order = section["verseOrder"]
                omitted = section.get("omittedVerses", [])
                if (not isinstance(order, list) or not order or not isinstance(omitted, list)
                        or any(not isinstance(v, str) or not VERSE.fullmatch(v) for v in [*order, *omitted])):
                    raise InventoryError("invalid-browser-verse-order")
                chapters[chapter] = {"verseOrder": order, "omittedVerses": omitted,
                                     "duplicateVerses": [v for v, count in Counter(order).items() if count > 1]}
            if label not in chapters:
                raise InventoryError("missing-browser-page-chapter")
            page_hash = metadata_digest({"url": url, "chapterOrder": list(chapters), "chapters": chapters})
            book["pageSources"][label] = {"url": url, "sha256": page_hash, "chapterOrder": list(chapters)}
            for chapter, record in chapters.items():
                incoming = {**record, "sourcePages": [{"url": url, "sha256": page_hash}]}
                merge_chapter(book["chapters"], chapter, incoming)
        book["chapterOrder"] = list(dict.fromkeys(chapter for page in page_order if page in book["pageSources"]
                                for chapter in book["pageSources"][page]["chapterOrder"]))
        inventory["books"][code] = book
    inventory["source"]["indexSHA256"] = metadata_digest([
        {"code": code, "slug": book["slug"]} for code, book in inventory["books"].items()])
    for error in compact.get("errors", []):
        # Error payloads are constructed codes and public URLs, never copied page messages.
        if not re.fullmatch(r"[a-z0-9-]+", error["code"]):
            raise InventoryError("invalid-browser-error")
        inventory["errors"].append({"url": source_url(error["url"]), "stage": "browser", "code": error["code"]})
    inventory["complete"] = (not inventory["errors"] and set(inventory["books"]) == set(BOOK_CODES)
                             and all(set(book["pageOrder"]) == set(book["pageSources"])
                                     for book in inventory["books"].values()))
    validate_inventory(inventory, require_complete=inventory["complete"])
    return inventory


def write_inventory(path: Path, inventory: dict) -> None:
    """Atomic checkpoint containing only the explicitly constructed metadata shape."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(inventory, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def merge_chapter(chapters: dict, label: str, incoming: dict) -> None:
    """Merge repeated page excerpts, retaining actual in-page duplicate labels."""
    existing = chapters.get(label)
    if existing is None:
        chapters[label] = incoming
        return
    if any(source["url"] in {old["url"] for old in existing["sourcePages"]}
           for source in incoming["sourcePages"]):
        raise InventoryError("page-already-imported")
    if (set(existing["verseOrder"]) & set(incoming["omittedVerses"])
            or set(existing["omittedVerses"]) & set(incoming["verseOrder"])):
        raise InventoryError("conflicting-page-verse-presence")
    for field in ("verseOrder", "omittedVerses"):
        already_observed = set(existing[field])
        existing[field].extend(value for value in incoming[field] if value not in already_observed)
    existing["sourcePages"].extend(incoming["sourcePages"])
    existing["duplicateVerses"] = [v for v, count in Counter(existing["verseOrder"]).items() if count > 1]


def add_page(book: dict, label: str, url: str, body: bytes) -> None:
    parsed = parse_chapter_page(body, url, label)
    for chapter_label, chapter in parsed["chapters"].items():
        merge_chapter(book["chapters"], chapter_label, chapter)
    book["pageSources"][label] = {
        "url": url, "sha256": digest(body), "chapterOrder": parsed["chapterOrder"],
    }
    book["chapterOrder"] = list(dict.fromkeys(chapter for page in book["pageOrder"]
                            if page in book["pageSources"]
                            for chapter in book["pageSources"][page]["chapterOrder"]))


def validate_inventory(inventory: dict, require_complete: bool = True) -> None:
    if inventory.get("schemaVersion") != 1 or inventory.get("edition") != "NABRE":
        raise InventoryError("invalid-inventory-version")
    source_url(inventory["source"]["indexURL"])
    index_hash = inventory["source"].get("indexSHA256")
    if index_hash is not None and not SHA256.fullmatch(index_hash):
        raise InventoryError("invalid-index-hash")
    if require_complete and (not inventory.get("complete") or inventory.get("errors")):
        raise InventoryError("incomplete-inventory")
    if require_complete and (set(inventory["books"]) != set(BOOK_CODES) or index_hash is None):
        raise InventoryError("incomplete-book-set")
    for code, book in inventory["books"].items():
        if code not in BOOK_CODES or not re.fullmatch(r"[a-z0-9-]+", book["slug"]):
            raise InventoryError("invalid-book")
        if len(book["chapterOrder"]) != len(set(book["chapterOrder"])):
            raise InventoryError("duplicate-chapter")
        if set(book["chapterOrder"]) != set(book["chapters"]):
            raise InventoryError("inconsistent-chapter-order")
        if require_complete and (not book["pageOrder"]
                                 or set(book["pageOrder"]) != set(book["pageSources"])):
            raise InventoryError("incomplete-book-pages")
        for label, chapter in book["chapters"].items():
            if not CHAPTER.fullmatch(label) or not chapter["verseOrder"]:
                raise InventoryError("invalid-chapter")
            for field in ["verseOrder", "omittedVerses", "duplicateVerses"]:
                if any(not VERSE.fullmatch(value) for value in chapter[field]):
                    raise InventoryError("invalid-verse-label")
            duplicates = [value for value, count in Counter(chapter["verseOrder"]).items() if count > 1]
            if chapter["duplicateVerses"] != duplicates:
                raise InventoryError("invalid-duplicate-labels")
            if set(chapter["verseOrder"]) & set(chapter["omittedVerses"]):
                raise InventoryError("conflicting-verse-presence")
            if not chapter["sourcePages"]:
                raise InventoryError("missing-chapter-source")
            for source in chapter["sourcePages"]:
                source_url(source["url"])
                if not SHA256.fullmatch(source["sha256"]):
                    raise InventoryError("invalid-chapter-hash")


def fetch_inventory(path: Path, workers: int, delay: float, refresh: bool) -> dict:
    inventory = empty_inventory() if refresh or not path.exists() else json.loads(path.read_text())
    validate_inventory(inventory, require_complete=False)
    inventory["complete"], inventory["errors"] = False, []
    fetcher = Fetcher(delay=delay)

    def fail(url: str, stage: str, error: InventoryError) -> None:
        inventory["errors"].append({"url": url, "stage": stage, "code": str(error)})
        print(f"{stage}: {url}: {error}", flush=True)

    if not inventory["books"]:
        try:
            body = fetcher.get(INDEX_URL)
            inventory["books"] = parse_book_index(body)
            inventory["source"]["indexSHA256"] = digest(body)
        except InventoryError as error:
            fail(INDEX_URL, "book-index", error)
            write_inventory(path, inventory)
            return inventory
    for code, book in inventory["books"].items():
        if not book["pageOrder"]:
            url = book["indexSource"]["url"]
            try:
                body = fetcher.get(url)
                book["pageOrder"] = parse_chapter_index(body, book["slug"], url)
                book["indexSource"] = {"url": url, "sha256": digest(body)}
                selected = urlparse(url).path.rstrip("/").rsplit("/", 1)[-1]
                if selected in book["pageOrder"]:
                    add_page(book, selected, url, body)
            except InventoryError as error:
                fail(url, "chapter-index", error)
                if fetcher.blocked.is_set():
                    break
                continue
        remaining = [page for page in book["pageOrder"] if page not in book["pageSources"]]

        def fetch_page(label: str) -> tuple:
            url = f"https://bible.usccb.org/bible/{book['slug']}/{label}"
            try:
                return label, url, fetcher.get(url), None
            except InventoryError as error:
                return label, url, None, error

        # map preserves the published page order even when requests finish out of order.
        with ThreadPoolExecutor(max_workers=workers) as pool:
            for label, url, body, error in pool.map(fetch_page, remaining):
                if error is not None:
                    fail(url, "chapter", error)
                else:
                    try:
                        add_page(book, label, url, body)
                    except InventoryError as error:
                        fail(url, "chapter-parse", error)
                # Drop the only returned HTTP body before writing numeric metadata.
                body = None
                write_inventory(path, inventory)
        print(f"{code}: {len(book['pageSources'])}/{len(book['pageOrder'])} pages", flush=True)
        if fetcher.blocked.is_set():
            break
    inventory["complete"] = (not inventory["errors"] and set(inventory["books"]) == set(BOOK_CODES)
                             and all(book["pageOrder"] and set(book["pageOrder"]) == set(book["pageSources"])
                                     for book in inventory["books"].values()))
    validate_inventory(inventory, require_complete=inventory["complete"])
    write_inventory(path, inventory)
    return inventory


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fetch", action="store_true")
    parser.add_argument("--refresh", action="store_true", help="Replace numeric metadata after a fresh full crawl")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--import-browser", type=Path, help="Import compact numeric DOM observations, never HTML")
    parser.add_argument("--output", type=Path, default=OUTPUT)
    parser.add_argument("--workers", type=int, choices=range(1, 5), default=2)
    parser.add_argument("--delay", type=float, default=0.5, help="Minimum seconds between request starts (at least 0.25)")
    args = parser.parse_args()
    if args.delay < 0.25:
        parser.error("--delay must be at least 0.25 seconds")
    if args.refresh and not args.fetch:
        parser.error("--refresh requires --fetch")
    if args.import_browser and args.fetch:
        parser.error("--import-browser and --fetch are separate acquisition methods")
    try:
        if args.import_browser:
            inventory = import_browser_inventory(json.loads(args.import_browser.read_text()))
            write_inventory(args.output, inventory)
        elif args.fetch:
            inventory = fetch_inventory(args.output, args.workers, args.delay, args.refresh)
        else:
            inventory = json.loads(args.output.read_text())
        validate_inventory(inventory)
    except (InventoryError, OSError, json.JSONDecodeError) as error:
        print(f"NABRE inventory unavailable: {error}")
        return 1
    print(f"NABRE inventory complete: {len(inventory['books'])} books; numeric metadata only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
