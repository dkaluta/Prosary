#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.3,<0.7", "lingua-language-detector>=2,<3"]
# ///
"""Collect TV Maria's published monthly archives as a source-only Tagalog review.

Discover monthly archives from the homepage, then follow their actual pagination
and post links. No invented URLs, translation, calendar assignment or native import.
The blog's underlying book quotations retain their literal credits; collection is
not permission to redistribute those books. A bounded partial crawl exits nonzero.
"""
from __future__ import annotations

import argparse
import collections
import copy
import datetime as dt
import hashlib
import json
import math
import re
import subprocess
import tempfile
import time
from pathlib import Path
from urllib.parse import urljoin, urlsplit, urlunsplit

from lingua import Language, LanguageDetectorBuilder
from lxml import etree, html as lhtml
from protego import Protego

BASE = "https://tvmaria.wordpress.com/"
ROBOTS = BASE + "robots.txt"
USER_AGENT = "ProsaryTagalogSaintsReview/1.0 (+https://prosary.app)"
CLASS = "contains(concat(' ', normalize-space(@class), ' '), ' {} ')"
ARCHIVE_PATH = re.compile(r"^/(20\d{2})/(0[1-9]|1[0-2])/(?:page/([1-9]\d*)/)?$")
POST_PATH = re.compile(r"^/(20\d{2})/(0[1-9]|1[0-2])/(0[1-9]|[12]\d|3[01])/[^/]+/$")
DETECTOR = LanguageDetectorBuilder.from_languages(
    Language.TAGALOG, Language.ENGLISH, Language.SPANISH, Language.FRENCH,
    Language.ITALIAN, Language.PORTUGUESE, Language.LATIN,
    Language.RUSSIAN, Language.UKRAINIAN, Language.HEBREW, Language.ARABIC).build()
BLOCKS = {"p", "div", "blockquote", "li", "ul", "ol", "h1", "h2", "h3", "h4", "h5", "h6", "dl", "dt", "dd", "table", "tr"}
INERT = {"script", "style", "noscript", "iframe", "form", "object", "nav", "footer"}
DATE_LABELS = re.compile(r"^(?:Kapanganakan|Kamatayan|Araw ng Kapistahan|Kapistahan)\s*:", re.I)
METADATA_LABELS = re.compile(r"^(?:Kilala (?:rin )?bilang|Kapanganakan|Kamatayan|Araw ng Kapistahan|Kapistahan|Patron ng|Pintakasi(?: ng| para sa)?)\s*:", re.I)
SAINT_TITLE = re.compile(r"^(?:San(?:ta|to)?\b|Santo\b|Sta\.|Sto\.|Ang (?:Birhen|mga .*Martir)|Mga .*Martir|Beato\b|Blessed\b|Saint\b)", re.I)
BOOK_REFERENCE = re.compile(r"^Abriol,\s*J\.?\s*C\.?\s*\(\d{4}\)\.\s*Talambuhay ng mga Santo\b.*\bPaulines Publishing House\b", re.I)
UNHEADED_WEB_REFERENCE = re.compile(r"^n\.?\s*a\.?\s*\(n\.?\s*d\.?\)\.\s+.+\bRetrieved\b.+https?://", re.I)


def digest(value: bytes | str) -> str:
    return hashlib.sha256(value.encode("utf-8") if isinstance(value, str) else value).hexdigest()


def whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def canonical_url(value: str, base: str = BASE, kind: str | None = None) -> str | None:
    try:
        parts = urlsplit(urljoin(base, value))
        if (parts.scheme not in {"http", "https"} or parts.hostname != "tvmaria.wordpress.com" or
                parts.username or parts.password or parts.port or parts.query):
            return None
        path = parts.path
        detected = "home" if path == "/" else "robots" if path == "/robots.txt" else (
            "archive" if ARCHIVE_PATH.fullmatch(path) else "post" if POST_PATH.fullmatch(path) else None)
        if detected is None or (kind and detected != kind):
            return None
        return urlunsplit(("https", "tvmaria.wordpress.com", path, "", ""))
    except (ValueError, TypeError):
        return None


