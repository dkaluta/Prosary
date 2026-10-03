#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Collect the published Arabic Roman saint calendar and source biographies.

Query each valid month/day (including February 29), follow returned next_uri and
subject href links, and retain UUID/date/prose/credit evidence for review only.
No native calendar dates, ranks, identity joins or translations are generated.
"""
from __future__ import annotations

import argparse
import calendar
import datetime as dt
import hashlib
import importlib.util
import json
import math
import re
import sys
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit
from uuid import UUID

import scrapy
from protego import Protego
from scrapy.crawler import CrawlerProcess
from scrapy.exceptions import IgnoreRequest
from scrapy.extensions.throttle import AutoThrottle
from scrapy.settings import default_settings

TOOLS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("hebrew_source_helpers", TOOLS / "scrape-catholic-hebrew-saints.py")
assert SPEC and SPEC.loader
helpers = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = helpers
SPEC.loader.exec_module(helpers)
BASE = "https://publication.evangelizo.ws"
ROBOTS = BASE + "/robots.txt"
UA = "ProsarySaintSourcesReview/1.0 (+https://prosary.app)"
ARABIC = re.compile(r"[\u0621-\u063a\u0641-\u064a]")


def source_robots(body: bytes, status: int, content_type: str) -> Protego:
    if status not in {200, 404}:
        raise ValueError("Robots unavailable")
    if status == 404:
        return Protego.parse("")
    text = body.decode("utf-8")
    if ("html" in content_type.lower() or re.search(r"<(?:html|script|!doctype)\b", text, re.I) or
            (text.strip() and not re.search(r"(?im)^\s*User-agent\s*:", text))):
        raise ValueError("Robots response is not a recognizable policy; no collection requests allowed")
    return Protego.parse(text)


def apply_source_delay(crawler, spider, delay: float):
    """Raise both slot and AutoThrottle minima after reading the source policy."""
    spider.download_delay = delay
    for slot in crawler.engine.downloader.slots.values():
        slot.delay = max(slot.delay, delay)
    for extension in crawler.extensions.middlewares:
        if isinstance(extension, AutoThrottle):
            extension.mindelay = max(extension.mindelay, delay)
            extension.maxdelay = max(extension.maxdelay, delay)


def canonical_url(url: str, base: str = BASE) -> str | None:
    try:
        parts = urlsplit(urljoin(base + "/", url))
        if (parts.scheme != "https" or parts.hostname != "publication.evangelizo.ws" or
                parts.username or parts.password or parts.port or parts.fragment):
            return None
        if parts.path.startswith("/AR/saints/"):
            subject = parts.path.removeprefix("/AR/saints/")
            if parts.query or str(UUID(subject)) != subject:
                return None
            return BASE + parts.path
        if parts.path != "/AR/saints":
            return None
        query = parse_qs(parts.query, keep_blank_values=True)
        if set(query) - {"day", "month", "page_size", "page_index"} or any(len(v) != 1 for v in query.values()):
            return None
        values = {k: int(v[0]) for k, v in query.items()}
        dt.date(2000, values["month"], values["day"])
        if not 1 <= values.get("page_size", 150) <= 150 or values.get("page_index", 1) < 1:
            return None
        ordered = {k: values[k] for k in ("day", "month", "page_size", "page_index") if k in values}
        return BASE + parts.path + "?" + urlencode(ordered)
    except (ValueError, KeyError, TypeError):
        return None


def collection_url(month: int, day: int) -> str:
    return BASE + "/AR/saints?" + urlencode({"day": day, "month": month, "page_size": 150})


def extract_biography(payload: dict, url: str, raw: bytes, occurrences: list[dict]) -> dict:
    source = payload["data"]
    subject = str(UUID(source["id"]))
    if url.rsplit("/", 1)[-1] != subject:
        raise ValueError("Response UUID differs from requested source UUID")
    bio = source.get("bio") or ""
    selector = helpers._selector(bio)
    body = selector.css("body")
    paragraphs = helpers._paragraphs(body[0].root) if body else []
    text = "\n".join(paragraphs)
    letters = sum(c.isalpha() for c in text)
    arabic = len(ARABIC.findall(text))
    share = arabic / letters if letters else 0
    issues = []
    if not bio.strip() or not text.strip():
        issues.append("missing-biography")
    elif arabic < 40 or share < 0.70:
        issues.append("biography-language-needs-review")
    if not ARABIC.search(source["name"]):
        issues.append("source-title-language-needs-review")
    source_date = {"month": source.get("month"), "day": source.get("day"),
                   "label": source.get("date_displayed")}
    dates = {(item["month"], item["day"]) for item in occurrences}
    if (source_date["month"], source_date["day"]) not in dates:
        issues.append("subject-date-differs-from-collection")
    years = re.findall(r"(?<!\d)([12]\d{4,})(?!\d)", text)
    if years:
        issues.append("implausible-year-literal")
    credits = source.get("bio_source")
    return {"sourceSubjectID": subject, "sourceURL": url, "sourceTitle": source["name"],
            "sourceEdition": "AR", "requestedLanguage": "ar",
            "language": "ar" if arabic >= 40 and share >= 0.70 and ARABIC.search(source["name"]) else None,
            "sourceMonthDay": source_date, "collectionOccurrences": occurrences,
            "sourceShortDescription": source.get("short_description"),
            "rawBiographyHTML": bio, "paragraphs": paragraphs,
            "credit": "Evangelizo.org — Daily Gospel (© Evangelizo.org)", "underlyingCredit": credits,
            "sourceResponseSHA256": hashlib.sha256(raw).hexdigest(),
            "sourceBiographyHTMLSHA256": hashlib.sha256(bio.encode("utf-8")).hexdigest(),
            "sourceTextSHA256": hashlib.sha256(text.encode("utf-8")).hexdigest(),
            "languageEvidence": {"arabicLetters": arabic, "alphabeticLetters": letters,
                                 "arabicLetterShare": round(share, 4)},
            "review": {"status": "mechanical-checks-passed" if not issues else "flagged",
                       "issues": issues, "implausibleYearLiterals": years,
                       "identityMapping": "unassigned", "historicalAccuracy": "not-certified",
                       "redistribution": "unapproved"}}


class ScopeMiddleware:
    def __init__(self, crawler):
        self.crawler = crawler

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    def process_request(self, request, spider=None):
        spider = spider or self.crawler.spider
        if request.url != ROBOTS and not canonical_url(request.url):
            raise IgnoreRequest("Outside published Arabic saint source scope")
        spider.attempted_requests += 1
        if spider.attempted_requests > spider.args.max_requests or spider.bytes_received > spider.args.max_bytes:
            spider.budget_limited = True
            raise IgnoreRequest("Source budget reached")


class ArabicSaintsSpider(scrapy.Spider):
    name = "evangelizo_arabic_saints"
    allowed_domains = ["publication.evangelizo.ws"]

    def __init__(self, args, **kwargs):
        super().__init__(**kwargs)
        self.args = args
        self.collections = {}
        self.subjects = {}
        self.records = {}
        self.errors = []
        self.attempted_requests = 0
        self.bytes_received = 0
        self.budget_limited = False
        self.completed = False
        self.scheduled = set()
        self.robots = {"url": ROBOTS, "status": None, "allowed": None}

    def error(self, reason, url, detail=None):
        self.errors.append({"reason": reason, "url": url, "detail": detail})

    async def start(self):
        yield scrapy.Request(ROBOTS, callback=self.parse_robots, errback=self.failed,
                             meta={"dont_obey_robotstxt": True, "handle_httpstatus_list": [404]})

    def parse_robots(self, response):
        self.robots.update({"status": response.status, "sourceResponseSHA256": hashlib.sha256(response.body).hexdigest()})
        try:
            parser = source_robots(response.body, response.status,
                                   response.headers.get("Content-Type", b"").decode("ascii", errors="ignore"))
        except (ValueError, UnicodeError) as error:
            self.robots["allowed"] = False
            self.error("robots-unavailable-or-unrecognized", response.url, str(error))
            return
        allowed = parser.can_fetch(collection_url(1, 1), UA)
        self.robots["allowed"] = allowed
        if not allowed:
            self.error("robots-unavailable-or-disallowed", response.url)
            return
        published_delay = parser.crawl_delay(UA)
        effective_delay = max(self.args.delay, float(published_delay or 0))
        if not math.isfinite(effective_delay):
            self.error("invalid-source-crawl-delay", response.url)
            return
        self.robots.update({"publishedCrawlDelaySeconds": published_delay, "effectiveDelaySeconds": effective_delay})
        apply_source_delay(self.crawler, self, effective_delay)
        for month in range(1, 13):
            for day in range(1, calendar.monthrange(2000, month)[1] + 1):
                url = collection_url(month, day)
                self.scheduled.add(url)
                yield scrapy.Request(url, callback=self.parse_collection, errback=self.failed,
                                     cb_kwargs={"month": month, "day": day}, priority=100)

    def parse_collection(self, response, month, day):
        payload = json.loads(response.body.decode("utf-8"))
        if not isinstance(payload.get("data"), list) or not isinstance(payload.get("pagination"), dict):
            raise ValueError("Unrecognized public saint collection response")
        canonical = canonical_url(response.url)
        if not canonical:
            raise ValueError("Collection redirect leaves the reviewed source shape")
        entries = payload["data"]
        self.collections[canonical] = {"url": canonical, "month": month, "day": day,
            "returnedCount": len(entries), "total": payload["pagination"]["total"],
            "nextURI": payload["pagination"].get("next_uri"),
            "subjectIDs": [str(UUID(item["id"])) for item in entries],
            "sourceResponseSHA256": hashlib.sha256(response.body).hexdigest()}
        for item in entries:
            url = canonical_url(item["href"])
            if not url or not url.endswith(str(UUID(item["id"]))):
                raise ValueError("Unrecognized published subject URL or UUID")
            occurrence = {"month": month, "day": day, "sourceTitle": item["name"],
                          "hasBiography": item.get("has_bio"), "collectionURL": canonical}
            self.subjects.setdefault(url, []).append(occurrence)
            if url not in self.scheduled:
                self.scheduled.add(url)
                yield scrapy.Request(url, callback=self.parse_biography, errback=self.failed)
        next_uri = payload["pagination"].get("next_uri")
        if next_uri:
            target = canonical_url(next_uri)
            if not target or target in self.collections or target in self.scheduled:
                self.error("invalid-or-cyclic-pagination", response.url, next_uri)
            else:
                query = parse_qs(urlsplit(target).query)
                if query.get("day") != [str(day)] or query.get("month") != [str(month)]:
                    raise ValueError("Pagination changed the source month/day")
                self.scheduled.add(target)
                yield scrapy.Request(target, callback=self.parse_collection, errback=self.failed,
                                     cb_kwargs={"month": month, "day": day}, priority=100)
        if len(self.collections) % 30 == 0:
            self.save("in-progress")
            self.logger.info("Source progress: %s date collection pages, %s unique subjects, %s biographies",
                             len(self.collections), len(self.subjects), len(self.records))

    def parse_biography(self, response):
        url = canonical_url(response.url)
        if not url or url not in self.subjects:
            raise ValueError("Biography URL differs from published subject links")
        record = extract_biography(json.loads(response.body.decode("utf-8")), url, response.body, self.subjects[url])
        self.records[url] = record
        if len(self.records) % 25 == 0:
            self.save("in-progress")

    def failed(self, failure):
        self.error("request-failed", failure.request.url, failure.getErrorMessage()[:500])

    def save(self, reason):
        stats = self.crawler.stats.get_stats()
        output = {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "source": {"provider": "Evangelizo.org — Daily Gospel", "siteURL": "https://alingilalyawmi.org/AR/gospel",
                       "edition": "AR", "language": "ar", "collection": BASE + "/AR/saints"},
            "scope": "Union of all 366 valid month/day saint collections, including February 29; published subject links only",
            "completed": self.completed, "finishReason": reason, "robots": self.robots,
            "policy": {"purpose": "source-only catalogue", "nativeImport": False, "minimumDelaySeconds": self.args.delay,
                       "calendarMapping": "none", "historicalAccuracy": "not-certified", "redistribution": "unapproved"},
            "crawl": {"dateCollectionPages": len(self.collections), "coveredMonthDays": len({(p["month"], p["day"]) for p in self.collections.values()}),
                      "discoveredSubjects": len(self.subjects), "biographies": len(self.records),
                      "flaggedRecords": sum(bool(r["review"]["issues"]) for r in self.records.values()),
                      "attemptedRequests": self.attempted_requests, "responseBytes": self.bytes_received,
                      "receivedResponses": stats.get("downloader/response_count", 0), "cacheHits": stats.get("httpcache/hit", 0),
                      "retriedRequests": stats.get("retry/count", 0), "budgetLimited": self.budget_limited},
            "collections": sorted(self.collections.values(), key=lambda p: (p["month"], p["day"], p["url"])),
            "articles": sorted(self.records.values(), key=lambda r: r["sourceSubjectID"]), "errors": self.errors}
        helpers._atomic_json(self.args.output, output)

    def closed(self, reason):
        stats = self.crawler.stats.get_stats()
        exceptions = sum(v for k, v in stats.items() if k.startswith("spider_exceptions/"))
        if exceptions:
            self.error("callback-exception", BASE, exceptions)
        dates = {(p["month"], p["day"]) for p in self.collections.values()}
        for month, day in dates:
            pages = [p for p in self.collections.values() if (p["month"], p["day"]) == (month, day)]
            ids = {subject for page in pages for subject in page["subjectIDs"]}
            if any(p["total"] != len(ids) for p in pages):
                self.error("collection-total-mismatch", collection_url(month, day))
        self.completed = (reason == "finished" and len(dates) == 366 and len(self.records) == len(self.subjects)
                          and not self.errors and not self.budget_limited and self.robots["allowed"] is True)
        self.save(reason)
        print(f"{'Complete' if self.completed else 'Incomplete'} Arabic source catalogue: {len(self.records)} subjects, "
              f"{sum(bool(r['review']['issues']) for r in self.records.values())} flagged, {len(self.errors)} errors")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/evangelizo-saints-ar.json")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-evangelizo-arabic-saints-cache")
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--max-requests", type=int, default=2000)
    parser.add_argument("--max-bytes", type=int, default=50 * 1024 * 1024)
    args = parser.parse_args()
    if not math.isfinite(args.delay) or args.delay < 2 or args.max_requests < 1 or args.max_bytes < 1:
        parser.error("A minimum two-second delay and positive budgets are required")
    settings = {"USER_AGENT": UA, "ROBOTSTXT_USER_AGENT": UA, "ROBOTSTXT_OBEY": True,
        "CONCURRENT_REQUESTS": 1, "CONCURRENT_REQUESTS_PER_DOMAIN": 1,
        "DOWNLOAD_DELAY": args.delay, "RANDOMIZE_DOWNLOAD_DELAY": False,
        "AUTOTHROTTLE_ENABLED": True, "AUTOTHROTTLE_START_DELAY": args.delay,
        "AUTOTHROTTLE_MAX_DELAY": 60, "AUTOTHROTTLE_TARGET_CONCURRENCY": 1,
        "DOWNLOAD_TIMEOUT": 30, "DOWNLOAD_MAXSIZE": 2 * 1024 * 1024, "RETRY_TIMES": 2,
        "COOKIES_ENABLED": False, "TELNETCONSOLE_ENABLED": False, "REMOTE_CONTROL_ENABLED": False,
        "HTTPCACHE_ENABLED": True, "HTTPCACHE_DIR": str(args.cache_dir.resolve()),
        "HTTPCACHE_EXPIRATION_SECS": 86400, "HTTPCACHE_IGNORE_HTTP_CODES": [408, 429, 500, 502, 503, 504],
        "HTTPCACHE_POLICY": "scrapy.extensions.httpcache.DummyPolicy",
        "DOWNLOADER_MIDDLEWARES": {ScopeMiddleware: 80, helpers.BoundedRetryBackoffMiddleware: 600},
        "LOG_LEVEL": "INFO", "LOGSTATS_INTERVAL": 60,
        "TWISTED_REACTOR": "twisted.internet.asyncioreactor.AsyncioSelectorReactor"}
    if hasattr(default_settings, "DOWNLOAD_DELAY_JITTER"):
        settings["DOWNLOAD_DELAY_JITTER"] = 0
    process = CrawlerProcess(settings)
    crawler = process.create_crawler(ArabicSaintsSpider)
    process.crawl(crawler, args=args)
    process.start()
    return 0 if crawler.spider and crawler.spider.completed else 1


if __name__ == "__main__":
    sys.exit(main())
