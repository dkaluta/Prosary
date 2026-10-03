#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3", "lingua-language-detector>=2,<3"]
# ///
"""Crawl the published English, French, Italian and Russian Feasts editions for review.

One spider shares the site's request delay across every edition. The neighbouring
Hebrew scraper supplies the tested HTML prose extractor; its script and catalogue
are never modified. These catalogues do not assign calendar dates or approve the
accuracy, genre, identity, translation credits or redistribution of source prose.

uv run --script Shared/tools/scrape-catholic-saints.py
Use --languages en fr it ru (default), --output-dir, or a separate --cache-dir.
Partial snapshots are saved during the crawl; budget/network failures exit nonzero.
"""
from __future__ import annotations

import argparse
import collections
import datetime as dt
import hashlib
import importlib.util
import json
import math
import re
import sys
import tempfile
from pathlib import Path
from urllib.parse import parse_qs, urlencode, urljoin, urlsplit, urlunsplit

import scrapy
from lingua import Language, LanguageDetectorBuilder
from scrapy.crawler import CrawlerProcess
from scrapy.exceptions import IgnoreRequest
from scrapy.robotstxt import ProtegoRobotParser
from scrapy.settings import default_settings

TOOLS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("catholic_hebrew_source_extractor", TOOLS / "scrape-catholic-hebrew-saints.py")
HEBREW_EXTRACTOR = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = HEBREW_EXTRACTOR
SPEC.loader.exec_module(HEBREW_EXTRACTOR)
BASE = HEBREW_EXTRACTOR.BASE
ROBOTS = HEBREW_EXTRACTOR.ROBOTS
USER_AGENT = "ProsarySaintsSourceReview/1.0 (+https://prosary.app)"
ALIASES = {"en": "en", "en-GB": "en", "fr": "fr", "fr-FR": "fr", "it": "it", "it-IT": "it",
           "ru": "ru", "ru-RU": "ru", "he": "he", "he-IL": "he"}
EDITIONS = {"en": {"heading": "Feasts", "flag": "/img/en.gif"},
            "fr": {"heading": "Fêtes", "flag": "/img/fr_fr.gif"},
            "it": {"heading": "Feste", "flag": "/img/it_it.gif"},
            "ru": {"heading": "Праздники", "flag": "/img/ru_ru.gif"}}
DETECTOR_LANGUAGES = [Language.ENGLISH, Language.FRENCH, Language.ITALIAN, Language.RUSSIAN,
                      Language.HEBREW, Language.ARABIC, Language.UKRAINIAN, Language.TAGALOG,
                      Language.LATIN, Language.SPANISH, Language.PORTUGUESE, Language.GERMAN,
                      Language.POLISH, Language.GREEK]
DETECTOR = LanguageDetectorBuilder.from_languages(*DETECTOR_LANGUAGES).build()
CONFIDENCE_MINIMUM = 0.65
CONFIDENCE_GAP = 0.15
CREDIT_PATTERNS = {"en": r"\b(?:sister|brother|father)\b.*\b(?:sent|wrote|writes)|\b(?:wrote|writes|sent|sends|provided|shared)\s+(?:to\s+)?us\b|\b(?:written|translated|compiled) by\b|\b(?:translation|translator|courtesy|thanks to)\b",
                  "fr": r"\b(?:sœur|soeur|frère|père)\b.*\b(?:envoy|écrit)|\bnous\s+(?:(?:a|ont)\s+)?(?:écrit|envoyé|transmis)\b|\b(?:traduction|traduit|traducteur|traductrice|avec l’aimable|par les soins)\b",
                  "it": r"\b(?:suor|suora|fratello|padre)\b.*\b(?:inviato|scritto|mandato)|\bci\s+(?:(?:ha|hanno)\s+(?:scritto|inviato|mandato)|scrive)\b|\b(?:traduzione|tradotto|traduttrice|traduttore|a cura di|per gentile)\b",
                  "ru": r"(?:сестра|брат|отец).*(?:прислал|написал)|(?:прислал[аи]?|написал[аи]?|пишет|предоставил[аи]?)\s+нам\b|(?:перевод|перевёл|перевел|перевела|подготовил|источник)"}