def parse_html(value: bytes | str):
    # WordPress declares UTF-8. Never silently replace an undecodable source glyph;
    # the unchanged network bytes remain in the external response cache on failure.
    return lhtml.fromstring(value if isinstance(value, str) else value.decode("utf-8"))


def paragraphs(root) -> list[str]:
    """Walk visible prose in order, retaining bare text/tails and inline punctuation."""
    result, pieces = [], []

    def flush():
        value = whitespace("".join(pieces))
        if value:
            result.append(value)
        pieces.clear()

    def walk(node):
        if not isinstance(node.tag, str) or node.tag.lower() in INERT:
            return
        tag = node.tag.lower()
        block = tag in BLOCKS
        if block:
            flush()
        if tag == "br":
            pieces.append(" ")
        if node.text:
            pieces.append(node.text)
        for child in node:
            walk(child)
            if child.tail:
                pieces.append(child.tail)
        if block:
            flush()

    walk(root)
    flush()
    return result


def language_evidence(text: str) -> dict:
    letters = sum(character.isalpha() for character in text)
    sample = text if len(text) <= 18000 else text[:14000] + "\n" + text[-4000:]
    values = DETECTOR.compute_language_confidence_values(sample) if letters else []
    ranked = [{"language": value.language.iso_code_639_1.name.lower(), "confidence": round(value.value, 6)}
              for value in values[:4]]
    best = ranked[0] if ranked else {"language": None, "confidence": 0.0}
    gap = best["confidence"] - (ranked[1]["confidence"] if len(ranked) > 1 else 0)
    return {"method": "lingua-high-accuracy-11-languages; prose excluding title/menu/book credits",
            "alphabeticCharacters": letters, "detectedLanguage": best["language"],
            "confidence": best["confidence"], "confidenceGap": round(gap, 6),
            "tagalogCandidate": best["language"] == "tl" and best["confidence"] >= 0.65 and gap >= 0.15,
            "topCandidates": ranked, "reviewRequired": True}


def extract_home(value: bytes | str, url: str = BASE) -> dict:
    root = parse_html(value)
    archives = {}
    for option in root.xpath("//*[@id='sidebar']//*[" + CLASS.format("widget_archive") + "]//option[@value]"):
        target = canonical_url(option.get("value", ""), url, "archive")
        if target and not ARCHIVE_PATH.fullmatch(urlsplit(target).path).group(3):
            archives[target] = {"url": target, "literalLabel": whitespace(option.text_content())}
    recent = {}
    for anchor in root.xpath("//*[@id='sidebar']//*[" + CLASS.format("widget_rss") + "]//a[@href]"):
        target = canonical_url(anchor.get("href"), url, "post")
        if target:
            recent[target] = whitespace(anchor.text_content())
    return {"archives": list(archives.values()), "publishedRecentPosts": recent,
            "recognizedArchiveWidget": bool(root.xpath("//*[@id='sidebar']//*[" + CLASS.format("widget_archive") + "]"))}


