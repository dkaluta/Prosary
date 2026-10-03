#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Collect the historical Our Parish Priest SAINT category from its published feed.

The archive disallows /search, so label pages are never requested. Its home page
publishes a full Atom feed; only that feed's actual next links are followed. All
feed entries are reconciled before claiming that the explicitly labelled SAINT
subset is complete. This is historical source material, never native app data.
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import importlib.util
import json
import math
import re
import subprocess
import sys
import tempfile
import time
from collections import defaultdict
from html import escape as escape_text
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from lxml import etree, html

TOOLS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("opp_source_parser", TOOLS / "scrape-tagalog-saints.py")
SOURCE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SOURCE
SPEC.loader.exec_module(SOURCE)
BASE = "https://ourparishpriest.blogspot.com/"
BLOGGER = "https://www.blogger.com/"
BLOG_ID = "1667200346737921903"
FEED = BASE + "feeds/posts/default"
USER_AGENT = SOURCE.USER_AGENT
NS = {"a": "http://www.w3.org/2005/Atom", "o": "http://a9.com/-/spec/opensearchrss/1.0/"}


def safe_url(url: str) -> bool:
    try:
        p = urlsplit(url)
        if p.scheme != "https" or p.username or p.password or p.port or p.fragment:
            return False
        if p.netloc == "ourparishpriest.blogspot.com":
            return not p.query and (p.path in {"/", "/robots.txt", "/feeds/posts/default"} or
                                   re.fullmatch(r"/\d{4}/\d{2}/[a-z0-9_%+-]+\.html", p.path) is not None)
        if p.netloc != "www.blogger.com":
            return False
        if p.path == "/robots.txt":
            return not p.query
        if p.path != f"/feeds/{BLOG_ID}/posts/default":
            return False
        q = parse_qs(p.query, keep_blank_values=True)
        return (set(q) == {"start-index", "max-results"} and
                all(len(v) == 1 for v in q.values()) and q["max-results"] == ["25"] and
                re.fullmatch(r"[1-9][0-9]*", q["start-index"][0]) is not None)
    except (ValueError, TypeError, KeyError):
        return False