def canonical_url(url: str, base: str = BASE, language: str | None = None) -> str | None:
    """Accept only published Feasts links; regional site aliases share one cache identity."""
    try:
        absolute = urljoin(base, url)
        parts = urlsplit(absolute)
        query = parse_qs(parts.query, keep_blank_values=True)
        if any(len(values) != 1 for values in query.values()):
            return None
        inherited = language or parse_qs(urlsplit(base).query).get("lang", ["en"])[0]
        source_language = query.get("lang", [inherited])[0]
        if source_language not in ALIASES:
            return None
        query["lang"] = [ALIASES[source_language]]
        normalized = urlunsplit((parts.scheme, parts.netloc, parts.path,
                                 urlencode({key: values[0] for key, values in query.items()}), parts.fragment))
        return HEBREW_EXTRACTOR.canonical_url(normalized)
    except (ValueError, TypeError):
        return None


def index_url(language: str) -> str:
    return BASE + "?" + urlencode({"cat": "faith", "m": "Feasts", "view": "category", "id": "35", "lang": language})


def url_language(url: str) -> str | None:
    return ALIASES.get(parse_qs(urlsplit(url).query).get("lang", [""])[0])


def language_evidence(text: str, expected: str) -> dict:
    letters = sum(character.isalpha() for character in text)
    sampled = text if len(text) <= 16000 else text[:12000] + "\n" + text[-4000:]
    values = DETECTOR.compute_language_confidence_values(sampled) if letters else []
    ranked = [{"language": value.language.iso_code_639_1.name.lower(), "confidence": round(value.value, 6)}
              for value in values[:5]]
    best = ranked[0] if ranked else {"language": None, "confidence": 0.0}
    next_confidence = ranked[1]["confidence"] if len(ranked) > 1 else 0.0
    gap = best["confidence"] - next_confidence
    matches = (best["language"] == expected and best["confidence"] >= CONFIDENCE_MINIMUM and gap >= CONFIDENCE_GAP)
    return {"method": "lingua-high-accuracy-14-languages; actual prose only",
            "alphabeticCharacters": letters, "detectedLanguage": best["language"],
            "confidence": best["confidence"], "confidenceGap": round(gap, 6),
            "matchesRequestedLanguage": matches, "requestedLanguage": expected,
            "sampledCharacters": len(sampled), "sourceCharacters": len(text), "topCandidates": ranked}


def extract_index(html: bytes | str, url: str, language: str) -> dict:
    selector = HEBREW_EXTRACTOR._selector(html)
    area = selector.css("#main_content > .col-md-8")
    title = HEBREW_EXTRACTOR._whitespace(area.css("h1").xpath("string(.)").get() or "")
    articles = {}
    pagination = {}
    raw_cards = 0
    unrecognized = []
    for anchor in area.css("a"):
        is_card = bool(anchor.css("h3"))
        raw_cards += int(is_card)
        href = anchor.attrib.get("href", "")
        target = canonical_url(href, url, language)
        if not target or url_language(target) != language:
            if is_card:
                unrecognized.append(href)
            continue
        query = parse_qs(urlsplit(target).query)
        if query["view"] == ["category"] and not is_card:
            pagination[target] = urljoin(url, href)
        elif query["view"] == ["article"] and is_card:
            caption = HEBREW_EXTRACTOR._whitespace(anchor.css("h3").xpath("string(.)").get() or "")
            intro_nodes = anchor.css(".cat_intro")
            intro = HEBREW_EXTRACTOR._whitespace(HEBREW_EXTRACTOR._text(intro_nodes[0].root)) if intro_nodes else ""
            articles[target] = {"url": target, "publishedURL": urljoin(url, href), "title": caption, "intro": intro}
        elif is_card:
            unrecognized.append(href)
    return {"title": title, "articles": list(articles.values()),
            "articleIDs": [parse_qs(urlsplit(target).query)["id"][0] for target in articles],
            "pagination": sorted(pagination),
            "publishedPagination": pagination, "recognizedArea": bool(area), "rawArticleCardCount": raw_cards,
            "unrecognizedArticleCardLinks": unrecognized, "footerCopyright": HEBREW_EXTRACTOR._copyright(selector)}


