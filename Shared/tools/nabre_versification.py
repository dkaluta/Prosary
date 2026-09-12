#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline NABRE reference inventory. Contains no Bible wording.

The inventory is extracted from the USCCB's own chapter/verse markers. It is
deliberately separate from translation correspondence: matching verse labels or
chapter lengths does not establish that two editions divide a passage alike.
"""
from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

DIRECTORY = Path(__file__).resolve().parent / "versification" / "nabre"
INVENTORY_PATH = DIRECTORY / "structure.json"
BOOKS = frozenset((
    "GEN EXO LEV NUM DEU JOS JDG RUT 1SA 2SA 1KI 2KI 1CH 2CH EZR NEH TOB JDT EST "
    "1MA 2MA JOB PSA PRO ECC SNG WIS SIR ISA JER LAM BAR EZK DAN HOS JOL AMO OBA "
    "JON MIC NAM HAB ZEP HAG ZEC MAL MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP "
    "COL 1TH 2TH 1TI 2TI TIT PHM HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV"
).split())
_CHAPTER = re.compile(r"[1-9][0-9]*|[A-F]")
_VERSE = re.compile(r"[1-9][0-9]*[a-z]?(?:-[1-9][0-9]*[a-z]?)?")
_HASH = re.compile(r"[0-9a-f]{64}")


class InvalidInventory(ValueError):
    pass


def _fields(value: object, allowed: set[str], required: set[str], label: str) -> dict:
    if not isinstance(value, dict) or not required <= value.keys() or not value.keys() <= allowed:
        raise InvalidInventory(f"Unexpected or missing {label} fields")
    return value


def _source(value: object, label: str) -> None:
    source = _fields(value, {"url", "sha256"}, {"url", "sha256"}, label)
    url = urlsplit(source["url"])
    if (url.scheme != "https" or url.netloc != "bible.usccb.org"
            or not url.path.startswith("/bible/") or url.query or url.fragment
            or not isinstance(source["sha256"], str) or not _HASH.fullmatch(source["sha256"])):
        raise InvalidInventory(f"Invalid {label} provenance")


class NabreInventory:
    """Validate actual published labels, preserving their published sequence."""

    def __init__(self, path: Path = INVENTORY_PATH, *, require_complete: bool = True):
        self.path = path
        self.data = json.loads(path.read_text(encoding="utf-8"))
        _fields(self.data, {"schemaVersion", "edition", "source", "books", "complete", "errors"},
                {"schemaVersion", "edition", "source", "books", "complete", "errors"}, "inventory")
        if self.data["schemaVersion"] != 1 or self.data["edition"] != "NABRE":
            raise InvalidInventory("Unsupported NABRE inventory")
        if type(self.data["complete"]) is not bool or not isinstance(self.data["errors"], list):
            raise InvalidInventory("Invalid inventory completion state")
        source = _fields(self.data["source"], {"indexURL", "indexSHA256", "hashKind"},
                         {"indexURL", "indexSHA256"}, "index")
        if (source["indexURL"].rstrip("/") != "https://bible.usccb.org/bible"
                or not isinstance(source["indexSHA256"], str)
                or not _HASH.fullmatch(source["indexSHA256"])):
            raise InvalidInventory("Invalid inventory index provenance")
        if source.get("hashKind", "sha256-decoded-http-body") not in {
                "sha256-decoded-http-body", "sha256-normalized-numeric-metadata-v1"}:
            raise InvalidInventory("Unknown inventory provenance hash kind")
        self.books = self.data["books"]
        if not isinstance(self.books, dict) or not self.books.keys() <= BOOKS:
            raise InvalidInventory("Unknown NABRE book")
        if require_complete and (not self.data["complete"] or self.data["errors"] or self.books.keys() != BOOKS):
            raise InvalidInventory("NABRE inventory is incomplete; finish the metadata crawl")
        for book, data in self.books.items():
            _fields(data, {"slug", "chapterOrder", "chapters", "pageOrder", "pageSources", "indexSource"},
                    {"slug", "chapterOrder", "chapters"}, "book")
            if not isinstance(data["slug"], str) or not re.fullmatch(r"[a-z0-9-]+", data["slug"]):
                raise InvalidInventory(f"Invalid book slug: {book}")
            order, chapters = data["chapterOrder"], data["chapters"]
            if (not isinstance(order, list) or not order or any(
                    not isinstance(c, str) or not _CHAPTER.fullmatch(c) for c in order)
                    or len(order) != len(set(order)) or not isinstance(chapters, dict)
                    or not chapters.keys() <= set(order)):
                raise InvalidInventory(f"Invalid chapter sequence: {book}")
            if require_complete and set(order) != chapters.keys():
                raise InvalidInventory(f"Missing NABRE chapters: {book}")
            if "indexSource" in data:
                _source(data["indexSource"], "book index")
            if "pageOrder" in data or "pageSources" in data:
                pages, sources = data.get("pageOrder"), data.get("pageSources")
                if (not isinstance(pages, list) or not pages or len(pages) != len(set(pages))
                        or any(not isinstance(p, str) or not _CHAPTER.fullmatch(p) for p in pages)
                        or not isinstance(sources, dict) or not sources.keys() <= set(pages)):
                    raise InvalidInventory("Invalid source page inventory")
                if require_complete and sources.keys() != set(pages):
                    raise InvalidInventory("Missing source pages")
                published_order = []
                for page in pages:
                    if page not in sources:
                        continue
                    entry = _fields(sources[page], {"url", "sha256", "chapterOrder"},
                                    {"url", "sha256", "chapterOrder"}, "source page")
                    _source({key: entry[key] for key in ("url", "sha256")}, "page")
                    if not isinstance(entry["chapterOrder"], list):
                        raise InvalidInventory("Invalid page chapter order")
                    published_order.extend(entry["chapterOrder"])
                if list(dict.fromkeys(published_order)) != order:
                    raise InvalidInventory("Page and chapter orders disagree")
            for chapter, metadata in chapters.items():
                _fields(metadata, {"verseOrder", "omittedVerses", "duplicateVerses", "sourcePages"},
                        {"verseOrder", "omittedVerses", "duplicateVerses", "sourcePages"}, "chapter")
                for key in ("verseOrder", "omittedVerses", "duplicateVerses"):
                    labels = metadata[key]
                    if not isinstance(labels, list) or any(
                            not isinstance(v, str) or not _VERSE.fullmatch(v) for v in labels):
                        raise InvalidInventory(f"Invalid verse labels: {book} {chapter}")
                labels = metadata["verseOrder"]
                if not labels or not set(metadata["duplicateVerses"]) <= set(labels):
                    raise InvalidInventory(f"Invalid chapter inventory: {book} {chapter}")
                repeated = {v for v in labels if labels.count(v) > 1}
                if repeated != set(metadata["duplicateVerses"]):
                    raise InvalidInventory(f"Unreported repeated verse: {book} {chapter}")
                if set(labels) & set(metadata["omittedVerses"]):
                    raise InvalidInventory(f"A verse cannot be present and omitted: {book} {chapter}")
                if not isinstance(metadata["sourcePages"], list) or not metadata["sourcePages"]:
                    raise InvalidInventory(f"Missing chapter provenance: {book} {chapter}")
                for page in metadata["sourcePages"]:
                    _source(page, "chapter")

    def chapter(self, book: str, chapter: str | int) -> dict:
        try:
            return self.books[book]["chapters"][str(chapter)]
        except KeyError as error:
            raise InvalidInventory(f"NABRE chapter not inventoried: {book} {chapter}") from error

    def contains(self, book: str, chapter: str | int, verse: str | int) -> bool:
        metadata = self.chapter(book, chapter)
        label = str(verse)
        return label in metadata["verseOrder"] and label not in metadata["duplicateVerses"]

    def span(self, book: str, start_chapter: str | int, start_verse: str | int,
             end_chapter: str | int, end_verse: str | int) -> list[tuple[str, str, str]]:
        """Expand in published order, never manufacturing omitted verse numbers."""
        start_chapter, end_chapter = str(start_chapter), str(end_chapter)
        start_verse, end_verse = str(start_verse), str(end_verse)
        try:
            order = self.books[book]["chapterOrder"]
            first, last = order.index(start_chapter), order.index(end_chapter)
        except (KeyError, ValueError) as error:
            raise InvalidInventory("Unknown NABRE span boundary") from error
        if first > last:
            raise InvalidInventory("Reversed NABRE chapter span")
        result = []
        for chapter in order[first:last + 1]:
            metadata = self.chapter(book, chapter)
            labels = metadata["verseOrder"]
            try:
                start = labels.index(start_verse) if chapter == start_chapter else 0
                end = labels.index(end_verse) if chapter == end_chapter else len(labels) - 1
            except ValueError as error:
                raise InvalidInventory("NABRE verse boundary is absent or omitted") from error
            if start > end:
                raise InvalidInventory("Reversed NABRE verse span")
            selected = labels[start:end + 1]
            if set(selected) & set(metadata["duplicateVerses"]):
                raise InvalidInventory("NABRE span has ambiguous repeated labels")
            result.extend((book, chapter, verse) for verse in selected)
        return result


@lru_cache(maxsize=1)
def inventory() -> NabreInventory:
    return NabreInventory()


if __name__ == "__main__":
    result = inventory()
    chapters = sum(len(book["chapters"]) for book in result.books.values())
    verses = sum(len(chapter["verseOrder"]) for book in result.books.values()
                 for chapter in book["chapters"].values())
    print(f"Verified NABRE metadata: {len(result.books)} books, {chapters} chapters, {verses} verse markers; no Scripture text.")
