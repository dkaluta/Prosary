#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.4,<1"]
# ///
"""Collect the official RKC Ukrainian Saint of the Day archive for source review.

Follow the archive's actual public Load More request, as specified by its published
frontend script. Keep repeated annual occurrences separate from the unique article
URLs. Completeness means this reachable, date-filtered archive, not a whole year or
the whole website. No source date/rank/identity is imported into an app calendar.

Run: uv run --script Shared/tools/scrape-rkc-saints.py
Offline repeat: ... --offline
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import importlib.util
import json
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import parse_qs, urljoin, urlsplit

from lxml import html as lh

TOOLS = Path(__file__).resolve().parent
# Shared source-preservation helpers; both scripts declare the same uv runtime.
SPEC = importlib.util.spec_from_file_location("credo_source_helpers", TOOLS / "scrape-credo-saints.py")
common = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(common)
sha, space, text, cls = common.sha, common.space, common.text, common.cls
BASE = "https://rkc.org.ua"
INDEX = BASE + "/blog/mec-category/svyatyy-dnya/"
ROBOTS = BASE + "/robots.txt"
AJAX = BASE + "/wp-admin/admin-ajax.php"
USER_AGENT = common.USER_AGENT
CREDIT = re.compile(r"(?:\b(?:Джерело|Переклад|Автор)\s*[:—-]|\bЗа матеріалами\b|CREDO|credo\.pro|КAI|КАІ|РІСУ|Vatican|catholic)", re.I)


def canonical_url(value: str, base: str = BASE) -> str | None:
    try:
        p = urlsplit(urljoin(base, value))
        if p.scheme != "https" or p.hostname != "rkc.org.ua" or p.port or p.username or p.password or p.fragment:
            return None
        if p.query:
            # Versioned frontend scripts must be actually discovered in the index.
            q = parse_qs(p.query)
            if (set(q) != {"ver"} or len(q["ver"]) != 1 or not re.fullmatch(r"[a-zA-Z0-9.]+", q["ver"][0]) or
                    not re.fullmatch(r"/wp-content/litespeed/js/[a-f0-9]+\.js", p.path)):
                return None
        elif p.path not in {"/", "/robots.txt", "/blog/mec-category/svyatyy-dnya/", "/wp-admin/admin-ajax.php"} and not re.fullmatch(r"/events/[a-z0-9-]+/", p.path):
            return None
        return BASE + p.path + ("?" + p.query if p.query else "")
    except (ValueError, TypeError):
        return None


class RestrictedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not canonical_url(newurl):
            raise urllib.error.URLError("Redirect escaped the public source scope")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Client:
    def __init__(self, args):
        self.args = args
        self.cache = args.cache_dir
        self.cache.mkdir(parents=True, exist_ok=True)
        self.opener = urllib.request.build_opener(RestrictedRedirect())
        self.policy = None
        self.delay = 2.0
        self.last = None
        self.stats = {"networkRequests": 0, "cacheHits": 0, "downloadedBytes": 0}
        self.provenance = []
        self.allowed = {ROBOTS, INDEX}

    def fetch(self, url, data=None, robots=False):
        if not canonical_url(url) or url not in self.allowed:
            raise ValueError("Request was not an allowed, discovered public source")
        if data is not None:
            values = parse_qs(data.decode("ascii"), keep_blank_values=True)
            if url != AJAX or values.get("action") != ["mec_list_load_more"] or values.get("apply_sf_date") != ["0"]:
                raise ValueError("Only the published read-only Load More action is permitted")
        if not robots and (not self.policy or not self.policy.can_fetch(url, USER_AGENT)):
            raise ValueError("Robots permission unavailable or denied")
        key = sha(url + "\n" + (data.decode("ascii") if data else "GET"))
        path = self.cache / (key + ".json")
        if path.exists():
            item = json.loads(path.read_text(encoding="utf-8"))
            body = base64.b64decode(item["bodyBase64"], validate=True)
            if item["sourceURL"] != url or item["requestBodySHA256"] != (sha(data) if data else None) or sha(body) != item["sourceHTMLSHA256"]:
                raise ValueError("HTTP cache provenance/digest mismatch")
            age = time.time() - dt.datetime.fromisoformat(item["fetchedAt"]).timestamp()
            if item["status"] == 200 and (age < 86400 or self.args.offline):
                self.stats["cacheHits"] += 1
                result = {**item, "body": body, "cacheHit": True}
                self.provenance.append({k: v for k, v in result.items() if k not in {"body", "bodyBase64"}})
                return result
        if self.args.offline:
            raise ValueError(f"Offline cache miss: {url}")
        for attempt in range(3):
            if self.stats["networkRequests"] >= self.args.max_requests:
                raise ValueError("Request budget reached")
            if self.last is not None:
                time.sleep(max(0, self.last + self.delay - time.monotonic()))
            self.last = time.monotonic()
            self.stats["networkRequests"] += 1
            print(f"Request {self.stats['networkRequests']}: {'POST' if data else 'GET'} {url}", flush=True)
            headers = {"User-Agent": USER_AGENT, "Accept": "text/html,application/json,text/plain;q=0.9"}
            if data:
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            req = urllib.request.Request(url, data=data, headers=headers)
            try:
                response = self.opener.open(req, timeout=45)
            except urllib.error.HTTPError as error:
                response = error
            except urllib.error.URLError:
                if attempt == 2:
                    raise
                time.sleep(self.delay * (2 ** attempt))
                continue
            with response:
                body = response.read(self.args.max_response_bytes + 1)
                self.stats["downloadedBytes"] += len(body)
                if len(body) > self.args.max_response_bytes or self.stats["downloadedBytes"] > self.args.max_bytes:
                    raise ValueError("Response/total byte budget reached")
                result = {"sourceURL": url, "responseURL": response.geturl(), "requestMethod": "POST" if data else "GET",
                          "requestBodySHA256": sha(data) if data else None, "status": response.code,
                          "contentType": response.headers.get("Content-Type", ""), "fetchedAt": common.now(),
                          "sourceHTMLSHA256": sha(body), "body": body, "cacheHit": False}
                if response.code in {429, 500, 502, 503, 504} and attempt < 2:
                    retry = response.headers.get("Retry-After", "")
                    try:
                        seconds = float(retry)
                    except ValueError:
                        try:
                            seconds = common.parsedate_to_datetime(retry).timestamp() - time.time()
                        except (ValueError, TypeError):
                            seconds = 30 * (2 ** attempt)
                    time.sleep(max(self.delay, seconds))
                    continue
                self.provenance.append({k: v for k, v in result.items() if k != "body"})
                if response.code == 200:
                    common.save(path, {k: v for k, v in result.items() if k not in {"body", "cacheHit"}} |
                                {"bodyBase64": base64.b64encode(body).decode("ascii")})
                return result
        raise ValueError("HTTP retries exhausted")

    def establish_robots(self):
        result = self.fetch(ROBOTS, robots=True)
        self.policy = common.robots_policy(result["body"], result["status"], result["contentType"])
        self.delay = max(2.0, float(self.policy.crawl_delay(USER_AGENT) or 0))
        return {"sourceURL": ROBOTS, "status": result["status"], "sourceHTMLSHA256": result["sourceHTMLSHA256"],
                "sourceWording": result["body"].decode("utf-8"), "effectiveDelaySeconds": self.delay}


def parse_cards(value, source_url, request_hash=None):
    root = common.document(value)
    cards = root.xpath(f"//article[{cls('mec-event-article')}]")
    result = []
    for position, card in enumerate(cards, 1):
        links = card.xpath(f"./h4[{cls('mec-event-title')}]/a")
        if len(links) != 1:
            raise ValueError("Ambiguous event card title/link")
        url = canonical_url(links[0].get("href", ""), INDEX)
        if not url or "/events/" not in url:
            raise ValueError("Event card escaped the article scope")
        date = card.xpath(f".//*[{cls('mec-start-date-label')}]")
        result.append({"sourceURL": url, "title": space(text(links[0])), "sourceID": links[0].get("data-event-id"),
                       "sourceDateWording": space(text(date[0])) if date else None,
                       "sourceIndexURL": source_url, "cardPosition": position, "sourceHTMLSHA256": sha(value),
                       "requestBodySHA256": request_hash})
    return result


def pagination_options(value):
    root = common.document(value)
    titles = root.xpath("//h1")
    if len(titles) != 1 or space(text(titles[0])) != "Святий дня":
        raise ValueError("Not the published Saint of the Day archive")
    scripts = [s for s in root.xpath("//script/text()") if ".mecListView(" in s]
    if len(scripts) != 1:
        raise ValueError("Archive has no unambiguous published Load More configuration")
    options = {}
    for key in ["start_date", "end_date", "offset", "limit", "pagination", "atts", "current_month_divider", "ajax_url"]:
        match = re.search(r"\b" + key + r':"([^\"]*)"', scripts[0])
        if not match:
            raise ValueError(f"Missing published pagination option: {key}")
        options[key] = match[1]
    if options["ajax_url"] != AJAX or options["pagination"] != "loadmore" or not options["offset"].isdigit():
        raise ValueError("Unsupported or unscoped public archive pagination")
    atts = parse_qs(options["atts"], keep_blank_values=True)
    if atts.get("atts[category]") != ["153"]:
        raise ValueError("Unexpected saint category in public pagination")
    script_urls = root.xpath("//script[@id='mec-frontend-script-js']/@src")
    if len(script_urls) != 1 or not canonical_url(script_urls[0]):
        raise ValueError("No allowed published pagination script")
    options["frontendScriptURL"] = script_urls[0]
    return options


def load_more_data(options):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", options["end_date"]) or not str(options["offset"]).isdigit():
        raise ValueError("Invalid pagination cursor")
    return ("action=mec_list_load_more&mec_start_date=" + options["end_date"] + "&mec_offset=" +
            str(options["offset"]) + "&" + options["atts"] + "&current_month_divider=" +
            str(options["current_month_divider"]) + "&apply_sf_date=0").encode("ascii")


def source_finished(response):
    # The published frontend treats both JSON false and numeric 0 as terminal.
    value = response.get("has_more_event")
    return response["count"] == 0 or value is False or (isinstance(value, int) and not isinstance(value, bool) and value == 0)


def parse_article(value, url, occurrences):
    root = common.document(value)
    titles = root.xpath(f"//h1[{cls('mec-single-title')}]")
    bodies = root.xpath(f"//*[{cls('mec-single-event-description')}]")
    if len(titles) != 1 or len(bodies) != 1:
        raise ValueError("Unrecognized or ambiguous published event template")
    paragraphs = [space(line) for line in text(bodies[0]).splitlines() if space(line)]
    prose = "\n".join(paragraphs)
    title = space(text(titles[0]))
    events = []
    for script in root.xpath("//script[@type='application/ld+json']/text()"):
        obj = json.loads(script)
        if isinstance(obj, dict) and obj.get("@type") == "Event":
            events.append({k: obj[k] for k in ["name", "startDate", "endDate", "eventStatus"] if k in obj})
    visible_dates = [space(text(n)) for n in root.xpath(f"//*[{cls('mec-single-event-date')}]")]
    policy = [space(text(h)) for h in root.xpath("//h2") if "Повне або часткове використання матеріалів" in text(h)]
    links = [{"sourceWording": space(text(a)), "sourceURL": urljoin(url, a.get("href", ""))}
             for a in bodies[0].xpath(".//a[@href]") if space(text(a))]
    credits = [{"sourceWording": p, "kind": "credit-or-reference", "reviewStatus": "unreviewed"} for p in paragraphs if CREDIT.search(p)]
    source_genre = common.genre(title, prose)
    if title.lower().startswith(("святі", "святих", "cвятих")) and "ангел" in title.lower():
        source_genre = "feast-description-candidate"
    issues = []
    if any(o["title"] != title for o in occurrences):
        issues.append("index-title-differs-from-article-title")
    for p in paragraphs:
        for match in re.finditer(r"\b(\d{4})\s*[–—-]\s*(\d{4})\b", p):
            first, last = int(match[1]), int(match[2])
            if last < first or last - first > 130 or last > dt.datetime.now(dt.timezone.utc).year + 1:
                issues.append("implausible-year-range:" + match.group())
    categories = [space(text(n)) for n in root.xpath(f"//*[{cls('mec-single-event-category')}]")]
    language = common.language_evidence(prose)
    return {"sourceURL": url, "sourceID": next((o["sourceID"] for o in occurrences if o["sourceID"]), None),
            "title": title, "languageCode": language["languageCode"], "sourceLanguageEvidence": language,
            "coverage": "full-published-event-description", "paragraphs": paragraphs,
            "sourceHTMLSHA256": sha(value), "sourceTextSHA256": sha(prose), "genre": source_genre,
            "literalDateEvidence": common.date_evidence(prose), "sourceEventDateEvidence": events,
            "visibleEventDateWording": visible_dates, "sourceCategoryWording": categories,
            "creditCandidates": credits, "bodyLinks": links, "policyEvidence": policy,
            "indexOccurrences": occurrences, "sourceReviewIssues": issues,
            "reviewStatus": "identity-genre-date-source-facts-attribution-and-reuse-required",
            "nativeImportAllowed": False, "calendarAppointmentsChanged": False}


def crawl(args):
    client = Client(args)
    output = {"schemaVersion": 1, "provider": "Roman Catholic Church in Ukraine", "sourceURL": INDEX,
              "languageCode": "uk", "generatedAt": common.now(), "complete": False,
              "scope": "published Saint of the Day archive from its displayed start date through public Load More termination",
              "coverage": "full-published-event-descriptions", "wholeLiturgicalYearClaimed": False,
              "nativeImportAllowed": False, "calendarAppointmentsChanged": False,
              "articles": [], "excluded": [], "quarantined": [], "indexPages": [], "errors": [],
              "reuseStatus": "publisher-permits-use-with-source-link-underlying-credits-require-review",
              "accessDiagnostics": {"transport": "ordinary-Python-urllib-no-browser-impersonation", "challengeBypassed": False},
              "limits": {"maxPages": args.max_pages, "maxArticles": args.max_articles, "maxRequests": args.max_requests,
                         "maxBytes": args.max_bytes, "maxResponseBytes": args.max_response_bytes}}
    occurrences = {}
    # Preserve the earlier genuine transport blocker without treating it as the
    # present source policy or executing the challenge's script.
    prior_challenge = Path("/private/tmp/prosary-rkc-robots.txt")
    if prior_challenge.exists():
        prior_body = prior_challenge.read_bytes()
        if b"Checking your browser" in prior_body or b"hcdn-cgi/jschallenge" in prior_body:
            output["accessDiagnostics"]["earlierChallengeResponse"] = {
                "sourceURL": ROBOTS, "status": 403, "sourceHTMLSHA256": sha(prior_body),
                "transport": "ordinary-curl", "challengeDocumentSeen": True,
                "resolution": "ordinary-urllib-returned-real-public-content"}
    prior_sitemap = Path("/private/tmp/prosary-rkc-sitemap-index.xml")
    if prior_sitemap.exists():
        sitemap_body = prior_sitemap.read_bytes()
        if b"<!DOCTYPE html" in sitemap_body or b"<html" in sitemap_body:
            sitemap_root = common.document(sitemap_body)
            output["accessDiagnostics"]["publishedSitemapResearch"] = {
                "sourceURL": BASE + "/sitemap_index.xml", "sourceHTMLSHA256": sha(sitemap_body),
                "status": 200, "contentType": "text/html; charset=UTF-8",
                "pageTitle": space(" ".join(sitemap_root.xpath("//title/text()"))),
                "validSitemap": False, "eventSitemapURLsDiscovered": [],
                "problem": "robots-published sitemap returns a site-under-development HTML document"}
    try:
        output["robots"] = client.establish_robots()
        response = client.fetch(INDEX)
        if response["status"] != 200:
            raise ValueError(f"Archive HTTP {response['status']}")
        options = pagination_options(response["body"])
        output["publishedInitialOptions"] = dict(options)
        client.allowed.add(options["frontendScriptURL"])
        script = client.fetch(options["frontendScriptURL"])
        js = script["body"].decode("utf-8")
        if script["status"] != 200 or 'action=mec_list_load_more&mec_start_date=' not in js or 'apply_sf_date=0' not in js or 'has_more_event' not in js:
            raise ValueError("Published frontend no longer confirms this public Load More protocol")
        output["paginationScript"] = {"sourceURL": options["frontendScriptURL"], "sourceHTMLSHA256": script["sourceHTMLSHA256"]}
        client.allowed.add(AJAX)
        cards = parse_cards(response["body"], INDEX)
        if not cards:
            raise ValueError("Initial published archive has no recognized cards")
        output["indexPages"].append({"page": 1, "sourceURL": INDEX, "sourceHTMLSHA256": response["sourceHTMLSHA256"],
                                     "cardCount": len(cards), "cards": cards})
        for card in cards:
            occurrences.setdefault(card["sourceURL"], []).append(card)
        seen_cursors = set()
        while True:
            if len(output["indexPages"]) >= args.max_pages:
                raise ValueError("Archive page budget reached before source termination")
            data = load_more_data(options)
            cursor = sha(data)
            if cursor in seen_cursors:
                raise ValueError("Repeated public archive cursor; completeness unverified")
            seen_cursors.add(cursor)
            response = client.fetch(AJAX, data)
            if response["status"] != 200:
                raise ValueError(f"Public Load More HTTP {response['status']}")
            obj = json.loads(response["body"].decode("utf-8"))
            if not isinstance(obj, dict) or not isinstance(obj.get("count"), int) or not isinstance(obj.get("html"), str):
                raise ValueError("Unrecognized public Load More response")
            cards = parse_cards(obj["html"], AJAX, cursor) if obj["html"].strip() else []
            if len(cards) != obj["count"]:
                raise ValueError("Public response count differs from discovered article cards")
            output["indexPages"].append({"page": len(output["indexPages"]) + 1, "sourceURL": AJAX,
                                         "requestBodySHA256": cursor, "sourceHTMLSHA256": response["sourceHTMLSHA256"],
                                         "cardCount": len(cards), "cards": cards,
                                         "responseCursor": {k: obj.get(k) for k in ["end_date", "offset", "current_month_divider", "has_more_event"]}})
            for card in cards:
                occurrences.setdefault(card["sourceURL"], []).append(card)
            print(f"Archive page {len(output['indexPages'])}: {len(cards)} cards; {len(occurrences)} unique articles", flush=True)
            output["discovery"] = {"publishedArticleURLs": list(occurrences), "rawCardCount": sum(p["cardCount"] for p in output["indexPages"])}
            output["stats"] = dict(client.stats)
            common.save(args.output, output)
            if source_finished(obj):
                output["termination"] = {"reason": "source-empty-page" if obj["count"] == 0 else "source-has-more-false",
                                         "sourceURL": AJAX, "requestBodySHA256": cursor,
                                         "lastSourceCursor": options["end_date"], "wholeYearClaimed": False}
                break
            for key in ["end_date", "offset", "current_month_divider"]:
                if key not in obj:
                    raise ValueError(f"Public pagination response lacks {key}")
                options[key] = str(obj[key])
        if len(occurrences) > args.max_articles:
            raise ValueError("Discovered article count exceeded the explicit article budget")
        output["discovery"] = {"publishedArticleURLs": list(occurrences), "rawCardCount": sum(p["cardCount"] for p in output["indexPages"])}
        for url, instances in occurrences.items():
            client.allowed.add(url)
            response = client.fetch(url)
            if response["status"] != 200:
                raise ValueError(f"Article HTTP {response['status']}: {url}")
            item = parse_article(response["body"], url, instances)
            key = "quarantined" if item["languageCode"] != "uk" or not item["paragraphs"] else "excluded" if item["genre"] == "other-article-review-required" else "articles"
            output[key].append(item)
            if len(output["articles"]) % 20 == 0:
                print(f"Full source pages: {sum(len(output[k]) for k in ['articles','excluded','quarantined'])}/{len(occurrences)}", flush=True)
            output["stats"] = dict(client.stats)
            common.save(args.output, output)
        identities, source_ids = {}, {}
        for item in output["articles"] + output["excluded"] + output["quarantined"]:
            identities.setdefault(item["title"].casefold(), []).append(item["sourceURL"])
            source_ids.setdefault(item["sourceID"], []).append(item["sourceURL"])
        output["duplicateReview"] = {"exactTitleGroups": [{"title": title, "sourceURLs": urls, "reviewStatus": "possible-shared-identity-no-auto-merge"}
                                                          for title, urls in identities.items() if len(urls) > 1],
                                     "sourceIDAliases": [urls for key, urls in source_ids.items() if key and len(urls) > 1],
                                     "annualOccurrencesRetained": sum(len(v) - 1 for v in occurrences.values())}
        output["complete"] = True
    except (ValueError, OSError, KeyboardInterrupt) as error:
        output["errors"].append({"type": type(error).__name__, "message": str(error) or "interrupted"})
    finally:
        output["generatedAt"] = common.now()
        output["stats"] = client.stats
        output["responseProvenance"] = client.provenance
        output["counts"] = {k: len(output[k]) for k in ["articles", "excluded", "quarantined", "indexPages"]}
        output["unfetchedArticleURLs"] = sorted(set(occurrences) - {a["sourceURL"] for key in ["articles", "excluded", "quarantined"] for a in output[key]})
        common.save(args.output, output)
    return output, 0 if output["complete"] else 1


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--output", type=Path, default=TOOLS / "sources/rkc-saints-uk.json")
    p.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-rkc-saints-http-cache")
    p.add_argument("--offline", action="store_true")
    p.add_argument("--max-pages", type=int, default=60)
    p.add_argument("--max-articles", type=int, default=500)
    p.add_argument("--max-requests", type=int, default=600)
    p.add_argument("--max-bytes", type=int, default=100_000_000)
    p.add_argument("--max-response-bytes", type=int, default=2_000_000)
    args = p.parse_args()
    if min(args.max_pages, args.max_articles, args.max_requests, args.max_bytes, args.max_response_bytes) <= 0:
        p.error("All request/page/article/byte budgets must be positive")
    result, status = crawl(args)
    print(json.dumps({k: result[k] for k in ["complete", "counts", "stats", "errors"]}, ensure_ascii=False))
    return status


if __name__ == "__main__":
    sys.exit(main())