def classification(title: str, language: str) -> str:
    patterns = {
        "en": (r"prayer", r"Moses|Abraham|Elijah|prophet", r"archangels|companions|saints", r"saint|\bSt\.|blessed|apostle|martyr"),
        "fr": (r"prière", r"Moïse|Abraham|Élie|prophète", r"archanges|compagnons|saints|saintes", r"saint|bienheureu|apôtre|martyr"),
        "it": (r"preghiera", r"Mosè|Abramo|Elia|profeta", r"arcangeli|compagni|santi", r"santa|santo|\bsan\b|beato|apostol|martir"),
        "ru": (r"молитв", r"Моисей|Авраам|Илия|пророк", r"архангел|сподвижник|святых", r"свят|блаж|апостол|мученик"),
    }
    for pattern, label in zip(patterns[language], ["prayer-or-devotional-text", "biblical-figure-candidate",
                                                "combined-saints-or-feast-candidate", "saint-biography-candidate"]):
        if re.search(pattern, title, re.I):
            return label
    return "feast-description-candidate"


def extract_article(html: bytes | str, url: str, language: str, *, request_url: str | None = None,
                    discovered_index_url: str | None = None, index_entry: dict | None = None) -> dict:
    # Its Hebrew acceptance decision is deliberately replaced; extraction remains shared.
    record = HEBREW_EXTRACTOR.extract_article(html, url, request_url=request_url,
                                            discovered_index_url=discovered_index_url, index_entry=index_entry)
    body = "\n".join(record["paragraphs"])
    combined = "\n".join([record["introduction"], *record["paragraphs"]])
    body_evidence = language_evidence(body, language)
    intro_evidence = language_evidence(record["introduction"], language)
    combined_evidence = language_evidence(combined, language)
    main = body_evidence if record["paragraphs"] else intro_evidence
    reason = None
    if not record["title"]:
        reason = "missing-article-title"
    elif main["alphabeticCharacters"] == 0:
        reason = "missing-article-prose"
    elif not main["matchesRequestedLanguage"]:
        reason = "source-language-mismatch-or-uncertain"
    elif combined_evidence["alphabeticCharacters"] < 40:
        reason = "insufficient-article-prose"
    shape = ("introduction-only" if not record["paragraphs"] else
             "short-body" if body_evidence["alphabeticCharacters"] < 40 else "body")
    # Retain every actual flag link; the neighbouring extractor handles its known bare aliases.
    selector = HEBREW_EXTRACTOR._selector(html)
    flag = next((link["url"] for link in record["multilingualLinks"]
                 if link["imagePath"] == EDITIONS[language]["flag"]), None)
    credits = []
    for location, texts in (("introduction", [record["introduction"]]), ("body", record["paragraphs"])):
        for text in texts:
            if re.search(CREDIT_PATTERNS[language], text, re.I):
                credits.append({"text": text, "location": location, "kind": "credit-or-reference", "reviewStatus": "required"})
    issues = []
    title_matches = index_entry is None or record["title"] == index_entry["title"]
    if not title_matches:
        issues.append({"code": "index-article-title-mismatch", "indexTitle": index_entry["title"]})
    if flag and url_language(flag) != language:
        issues.append({"code": "published-language-flag-targets-another-edition", "publishedURL": flag})
    if record["paragraphs"] and intro_evidence["alphabeticCharacters"] >= 80 and not intro_evidence["matchesRequestedLanguage"]:
        issues.append({"code": "introduction-language-differs-or-is-uncertain", "evidence": intro_evidence})
    years = sorted(set(int(value) for value in re.findall(r"(?<!\d)(?:[12]\d{3}|[3-9]\d{3})(?!\d)", combined)))
    long_numbers = [{"literal": match[0], "context": combined[max(0, match.start()-70):match.end()+70]}
                    for match in re.finditer(r"(?<!\d)\d{5,}(?!\d)", combined)]
    if long_numbers:
        # A conference number or identifier may be legitimate. These are review
        # candidates, never automatic historical corrections or assumed years.
        issues.append({"code": "implausible-year-literal-or-identifier-needs-context", "candidates": long_numbers})
    if language == "ru" and record["articleId"] == "3889" and re.search(r"(?<!\d)19897(?!\d)", combined):
        issues.append({"code": "confirmed-source-death-year-discrepancy", "sourceLiteral": "19897",
                       "subject": "Thérèse of Lisieux", "verifiedDeathDate": "1897-09-30",
                       "verificationURL": "https://www.vatican.va/content/john-paul-ii/en/apost_letters/1997/documents/hf_jp-ii_apl_19101997_divini-amoris.html",
                       "verificationLocation": "paragraph 5", "handling": "source prose unchanged; editorial review required"})
    if any(value > dt.date.today().year + 1 for value in years):
        issues.append({"code": "future-year-like-number-needs-context", "values": [value for value in years if value > dt.date.today().year + 1]})
    if reason:
        issues.append({"code": reason, "evidence": main})
    for field in ["hebrewFlagURL", "sourceDateLiteral"]:
        record.pop(field, None)
    record.update({"sourceURL": canonical_url(url, language=language) or url,
                   "language": language if reason is None else None, "requestedLanguage": language,
                   "languageEvidence": combined_evidence, "bodyLanguageEvidence": body_evidence,
                   "introductionLanguageEvidence": intro_evidence, "contentShape": shape,
                   "languageFlagURL": flag,
                   "languageFlagMatchesRequestedEdition": bool(flag and url_language(flag) == language),
                   "credits": credits, "rejectionReason": reason,
                   "classification": classification(record["title"], language),
                   "htmlLanguageAttribute": selector.css("html").attrib.get("lang"),
                   "sourceDateLabel": record["title"], "sourceYearLikeNumbers": years,
                   "longNumericLiteralReviewCandidates": long_numbers,
                   "review": {"automatedChecks": {"sourceHTMLDigestRecorded": True,
                                                 "articleLanguageMatches": reason is None,
                                                 "indexTitleMatches": title_matches,
                                                 "primaryContentOnly": True},
                              "issues": issues,
                              "manualReviewRequired": ["biographical accuracy", "genre and saint identity", "calendar dates and precedence",
                                                       "author and translator attribution", "reuse permission"]}})
    return record