class Client:
    def __init__(self, args):
        self.args = args
        self.policies = {}
        self.effective_delay = max(2.0, args.delay)
        self.last_completion = 0.0
        self.attempts = self.cache_hits = self.bytes = 0
        self.provenance = []
        self.args.cache_dir.mkdir(parents=True, exist_ok=True)

    def get(self, url: str, *, robots=False) -> tuple[bytes, dict]:
        if not safe_url(url):
            raise ValueError("Out-of-scope URL: " + url)
        host = urlsplit(url).netloc
        if not robots and (host not in self.policies or not self.policies[host].can_fetch(url, USER_AGENT)):
            raise ValueError("Robots does not authorize request: " + url)
        cache = self.args.cache_dir / (SOURCE.sha256(url) + ".json")
        if cache.exists() and time.time() - cache.stat().st_mtime < self.args.cache_expiry:
            value = json.loads(cache.read_text())
            body = base64.b64decode(value["bodyBase64"], validate=True)
            if value["url"] != url or SOURCE.sha256(body) != value["sha256"]:
                raise ValueError("Source cache integrity mismatch")
            self.cache_hits += 1
            self.provenance.append({k: v for k, v in value.items() if k != "bodyBase64"} | {"cacheHit": True})
            return body, value
        for retry in range(3):
            if self.attempts >= self.args.max_requests or self.bytes >= self.args.max_bytes:
                raise ValueError("Finite request/response budget reached")
            time.sleep(max(0, self.last_completion + self.effective_delay - time.monotonic()))
            self.attempts += 1
            with tempfile.TemporaryDirectory(prefix="prosary-opp-blogger-") as folder:
                head, dest = Path(folder) / "headers", Path(folder) / "body"
                result = subprocess.run(["curl", "--silent", "--show-error", "--compressed",
                    "--max-time", "35", "--max-filesize", str(self.args.max_bytes - self.bytes),
                    "--user-agent", USER_AGENT, "--dump-header", str(head), "--output", str(dest),
                    "--url", url], capture_output=True, timeout=40)
                self.last_completion = time.monotonic()
                if result.returncode:
                    raise ValueError("Bounded curl transport failed: " + result.stderr.decode(errors="replace")[:200])
                blocks = [b for b in head.read_bytes().replace(b"\r\n", b"\n").split(b"\n\n") if b.startswith(b"HTTP/")]
                if not blocks:
                    raise ValueError("No HTTP response headers")
                lines = blocks[-1].decode("latin-1").splitlines()
                status = int(lines[0].split()[1])
                headers = {line.split(":", 1)[0].lower(): line.split(":", 1)[1].strip()
                           for line in lines[1:] if ":" in line}
                body = dest.read_bytes()
            self.bytes += len(body)
            value = {"url": url, "status": status, "headers": headers,
                     "sha256": SOURCE.sha256(body), "responseBytes": len(body),
                     "capturedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
                     "bodyBase64": base64.b64encode(body).decode("ascii")}
            self.provenance.append({k: v for k, v in value.items() if k != "bodyBase64"} | {"cacheHit": False})
            if status in {429, 500, 502, 503, 504} and retry < 2:
                raw = headers.get("retry-after", "")
                try:
                    pause = float(raw)
                except ValueError:
                    pause = 4 * 2 ** retry
                if not math.isfinite(pause) or pause > 60:
                    raise ValueError("Server requests a later retry; stopping this bounded run")
                time.sleep(max(4 * 2 ** retry, pause))
                continue
            if status == 200:
                SOURCE.atomic_json(cache, value)
            if status != 200:
                raise ValueError(f"HTTP {status}: {url}; source hash {value['sha256']}")
            return body, value
        raise ValueError("Retry budget exhausted")

    def robots(self, origin: str) -> dict:
        body, evidence = self.get(origin + "robots.txt", robots=True)
        policy = SOURCE.source_robots(body, evidence["status"], evidence["headers"].get("content-type", ""))
        delay = policy.crawl_delay(USER_AGENT)
        if delay is not None:
            if not math.isfinite(float(delay)) or float(delay) > 60:
                raise ValueError("Published crawl delay exceeds this run's bounded waiting policy")
            self.effective_delay = max(self.effective_delay, float(delay))
        self.policies[urlsplit(origin).netloc] = policy
        return {"sourceURL": origin + "robots.txt", "sourceText": body.decode("utf-8"),
                "sourceSHA256": evidence["sha256"], "status": evidence["status"],
                "crawlDelaySeconds": delay, "effectiveDelaySeconds": self.effective_delay}


def parse_feed(body: bytes) -> dict:
    root = etree.fromstring(body, etree.XMLParser(resolve_entities=False, no_network=True))
    if root.tag != "{" + NS["a"] + "}feed":
        raise ValueError("Expected an actual Atom feed, not HTML/challenge")
    def number(name):
        value = root.findtext("o:" + name, namespaces=NS)
        if not value or not re.fullmatch(r"[1-9][0-9]*", value):
            raise ValueError("Missing positive published feed counter: " + name)
        return int(value)
    entries = root.findall("a:entry", NS)
    next_links = root.xpath("a:link[@rel='next']/@href", namespaces=NS)
    if len(next_links) > 1 or (next_links and not safe_url(next_links[0])):
        raise ValueError("Unexpected published feed pagination URL")
    return {"total": number("totalResults"), "start": number("startIndex"),
            "pageSize": number("itemsPerPage"), "entries": entries,
            "nextURL": next_links[0] if next_links else None}