def extract_archive(value: bytes | str, url: str) -> dict:
    root = parse_html(value)
    area = root.xpath("//*[@id='content']")
    posts, failures = {}, []
    nodes = area[0].xpath(".//*[" + CLASS.format("post") + " and " + CLASS.format("type-post") + "]") if area else []
    for node in nodes:
        anchors = node.xpath("./h2/a[@href] | ./h3/a[@href]")
        if not anchors:
            failures.append("post-heading-has-no-published-link")
            continue
        target = canonical_url(anchors[0].get("href"), url, "post")
        if not target:
            failures.append(anchors[0].get("href"))
            continue
        match = re.search(r"\bpost-(\d+)\b", node.get("class", ""))
        posts[target] = {"url": target, "publishedURL": urljoin(url, anchors[0].get("href")),
                         "title": whitespace(anchors[0].text_content()),
                         "wordPressPostID": int(match[1]) if match else None}
    pagination, unrecognized, home_links = set(), [], []
    current = ARCHIVE_PATH.fullmatch(urlsplit(url).path)
    for anchor in area[0].xpath(".//*[" + CLASS.format("navigation") + "]//a[@href]") if area else []:
        if canonical_url(anchor.get("href"), url) == BASE:
            home_links.append({"url": BASE, "literalLabel": whitespace(anchor.text_content())})
            continue
        target = canonical_url(anchor.get("href"), url, "archive")
        match = ARCHIVE_PATH.fullmatch(urlsplit(target).path) if target else None
        if match and match.group(1, 2) == current.group(1, 2):
            pagination.add(target)
        else:
            unrecognized.append(anchor.get("href"))
    title = area[0].xpath(".//*[" + CLASS.format("pagetitle") + "]") if area else []
    return {"recognizedArea": bool(area), "title": whitespace(title[0].text_content()) if title else "",
            "posts": list(posts.values()), "rawPostCount": len(nodes), "unrecognizedPostLinks": failures,
            "pagination": sorted(pagination), "unrecognizedPaginationLinks": unrecognized,
            "publishedHomeNavigation": home_links}


def content_entry(entry):
    """Keep the source entry, ending before WordPress sharing/category/posting UI."""
    cleaned = copy.deepcopy(entry)
    for node in list(cleaned):
        classes = set(node.get("class", "").split())
        if (node.get("id", "") in {"jp-post-flair", "jp-relatedposts"} or
                {"sharedaddy", "postmetadata", "sd-block"} & classes):
            position = cleaned.index(node)
            for remainder in list(cleaned)[position:]:
                cleaned.remove(remainder)
            break
    # Missing share widgets must still exclude the theme's loose category footer.
    for node in list(cleaned.xpath(".//strong")):
        if whitespace(node.text_content()).startswith("Explore posts in the same categories:"):
            parent = node.getparent()
            position = parent.index(node)
            for remainder in list(parent)[position:]:
                parent.remove(remainder)
    return cleaned


