#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Collect the published Our Parish Priest Saints & Sinners category for review.

This source-only catalogue never writes native app data. The site's public
WordPress API supplies the actual published post IDs, URLs and complete rendered
article HTML. No article URLs, months or saint names are guessed. The biography
is the source's A. KUWENTO NG BUHAY section, ending at B. HAMON SA BUHAY.
Songs/prayers, reflections and source credits remain separate from biography.

Run: uv run --script Shared/tools/scrape-tagalog-saints.py
Offline: ... --parse-json /tmp/saved-response.json --parse-url URL
Rebuild a saved catalogue's extraction without network: ... --review-existing
"""
from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import hashlib
import json
import math
import re
import subprocess
import tempfile
import time
import unicodedata
from collections import Counter, defaultdict
from email.utils import parsedate_to_datetime
from html import escape
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit

import scrapy
from protego import Protego
from scrapy.crawler import CrawlerProcess
from scrapy.exceptions import IgnoreRequest
from scrapy.http import Headers, TextResponse
from scrapy.selector import Selector
from twisted.internet.error import ConnectionLost

TOOLS = Path(__file__).resolve().parent
BASE = "https://www.ourparishpriest.com/"
INDEX = BASE + "saints-sinners/"
ABOUT = BASE + "about/"
ROBOTS = BASE + "robots.txt"
USER_AGENT = "ProsaryTagalogSaintsReview/1.0 (+https://prosary.app)"
FIELDS = "id,link,date,modified,title,categories,content"
INDEX_FIELDS = "id,link,date,modified,title,categories"
MONTHS = {
    "enero": 1, "january": 1, "pebrero": 2, "february": 2,
    "marso": 3, "march": 3, "abril": 4, "april": 4, "mayo": 5, "may": 5,
    "hunyo": 6, "june": 6, "hulyo": 7, "july": 7, "agosto": 8, "august": 8,
    "setyembre": 9, "septiyembre": 9, "september": 9, "oktubre": 10, "october": 10,
    "nobyembre": 11, "november": 11, "disyembre": 12, "december": 12,
}
MONTH_PATTERN = "(?:" + "|".join(sorted(MONTHS, key=len, reverse=True)) + ")"
DATE = re.compile(rf"\b({MONTH_PATTERN})\s+([0-9]{{1,2}})(?![0-9])", re.I)
DATE_REVERSE = re.compile(rf"\b([0-9]{{1,2}})\s+(?:ng\s+)?({MONTH_PATTERN})\b", re.I)
BIO = re.compile(r"^A\s*[.)]?\s*KUWENTO\s+NG\s+BUHAY\s*:?\s*$", re.I)
REFLECTION = re.compile(r"^B\s*[.)]?\s*HAMON\s+SA\s+BUHAY\s*:?\s*$", re.I)
ENDING = re.compile(r"^[KC]\s*[.)]?\s*KATAGA\s+NG\s+BUHAY\s*:?\s*$", re.I)
CREDIT = re.compile(r"(?:mula\s+sa\s+aklat|from\s+(?:the\s+)?book|by\s+Fr\.?|"
                    r"Fr\.?\s*R\.?\s*Marcos|Isang\s+Sulyap\s+sa\s+mga\s+Santo|"
                    r"\bSource\s*:|Abriol|Paulines\s+Publishing|©|Copyright)", re.I)
TAGALOG_WORDS = frozenset("ang ng mga sa si siya sina ni nila niya kanyang kaniya kaniyang nang "
                         "noong dahil kaya isang naging naman ito din rin upang kung kapag ating "
                         "natin tayo sila ay mula hindi walang higit lahat araw buhay diyos mahal "
                         "gawain loob sarili taong tao panahon banal pananampalataya dasal ".split())
ENGLISH_WORDS = frozenset("the and of to in he she his her is was were are that with for a an "
                         "this from on as by who but they their it at had have has".split())
BLOCKS = {"p", "div", "li", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "tr"}
EXCLUDED = {"script", "style", "noscript", "form", "iframe", "object", "nav", "footer",
            "img", "audio", "video", "source", "svg"}
PIO_VATICAN = "https://www.vatican.va/news_services/liturgy/saints/ns_lit_doc_20020616_padre-pio_en.html"


def sha256(value: bytes | str) -> str:
    return hashlib.sha256(value.encode("utf-8") if isinstance(value, str) else value).hexdigest()


def source_robots(body: bytes, status: int, content_type: str) -> Protego:
    """A successful challenge or unknown document is not an empty robots policy."""
    if status not in {200, 404}:
        raise ValueError("Robots unavailable")
    if status == 404:
        return Protego.parse("")
    text = body.decode("utf-8")
    if ("html" in content_type.lower() or re.search(r"<(?:html|script|!doctype)\b", text, re.I) or
            (text.strip() and not re.search(r"(?im)^\s*User-agent\s*:", text))):
        raise ValueError("Robots response is not a recognizable policy; no category requests allowed")
    return Protego.parse(text)


def whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def source_url(url: str, base: str = BASE) -> str | None:
    """Only public source HTML, never media, credentials, query searches or login."""
    try:
        parts = urlsplit(urljoin(base, url))
        if (parts.scheme not in {"http", "https"} or
                parts.hostname not in {"ourparishpriest.com", "www.ourparishpriest.com"} or
                parts.username or parts.password or parts.port or parts.query or parts.fragment):
            return None
        path = parts.path
        if path in {"/saints-sinners/", "/about/", "/robots.txt"} or re.fullmatch(
                r"/[0-9]{4}/[0-9]{2}/[a-z0-9%-]+/", path):
            return BASE + path.lstrip("/")
    except (ValueError, TypeError):
        pass
    return None


def api_url(category_id: int, page: int = 1) -> str:
    return BASE + "wp-json/wp/v2/posts?" + urlencode({"categories": category_id,
        "per_page": 100, "page": page, "_fields": FIELDS})


def allowed_api_url(url: str, category_id: int | None = None) -> bool:
    try:
        parts = urlsplit(url)
        values = parse_qs(parts.query)
        return (parts.scheme == "https" and parts.netloc == "www.ourparishpriest.com" and
                not parts.fragment and parts.path == "/wp-json/wp/v2/posts" and
                set(values) == {"categories", "per_page", "page", "_fields"} and
                all(len(value) == 1 for value in values.values()) and
                re.fullmatch(r"[1-9][0-9]*", values["categories"][0]) is not None and
                (category_id is None or int(values["categories"][0]) == category_id) and
                values["per_page"] == ["100"] and values["_fields"] == [FIELDS] and
                re.fullmatch(r"[1-9][0-9]*", values["page"][0]) is not None)
    except (ValueError, TypeError, KeyError):
        return False


def _text(element) -> str:
    if not isinstance(element.tag, str) or element.tag.lower() in EXCLUDED:
        return ""
    text = [element.text or ""]
    for child in element:
        tag = child.tag.lower() if isinstance(child.tag, str) else ""
        if tag == "br":
            text.append("\n")
        elif tag not in EXCLUDED:
            text.append(("\n" if tag in BLOCKS else "") + _text(child) +
                        ("\n" if tag in BLOCKS else ""))
        text.append(child.tail or "")
    return "".join(text)


def source_blocks(rendered: str) -> list[str]:
    """Read author prose in order; omit dynamic share counters and media alt text."""
    root = Selector(text="<div id='prosary-source'>" + rendered + "</div>").css("#prosary-source")[0].root
    for child in list(root.xpath(".//*[contains(concat(' ', normalize-space(@class), ' '), ' sfsiaftrpstwpr ') "
                                "or contains(concat(' ', normalize-space(@class), ' '), ' post-views ')]")):
        child.getparent().remove(child)

    def walk(node):
        tag = node.tag.lower() if isinstance(node.tag, str) else ""
        if tag in EXCLUDED:
            return []
        children = [child for child in node if isinstance(child.tag, str) and child.tag.lower() in BLOCKS]
        if tag in {"p", "li", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "tr"} or not children:
            return [whitespace(line) for line in _text(node).splitlines() if whitespace(line)]
        result = []
        pending = node.text or ""
        for child in node:
            child_tag = child.tag.lower() if isinstance(child.tag, str) else ""
            if child_tag in BLOCKS:
                result.extend(whitespace(line) for line in pending.splitlines() if whitespace(line))
                pending = ""
                result.extend(walk(child))
            elif child_tag == "br":
                pending += "\n"
            elif child_tag not in EXCLUDED:
                pending += _text(child)
            pending += child.tail or ""
        result.extend(whitespace(line) for line in pending.splitlines() if whitespace(line))
        return result
    return walk(root)


def language_evidence(paragraphs: list[str]) -> dict:
    """Conservative prose lexicon screen, explicitly not metadata or certification."""
    words = re.findall(r"\b[^\W\d_]+\b", " ".join(paragraphs).casefold())
    counts = Counter(word for word in words if word in TAGALOG_WORDS)
    tagalog = sum(counts.values())
    english = sum(word in ENGLISH_WORDS for word in words)
    share = tagalog / len(words) if words else 0
    accepted = len(words) >= 35 and tagalog >= 8 and len(counts) >= 6 and share >= .085
    return {"method": "source-prose Tagalog function-word lexicon; title/menu/HTML language ignored",
            "wordCount": len(words), "tagalogMarkerCount": tagalog,
            "distinctTagalogMarkers": len(counts), "tagalogMarkerShare": round(share, 4),
            "englishFunctionWordShare": round(english / len(words), 4) if words else 0,
            "markers": dict(sorted(counts.items())), "tagalogCandidate": accepted,
            "reviewRequired": True}


def dates_from_labels(paragraphs: list[str]) -> list[dict]:
    """Only short pre-biography feast labels, never posting dates or narrative dates."""
    values = []
    for line in paragraphs:
        if len(line.split()) > 24:
            continue
        for matcher, reversed_date in ((DATE, False), (DATE_REVERSE, True)):
            for match in matcher.finditer(line):
                month, day = (match[2], match[1]) if reversed_date else (match[1], match[2])
                try:
                    dt.date(2000, MONTHS[month.casefold()], int(day))
                except ValueError:
                    continue
                item = {"literal": match[0], "sourceLine": line,
                        "month": MONTHS[month.casefold()], "day": int(day),
                        "mappingStatus": "source-label-only; calendar identity/precedence not assigned"}
                if item not in values:
                    values.append(item)
    return values


def sections_from_blocks(blocks: list[str]) -> tuple[dict, list[str]]:
    sections = {"preamble": [], "biography": [], "songsOrPrayers": [],
                "reflection": [], "scriptureOrPrayerEnding": [], "other": []}
    notes = []
    section = "preamble"
    has_biography = False
    for line in blocks:
        if BIO.fullmatch(line):
            section = "biography"
            has_biography = True
            continue
        if REFLECTION.fullmatch(line):
            section = "reflection"
            continue
        if ENDING.fullmatch(line):
            section = "scriptureOrPrayerEnding"
            continue
        if section == "biography" and (re.search(r"^Narito.*\b(?:awit|awiting|kanta|song)\b", line, re.I)
                or re.fullmatch(r"(?:PANALANGIN|PRAYER|AWIT|SONG|REFRAIN|FINALE)\s*:?.{0,80}", line)
                or re.match(r"^(?:Refrain|FINALE)\s*:", line)):
            notes.append("Embedded song/prayer begins at source line: " + line)
            section = "songsOrPrayers"
        sections[section].append(line)
    if not has_biography:
        notes.append("No explicit A. KUWENTO NG BUHAY section; never treat unmarked prose as biography.")
        sections["other"] = sections.pop("preamble")
        sections["preamble"] = []
    return sections, notes


def identity_label(title: str) -> str:
    return re.sub(rf"^SAINTS?\s+OF\s+{MONTH_PATTERN}\s*:\s*", "", title, flags=re.I).strip()


def identity_key(label: str) -> str:
    text = "".join(char for char in unicodedata.normalize("NFKD", label.casefold())
                   if not unicodedata.combining(char))
    return re.sub(r"[^a-z0-9]+", "-", text).strip("-")


def extract_post(post: dict, response_url: str, response_digest: str) -> dict:
    rendered = post.get("content", {}).get("rendered", "")
    if not isinstance(rendered, str):
        raise ValueError("Non-text published source content")
    title = whitespace(Selector(text=post.get("title", {}).get("rendered", "")).xpath("string(.)").get() or "")
    blocks = source_blocks(rendered)
    sections, notes = sections_from_blocks(blocks)
    biography = sections["biography"]
    evidence = language_evidence(biography)
    dates = dates_from_labels(sections["preamble"])
    credits = [line for line in blocks if CREDIT.search(line)]
    rejection = []
    if not biography:
        rejection.append("no-explicit-biography-section")
    elif not evidence["tagalogCandidate"]:
        rejection.append("biography-not-demonstrably-Tagalog")
    date_keys = {(value["month"], value["day"]) for value in dates}
    if biography and len(date_keys) != 1:
        rejection.append("missing-or-ambiguous-source-feast-label")
    findings = []
    label = identity_label(title)
    if re.search(r"PADRE\s+PIO|PIO\s+NG\s+PIETRELCINA", title, re.I):
        death_lines = [line for line in biography if re.search(r"namatay|kamatayan|pumanaw", line, re.I)
                       and re.search(r"\b196[89]\b", line)]
        years = sorted(set(re.findall(r"\b196[89]\b", " ".join(death_lines))))
        if "1969" in years:
            findings.append({"type": "source-death-year-error", "sourceYears": years,
                "sourceLines": death_lines,
                "corroboration": {"provider": "Holy See", "sourceURL": PIO_VATICAN,
                    "verifiedAt": "2026-10-03", "deathDate": "1968-09-23",
                    "feastMonthDay": "09-23", "method": "live official canonization biography checked"},
                "decision": "Quarantine this source biography. Preserve its original wording; do not silently replace 1969."})
            rejection.append("source-factual-error-confirmed-by-Holy-See")
    links = []
    for href in Selector(text=rendered).css("a::attr(href)").getall():
        target = source_url(href, post["link"])
        if target and target not in links:
            links.append(target)
    return {"recordId": f"our-parish-priest:{post['id']}", "wordPressPostID": post["id"],
        "sourceURL": source_url(post["link"]), "sourceResponseURL": response_url,
        "sourceResponseSHA256": response_digest, "sourceHTMLSHA256": sha256(rendered),
        "sourceTextSHA256": sha256("\n".join(blocks)), "sourcePublishedAt": post.get("date"),
        "sourceModifiedAt": post.get("modified"), "sourceTitle": title,
        "sourceCapture": {"method": "published source content supplied to extractor",
                          "contentCaptured": isinstance(post.get("content"), dict)},
        "identityCandidate": {"label": label, "literalTitleKey": identity_key(label),
            "reviewStatus": "provisional; no Prosary calendar identity assigned"},
        "sourceFeastLabels": dates, "literalCredits": credits,
        "sourceHTML": rendered, "sourceParagraphs": blocks, "sections": sections,
        "biographyTextSHA256": sha256("\n".join(biography)),
        "languageEvidence": evidence, "articleLanguageEvidence": language_evidence(blocks),
        "separationNotes": notes, "publishedArticleLinks": links,
        "classification": "Tagalog-biography-review-candidate" if not rejection else "quarantined-source",
        "review": {"status": "quarantined" if rejection else "editorial-and-reuse-review-required",
            "reasons": rejection, "findings": findings}, "categoryIds": post.get("categories", [])}


def group_duplicates(records: list[dict]) -> tuple[list[dict], list[str]]:
    """Group only identical normalized literal headings with matching printed dates.

    This is deliberately not saint synonym matching. Preserve every source record
    and date/title spelling; choose the latest valid edition, explain the evidence.
    """
    groups = defaultdict(list)
    for record in records:
        if not record["sections"]["biography"]:
            continue
        dates = sorted({(value["month"], value["day"]) for value in record["sourceFeastLabels"]})
        group = record["identityCandidate"]["literalTitleKey"] + "|" + json.dumps(dates)
        groups[group].append(record)
    duplicates, selected = [], []
    for key, editions in sorted(groups.items()):
        candidates = [record for record in editions if record["classification"] == "Tagalog-biography-review-candidate"]
        latest = max(candidates, key=lambda item: (item["sourcePublishedAt"] or "", item["sourceModifiedAt"] or "",
                                                 item["wordPressPostID"])) if candidates else None
        if latest:
            selected.append(latest["recordId"])
        if len(editions) > 1:
            duplicates.append({"groupKey": key, "evidence": "identical normalized literal title and source feast month/day",
                "recordIds": [item["recordId"] for item in sorted(editions, key=lambda value: value["wordPressPostID"])],
                "selectedRecordId": latest["recordId"] if latest else None,
                "selection": "latest non-quarantined publication, then modification, then published post ID; every edition retained",
                "differentBiographyHashes": len({item["biographyTextSHA256"] for item in editions})})
    return duplicates, sorted(selected)


def atomic_json(path: Path, value: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    try:
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


class BoundaryMiddleware:
    def __init__(self, crawler):
        self.crawler = crawler

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    def process_request(self, request, spider=None):
        spider = spider or self.crawler.spider
        if source_url(request.url) not in {ROBOTS, INDEX, ABOUT} and not allowed_api_url(request.url, spider.category_id):
            spider.errors.append({"type": "out-of-scope-request", "url": request.url})
            raise IgnoreRequest("Only published category discovery and category REST responses are in scope")
        spider.attempted_requests += 1
        if spider.attempted_requests > spider.args.max_requests or spider.response_bytes >= spider.args.max_bytes:
            spider.budget_limited = True
            raise IgnoreRequest("Source review crawl budget reached")


class RetryBackoffMiddleware:
    def __init__(self, crawler):
        self.crawler = crawler

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    async def process_response(self, request, response, spider=None):
        spider = spider or self.crawler.spider
        spider.response_bytes += len(response.body)
        if spider.response_bytes > spider.args.max_bytes:
            spider.budget_limited = True
        if response.status in {429, 500, 502, 503, 504} and request.meta.get("retry_times", 0) < 2:
            delay = 4 * (2 ** request.meta.get("retry_times", 0))
            header = response.headers.get("Retry-After", b"").decode("ascii", errors="ignore")
            try:
                delay = max(delay, float(header))
            except ValueError:
                try:
                    delay = max(delay, (parsedate_to_datetime(header) - dt.datetime.now(dt.timezone.utc)).total_seconds())
                except (ValueError, TypeError, OverflowError):
                    pass
            await asyncio.sleep(min(30, delay))
        return response


class CurlTransportMiddleware:
    """Use the host's working HTTPS transport after Scrapy cache/robots checks.

    Scrapy's Twisted TLS connections are closed by this source in the current
    host environment. curl supplies a bounded GET response to the same spider,
    without following redirects, cookies, media, credentials or any extra URLs.
    Middleware responses bypass Scrapy's downloader delay, so this transport
    enforces the serial two-second interval itself, including robots requests.
    """
    def __init__(self, crawler):
        self.crawler = crawler
        self.lock = asyncio.Lock()
        self.last_completion = 0.0

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    @staticmethod
    def fetch(request, max_bytes):
        with tempfile.TemporaryDirectory(prefix="prosary-tagalog-response-") as folder:
            header_path, body_path = Path(folder) / "headers", Path(folder) / "body"
            result = subprocess.run(["curl", "--silent", "--show-error", "--compressed",
                "--max-time", "35", "--max-filesize", str(max_bytes),
                "--user-agent", USER_AGENT, "--dump-header", str(header_path),
                "--output", str(body_path), "--url", request.url],
                capture_output=True, timeout=40)
            if result.returncode:
                raise ConnectionLost("Bounded curl GET failed: " + result.stderr.decode("utf-8", errors="replace")[:250])
            raw_headers = header_path.read_bytes().replace(b"\r\n", b"\n")
            header_blocks = [block for block in raw_headers.split(b"\n\n") if block.startswith(b"HTTP/")]
            if not header_blocks:
                raise ConnectionLost("Bounded curl GET returned no HTTP response headers")
            lines = header_blocks[-1].splitlines()
            status = int(lines[0].split()[1])
            headers = Headers()
            for line in lines[1:]:
                if b":" not in line:
                    continue
                key, value = line.split(b":", 1)
                # curl already expands the response body; do not decompress twice.
                if key.lower() not in {b"content-encoding", b"content-length", b"transfer-encoding"}:
                    headers.appendlist(key, value.strip())
            return TextResponse(request.url, status=status, headers=headers,
                body=body_path.read_bytes(), encoding="utf-8", request=request)

    async def process_request(self, request, spider=None):
        spider = spider or self.crawler.spider
        async with self.lock:
            await asyncio.sleep(max(0, self.last_completion + spider.args.delay - time.monotonic()))
            try:
                return await asyncio.to_thread(self.fetch, request, spider.args.max_bytes)
            finally:
                self.last_completion = time.monotonic()


class TagalogSaintsSpider(scrapy.Spider):
    name = "tagalog_saints_review"
    allowed_domains = ["www.ourparishpriest.com", "ourparishpriest.com"]

    def __init__(self, args, **kwargs):
        super().__init__(**kwargs)
        self.args = args
        self.records = {}
        self.category_id = None
        self.pages = {}
        self.errors = []
        self.source_policy = {}
        self.robots = {"sourceURL": ROBOTS, "status": None, "categoryAllowed": None}
        self.collection_total = None
        self.expected_pages = None
        self.budget_limited = False
        self.attempted_requests = 0
        self.response_bytes = 0
        self.completed = False
        self.robot_parser = None

    async def start(self):
        yield scrapy.Request(ROBOTS, callback=self.parse_robots, errback=self.request_failed,
                             meta={"dont_obey_robotstxt": True, "handle_httpstatus_list": [404]})

    def parse_robots(self, response):
        self.robots.update({"status": response.status, "sourceSHA256": sha256(response.body),
                            "sourceText": response.text})
        try:
            self.robot_parser = source_robots(response.body, response.status,
                response.headers.get("Content-Type", b"").decode("ascii", errors="ignore"))
        except (ValueError, UnicodeError) as error:
            self.errors.append({"type": "robots-unavailable-or-unrecognized", "status": response.status,
                                "detail": str(error)})
            return
        self.robots["categoryAllowed"] = self.robot_parser.can_fetch(INDEX, USER_AGENT)
        if not self.robots["categoryAllowed"]:
            self.errors.append({"type": "robots-disallows-index"})
            return
        published_delay = self.robot_parser.crawl_delay(USER_AGENT)
        effective_delay = max(self.args.delay, float(published_delay or 0))
        if not math.isfinite(effective_delay):
            self.errors.append({"type": "invalid-source-crawl-delay"})
            return
        self.args.delay = effective_delay
        self.robots.update({"publishedCrawlDelaySeconds": published_delay,
                            "effectiveDelaySeconds": effective_delay})
        yield scrapy.Request(INDEX, callback=self.parse_index, errback=self.request_failed)
        yield scrapy.Request(ABOUT, callback=self.parse_about, errback=self.request_failed)

    def parse_index(self, response):
        selector = Selector(text=response.text)
        matches = []
        for element in selector.css("[data-args]"):
            query = parse_qs(element.attrib["data-args"])
            if query.get("tax_query[0][taxonomy]") == ["category"]:
                values = query.get("tax_query[0][terms][0]", [])
                if len(values) == 1 and re.fullmatch(r"[1-9][0-9]*", values[0]):
                    matches.append(int(values[0]))
        api_link = selector.css('link[rel="https://api.w.org/"]::attr(href)').get()
        if len(set(matches)) != 1 or not api_link or urljoin(response.url, api_link) != BASE + "wp-json/":
            self.errors.append({"type": "unrecognized-published-category-or-api", "url": response.url,
                                "publishedCategoryIds": matches, "advertisedAPI": api_link})
            return
        self.category_id = matches[0]
        self.source_policy["discovery"] = {"indexURL": response.url, "indexHTMLSHA256": sha256(response.body),
            "categoryID": self.category_id, "advertisedAPI": api_link,
            "method": "published category widget taxonomy ID and advertised public WordPress API; GET only"}
        print(f"Discovered published Saints & Sinners category {self.category_id}; reading actual post URLs/content from the advertised API.", flush=True)
        target = api_url(self.category_id)
        if not self.robot_parser.can_fetch(target, USER_AGENT):
            self.errors.append({"type": "robots-disallows-category-api", "url": target})
            return
        yield scrapy.Request(target, callback=self.parse_collection, errback=self.request_failed)

    def parse_about(self, response):
        selector = Selector(text=response.text)
        rendered = selector.css("section.entry-content").get() or ""
        self.source_policy["reuse"] = {"aboutURL": response.url, "sourceHTMLSHA256": sha256(response.body),
            "sourceParagraphs": source_blocks(rendered),
            "copyrightLiteral": "All Rights Reserved" if "All Rights Reserved" in response.text else None,
            "status": "preserve literal attribution request; no standard open license or app reuse approval inferred"}

    def parse_collection(self, response):
        page = int(parse_qs(urlsplit(response.url).query)["page"][0])
        try:
            posts = json.loads(response.body)
            total = int(response.headers.get("X-WP-Total", b"-1"))
            pages = int(response.headers.get("X-WP-TotalPages", b"-1"))
            if not isinstance(posts, list) or not posts or total <= 0 or pages <= 0:
                raise ValueError("Missing published collection body/counts")
            if self.collection_total is not None and (total != self.collection_total or pages != self.expected_pages):
                raise ValueError("Published collection changed during crawl")
            self.collection_total, self.expected_pages = total, pages
            digest = sha256(response.body)
            self.pages[page] = {"url": response.url, "sourceResponseSHA256": digest,
                                "postCount": len(posts), "publishedTotal": total, "publishedPages": pages}
            for post in posts:
                if (not isinstance(post, dict) or not isinstance(post.get("id"), int) or
                        self.category_id not in post.get("categories", []) or
                        not source_url(post.get("link", "")) or
                        not isinstance(post.get("content"), dict) or post["content"].get("protected") is True):
                    raise ValueError("Unrecognized or protected source post")
                record = extract_post(post, response.url, digest)
                previous = self.records.get(post["id"])
                if previous and previous != record:
                    raise ValueError("Published post repeated with different metadata/content")
                self.records[post["id"]] = record
            print(f"Collection page {page}/{pages}: {len(posts)} source posts; {len(self.records)}/{total} preserved.", flush=True)
        except (ValueError, TypeError, KeyError) as error:
            self.errors.append({"type": "collection-shape-or-count-error", "url": response.url, "detail": str(error)})
            return
        if page < pages:
            if page >= self.args.max_pages:
                self.budget_limited = True
                return
            target = api_url(self.category_id, page + 1)
            if not self.robot_parser.can_fetch(target, USER_AGENT):
                self.errors.append({"type": "robots-disallows-category-api", "url": target})
                return
            yield scrapy.Request(target, callback=self.parse_collection, errback=self.request_failed)

    def request_failed(self, failure):
        error = {"type": "request-failed", "url": failure.request.url,
                 "detail": failure.getErrorMessage()[:300]}
        response = getattr(failure.value, "response", None)
        if response is not None:
            title = whitespace(response.css("title::text").get() or "")
            error.update({"responseStatus": response.status,
                          "responseSHA256": sha256(response.body), "responseTitle": title,
                          "browserChallengeDetected": "checking your browser" in title.casefold()})
            if failure.request.url == ROBOTS:
                self.robots.update({"status": response.status, "sourceSHA256": sha256(response.body),
                                    "statusDescription": "robots unavailable; no category requests were made"})
        self.errors.append(error)

    def closed(self, reason):
        stats = self.crawler.stats.get_stats()
        exceptions = sum(value for key, value in stats.items() if key.startswith("spider_exceptions/"))
        if exceptions:
            self.errors.append({"type": "spider-callback-exceptions", "count": exceptions})
        self.completed = (reason == "finished" and not self.errors and not self.budget_limited and
            self.robots["categoryAllowed"] is True and self.collection_total is not None and
            len(self.records) == self.collection_total and len(self.pages) == self.expected_pages and
            "reuse" in self.source_policy)
        records = sorted(self.records.values(), key=lambda item: item["wordPressPostID"])
        duplicate_groups, selected = group_duplicates(records)
        output = {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "provider": "Our Parish Priest", "language": "tl", "sourceSite": BASE,
            "scope": "All currently published posts in the site's Saints & Sinners category; a source collection, not all Catholic saints",
            "completed": self.completed, "finishReason": reason,
            "policy": {"purpose": "source-only review catalogue; no native imports, translations or invented identities",
                "biography": "literal A. KUWENTO NG BUHAY section through B. HAMON SA BUHAY; embedded songs/prayers separated",
                "provenance": "complete original rendered source HTML and prose retained separately from extracted biography",
                "dates": "printed feast labels only, never API posting date or URL year/month",
                "identity": "normalized literal title+printed feast date is only a duplicate candidate; no calendar identity join",
                "reuse": "review credits and underlying rights before any app redistribution",
                "transport": "bounded curl GET supplies Scrapy responses after cache/robots checks; no redirect following",
                "userAgent": USER_AGENT, "minimumDelaySeconds": self.args.delay,
                "cacheExpirySeconds": self.args.cache_expiry},
            "robots": self.robots, "sourcePolicyEvidence": self.source_policy,
            "crawl": {"publishedTotal": self.collection_total, "publishedPages": self.expected_pages,
                "collectionPagesRead": len(self.pages), "recordsPreserved": len(records),
                "tagalogBiographyRecords": sum(record["languageEvidence"]["tagalogCandidate"] for record in records),
                "selectedBiographyCandidates": len(selected), "duplicateGroups": len(duplicate_groups),
                "quarantinedRecords": sum(record["classification"] == "quarantined-source" for record in records),
                "attemptedRequests": self.attempted_requests, "responseBodyBytes": self.response_bytes,
                "cacheHits": stats.get("httpcache/hit", 0), "retries": stats.get("retry/count", 0),
                "maxPages": self.args.max_pages, "maxRequests": self.args.max_requests,
                "maxResponseBytes": self.args.max_bytes, "budgetLimited": self.budget_limited},
            "collectionPages": [self.pages[page] for page in sorted(self.pages)],
            "records": records, "duplicateGroups": duplicate_groups,
            "selectedBiographyCandidateIds": selected,
            "reviewStatus": "editorial-and-reuse-review-required", "errors": self.errors}
        atomic_json(self.args.output, output)
        print(f"{'Complete' if self.completed else 'Incomplete'} source collection: {len(records)} posts, "
              f"{len(selected)} biography candidates; output {self.args.output}", flush=True)


def review_existing(path: Path):
    value = json.loads(path.read_text(encoding="utf-8"))
    records = []
    for old in value["records"]:
        post = {"id": old["wordPressPostID"], "link": old["sourceURL"],
            "title": {"rendered": escape(old["sourceTitle"])}, "content": {"rendered": old["sourceHTML"]},
            "date": old["sourcePublishedAt"], "modified": old["sourceModifiedAt"], "categories": old["categoryIds"]}
        record = extract_post(post, old["sourceResponseURL"], old["sourceResponseSHA256"])
        for key in ("originalResponseHTML", "sourceCapture", "manualSourceReview", "additionalMetadataSnapshotEvidence"):
            if key in old:
                record[key] = old[key]
        if old.get("sourceCapture", {}).get("contentCaptured") is False:
            record["classification"], record["review"] = old["classification"], old["review"]
        records.append(record)
    value["records"] = records
    value["duplicateGroups"], value["selectedBiographyCandidateIds"] = group_duplicates(records)
    value["crawl"].update({"tagalogBiographyRecords": sum(record["languageEvidence"]["tagalogCandidate"] for record in records),
        "selectedBiographyCandidates": len(value["selectedBiographyCandidateIds"]),
        "duplicateGroups": len(value["duplicateGroups"]),
        "quarantinedRecords": sum(record["classification"] == "quarantined-source" for record in records)})
    atomic_json(path, value)
    print(f"Reviewed extraction from {len(records)} preserved source posts; no network requests.")


def add_saved_html(path: Path, snapshots: list[Path]):
    """Review exact source responses already saved during authorized discovery.

    This cannot complete a blocked collection. The recorded collection pages,
    counts and completion flag stay separate from these cached article samples.
    """
    value = json.loads(path.read_text(encoding="utf-8"))
    records = {record["wordPressPostID"]: record for record in value["records"]}
    for snapshot in snapshots:
        raw = snapshot.read_bytes()
        document = raw.decode("utf-8")
        selector = Selector(text=document)
        articles = selector.css("article.category-saints-sinners[id]")
        content = re.search(r'<section\s+class="entry-content"\s*>(.*?)</section>', document, re.S)
        schema = selector.css('script.yoast-schema-graph::text').get()
        if len(articles) != 1 or not content or not schema:
            raise ValueError("Saved HTML must contain one actual Saints & Sinners article and published metadata")
        graph = json.loads(schema).get("@graph", [])
        metadata = next((node for node in graph if node.get("@type") == "Article"), None)
        if not metadata or not source_url(metadata.get("mainEntityOfPage", {}).get("@id", "")):
            raise ValueError("Saved source has no in-scope canonical published article URL")
        source = source_url(metadata["mainEntityOfPage"]["@id"])
        post_id = int(re.fullmatch(r"post-([0-9]+)", articles[0].attrib["id"])[1])
        title = whitespace(articles[0].css(".entry-title").xpath("string(.)").get() or "")
        record = extract_post({"id": post_id, "link": source, "title": {"rendered": title},
            "content": {"rendered": content[1]}, "date": metadata.get("datePublished"),
            "modified": metadata.get("dateModified"), "categories": []}, source, sha256(raw))
        record.update({"originalResponseHTML": document,
            "sourceCapture": {"method": "previously saved original HTML response; offline extraction only",
                "contentCaptured": True,
                "savedAt": dt.datetime.fromtimestamp(snapshot.stat().st_mtime, dt.timezone.utc).isoformat(),
                "literalCategoryClass": "category-saints-sinners", "declaredLanguage": metadata.get("inLanguage"),
                "originalResponseSHA256": sha256(raw)}})
        if post_id in records and records[post_id] != record:
            if records[post_id].get("sourceCapture", {}).get("contentCaptured") is True:
                if records[post_id]["sourceResponseSHA256"] != record["sourceResponseSHA256"]:
                    raise ValueError("Saved HTML would overwrite a different preserved record")
                for key in ("manualSourceReview", "additionalMetadataSnapshotEvidence"):
                    if key in records[post_id]:
                        record[key] = records[post_id][key]
            elif records[post_id].get("sourceCapture", {}).get("contentCaptured") is not False:
                raise ValueError("Saved HTML would overwrite a different preserved record")
            else:
                record["additionalMetadataSnapshotEvidence"] = {
                    key: records[post_id][key] for key in ("sourceResponseURL", "sourceResponseSHA256",
                        "sourcePublishedAt", "sourceModifiedAt", "categoryIds")}
        records[post_id] = record
    value["records"] = sorted(records.values(), key=lambda record: record["wordPressPostID"])
    value["duplicateGroups"], value["selectedBiographyCandidateIds"] = group_duplicates(value["records"])
    value["crawl"].update({"recordsPreserved": len(value["records"]),
        "tagalogBiographyRecords": sum(record["languageEvidence"]["tagalogCandidate"] for record in value["records"]),
        "selectedBiographyCandidates": len(value["selectedBiographyCandidateIds"]),
        "duplicateGroups": len(value["duplicateGroups"]),
        "quarantinedRecords": sum(record["classification"] == "quarantined-source" for record in value["records"])})
    value["crawl"]["metadataOnlyRecords"] = sum(record["classification"] == "source-index-metadata-only" for record in value["records"])
    value["crawl"]["articleBodiesCaptured"] = sum(record.get("sourceCapture", {}).get("contentCaptured") is True for record in value["records"])
    value["scopeLimitations"] = ["The live collection stopped at the site's HTTP 403 browser challenge.",
        "These separately identified, previously captured original article responses are review samples only; the published collection is incomplete."]
    atomic_json(path, value)
    print(f"Preserved {len(snapshots)} cached article samples; collection remains incomplete. No network requests.")


def add_saved_api(path: Path, snapshot: Path, headers_path: Path, response_url: str):
    """Preserve an actually received metadata index, without inventing article prose."""
    parts = urlsplit(response_url)
    query = parse_qs(parts.query)
    if (parts.netloc != "www.ourparishpriest.com" or parts.scheme != "https" or
            parts.path != "/wp-json/wp/v2/posts" or query.get("_fields") != [INDEX_FIELDS] or
            query.get("per_page") != ["100"] or query.get("categories") != ["5"]):
        raise ValueError("Only the actual saved public category metadata response is accepted")
    raw = snapshot.read_bytes()
    posts = json.loads(raw)
    raw_headers = headers_path.read_text(encoding="utf-8")
    total = re.search(r"(?im)^x-wp-total:\s*(\d+)", raw_headers)
    pages = re.search(r"(?im)^x-wp-totalpages:\s*(\d+)", raw_headers)
    status = re.search(r"HTTP/\S+\s+(\d+)", raw_headers)
    if not total or not pages or not status or status[1] != "200" or not isinstance(posts, list):
        raise ValueError("Saved metadata snapshot needs its successful HTTP headers and published counts")
    value = json.loads(path.read_text(encoding="utf-8"))
    records = {record["wordPressPostID"]: record for record in value["records"]}
    digest = sha256(raw)
    for post in posts:
        if not source_url(post.get("link", "")) or "content" in post:
            raise ValueError("Unexpected saved metadata-only published source record")
        record = extract_post(post, response_url, digest)
        record["sourceCapture"] = {"method": "previously saved public API metadata only; offline extraction",
            "contentCaptured": False, "savedAt": dt.datetime.fromtimestamp(snapshot.stat().st_mtime, dt.timezone.utc).isoformat()}
        record["classification"] = "source-index-metadata-only"
        record["review"] = {"status": "source-body-not-captured", "reasons": ["source-body-not-captured"], "findings": []}
        records.setdefault(record["wordPressPostID"], record)
    value["records"] = sorted(records.values(), key=lambda record: record["wordPressPostID"])
    value["discoverySnapshots"] = [{"sourceResponseURL": response_url, "sourceResponseSHA256": digest,
        "originalResponseJSON": raw.decode("utf-8"), "originalResponseHeaders": raw_headers,
        "sourceFields": INDEX_FIELDS, "postCount": len(posts), "publishedTotal": int(total[1]),
        "publishedPages": int(pages[1]), "contentCaptured": False}]
    value["crawl"].update({"publishedTotal": int(total[1]), "publishedPages": int(pages[1]),
        "recordsPreserved": len(records), "metadataIndexPagesCaptured": 1,
        "metadataOnlyRecords": sum(record["classification"] == "source-index-metadata-only" for record in records.values())})
    value["completed"] = False
    atomic_json(path, value)
    print(f"Preserved {len(posts)}/{total[1]} actual published post metadata records; no article prose invented or network requests.")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/tagalog-saints.json")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-tagalog-saints-http-cache")
    parser.add_argument("--cache-expiry", type=int, default=86400)
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--max-pages", type=int, default=20)
    parser.add_argument("--max-requests", type=int, default=80)
    parser.add_argument("--max-bytes", type=int, default=40 * 1024 * 1024)
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="WARNING")
    parser.add_argument("--parse-json", type=Path)
    parser.add_argument("--parse-url", default=api_url(5))
    parser.add_argument("--review-existing", action="store_true")
    parser.add_argument("--add-saved-html", type=Path, nargs="+")
    parser.add_argument("--add-saved-api", type=Path)
    parser.add_argument("--api-headers", type=Path)
    args = parser.parse_args()
    if not math.isfinite(args.delay) or args.delay < 2 or min(args.max_pages, args.max_requests, args.max_bytes, args.cache_expiry) < 1:
        parser.error("Minimum delay is two seconds; budgets and cache expiry must be positive.")
    if args.review_existing:
        review_existing(args.output)
        return 0
    if args.add_saved_html:
        add_saved_html(args.output, args.add_saved_html)
        return 0
    if args.add_saved_api:
        if not args.api_headers:
            parser.error("--add-saved-api requires the actual --api-headers capture")
        add_saved_api(args.output, args.add_saved_api, args.api_headers, args.parse_url)
        return 0
    if args.parse_json:
        raw = args.parse_json.read_bytes()
        posts = json.loads(raw)
        atomic_json(args.output, {"records": [extract_post(post, args.parse_url, sha256(raw)) for post in posts]})
        return 0
    process = CrawlerProcess(settings={"USER_AGENT": USER_AGENT, "ROBOTSTXT_OBEY": True,
        "CONCURRENT_REQUESTS": 1, "CONCURRENT_REQUESTS_PER_DOMAIN": 1,
        "DOWNLOAD_DELAY": args.delay, "DOWNLOAD_DELAY_JITTER": 0,
        "DOWNLOAD_TIMEOUT": 35, "DOWNLOAD_MAXSIZE": args.max_bytes,
        "RETRY_TIMES": 2, "RETRY_HTTP_CODES": [429, 500, 502, 503, 504],
        "COOKIES_ENABLED": False, "TELNETCONSOLE_ENABLED": False,
        "HTTPERROR_ALLOWED_CODES": [], "HTTPCACHE_ENABLED": True,
        "HTTPCACHE_DIR": str(args.cache_dir), "HTTPCACHE_EXPIRATION_SECS": args.cache_expiry,
        "HTTPCACHE_IGNORE_HTTP_CODES": [400, 401, 403, 404, 429, 500, 502, 503, 504],
        "HTTPCACHE_POLICY": "scrapy.extensions.httpcache.DummyPolicy",
        "DOWNLOADER_MIDDLEWARES": {f"{__name__}.BoundaryMiddleware": 50,
                                   f"{__name__}.RetryBackoffMiddleware": 560,
                                   f"{__name__}.CurlTransportMiddleware": 950},
        "LOG_LEVEL": args.log_level, "REQUEST_FINGERPRINTER_IMPLEMENTATION": "2.7"})
    crawler = process.create_crawler(TagalogSaintsSpider)
    process.crawl(crawler, args=args)
    process.start()
    return 0 if crawler.spider and crawler.spider.completed else 1


if __name__ == "__main__":
    raise SystemExit(main())