def extract_entry(entry, response_url: str, response_hash: str) -> dict:
    identity = entry.findtext("a:id", namespaces=NS)
    if not valid_identity(identity):
        raise ValueError("Wrong archive identity in feed entry")
    urls = entry.xpath("a:link[@rel='alternate' and @type='text/html']/@href", namespaces=NS)
    if len(urls) != 1 or not safe_url(urls[0]) or not urls[0].endswith(".html"):
        raise ValueError("Missing or unsafe published article URL")
    content = entry.find("a:content", NS)
    if content is None or content.get("type") != "html":
        raise ValueError("Published entry lacks full rendered HTML content")
    number = int(identity.rsplit("-", 1)[1])
    original_html = content.text or ""
    post = {"id": number, "link": SOURCE.BASE + "2000/01/source-adapter/",
            "date": entry.findtext("a:published", namespaces=NS),
            "modified": entry.findtext("a:updated", namespaces=NS),
            "title": {"rendered": escape_text(entry.findtext("a:title", namespaces=NS) or "")},
            "content": {"rendered": logical_html(original_html)}}
    record = SOURCE.extract_post(post, response_url, response_hash)
    record["sourceHTML"] = original_html
    record["sourceHTMLSHA256"] = SOURCE.sha256(original_html)
    record.pop("wordPressPostID")
    record["recordId"] = "opp-blogger:" + str(number)
    record["bloggerPostID"] = str(number)
    record["sourceAtomID"] = identity
    record["sourceURL"] = urls[0]
    record["sourceLabels"] = entry.xpath("a:category/@term", namespaces=NS)
    record["sourceAtomAuthor"] = entry.findtext("a:author/a:name", namespaces=NS)
    record["sourceCapture"] = {"method": "complete published Atom content[type=html]",
        "contentCaptured": True, "sourceIsHistoricalArchive": True,
        "paragraphNormalization": "Physical formatting line wraps inside HTML text nodes normalize to spaces; actual block elements and br remain source boundaries. Exact original HTML is retained separately."}
    continuation_lines = [line for line in record["sourceParagraphs"] if len(line.split()) <= 60 and
        re.search(r"\b(?:tunghayan\s+ang\s+kabuuan|ang\s+kabuuan(?:\s+ng\s+salaysay)?\s+ay\s+(?:narito|nasa))\b", line, re.I)
        and "ourparishpriest.com" in original_html]
    record["sourceCompletenessEvidence"] = {
        "publishedAtomContentCapturedCompletely": True,
        "biographyContinuesOnNewSite": bool(continuation_lines),
        "literalContinuationWording": continuation_lines,
        "unletteredBiographyHeadingPresent": "KUWENTO NG BUHAY" in record["sourceParagraphs"]}
    if continuation_lines and record["sections"]["biography"]:
        record["sections"]["migrationNotice"] = continuation_lines
        record["sections"]["biography"] = [line for line in record["sections"]["biography"] if line not in continuation_lines]
        record["biographyTextSHA256"] = SOURCE.sha256("\n".join(record["sections"]["biography"]))
        record["languageEvidence"] = SOURCE.language_evidence(record["sections"]["biography"])
        if record["classification"] == "Tagalog-biography-review-candidate":
            if record["languageEvidence"]["tagalogCandidate"]:
                record["classification"] = "Tagalog-biography-excerpt-review-candidate"
                record["review"]["coverage"] = "source explicitly says biography continues on new site"
            else:
                record["classification"] = "quarantined-source"
                record["review"]["status"] = "quarantined"
                record["review"]["reasons"].append("short-introduction-not-demonstrably-Tagalog")
    annotate_known_source_conflicts(record)
    record["categoryIds"] = []
    record["publishedArticleLinks"] = [href for href in html.fromstring("<div>" + record["sourceHTML"] + "</div>").xpath(".//a/@href")
                                        if safe_url(href) and href.endswith(".html")]
    record["languageCode"] = "tl" if record["languageEvidence"]["tagalogCandidate"] else None
    if record["sections"]["biography"]:
        genre = "source-marked-biography-excerpt" if continuation_lines else "source-marked-biography"
    elif "ourparishpriest.com" in record["sourceHTML"] and re.search(
            r"MATUTUNGHAYAN|TUNGHAYAN|OUR NEW WEBSITE|BAGONG WEBSITE", " ".join(record["sourceParagraphs"]), re.I):
        genre = "migration-stub"
    elif re.search(r"PANALANGIN|NOBENA|NOVENA|PRAYER", record["sourceTitle"], re.I):
        genre = "prayer-or-devotion-candidate"
    else:
        genre = "other-or-unmarked-prose; review-required"
    record["genreEvidence"] = {"classification": genre,
        "method": "literal source section/title/stub wording; publisher SAINT label alone never proves biography"}
    record["nativeImportAllowed"] = False
    record["calendarAppointmentsChanged"] = False
    return record