def extract_article(value: bytes | str, url: str, *, index_entries: list[dict] | None = None) -> dict:
    source_bytes = value.encode("utf-8") if isinstance(value, str) else value
    root = parse_html(value)
    posts = root.xpath("//*[@id='content']//*[" + CLASS.format("post") + " and " + CLASS.format("type-post") + "]")
    issues = []
    post = posts[0] if len(posts) == 1 else None
    headings = post.xpath("./h2 | ./h1") if post is not None else []
    title = whitespace(headings[0].text_content()) if len(headings) == 1 else ""
    entries = post.xpath("./*[" + CLASS.format("entrytext") + "]") if post is not None else []
    raw_entry = etree.tostring(entries[0], encoding="unicode", method="html", with_tail=False) if len(entries) == 1 else ""
    entry = content_entry(entries[0]) if len(entries) == 1 else lhtml.fromstring("<div></div>")
    content_html = etree.tostring(entry, encoding="unicode", method="html", with_tail=False)
    prose = paragraphs(entry)
    sections = {"biography": [], "reflection": [], "credits": [], "metadata": []}
    state = "biography"
    for paragraph in prose:
        marker = re.fullmatch(r"(ARAL|PAGNINILAY|REFLECTION|SOURCE|SOURCES|PINAGKUNAN|SANGGUNIAN)(?:\s*:\s*(.*))?", paragraph, re.I)
        if marker:
            state = "reflection" if marker[1].upper() in {"ARAL", "PAGNINILAY", "REFLECTION"} else "credits"
            if marker[2]:
                sections[state].append(marker[2])
            continue
        # Several genuine entries print their bibliography without a Source:
        # heading. Require a literal bibliographic form, never infer an author
        # merely because a person's name or book is discussed in the narrative.
        if BOOK_REFERENCE.search(paragraph) or UNHEADED_WEB_REFERENCE.search(paragraph):
            state = "credits"
        if state == "biography" and METADATA_LABELS.search(paragraph):
            sections["metadata"].append(paragraph)
        else:
            sections[state].append(paragraph)
    # The first label is usually a saint's role; retain it with biography, never infer facts.
    narrative = "\n".join(sections["biography"])
    evidence = language_evidence(narrative)
    saint_title = bool(SAINT_TITLE.search(title))
    biography_candidate = saint_title and evidence["tagalogCandidate"] and evidence["alphabeticCharacters"] >= 120
    if post is None or len(entries) != 1:
        disposition, genre = "quarantine", "malformed-or-missing-primary-entry"
        issues.append("missing-or-ambiguous-primary-post")
    elif not title:
        disposition, genre = "quarantine", "untitled-source-post"
        issues.append("source-title-empty")
    elif not prose:
        disposition, genre = "quarantine", "empty-source-entry"
        issues.append("empty-source-prose")
    elif biography_candidate:
        disposition, genre = "articles", "Tagalog-saint-or-feast-biography-review-candidate"
    elif evidence["detectedLanguage"] == "en" and evidence["confidence"] >= 0.65:
        disposition, genre = "excluded", "English-source-post"
    elif not saint_title:
        disposition, genre = "excluded", "reading-reflection-or-other-source-post"
    else:
        disposition, genre = "quarantine", "saint-title-with-uncertain-or-insufficient-Tagalog-prose"
        issues.append("Tagalog-biography-not-demonstrated")
    if index_entries and any(entry["title"] != title for entry in index_entries):
        issues.append("index-article-title-mismatch")
    match = re.search(r"\bpost-(\d+)\b", post.get("class", "")) if post is not None else None
    identifier = int(match[1]) if match else None
    credits = [{"literal": paragraph, "location": "source-credit-section", "kind": "underlying-book-or-source-reference",
                "reviewRequired": True} for paragraph in sections["credits"]]
    labels = [paragraph for paragraph in prose if DATE_LABELS.search(paragraph)]
    posted = post.xpath(".//*[" + CLASS.format("postmetadata") + "]") if post is not None else []
    return {"recordId": "tvmaria:" + (str(identifier) if identifier is not None else digest(url)[:16]),
        "wordPressPostID": identifier, "sourceURL": url, "sourceTitle": title,
        "sourcePageHTMLSHA256": digest(source_bytes), "originalEntryHTML": raw_entry,
        "originalEntryHTMLSHA256": digest(raw_entry), "sourceHTML": content_html,
        "sourceHTMLSHA256": digest(content_html), "sourceParagraphs": prose,
        "sourceTextSHA256": digest("\n".join(prose)), "sections": sections,
        "biographyTextSHA256": digest(narrative), "literalCredits": credits,
        "sourceFeastLabels": [label for label in labels if re.search(r"(?:Araw ng )?Kapistahan", label, re.I)],
        "literalDateEvidence": labels,
        "sourcePostingWording": [whitespace(node.text_content()) for node in posted],
        "sourcePostingDateIsFeastDate": False, "languageEvidence": evidence,
        "language": "tl" if biography_candidate else None, "classification": genre,
        "contentShape": "captured-source-entry", "disposition": disposition,
        "indexOccurrences": index_entries or [], "sourceCapture": {"contentCaptured": True,
            "method": "public original HTML; exact visible prose except whitespace"},
        "review": {"status": "required", "reasons": issues,
            "manualReviewRequired": ["subject and genre", "historical facts", "printed feast wording",
                "source and underlying book rights", "selection of biography versus reflection"]},
        "nativeImportAllowed": False, "calendarIdentityMapping": "unassigned", "reuseApproved": False}


class CrawlStopped(Exception):
    pass