class BoundaryMiddleware:
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
            raise IgnoreRequest("Shared request or response-byte budget reached")


def new_state(language: str) -> dict:
    return {"language": language, "indexPages": {}, "articles": {}, "quarantine": {}, "errors": [],
            "scheduledPages": set(), "scheduledArticles": set(), "discoveredArticles": set(),
            "naturalEnd": False, "copyright": None, "responses": 0, "cacheHits": 0}


class SaintsSpider(scrapy.Spider):
    name = "catholic_saints_editions_review"
    allowed_domains = ["www.catholic.co.il", "catholic.co.il"]

    def __init__(self, args, **kwargs):
        super().__init__(**kwargs)
        self.args = args
        self.states = {language: new_state(language) for language in args.languages}
        self.errors = []
        self.attempted_requests = 0
        self.bytes_received = 0
        self.budget_limited = False
        self.robots = {"url": ROBOTS, "status": None, "allowed": {}}
        self.completed = False
        self.progress_responses = 0
        self.hebrew_links = collections.defaultdict(list)
        existing = TOOLS / "sources/catholic-hebrew-saints.json"
        if existing.exists():
            for article in json.loads(existing.read_text())["articles"]:
                for link in article["multilingualLinks"]:
                    self.hebrew_links[link["url"]].append({"articleId": article["articleId"], "sourceURL": article["sourceURL"],
                                                            "title": article["title"], "relationship": "published-language-flag; identity-unapproved"})

    def error(self, reason, url, detail=None):
        error = {"reason": reason, "url": url, "detail": detail}
        language = url_language(url)
        (self.states[language]["errors"] if language in self.states else self.errors).append(error)

    async def start(self):
        yield scrapy.Request(ROBOTS, callback=self.parse_robots, errback=self.request_failed,
                             meta={"dont_obey_robotstxt": True, "handle_httpstatus_list": [404]})

    def parse_robots(self, response):
        self.robots.update({"status": response.status, "sourceHTMLSHA256": hashlib.sha256(response.body).hexdigest()})
        if response.status not in {200, 404}:
            self.error("robots-unavailable", response.url, f"HTTP {response.status}")
            return
        parser = ProtegoRobotParser.from_crawler(self.crawler, response.body if response.status == 200 else b"")
        for language, state in self.states.items():
            target = index_url(language)
            allowed = parser.allowed(target, USER_AGENT)
            self.robots["allowed"][language] = allowed
            if not allowed:
                self.error("robots-disallows-category", target)
                continue
            state["scheduledPages"].add(target)
            yield scrapy.Request(target, callback=self.parse_index, errback=self.request_failed,
                                 priority=100, cb_kwargs={"language": language})

    def progress(self, response, language):
        state = self.states[language]
        state["responses"] += 1
        state["cacheHits"] += int("cached" in response.flags)
        self.progress_responses += 1
        if self.progress_responses % 25 == 0:
            self.save_all("running")

    def parse_index(self, response, language):
        state = self.states[language]
        page = extract_index(response.body, response.url, language)
        state["copyright"] = state["copyright"] or page["footerCopyright"]
        url = canonical_url(response.url, language=language)
        parent_url = response.meta.get("populatedParentURL")
        state["indexPages"][url] = {"url": url, "title": page["title"], "sourceHTMLSHA256": hashlib.sha256(response.body).hexdigest(),
                                     "articleCount": len(page["articles"]), "articleIDs": page["articleIDs"],
                                     "pagination": page["pagination"],
                                     "publishedPagination": page["publishedPagination"], "recognizedArea": page["recognizedArea"],
                                     "rawArticleCardCount": page["rawArticleCardCount"], "terminalEmptyPage": False,
                                     "populatedParentURL": parent_url}
        self.progress(response, language)
        if not page["recognizedArea"] or page["title"] != EDITIONS[language]["heading"]:
            self.error("unrecognized-edition-category", response.url, page["title"])
            return
        if page["unrecognizedArticleCardLinks"]:
            self.error("unrecognized-article-card-links", response.url, page["unrecognizedArticleCardLinks"])
            return
        if not page["articles"]:
            parent = state["indexPages"].get(parent_url, {})
            if (HEBREW_EXTRACTOR._page(url) > 0 and not page["rawArticleCardCount"] and parent.get("articleCount", 0) > 0
                    and url in parent.get("pagination", []) and HEBREW_EXTRACTOR._page(parent_url) < HEBREW_EXTRACTOR._page(url)):
                state["indexPages"][url]["terminalEmptyPage"] = True
                state["naturalEnd"] = True
                self.save_all("running")
                return
            self.error("unproved-empty-category", response.url)
            return
        if not any(HEBREW_EXTRACTOR._page(link) > HEBREW_EXTRACTOR._page(url) for link in page["pagination"]):
            state["naturalEnd"] = True
        for target in page["pagination"]:
            if target in state["scheduledPages"]:
                continue
            if len(state["scheduledPages"]) >= self.args.max_pages:
                self.budget_limited = True
                continue
            state["scheduledPages"].add(target)
            yield scrapy.Request(target, callback=self.parse_index, errback=self.request_failed, priority=100,
                                 cb_kwargs={"language": language},
                                 meta={"populatedParentURL": url} if HEBREW_EXTRACTOR._page(target) > HEBREW_EXTRACTOR._page(url) else {})
        for entry in page["articles"]:
            target = entry["url"]
            if target in state["discoveredArticles"]:
                continue
            state["discoveredArticles"].add(target)
            if sum(len(value["scheduledArticles"]) for value in self.states.values()) >= self.args.max_articles:
                self.budget_limited = True
                continue
            state["scheduledArticles"].add(target)
            yield scrapy.Request(target, callback=self.parse_article, errback=self.request_failed,
                                 cb_kwargs={"language": language, "discovered_index_url": url, "index_entry": entry, "chain": [target]},
                                 meta={"originalRequestURL": target})

    def parse_article(self, response, language, discovered_index_url, index_entry, chain):
        state = self.states[language]
        record = extract_article(response.body, response.url, language,
                                 request_url=response.meta.get("originalRequestURL", response.request.url),
                                 discovered_index_url=discovered_index_url, index_entry=index_entry)
        state["copyright"] = state["copyright"] or record.pop("footerCopyright")
        record["publishedLinkChain"] = chain
        record["relatedHebrewArticles"] = self.hebrew_links.get(record["sourceURL"], [])
        if record["rejectionReason"] is None:
            state["articles"][record["sourceURL"]] = record
        else:
            # Unlike an app importer, the review archive keeps the complete source,
            # including Latin quotations, French names, or foreign fallback articles.
            target = (record["languageFlagURL"] if record["rejectionReason"] == "source-language-mismatch-or-uncertain"
                      and record["languageFlagMatchesRequestedEdition"] else None)
            if target in chain:
                record["flagFollowResult"] = "cycle"
            elif target in state["scheduledArticles"]:
                record["flagFollowResult"] = "already-scheduled"
            elif not target:
                record["flagFollowResult"] = "no-published-language-link"
            elif len(chain) >= 5 or sum(len(value["scheduledArticles"]) for value in self.states.values()) >= self.args.max_articles:
                record["flagFollowResult"] = "follow-budget-reached"
                self.budget_limited = True
            else:
                record["flagFollowResult"] = "followed-published-language-link"
                state["scheduledArticles"].add(target)
                yield scrapy.Request(target, callback=self.parse_article, errback=self.request_failed,
                                     cb_kwargs={"language": language, "discovered_index_url": discovered_index_url,
                                                "index_entry": index_entry, "chain": [*chain, target]},
                                     meta={"originalRequestURL": target})
            state["quarantine"][record["sourceURL"]] = record
        self.progress(response, language)

    def request_failed(self, failure):
        self.error("request-failed", failure.request.url, failure.getErrorMessage()[:500])
        self.save_all("running")

    def snapshot(self, language, reason):
        state = self.states[language]
        pending = len(state["scheduledArticles"]) - len(state["articles"]) - len(state["quarantine"])
        errors = [*self.errors, *state["errors"]]
        completed = (reason == "finished" and state["naturalEnd"] and not errors and not self.budget_limited
                     and self.robots["allowed"].get(language) is True and pending == 0)
        records = [*state["articles"].values(), *state["quarantine"].values()]
        issues = collections.Counter(issue["code"] for record in records for issue in record["review"]["issues"])
        return {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                "source": {"provider": "Saint James Vicariate for Hebrew Speaking Catholics in Israel", "siteURL": BASE,
                           "indexURL": index_url(language), "language": language, "footerCopyright": state["copyright"]},
                "reviewStatus": "required", "completed": completed, "finishReason": reason, "robots": self.robots,
                "policy": {"purpose": "source-only review catalogue; no native dataset import", "calendarMapping": "none",
                           "languageValidation": "independent body/intro classification using Lingua with foreign-language alternatives",
                           "classificationLanguages": [value.iso_code_639_1.name.lower() for value in DETECTOR_LANGUAGES],
                           "confidenceMinimum": CONFIDENCE_MINIMUM, "confidenceGapMinimum": CONFIDENCE_GAP,
                           "sourceText": "complete original article prose, whitespace normalized; all mixed and quarantined text retained",
                           "copyrightReview": "required before redistribution", "userAgent": USER_AGENT,
                           "minimumDelaySeconds": self.args.delay, "cacheExpirySeconds": self.args.cache_expiry},
                "crawl": {"indexPages": len(state["indexPages"]), "discoveredArticles": len(state["discoveredArticles"]),
                          "scheduledArticleRequests": len(state["scheduledArticles"]), "languageVerifiedArticles": len(state["articles"]),
                          "quarantinedAttempts": len(state["quarantine"]), "pendingArticleRequests": pending,
                          "receivedResponses": state["responses"], "cacheHits": state["cacheHits"],
                          "downloadedResponses": max(0, state["responses"] - state["cacheHits"]),
                          "sharedAttemptedRequests": self.attempted_requests, "sharedResponseBodyBytes": self.bytes_received,
                          "budgetLimited": self.budget_limited, "naturalPaginationEnd": state["naturalEnd"],
                          "maxPagesPerEdition": self.args.max_pages, "maxArticlesShared": self.args.max_articles,
                          "maxRequestsShared": self.args.max_requests, "maxResponseBytesShared": self.args.max_bytes},
                "reviewSummary": {"factualChecks": ["published index links only", "primary prose excludes navigation/sidebar",
                                                   "source HTML and prose hashes", "body language independently checked",
                                                   "index/article title comparisons", "published translation-link provenance"],
                                  "issues": dict(issues), "historicalAccuracy": "not certified; source statements preserved for review",
                                  "identityMapping": "unapproved; published language flags are evidence only"},
                "indexPages": sorted(state["indexPages"].values(), key=lambda item: HEBREW_EXTRACTOR._page(item["url"])),
                "articles": sorted(state["articles"].values(), key=lambda item: int(item["articleId"])),
                "quarantine": sorted(state["quarantine"].values(), key=lambda item: int(item["articleId"])), "errors": errors}

    def save_all(self, reason):
        for language in self.states:
            snapshot = self.snapshot(language, reason)
            HEBREW_EXTRACTOR._atomic_json(self.args.output_dir / f"catholic-saints-{language}.json", snapshot)

    def closed(self, reason):
        stats = self.crawler.stats.get_stats()
        if any(key.startswith("spider_exceptions/") for key in stats):
            self.error("spider-callback-exception", ROBOTS, {key: value for key, value in stats.items() if key.startswith("spider_exceptions/")})
        self.save_all(reason)
        self.completed = all(self.snapshot(language, reason)["completed"] for language in self.states)
        for language, state in self.states.items():
            print(f"{language}: {len(state['articles'])} language-verified source articles; {len(state['quarantine'])} quarantined; "
                  f"{len(state['errors'])} errors; completed={self.snapshot(language, reason)['completed']}", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--languages", nargs="+", choices=list(EDITIONS), default=list(EDITIONS))
    parser.add_argument("--output-dir", type=Path, default=TOOLS / "sources")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-catholic-saints-http-cache")
    parser.add_argument("--cache-expiry", type=int, default=86400)
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--max-pages", type=int, default=100)
    parser.add_argument("--max-articles", type=int, default=2000)
    parser.add_argument("--max-requests", type=int, default=3000)
    parser.add_argument("--max-bytes", type=int, default=100 * 1024 * 1024)
    parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], default="INFO")
    args = parser.parse_args()
    if (len(set(args.languages)) != len(args.languages) or not math.isfinite(args.delay) or args.delay < 2
            or min(args.cache_expiry, args.max_pages, args.max_articles, args.max_requests, args.max_bytes) <= 0):
        parser.error("Unique editions, delay >=2 seconds, and positive budgets are required.")
    settings = {"USER_AGENT": USER_AGENT, "ROBOTSTXT_USER_AGENT": USER_AGENT, "ROBOTSTXT_OBEY": True,
                "CONCURRENT_REQUESTS": 1, "CONCURRENT_REQUESTS_PER_DOMAIN": 1, "DOWNLOAD_DELAY": args.delay,
                "AUTOTHROTTLE_ENABLED": True, "AUTOTHROTTLE_START_DELAY": args.delay, "AUTOTHROTTLE_MAX_DELAY": 60,
                "AUTOTHROTTLE_TARGET_CONCURRENCY": 1.0, "DOWNLOAD_TIMEOUT": 30, "DOWNLOAD_MAXSIZE": 2 * 1024 * 1024,
                "DOWNLOAD_WARNSIZE": 1024 * 1024, "RETRY_TIMES": 2, "RETRY_HTTP_CODES": [408, 429, 500, 502, 503, 504],
                "REDIRECT_MAX_TIMES": 3, "COOKIES_ENABLED": False, "HTTPCACHE_ENABLED": True,
                "HTTPCACHE_DIR": str(args.cache_dir.resolve()), "HTTPCACHE_EXPIRATION_SECS": args.cache_expiry,
                "HTTPCACHE_IGNORE_HTTP_CODES": [408, 429, 500, 502, 503, 504],
                "HTTPCACHE_POLICY": "scrapy.extensions.httpcache.DummyPolicy",
                "DOWNLOADER_MIDDLEWARES": {BoundaryMiddleware: 80, HEBREW_EXTRACTOR.BoundedRetryBackoffMiddleware: 600},
                "LOG_LEVEL": args.log_level, "LOGSTATS_INTERVAL": 60, "TELNETCONSOLE_ENABLED": False,
                "REMOTE_CONTROL_ENABLED": False, "TWISTED_REACTOR": "twisted.internet.asyncioreactor.AsyncioSelectorReactor"}
    settings.update({"DOWNLOAD_DELAY_JITTER": 0} if hasattr(default_settings, "DOWNLOAD_DELAY_JITTER")
                    else {"RANDOMIZE_DOWNLOAD_DELAY": False})
    process = CrawlerProcess(settings=settings)
    crawler = process.create_crawler(SaintsSpider)
    process.crawl(crawler, args=args)
    process.start()
    return 0 if crawler.spider and crawler.spider.completed else 1


if __name__ == "__main__":
    sys.exit(main())