def annotate_known_source_conflicts(record: dict) -> None:
    """Attach primary-source conflicts found in independent editorial review.

    This is a narrowly evidenced hold, never a correction or a general historical
    accuracy certification. Literal source prose and attribution remain intact.
    """
    if record["recordId"] != "opp-blogger:5538193347137277050":
        return
    lines = [line for line in record["sections"]["biography"]
             if line.startswith("Buhay pa si San Francisco") and "Franciscan Capuchins" in line]
    if not lines:
        return
    record["review"]["findings"].append({
        "type": "source-franciscan-branches-chronology-error",
        "sourceLines": lines,
        "sourceClaim": "The three named Franciscan branches, including Capuchins, arose during Saint Francis's lifetime.",
        "corroboration": [
            {"provider": "Order of Friars Minor Capuchin", "sourceURL": "https://www.ofmcap.org/en/the-history-of-the-capuchins/",
             "verifiedAt": "2026-10-03", "publishedEvidence": "Capuchin origins around 1525 and papal approval in 1528",
             "method": "live official institutional history checked by independent source reviewer"},
            {"provider": "Order of Friars Minor Capuchin", "sourceURL": "https://www.ofmcap.org/en/x-giornata-della-famiglia-cappuccina-2026/",
             "verifiedAt": "2026-10-03", "publishedEvidence": "2026 commemorates the 800th anniversary of Saint Francis's death",
             "method": "live official anniversary article checked by independent source reviewer"}
        ],
        "decision": "Quarantine the biography pending editorial correction by its publisher; preserve its original paragraph and book credit."})
    record["classification"] = "quarantined-source"
    record["review"]["status"] = "quarantined"
    record["review"]["reasons"].append("source-factual-error-confirmed-by-official-Capuchin-history")


def logical_html(rendered: str) -> str:
    """Word markup's physical newlines are not authored paragraph boundaries.

    Normalize whitespace inside each actual text node, preserving the element
    tree and every visible word. The source's real paragraph and br boundaries
    remain intact; section headings may span inline spans or formatting lines.
    This derived representation never replaces stored original source HTML.
    """
    root = html.fromstring("<div>" + rendered + "</div>")
    for node in root.iter():
        if node.text:
            node.text = re.sub(r"\s+", " ", node.text)
        if node.tail:
            node.tail = re.sub(r"\s+", " ", node.tail)
    return etree.tostring(root, encoding="unicode", method="html")


def valid_identity(identity: str | None) -> bool:
    return isinstance(identity, str) and re.fullmatch(
        rf"tag:blogger\.com,1999:blog-{BLOG_ID}\.post-[1-9][0-9]*", identity) is not None


def duplicate_candidates(records: list[dict]) -> list[dict]:
    groups = defaultdict(list)
    for record in records:
        if not record["sections"]["biography"]:
            continue
        dates = sorted({(v["month"], v["day"]) for v in record["sourceFeastLabels"]})
        if len(dates) != 1:
            continue
        key = record["identityCandidate"]["literalTitleKey"] + "|" + json.dumps(dates)
        groups[key].append(record)
    return [{"groupKey": key, "recordIds": [r["recordId"] for r in values],
             "differentBiographyHashes": len({r["biographyTextSHA256"] for r in values}),
             "decision": "Identical normalized literal heading and printed month/day only; every edition retained, no canonical identity join"}
            for key, values in sorted(groups.items()) if len(values) > 1]