class Collector:
    def __init__(self, args):
        self.args = args
        self.cache = args.cache_dir
        self.cache.mkdir(parents=True, exist_ok=True)
        self.last_request = 0.0
        self.requests = self.received = self.downloads = self.cache_hits = self.bytes = self.retries = 0
        self.errors = []
        self.budget_limited = False
        self.blocked = False
        self.robot_parser = None
        self.robots = {"sourceURL": ROBOTS, "status": None, "allowed": None}
        self.discovery = {"homepageURL": BASE, "archiveSeeds": [], "publishedRecentPosts": {},
                          "publishedArticleURLs": [], "scope": "all monthly archives published by homepage widget"}
        self.index_pages = {}
        self.occurrences = collections.defaultdict(list)
        self.records = {}
        self.pending = []
        self.completed = False

    def fetch(self, url):
        if not canonical_url(url):
            raise CrawlStopped("outside-public-archive-scope:" + url)
        if self.robot_parser and not self.robot_parser.can_fetch(url, USER_AGENT):
            raise CrawlStopped("robots-disallows-published-url:" + url)
        if self.requests >= self.args.max_requests or self.bytes >= self.args.max_bytes:
            self.budget_limited = True
            raise CrawlStopped("request-or-byte-budget-reached")
        self.requests += 1
        key = digest(url)
        body_file, metadata_file = self.cache / (key + ".html"), self.cache / (key + ".json")
        if body_file.exists() and metadata_file.exists():
            metadata = json.loads(metadata_file.read_text())
            age = time.time() - metadata.get("savedEpoch", 0)
            body = body_file.read_bytes()
            if 0 <= age <= self.args.cache_expiry and digest(body) == metadata.get("bodySHA256"):
                self.cache_hits += 1
                self.received += 1
                self.bytes += len(body)
                if self.bytes > self.args.max_bytes:
                    self.budget_limited = True
                    raise CrawlStopped("response-byte-budget-reached")
                return metadata["status"], body
        for attempt in range(3):
            if attempt:
                if self.requests >= self.args.max_requests:
                    self.budget_limited = True
                    raise CrawlStopped("request-budget-reached-during-retry")
                self.requests += 1
            wait = self.args.delay - (time.monotonic() - self.last_request)
            if wait > 0:
                time.sleep(wait)
            self.last_request = time.monotonic()
            with tempfile.TemporaryDirectory(prefix="prosary-tvmaria-response-") as temp:
                body_path, header_path = Path(temp) / "body", Path(temp) / "headers"
                command = ["curl", "--silent", "--show-error", "--connect-timeout", "15", "--max-time", "40",
                    "--max-filesize", str(self.args.max_response_bytes), "--user-agent", USER_AGENT,
                    "--dump-header", str(header_path), "--output", str(body_path), "--write-out", "%{http_code}", url]
                result = subprocess.run(command, capture_output=True, text=True, timeout=45)
                body = body_path.read_bytes() if body_path.exists() else b""
                headers = header_path.read_text(errors="replace") if header_path.exists() else ""
                status = int(result.stdout[-3:]) if result.stdout[-3:].isdigit() else 0
            self.downloads += 1
            self.received += 1
            self.bytes += len(body)
            if result.returncode == 63:
                self.budget_limited = True
                raise CrawlStopped("individual-response-byte-budget-reached:" + url)
            if result.returncode:
                raise CrawlStopped("public-request-failed:" + url + ":" + result.stderr[:180])
            if len(body) > self.args.max_response_bytes or self.bytes > self.args.max_bytes:
                self.budget_limited = True
                raise CrawlStopped("response-byte-budget-reached")
            if status in {401, 403} or re.search(rb"(?:cf-chl-|challenge-platform|verify you are human|checking your browser)", body, re.I):
                self.blocked = True
                raise CrawlStopped("public-browser-challenge-or-access-block:" + url + ":HTTP" + str(status))
            if status in {429, 500, 502, 503, 504} and attempt < 2:
                self.retries += 1
                retry = re.search(r"(?im)^Retry-After:\s*(\d+)\s*$", headers)
                time.sleep(min(60, max(4 * 2 ** attempt, int(retry[1]) if retry else 0)))
                continue
            if 300 <= status < 400:
                raise CrawlStopped("unfollowed-public-redirect:" + url)
            if status != 200:
                raise CrawlStopped("public-request-http-error:" + url + ":HTTP" + str(status))
            body_file.write_bytes(body)
            metadata_file.write_text(json.dumps({"url": url, "status": status, "bodySHA256": digest(body),
                "savedEpoch": time.time(), "savedAt": dt.datetime.now(dt.timezone.utc).isoformat()}))
            return status, body
        raise CrawlStopped("bounded-retries-exhausted:" + url)

    def snapshot(self, finish_reason="running"):
        buckets = {name: [r for r in self.records.values() if r["disposition"] == name]
                   for name in ("articles", "excluded", "quarantine")}
        published = sorted(self.occurrences)
        missing = sorted(set(published) - set(self.records))
        output = {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "provider": "TV Maria on WordPress", "sourceSite": BASE, "language": "tl",
            "scope": "Posts in every monthly archive publicly listed on the TV Maria homepage; not a complete saint calendar",
            "completed": self.completed, "finishReason": finish_reason, "robots": self.robots,
            "policy": {"userAgent": USER_AGENT, "minimumDelaySeconds": self.args.delay,
                "purpose": "source-only review; no native import or calendar identity/date changes",
                "wording": "source wording unchanged except whitespace; no machine translation",
                "reflection": "ARAL/PAGNINILAY and bibliographic credit sections are separated from biography",
                "rights": "Preserve literal underlying book credits; no book or website reuse approval inferred",
                "htmlEvidence": "Serialized original entry and bounded primary-entry HTML; exact network bytes are hash-pinned in the external cache",
                "postingDates": "archive/URL/posting dates are transport evidence, never feast dates",
                "cacheExpirySeconds": self.args.cache_expiry},
            "discovery": {**self.discovery, "publishedArticleURLs": published},
            "indexPages": list(self.index_pages.values()),
            "selectedBiographyCandidateIds": [r["recordId"] for r in buckets["articles"]],
            "unfetchedArticleURLs": missing, "remainingPaginationURLs": sorted(self.pending),
            "crawl": {"attemptedRequests": self.requests, "receivedResponses": self.received,
                "downloadedResponses": self.downloads, "cacheHits": self.cache_hits,
                "responseBodyBytes": self.bytes, "retries": self.retries,
                "discoveredArticles": len(published), "articlesPreserved": len(self.records),
                "TagalogBiographyCandidates": len(buckets["articles"]), "maxArticles": self.args.max_articles,
                "maxPages": self.args.max_pages, "maxRequests": self.args.max_requests,
                "maxResponseBytes": self.args.max_bytes, "maxTotalResponseBytes": self.args.max_bytes,
                "maxIndividualResponseBytes": self.args.max_response_bytes, "budgetLimited": self.budget_limited,
                "accessBlocked": self.blocked, "naturalPaginationEnd": not self.pending and bool(self.index_pages)},
            "errors": self.errors, **buckets, "nativeImport": False, "calendarDatesChanged": False, "reuseApproval": False}
        self.args.output.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.args.output.with_suffix(".json.tmp")
        temporary.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(self.args.output)
        return output

    def run(self):
        try:
            status, robots = self.fetch(ROBOTS)
            self.robots.update({"status": status, "sourceText": robots.decode("utf-8"), "sourceSHA256": digest(robots)})
            self.robot_parser = Protego.parse(robots.decode("utf-8"))
            self.robots["allowed"] = self.robot_parser.can_fetch(BASE, USER_AGENT)
            if not self.robots["allowed"]:
                raise CrawlStopped("robots-disallows-homepage")
            _, home = self.fetch(BASE)
            discovered = extract_home(home)
            self.discovery.update({"homepageHTMLSHA256": digest(home), "archiveSeeds": discovered["archives"],
                                   "publishedRecentPosts": discovered["publishedRecentPosts"]})
            if not discovered["recognizedArchiveWidget"] or not discovered["archives"]:
                raise CrawlStopped("no-published-monthly-archives")
            self.pending = sorted((entry["url"] for entry in discovered["archives"]), reverse=True)
            while self.pending:
                url = self.pending.pop(0)
                if url in self.index_pages:
                    continue
                if len(self.index_pages) >= self.args.max_pages:
                    self.pending.insert(0, url)
                    self.budget_limited = True
                    self.errors.append({"reason": "published-archive-page-budget-reached"})
                    break
                _, body = self.fetch(url)
                page = extract_archive(body, url)
                page.update({"sourceURL": url, "sourceHTMLSHA256": digest(body)})
                self.index_pages[url] = page
                if not page["recognizedArea"] or not page["title"] or not page["posts"]:
                    raise CrawlStopped("empty-or-unrecognized-published-archive:" + url)
                if page["unrecognizedPostLinks"] or page["unrecognizedPaginationLinks"]:
                    raise CrawlStopped("unrecognized-published-archive-links:" + url)
                for link in page["pagination"]:
                    if link not in self.index_pages and link not in self.pending:
                        self.pending.insert(0, link)
                for entry in page["posts"]:
                    self.occurrences[entry["url"]].append({**entry, "sourceIndexURL": url})
                if len(self.occurrences) > self.args.max_articles:
                    self.budget_limited = True
                    self.errors.append({"reason": "published-post-budget-reached"})
                    break
                if len(self.index_pages) % 10 == 0:
                    self.snapshot()
                    print(f"Indexed {len(self.index_pages)} published archive pages; {len(self.occurrences)} posts", flush=True)
            # The homepage's recent-post list independently checks archive discovery.
            if not self.budget_limited and not set(discovered["publishedRecentPosts"]).issubset(self.occurrences):
                raise CrawlStopped("homepage-recent-post-not-in-published-monthly-archives")
            for number, url in enumerate(list(self.occurrences)[:self.args.max_articles], 1):
                _, body = self.fetch(url)
                record = extract_article(body, url, index_entries=self.occurrences[url])
                self.records[url] = record
                if number % 10 == 0:
                    self.snapshot()
                    print(f"Preserved {number}/{len(self.occurrences)} original source posts", flush=True)
            self.completed = not self.errors and not self.budget_limited and not self.pending
        except (CrawlStopped, OSError, ValueError, subprocess.TimeoutExpired) as error:
            self.errors.append({"reason": str(error), "at": dt.datetime.now(dt.timezone.utc).isoformat()})
        output = self.snapshot("finished" if self.completed else "blocked" if self.blocked else "incomplete")
        print(json.dumps({"completed": self.completed, "archivePages": len(self.index_pages),
            "publishedPosts": len(self.occurrences), "biographyCandidates": len(output["articles"]),
            "excluded": len(output["excluded"]), "quarantine": len(output["quarantine"]),
            "errors": self.errors, "output": str(self.args.output)}, ensure_ascii=False), flush=True)
        return 0 if self.completed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).with_name("sources") / "tvmaria-saints-tl.json")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-tvmaria-saints-cache")
    parser.add_argument("--cache-expiry", type=int, default=86400)
    parser.add_argument("--max-pages", type=int, default=150)
    parser.add_argument("--max-articles", type=int, default=300)
    parser.add_argument("--max-requests", type=int, default=500)
    parser.add_argument("--max-bytes", type=int, default=80 * 1024 * 1024)
    parser.add_argument("--max-response-bytes", type=int, default=2 * 1024 * 1024)
    parser.add_argument("--delay", type=float, default=2.0)
    args = parser.parse_args()
    if not math.isfinite(args.delay) or args.delay < 2 or min(args.max_pages, args.max_articles, args.max_requests, args.max_bytes, args.max_response_bytes, args.cache_expiry) < 1:
        parser.error("Delay must be at least 2 seconds and every limit must be positive")
    return Collector(args).run()


if __name__ == "__main__":
    raise SystemExit(main())
