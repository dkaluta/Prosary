#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Collect Hebrew Feasts articles from the Saint James Vicariate for review.

This is a source catalogue, not an app-data importer. Follow the published Hebrew
category's links and pagination, and follow the Hebrew flag only when a discovered
article is not Hebrew. The actual article text decides its language. Every genre,
identity, feast date, credit and proposed excerpt still needs human review.

Run: uv run --script Shared/tools/scrape-catholic-hebrew-saints.py
Offline inspection: ... --parse-html FILE --parse-url URL --parse-kind article
Bounded diagnostic crawl: ... --limit 5 --output /tmp/hebrew-saints-sample.json
"""
from __future__ import annotations

import argparse
import asyncio
import datetime as dt
import hashlib
import json
import os
import re
import sys
import tempfile
from email.utils import parsedate_to_datetime
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit

import scrapy
from scrapy.crawler import CrawlerProcess
from scrapy.exceptions import IgnoreRequest
from scrapy.robotstxt import ProtegoRobotParser
from scrapy.selector import Selector
from scrapy.settings import default_settings

TOOLS = Path(__file__).resolve().parent
BASE = "https://www.catholic.co.il/"
INDEX = BASE + "?cat=faith&m=Feasts&view=category&id=35&lang=he"
ROBOTS = BASE + "robots.txt"
USER_AGENT = "ProsaryHebrewSaintsReview/1.0 (+https://prosary.app)"
BLOCKS = {"p", "div", "li", "h1", "h2", "h3", "h4", "blockquote", "tr"}
EXCLUDED = {"script", "style", "noscript", "form", "iframe", "object", "nav", "footer"}
HEBREW = re.compile(r"[\u05d0-\u05ea]")
CREDIT = re.compile(r"(?:שלח[הו]?|כתב[הו]?|כותב[תיםות]*) לנו|נכתב|מאת\b|תרגום|תרגם|תורגם|באדיבות|הכינ[הו]?\b")
DATE_LITERAL = re.compile(r"(?:[בה]-?)?\d{1,2}\s+ב[א-ת]+")


def canonical_url(url: str, base: str = BASE) -> str | None:
    """Canonicalize only public Feasts article/category links; never guess an ID."""
    try:
        parts = urlsplit(urljoin(base, url))
        if (parts.scheme not in {"https", "http"} or
                parts.hostname not in {"catholic.co.il", "www.catholic.co.il"} or
                parts.username or parts.password or parts.port or parts.fragment or
                parts.path not in {"/", "/index.php"}):
            return None
        query = parse_qs(parts.query, keep_blank_values=True)
        if set(query) - {"cat", "m", "view", "id", "lang", "page"}:
            return None
        if any(len(values) != 1 for values in query.values()):
            return None
        values = {key: value[0] for key, value in query.items()}
        if (values.get("cat") != "faith" or values.get("m") != "Feasts" or
                values.get("view") not in {"article", "category"} or
                not re.fullmatch(r"[1-9]\d*", values.get("id", ""))):
            return None
        if values.get("lang", "he") not in {"en", "he", "ru", "fr", "it"}:
            return None
        if values["view"] == "category" and values["id"] != "35":
            return None
        if "page" in values and (values["view"] != "category" or
                                  not re.fullmatch(r"\d+", values["page"])):
            return None
        ordered = {"cat": "faith", "m": "Feasts", "view": values["view"],
                   "id": values["id"], "lang": values.get("lang", "he")}
        if int(values.get("page", "0")):
            ordered["page"] = str(int(values["page"]))
        return BASE + "?" + urlencode(ordered)
    except (ValueError, TypeError):
        return None


def _selector(html: bytes | str) -> Selector:
    # The source declares UTF-8. Fail rather than replacing invalid source glyphs.
    return Selector(text=html.decode("utf-8") if isinstance(html, bytes) else html)


def _whitespace(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


def _text(element) -> str:
    """Preserve source characters while separating HTML block/br boundaries."""
    if not isinstance(element.tag, str) or element.tag.lower() in EXCLUDED:
        return ""
    parts = [element.text or ""]
    for child in element:
        tag = child.tag.lower() if isinstance(child.tag, str) else ""
        if tag == "br":
            parts.append("\n")
        elif tag not in EXCLUDED:
            value = _text(child)
            parts.append(("\n" if tag in BLOCKS else "") + value +
                         ("\n" if tag in BLOCKS else ""))
        parts.append(child.tail or "")
    return "".join(parts)


def _paragraphs(element, excluded_element=None) -> list[str]:
    """Collect article prose once, without media captions from image alt text."""
    tag = element.tag.lower() if isinstance(element.tag, str) else ""
    if element is excluded_element or tag in EXCLUDED or tag in {"h1", "img", "br"}:
        return []
    if tag in {"p", "li", "h2", "h3", "h4", "blockquote"}:
        value = _whitespace(_text(element))
        return [value] if value else []
    if not any(isinstance(child.tag, str) and child.tag.lower() in BLOCKS
               for child in element):
        value = _whitespace(_text(element))
        return [value] if value else []
    result = []
    pending = element.text or ""
    for child in element:
        child_tag = child.tag.lower() if isinstance(child.tag, str) else ""
        if child_tag in BLOCKS:
            value = _whitespace(pending)
            if value:
                result.append(value)
            pending = ""
            result.extend(_paragraphs(child, excluded_element))
        elif child_tag == "br":
            pending += "\n"
        elif child_tag not in EXCLUDED:
            pending += _text(child)
        pending += child.tail or ""
    value = _whitespace(pending)
    if value:
        result.append(value)
    return result


def _copyright(selector: Selector) -> str | None:
    for node in selector.xpath("//text()[contains(., '©')]").getall():
        text = _whitespace(node)
        if "Saint James Vicariate" in text:
            return text
    return None


def _language_evidence(text: str) -> dict:
    letters = sum(character.isalpha() for character in text)
    hebrew = len(HEBREW.findall(text))
    return {"hebrewLetters": hebrew, "alphabeticCharacters": letters,
            "hebrewLetterShare": round(hebrew / letters, 4) if letters else 0,
            "method": "article-prose-script-count; ignores menu and html language attribute"}


def extract_index(html: bytes | str, url: str) -> dict:
    """Pure HTML extractor. Pagination is published links, not calculated dates/pages."""
    selector = _selector(html)
    area = selector.css("#main_content > .col-md-8")
    title = _whitespace(area.css("h1").xpath("string(.)").get() or "")
    articles = {}
    pagination = set()
    raw_cards = 0
    unrecognized_cards = []
    for anchor in area.css("a"):
        is_card = bool(anchor.css("h3"))
        raw_cards += int(is_card)
        href = anchor.attrib.get("href", "")
        target = canonical_url(href, url)
        if not target:
            if is_card:
                unrecognized_cards.append(href)
            continue
        query = parse_qs(urlsplit(target).query)
        if query["lang"] != ["he"]:
            if is_card:
                unrecognized_cards.append(href)
            continue
        if query["view"] == ["category"] and not is_card:
            pagination.add(target)
        elif query["view"] == ["article"] and is_card:
            caption = _whitespace(anchor.css("h3").xpath("string(.)").get() or "")
            intro_nodes = anchor.css(".cat_intro")
            intro = _whitespace(_text(intro_nodes[0].root)) if intro_nodes else ""
            date = DATE_LITERAL.search(caption)
            articles[target] = {"url": target, "title": caption, "intro": intro,
                                "dateLiteral": date[0] if date else None}
        elif is_card:
            unrecognized_cards.append(href)
    return {"title": title, "articles": list(articles.values()),
            "pagination": sorted(pagination), "footerCopyright": _copyright(selector),
            "recognizedArea": bool(area), "rawArticleCardCount": raw_cards,
            "unrecognizedArticleCardLinks": unrecognized_cards}


def _classification(title: str, introduction: str) -> str:
    # These are review labels, never assertions that a saint/date has been matched.
    if re.search(r"תפיל[הת]|תפילת|יום תפילה", title):
        return "prayer-or-devotional-text"
    if re.search(r"משה|אברהם|שרה|אליהו|נביא", title):
        return "biblical-figure-candidate"
    if re.search(r"מלאכים|קדושים|וחבריו|וכל|מיכאל.*גבריאל", title):
        return "combined-saints-or-feast-candidate"
    if re.search(r"קדוש[הת]?|שליח|מבשר", title) or "ביוגרפיה" in introduction:
        return "saint-biography-candidate"
    return "feast-description-candidate"


def extract_article(html: bytes | str, url: str, *, request_url: str | None = None,
                    discovered_index_url: str | None = None,
                    index_entry: dict | None = None) -> dict:
    """Pure extraction; Hebrew acceptance uses the article, never a flag/menu label."""
    selector = _selector(html)
    area = selector.css("#main_content > .col-md-7 > div")
    wrapper = area[0].root if area else None
    title = ""
    introduction = ""
    paragraphs = []
    if wrapper is not None:
        heading = wrapper.find("h1")
        if heading is not None:
            title = _whitespace(_text(heading))
        intro_node = None
        for child in wrapper:
            if (isinstance(child.tag, str) and child.tag.lower() == "div" and
                    re.search(r"font-weight\s*:\s*bold", child.get("style", ""), re.I)):
                intro_node = child
                introduction = _whitespace(_text(child))
                break
        paragraphs = _paragraphs(wrapper, intro_node)
    links = []
    flag = None
    for anchor in selector.xpath("//a[img]"):
        image = anchor.css("img").attrib.get("src", "")
        if not image.startswith("/img/"):
            continue
        target = canonical_url(anchor.attrib.get("href", ""), url)
        if target and parse_qs(urlsplit(target).query).get("view") == ["article"]:
            entry = {"url": target, "imagePath": image,
                     "label": anchor.css("img").attrib.get("alt", "")}
            if entry not in links:
                links.append(entry)
            if image == "/img/he_il.gif":
                flag = target
    content = "\n".join([introduction, *paragraphs])
    evidence = _language_evidence(content)
    body_evidence = _language_evidence("\n".join(paragraphs))
    intro_evidence = _language_evidence(introduction)
    reason = None
    shape = None
    if not title:
        reason = "missing-article-title"
    elif paragraphs:
        if not body_evidence["alphabeticCharacters"]:
            reason = "article-body-has-no-language-evidence"
        elif not body_evidence["hebrewLetters"] or body_evidence["hebrewLetterShare"] < 0.70:
            reason = "article-body-is-not-demonstrably-hebrew"
        elif not HEBREW.search(title):
            reason = "article-title-is-not-hebrew"
        elif evidence["hebrewLetters"] < 40:
            reason = "insufficient-article-prose"
        else:
            shape = "short-body" if body_evidence["hebrewLetters"] < 40 else "body"
    elif (HEBREW.search(title) and intro_evidence["hebrewLetters"] >= 40 and
          intro_evidence["hebrewLetterShare"] >= 0.70):
        # Some published Hebrew biographies live entirely in the bold intro field.
        shape = "introduction-only"
    elif not HEBREW.search(title) and intro_evidence["hebrewLetterShare"] >= 0.70:
        reason = "article-title-is-not-hebrew"
    elif intro_evidence["alphabeticCharacters"] and intro_evidence["hebrewLetterShare"] < 0.70:
        reason = "article-introduction-is-not-demonstrably-hebrew"
    elif intro_evidence["hebrewLetters"]:
        reason = "insufficient-article-prose"
    else:
        reason = "missing-article-body"
    canonical = canonical_url(url)
    article_id = parse_qs(urlsplit(canonical).query)["id"][0] if canonical else None
    date = DATE_LITERAL.search(title)
    source = html.encode("utf-8") if isinstance(html, str) else html
    credits = []
    for location, texts in (("introduction", [introduction]), ("body", paragraphs)):
        for text in texts:
            if text and CREDIT.search(text):
                credits.append({"text": text, "location": location,
                                "kind": "credit-or-reference", "reviewStatus": "required"})
    return {"articleId": article_id, "sourceURL": canonical or url,
            "requestURL": request_url or url, "title": title,
            "introduction": introduction, "paragraphs": paragraphs,
            "language": "he" if reason is None else None, "languageEvidence": evidence,
            "bodyLanguageEvidence": body_evidence, "introductionLanguageEvidence": intro_evidence,
            "contentShape": shape,
            "multilingualLinks": links, "hebrewFlagURL": flag, "credits": credits,
            "classification": _classification(title, introduction) if reason is None else "quarantined",
            "rejectionReason": reason, "sourceHTMLSHA256": hashlib.sha256(source).hexdigest(),
            "sourceTextSHA256": hashlib.sha256(content.encode("utf-8")).hexdigest(),
            "discoveredIndexURL": discovered_index_url,
            "indexEntry": index_entry, "sourceDateLiteral": date[0] if date else None,
            "reviewStatus": "required", "footerCopyright": _copyright(selector)}


def quarantine_record(record: dict) -> dict:
    """Keep complete mixed Hebrew source evidence; bound wholly foreign attempts."""
    rejected = dict(record)
    intro = record["introduction"]
    intro_evidence = _language_evidence(intro)
    preserve_intro = intro_evidence["hebrewLetters"] > 0 and intro_evidence["hebrewLetterShare"] >= 0.70
    paragraphs = [text for text in record["paragraphs"]
                  if (evidence := _language_evidence(text))["hebrewLetters"] > 0
                  and evidence["hebrewLetterShare"] >= 0.70]
    rejected["bodyEvidence"] = _whitespace(" ".join([intro, *record["paragraphs"]]))[:240]
    rejected["introduction"] = intro if preserve_intro else ""
    rejected["paragraphs"] = paragraphs
    rejected["preservedHebrewProse"] = {"introduction": preserve_intro,
                                        "paragraphs": len(paragraphs),
                                        "omittedNonHebrewParagraphs": len(record["paragraphs"]) - len(paragraphs)}
    if HEBREW.search(record["title"]) and record["languageEvidence"]["hebrewLetters"] >= 40:
        # Latin quotations, French names, or a bilingual schedule can lower the
        # script ratio without making the source article wholly foreign. Retain
        # every original prose block separately for review; language remains None.
        rejected["sourceLanguageShape"] = "mixed-language"
        rejected["fullSourceProse"] = {"introduction": intro, "paragraphs": record["paragraphs"]}
    # Credits stay literal; preserve only evidence belonging to retained Hebrew prose.
    retained = {rejected["introduction"], *paragraphs}
    rejected["credits"] = [credit for credit in record["credits"] if credit["text"] in retained]
    return rejected


def _page(url: str) -> int:
    return int(parse_qs(urlsplit(url).query).get("page", ["0"])[0])


def _atomic_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".tmp-{os.getpid()}")
    try:
        temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


class FeastsBoundaryMiddleware:
    """Block off-scope redirects and enforce shared request/byte budgets."""
    def __init__(self, crawler):
        self.crawler = crawler

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    def process_request(self, request, spider=None):
        spider = spider or self.crawler.spider
        if request.url != ROBOTS and canonical_url(request.url) is None:
            spider.error("off-scope-request", request.url)
            raise IgnoreRequest("Outside public Feasts scope")
        spider.attempted_requests += 1
        if spider.attempted_requests > spider.args.max_requests or spider.bytes_received > spider.args.max_bytes:
            spider.budget_limited = True
            raise IgnoreRequest("Request or response-byte budget reached")
        return None


class BoundedRetryBackoffMiddleware:
    def __init__(self, crawler):
        self.crawler = crawler

    @classmethod
    def from_crawler(cls, crawler):
        return cls(crawler)

    async def process_response(self, request, response, spider=None):
        spider = spider or self.crawler.spider
        spider.bytes_received += len(response.body)
        if spider.bytes_received > spider.args.max_bytes:
            spider.budget_limited = True
        if response.status in {429, 500, 502, 503, 504}:
            attempt = request.meta.get("retry_times", 0)
            if attempt < 2:
                delay = 4 * (2 ** attempt)
                header = response.headers.get("Retry-After", b"").decode("ascii", errors="ignore")
                try:
                    delay = max(delay, float(header))
                except ValueError:
                    try:
                        delay = max(delay, (parsedate_to_datetime(header) - dt.datetime.now(dt.timezone.utc)).total_seconds())
                    except (ValueError, TypeError, OverflowError):
                        pass
                await asyncio.sleep(min(60, delay))
        return response


class HebrewSaintsSpider(scrapy.Spider):
    name = "catholic_hebrew_saints_review"
    allowed_domains = ["www.catholic.co.il", "catholic.co.il"]

    def __init__(self, args, **kwargs):
        super().__init__(**kwargs)
        self.args = args
        self.index_pages = {}
        self.article_records = {}
        self.quarantine = []
        self.errors = []
        self.scheduled_pages = set()
        self.scheduled_articles = set()
        self.discovered_articles = set()
        self.natural_end = False
        self.budget_limited = False
        self.attempted_requests = 0
        self.bytes_received = 0
        self.copyright = None
        self.robots = {"url": ROBOTS, "status": None, "allowed": None}
        self.completed = False

    def error(self, reason, url, detail=None):
        self.errors.append({"reason": reason, "url": url, "detail": detail})

    async def start(self):
        # Fetch robots explicitly first so unavailable robots cannot silently permit a crawl.
        yield scrapy.Request(ROBOTS, callback=self.parse_robots, errback=self.request_failed,
                             meta={"dont_obey_robotstxt": True, "handle_httpstatus_list": [404]})

    def parse_robots(self, response):
        self.robots.update({"status": response.status,
                            "sourceHTMLSHA256": hashlib.sha256(response.body).hexdigest()})
        if response.status not in {200, 404}:
            self.error("robots-unavailable", response.url, f"HTTP {response.status}")
            return
        parser = ProtegoRobotParser.from_crawler(self.crawler, response.body if response.status == 200 else b"")
        self.robots["allowed"] = parser.allowed(INDEX, USER_AGENT)
        if not self.robots["allowed"]:
            self.error("robots-disallows-category", INDEX)
            return
        self.scheduled_pages.add(canonical_url(INDEX))
        yield scrapy.Request(INDEX, callback=self.parse_index, errback=self.request_failed, priority=100)

    def parse_index(self, response):
        page = extract_index(response.body, response.url)
        self.copyright = self.copyright or page.pop("footerCopyright")
        url = canonical_url(response.url)
        parent_url = response.meta.get("populatedParentURL")
        self.index_pages[url] = {"url": url, "title": page["title"],
                                 "sourceHTMLSHA256": hashlib.sha256(response.body).hexdigest(),
                                 "articleCount": len(page["articles"]), "pagination": page["pagination"],
                                 "recognizedArea": page["recognizedArea"],
                                 "rawArticleCardCount": page["rawArticleCardCount"],
                                 "terminalEmptyPage": False, "populatedParentURL": parent_url}
        if page["title"] != "חגים" or not page["recognizedArea"]:
            self.error("unrecognized-or-empty-hebrew-category", response.url)
            return
        if page["unrecognizedArticleCardLinks"]:
            self.error("unrecognized-article-card-links", response.url,
                       page["unrecognizedArticleCardLinks"])
            return
        if not page["articles"]:
            parent = self.index_pages.get(parent_url, {})
            if (_page(url) > 0 and not page["rawArticleCardCount"] and
                    parent.get("articleCount", 0) > 0 and url in parent.get("pagination", []) and
                    _page(parent_url) < _page(url)):
                # This site prints a synthetic next arrow even past its final article.
                # A published link from a populated page to a recognized empty category
                # is its natural terminator; never follow the empty page's next arrow.
                self.index_pages[url]["terminalEmptyPage"] = True
                self.natural_end = True
                return
            self.error("unrecognized-or-empty-hebrew-category", response.url)
            return
        higher_pages = [link for link in page["pagination"] if _page(link) > _page(url)]
        if not higher_pages:
            self.natural_end = True
        for target in page["pagination"]:
            if target in self.scheduled_pages:
                continue
            if len(self.scheduled_pages) >= self.args.max_pages:
                self.budget_limited = True
                continue
            self.scheduled_pages.add(target)
            yield scrapy.Request(target, callback=self.parse_index, errback=self.request_failed, priority=100,
                                 meta={"populatedParentURL": url} if _page(target) > _page(url) else {})
        for entry in page["articles"]:
            target = entry["url"]
            if target in self.discovered_articles:
                continue
            self.discovered_articles.add(target)
            if len(self.scheduled_articles) >= self.args.max_articles:
                self.budget_limited = True
                continue
            self.scheduled_articles.add(target)
            yield scrapy.Request(target, callback=self.parse_article, errback=self.request_failed,
                                 meta={"originalRequestURL": target},
                                 cb_kwargs={"discovered_index_url": url, "index_entry": entry,
                                            "chain": [target]})

    def parse_article(self, response, discovered_index_url, index_entry, chain):
        record = extract_article(response.body, response.url,
                                 request_url=response.meta.get("originalRequestURL", response.request.url),
                                 discovered_index_url=discovered_index_url, index_entry=index_entry)
        record["publishedLinkChain"] = chain
        self.copyright = self.copyright or record.pop("footerCopyright")
        if record["rejectionReason"] is None:
            self.article_records[record["sourceURL"]] = record
            return
        # Preserve complete actual Hebrew even when a malformed article cannot be accepted.
        rejected = quarantine_record(record)
        target = (record["hebrewFlagURL"] if
                  record["rejectionReason"] in {"article-body-is-not-demonstrably-hebrew",
                                               "article-introduction-is-not-demonstrably-hebrew"} else None)
        if target in chain:
            rejected["flagFollowResult"] = "cycle"
        elif target in self.scheduled_articles:
            rejected["flagFollowResult"] = "already-scheduled"
        elif not target:
            rejected["flagFollowResult"] = "no-published-hebrew-article-link"
        elif len(chain) >= 5 or len(self.scheduled_articles) >= self.args.max_articles:
            rejected["flagFollowResult"] = "follow-budget-reached"
            self.budget_limited = True
        else:
            rejected["flagFollowResult"] = "followed-published-hebrew-link"
            self.scheduled_articles.add(target)
            yield scrapy.Request(target, callback=self.parse_article, errback=self.request_failed,
                                 meta={"originalRequestURL": target},
                                 cb_kwargs={"discovered_index_url": discovered_index_url,
                                            "index_entry": index_entry, "chain": [*chain, target]})
        self.quarantine.append(rejected)

    def request_failed(self, failure):
        self.error("request-failed", failure.request.url, failure.getErrorMessage()[:500])

    def closed(self, reason):
        stats = self.crawler.stats.get_stats()
        exceptions = sum(value for key, value in stats.items() if key.startswith("spider_exceptions/"))
        if exceptions:
            self.error("spider-callback-exception", INDEX, f"{exceptions} callback errors")
        self.completed = (reason == "finished" and self.natural_end and not self.errors and
                          not self.budget_limited and self.robots["allowed"] is True)
        output = {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                  "source": {"provider": "Saint James Vicariate for Hebrew Speaking Catholics in Israel",
                             "siteURL": BASE, "indexURL": INDEX, "language": "he",
                             "footerCopyright": self.copyright},
                  "reviewStatus": "required", "completed": self.completed, "finishReason": reason,
                  "robots": self.robots,
                  "policy": {"purpose": "source-only review catalogue; no native dataset import",
                             "languageValidation": "actual article prose, never menu or lang attribute",
                             "calendarMapping": "none; printed date labels are unreviewed source literals",
                             "copyrightReview": "required before redistribution of full article prose",
                             "userAgent": USER_AGENT, "minimumDelaySeconds": self.args.delay,
                             "cacheExpirySeconds": self.args.cache_expiry},
                  "crawl": {"indexPages": len(self.index_pages),
                            "discoveredArticles": len(self.discovered_articles),
                            "scheduledArticleRequests": len(self.scheduled_articles),
                            "hebrewArticles": len(self.article_records), "quarantinedAttempts": len(self.quarantine),
                            "attemptedRequests": self.attempted_requests, "responseBodyBytes": self.bytes_received,
                            "receivedResponses": stats.get("downloader/response_count", 0),
                            "downloadedResponses": max(0, stats.get("downloader/response_count", 0) -
                                                       stats.get("httpcache/hit", 0)),
                            "cacheHits": stats.get("httpcache/hit", 0),
                            "retriedRequests": stats.get("retry/count", 0),
                            "budgetLimited": self.budget_limited, "naturalPaginationEnd": self.natural_end,
                            "maxPages": self.args.max_pages, "maxArticles": self.args.max_articles,
                            "maxRequests": self.args.max_requests, "maxResponseBytes": self.args.max_bytes},
                  "indexPages": sorted(self.index_pages.values(), key=lambda item: _page(item["url"])),
                  "articles": sorted(self.article_records.values(), key=lambda item: int(item["articleId"])),
                  "quarantine": self.quarantine, "errors": self.errors}
        _atomic_json(self.args.output, output)
        print(f"{'Complete' if self.completed else 'Incomplete'} source review catalogue: "
              f"{len(self.article_records)} Hebrew articles, {len(self.quarantine)} quarantined attempts, "
              f"{len(self.errors)} errors → {self.args.output}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/catholic-hebrew-saints.json")
    parser.add_argument("--cache-dir", type=Path,
                        default=Path(tempfile.gettempdir()) / "prosary-catholic-hebrew-saints-http-cache")
    parser.add_argument("--cache-expiry", type=int, default=86400,
                        help="Reuse successful HTML for this many seconds (default one day).")
    parser.add_argument("--delay", type=float, default=2.0, help="Minimum seconds between requests; at least 2.")
    parser.add_argument("--max-pages", type=int, default=100)
    parser.add_argument("--max-articles", type=int, default=1000)
    parser.add_argument("--max-requests", type=int, default=2500)
    parser.add_argument("--max-bytes", type=int, default=50 * 1024 * 1024)
    parser.add_argument("--limit", type=int, help="Diagnostic alias for --max-articles; output remains incomplete if truncated.")
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO")
    parser.add_argument("--parse-html", type=Path, help="Extract a local saved HTML fixture without any network access.")
    parser.add_argument("--parse-url", default=INDEX, help="Source URL associated with --parse-html.")
    parser.add_argument("--parse-kind", choices=["index", "article"], default="article")
    args = parser.parse_args()
    if args.parse_html:
        extractor = extract_index if args.parse_kind == "index" else extract_article
        print(json.dumps(extractor(args.parse_html.read_bytes(), args.parse_url), ensure_ascii=False, indent=2))
        return 0
    if args.limit is not None:
        args.max_articles = args.limit
    if args.delay < 2 or min(args.max_pages, args.max_articles, args.max_requests, args.max_bytes, args.cache_expiry) <= 0:
        parser.error("Delay must be at least 2 seconds and every crawl/cache budget must be positive.")
    settings = {"USER_AGENT": USER_AGENT, "ROBOTSTXT_USER_AGENT": USER_AGENT, "ROBOTSTXT_OBEY": True,
                "CONCURRENT_REQUESTS": 1, "CONCURRENT_REQUESTS_PER_DOMAIN": 1,
                "DOWNLOAD_DELAY": args.delay,
                "AUTOTHROTTLE_ENABLED": True, "AUTOTHROTTLE_START_DELAY": args.delay,
                "AUTOTHROTTLE_MAX_DELAY": 60, "AUTOTHROTTLE_TARGET_CONCURRENCY": 1.0,
                "DOWNLOAD_TIMEOUT": 30, "DOWNLOAD_MAXSIZE": 2 * 1024 * 1024,
                "DOWNLOAD_WARNSIZE": 1024 * 1024, "RETRY_TIMES": 2,
                "RETRY_HTTP_CODES": [408, 429, 500, 502, 503, 504],
                "REDIRECT_MAX_TIMES": 3, "COOKIES_ENABLED": False,
                "HTTPCACHE_ENABLED": True, "HTTPCACHE_DIR": str(args.cache_dir.resolve()),
                "HTTPCACHE_EXPIRATION_SECS": args.cache_expiry,
                "HTTPCACHE_IGNORE_HTTP_CODES": [408, 429, 500, 502, 503, 504],
                "HTTPCACHE_POLICY": "scrapy.extensions.httpcache.DummyPolicy",
                "DOWNLOADER_MIDDLEWARES": {FeastsBoundaryMiddleware: 80, BoundedRetryBackoffMiddleware: 600},
                "LOG_LEVEL": args.log_level, "LOGSTATS_INTERVAL": 60,
                "TELNETCONSOLE_ENABLED": False, "REMOTE_CONTROL_ENABLED": False,
                "TWISTED_REACTOR": "twisted.internet.asyncioreactor.AsyncioSelectorReactor"}
    # Older supported Scrapy releases use the equivalent boolean setting.
    settings.update({"DOWNLOAD_DELAY_JITTER": 0} if hasattr(default_settings, "DOWNLOAD_DELAY_JITTER")
                    else {"RANDOMIZE_DOWNLOAD_DELAY": False})
    process = CrawlerProcess(settings=settings)
    crawler = process.create_crawler(HebrewSaintsSpider)
    process.crawl(crawler, args=args)
    process.start()
    return 0 if crawler.spider and crawler.spider.completed else 1


if __name__ == "__main__":
    sys.exit(main())