def crawl(args) -> dict:
    client = Client(args)
    result = {"schemaVersion": 1, "provider": "Our Parish Priest historical Blogger archive",
        "language": "tl", "sourceSite": BASE, "sourceURL": FEED,
        "scope": "Every explicitly SAINT-labelled entry in the full homepage-published Atom feed; follow only published next links",
        "completed": False, "wholeLiturgicalYearClaimed": False, "sourceIsHistoricalArchive": True,
        "nativeImportAllowed": False, "calendarAppointmentsChanged": False,
        "robots": [], "sourcePolicyEvidence": {}, "feedPages": [], "records": [],
        "otherFeedEntryMetadata": [], "fullPageAudits": [], "errors": [],
        "reviewStatus": "editorial-and-underlying-rights-review-required",
        "limitations": ["Archive announces migration in August 2024; it does not contain all later new-site publications.",
                         "SAINT is a publisher label, not proof that every item is a Tagalog biography.",
                         "Biography candidates require the literal A. KUWENTO NG BUHAY source section; other genres are retained separately.",
                         "Dates come only from printed source labels; no native saint/calendar identity is inferred.",
                         "Book/source credits are preserved. Archive citation wording does not license third-party book material."]}
    seen = set()
    visited = set()
    expected_total = None
    start = 1
    try:
        result["robots"] = [client.robots(BASE), client.robots(BLOGGER)]
        body, evidence = client.get(BASE)
        home = html.fromstring(body)
        published = home.xpath("//link[@rel='alternate' and @type='application/atom+xml']/@href")
        if FEED not in published:
            raise ValueError("Expected feed is not actually published by archive home page")
        result["sourcePolicyEvidence"]["homePublishedFeed"] = {"sourceURL": BASE, "sourceSHA256": evidence["sha256"], "publishedFeedURL": FEED}
        label_counts = home.xpath("//a[@href='https://ourparishpriest.blogspot.com/search/label/SAINT']/span[contains(concat(' ',normalize-space(@class),' '),' label-count ')]/text()")
        if len(label_counts) != 1 or not re.fullmatch(r"[1-9][0-9]*", label_counts[0]):
            raise ValueError("Missing published SAINT label counter; subset completeness unproven")
        result["sourcePolicyEvidence"]["homeSaintLabelCounter"] = label_counts
        migration = [SOURCE.whitespace(x.text_content()) for x in home.xpath("//*[contains(concat(' ',normalize-space(@class),' '),' post-snippet ')]")
                     if "new website" in x.text_content().lower() or "bagong website" in x.text_content().lower()]
        result["sourcePolicyEvidence"]["migrationWording"] = migration
        url = FEED
        while url:
            if url in visited or len(visited) >= args.max_pages:
                raise ValueError("Repeated feed cursor or finite page budget reached")
            visited.add(url)
            body, evidence = client.get(url)
            page = parse_feed(body)
            if expected_total is None:
                expected_total = page["total"]
            if page["total"] != expected_total or page["start"] != start or page["pageSize"] != 25:
                raise ValueError("Published feed counters changed or cursor has a gap")
            expected_count = min(25, expected_total - start + 1)
            if len(page["entries"]) != expected_count:
                raise ValueError("Feed entries disagree with published total/cursor")
            for entry in page["entries"]:
                identity = entry.findtext("a:id", namespaces=NS)
                if not valid_identity(identity) or identity in seen:
                    raise ValueError("Missing or repeated feed post identity; completeness is unproven")
                seen.add(identity)
                labels = entry.xpath("a:category/@term", namespaces=NS)
                if "SAINT" in labels:
                    result["records"].append(extract_entry(entry, url, evidence["sha256"]))
                else:
                    result["otherFeedEntryMetadata"].append({"sourceAtomID": identity,
                        "sourceTitle": entry.findtext("a:title", namespaces=NS), "sourceLabels": labels,
                        "sourceURL": entry.xpath("a:link[@rel='alternate' and @type='text/html']/@href", namespaces=NS),
                        "decision": "Excluded from SAINT scope by explicit publisher category"})
            result["feedPages"].append({"sourceURL": url, "sourceSHA256": evidence["sha256"],
                "sourceTotal": page["total"], "startIndex": page["start"], "entryCount": len(page["entries"]),
                "nextURL": page["nextURL"]})
            start += len(page["entries"])
            if bool(page["nextURL"]) != (len(seen) < expected_total):
                raise ValueError("Published next cursor disagrees with total; stopping without completion claim")
            url = page["nextURL"]
            if len(visited) % 10 == 0:
                print(f"Feed pages {len(visited)}; {len(seen)}/{expected_total} entries; {len(result['records'])} SAINT records", flush=True)
                SOURCE.atomic_json(args.output, result)
        if len(seen) != expected_total:
            raise ValueError("Published feed total did not reconcile with unique post identities")
        if len(result["records"]) != int(label_counts[0]):
            raise ValueError("Feed SAINT subset disagrees with archive's published label counter")
        preferred = {BASE + "2014/11/meet-saints-san-juan-bosco_21.html",
                     BASE + "2014/11/meet-saints-santo-tomas-aquino.html",
                     BASE + "2014/11/meet-saints-santa-angela-merici.html"}
        candidates = [r for r in result["records"] if r["classification"] == "Tagalog-biography-review-candidate"]
        audit_candidates = [r for r in candidates if r["sourceURL"] in preferred] + [r for r in candidates if r["sourceURL"] not in preferred]
        for record in audit_candidates[:3]:
            body, evidence = client.get(record["sourceURL"])
            page = html.fromstring(body)
            nodes = page.xpath("//*[contains(concat(' ',normalize-space(@class),' '),' post-body ')]")
            if len(nodes) != 1:
                raise ValueError("Representative full page lacks one article body")
            rendered = etree.tostring(nodes[0], encoding="unicode", method="html")
            page_blocks = SOURCE.source_blocks(logical_html(rendered))
            agrees = SOURCE.whitespace(" ".join(page_blocks)) == SOURCE.whitespace(" ".join(record["sourceParagraphs"]))
            usage = page.xpath("//*[contains(concat(' ',normalize-space(@class),' '),' widget ')]")
            wording = [SOURCE.whitespace(node.text_content()) for node in usage
                       if "if you use any original content" in node.text_content()]
            result["fullPageAudits"].append({"recordId": record["recordId"], "sourceURL": record["sourceURL"],
                "sourceResponseSHA256": evidence["sha256"], "sourceParagraphs": page_blocks,
                "sourceTextSHA256": SOURCE.sha256("\n".join(page_blocks)), "feedBodyMatchesFullPage": agrees,
                "literalReuseWording": wording})
            if not agrees:
                raise ValueError("Representative feed content differs from actual published full article; review required")
        result["completed"] = True
    except (ValueError, OSError, subprocess.SubprocessError, etree.Error) as exc:
        result["errors"].append({"type": "bounded-source-crawl-stopped", "detail": str(exc)})
    result["generatedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
    result["duplicateIdentityCandidates"] = duplicate_candidates(result["records"])
    result["responseProvenance"] = client.provenance
    result["crawl"] = {"publishedFeedTotal": expected_total, "uniqueFeedEntriesRead": len(seen),
        "feedPagesRead": len(result["feedPages"]), "saintLabelEntries": len(result["records"]),
        "tagalogBiographyCandidates": sum(r["classification"] == "Tagalog-biography-review-candidate" for r in result["records"]),
        "tagalogBiographyExcerptCandidates": sum(r["classification"] == "Tagalog-biography-excerpt-review-candidate" for r in result["records"]),
        "quarantinedOrOtherGenres": sum(r["classification"] not in {"Tagalog-biography-review-candidate", "Tagalog-biography-excerpt-review-candidate"} for r in result["records"]),
        "liveRequests": client.attempts, "cacheHits": client.cache_hits, "responseBytes": client.bytes,
        "minimumDelaySeconds": client.effective_delay, "maxRequests": args.max_requests, "maxPages": args.max_pages}
    SOURCE.atomic_json(args.output, result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/opp-blogger-saints-tl.json")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-opp-blogger-saints-cache")
    parser.add_argument("--cache-expiry", type=int, default=86400)
    parser.add_argument("--delay", type=float, default=2.0)
    parser.add_argument("--max-pages", type=int, default=90)
    parser.add_argument("--max-requests", type=int, default=110)
    parser.add_argument("--max-bytes", type=int, default=80 * 1024 * 1024)
    args = parser.parse_args()
    if (not math.isfinite(args.delay) or args.delay < 2 or args.cache_expiry <= 0 or
            min(args.max_pages, args.max_requests, args.max_bytes) <= 0):
        parser.error("Use finite positive budgets/cache duration and delay >=2 seconds")
    result = crawl(args)
    print(json.dumps(result["crawl"], ensure_ascii=False), flush=True)
    return 0 if result["completed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
