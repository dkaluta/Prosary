#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lxml>=5,<7", "protego>=0.4,<1"]
# ///
"""Collect CREDO's published Ukrainian saints/feasts category excerpts for review.

This follows only real category pagination and retains every published card, even
when it is news or a reflection rather than a biography. It does not claim to
download every full article, to cover every calendar day, or to license reuse.
Three representative full pages are audited by default. RKC's inaccessible robots
endpoint is recorded separately; a challenge is never interpreted as permission.

Run: uv run --script Shared/tools/scrape-credo-saints.py
Offline rerun: ... --offline
Inspect source: ... --parse-html FILE --parse-url URL --parse-kind index|article
"""
from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import time
import unicodedata
import urllib.error
import urllib.request
from collections import Counter, deque
from email.utils import parsedate_to_datetime
from pathlib import Path
from urllib.parse import urljoin, urlsplit

from lxml import html as lh
from protego import Protego

TOOLS = Path(__file__).resolve().parent
BASE = "https://credo.pro"
INDEX = BASE + "/saints"
ROBOTS = BASE + "/robots.txt"
RKC_ROBOTS = "https://rkc.org.ua/robots.txt"
USER_AGENT = "ProsarySaintSourceResearch/1.0 (+https://prosary.app)"
EXCLUDED = {"script", "style", "noscript", "form", "iframe", "object", "nav", "footer"}
BLOCKS = {"p", "div", "li", "h1", "h2", "h3", "h4", "blockquote", "tr"}
MONTHS = {name: n for n, name in enumerate(
    ["січня", "лютого", "березня", "квітня", "травня", "червня", "липня",
     "серпня", "вересня", "жовтня", "листопада", "грудня"], 1)}
DATE = re.compile(r"\b(0?[1-9]|[12]\d|3[01])\s+(" + "|".join(MONTHS) +
                  r")(?:\s+((?:1|2)\d{3})(?:\s*р(?:оку|\.))?)?", re.I)
RITE = re.compile(r"(Римо-катол\.?|Греко-катол\.?)\s*:\s*([^\n()]{1,100}(?:\([^\n)]{1,100}\))?)", re.I)
CREDIT = re.compile(r"(?:\b(?:Джерело|Переклад|Автор)\s*[:—-]|\bЗа матеріалами\b|пише\s|КAI|КАІ|РІСУ|CREDO)", re.I)


def sha(value: bytes | str) -> str:
    return hashlib.sha256(value.encode("utf-8") if isinstance(value, str) else value).hexdigest()


def now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds")


def space(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def canonical_url(value: str, base: str = INDEX, kind: str | None = None) -> str | None:
    """Allow only public category pages and numeric article routes on one host."""
    try:
        parts = urlsplit(urljoin(base, value))
        if (parts.scheme != "https" or parts.hostname != "credo.pro" or parts.port or
                parts.username or parts.password or parts.query or parts.fragment):
            return None
        path = parts.path.rstrip("/")
        is_index = bool(re.fullmatch(r"/saints(?:/page/[1-9]\d*)?", path))
        is_article = bool(re.fullmatch(r"/(?:19|20)\d{2}/(?:0[1-9]|1[0-2])/[1-9]\d*", path))
        if (kind == "index" and not is_index) or (kind == "article" and not is_article):
            return None
        return BASE + path if is_index or is_article else None
    except (ValueError, TypeError):
        return None


def document(value: bytes | str):
    # The publisher's pages are UTF-8; never silently replace source glyphs.
    return lh.fromstring(value.decode("utf-8") if isinstance(value, bytes) else value)


def text(element, omit_classes: frozenset[str] = frozenset()) -> str:
    if not isinstance(element.tag, str) or element.tag.lower() in EXCLUDED:
        return ""
    if set(element.get("class", "").split()) & omit_classes:
        return ""
    values = [element.text or ""]
    for child in element:
        tag = child.tag.lower() if isinstance(child.tag, str) else ""
        if tag == "br":
            values.append("\n")
        elif tag not in EXCLUDED:
            value = text(child, omit_classes)
            values.append(("\n" if tag in BLOCKS else "") + value +
                          ("\n" if tag in BLOCKS else ""))
        # Tails belong to the containing prose, including tails of excluded nodes.
        values.append(child.tail or "")
    return "".join(values)


def cls(name: str) -> str:
    return f"contains(concat(' ',normalize-space(@class),' '),' {name} ')"


def language_evidence(value: str) -> dict:
    letters = [c for c in value if c.isalpha()]
    cyrillic = sum("\u0400" <= c <= "\u052f" for c in letters)
    ukrainian = Counter(c.lower() for c in value if c.lower() in "іїєґ")
    russian = Counter(c.lower() for c in value if c.lower() in "ыэёъ")
    share = cyrillic / max(len(letters), 1)
    accepted = cyrillic >= 20 and sum(ukrainian.values()) >= 2 and share >= .5 and sum(russian.values()) <= max(2, cyrillic * .01)
    return {"languageCode": "uk" if accepted else None, "cyrillicLetterCount": cyrillic,
            "cyrillicLetterShare": round(share, 4), "ukrainianDistinctiveLetters": dict(ukrainian),
            "russianDistinctiveLetters": dict(russian), "method": "actual-source-prose-script-and-language-characters"}


def date_evidence(value: str) -> list[dict]:
    result = []
    for match in DATE.finditer(value):
        result.append({"sourceWording": match.group(), "day": int(match[1]),
                       "month": MONTHS[match[2].lower()], "explicitYear": int(match[3]) if match[3] else None,
                       "context": space(value[max(0, match.start() - 60):match.end() + 100]),
                       "reviewStatus": "unclassified-source-date-not-a-calendar-appointment"})
    return result


def rite_evidence(value: str) -> list[dict]:
    return [{"sourceWording": space(m.group()), "rite": "latin" if m[1].lower().startswith("римо") else "byzantine",
             "reviewStatus": "source-label-only"} for m in RITE.finditer(value)]


def genre(title: str, prose: str) -> str:
    if re.match(r"^Свят(?:ий|а|і|ого|ої|их)\s+(?:Арх)?Ангел", title, re.I):
        return "feast-description-candidate"
    if (re.match(r"^(?:Свят(?:ий|а|і|ого|ої|их)|Блаженн(?:ий|а|і|ого|ої|их)|Праведн(?:ий|а|і))\s", title)
            or re.match(r"^Свв?\.\s*", title)
            or re.match(r"^Спомин\s+(?:свв?\.\s*|свят(?:ого|ої|их)\s+)", title, re.I)
            or title == "Мати Тереза з Калькутти"):
        return "saint-biography-candidate"
    if (re.match(r"^(?:Свято |Урочистість |Пресвят|Внебовзяття|Мучеництво|Успіння|Непорочне|Преображення|Вознесіння|Стрітення|Богоявлення|Собор |Всіх святих|Благовіщення|Введення у храм|Празник |Велика [Сс]убота|Велика [Пп][’']ятниця|Великий [Чч]етвер|Спомин Непорочного)", title)
            or rite_evidence(prose)):
        return "feast-description-candidate"
    return "other-article-review-required"


def policy_evidence(root) -> list[str]:
    candidates = root.xpath(f"//*[{cls('corit')}] | //*[{cls('author-wrap')}]")
    # Some templates contain an accidentally truncated duplicate footer.
    return list(dict.fromkeys(space(text(n)) for n in candidates if len(space(text(n))) > 80))


def parse_index(value: bytes | str, url: str) -> dict:
    if canonical_url(url, kind="index") != url:
        raise ValueError("Not an allowed category URL")
    root = document(value)
    titles = root.xpath(f"//h1[{cls('pagenam_custom_single')}]")
    if len(titles) != 1 or space(text(titles[0])) != "Свята та святі":
        raise ValueError("Unrecognized saints category template/title")
    cards = root.xpath(f"//*[@id='content-block']//*[{cls('category_wrap')}]/*[{cls('main-line-item')}]")
    if not cards:
        raise ValueError("Category has no recognized published article cards")
    rows = []
    for position, card in enumerate(cards, 1):
        links = card.xpath(f"./a[{cls('home-line-link')}]")
        if len(links) != 1:
            raise ValueError(f"Card {position} has an ambiguous article link")
        source_url = canonical_url(links[0].get("href", ""), url, "article")
        title = card.xpath(f".//*[{cls('line_post_content_wrap')}]/h3")
        paragraphs = card.xpath(f".//*[{cls('line_post_content_wrap')}]/p")
        if not source_url or len(title) != 1 or len(paragraphs) != 1:
            raise ValueError(f"Card {position} has an unrecognized article/title/excerpt")
        source_title = space(text(title[0]))
        # Keep line breaks in the publisher's excerpt for literal rite/date labels.
        prose = "\n".join(space(line) for line in text(paragraphs[0]).splitlines() if space(line))
        publications = card.xpath(f".//span[{cls('numView')}]")
        rows.append({"sourceURL": source_url, "sourceID": source_url.rsplit("/", 1)[1],
                     "title": source_title, "sourceExcerpt": prose, "sourceTextSHA256": sha(prose),
                     "coverage": "published-category-excerpt", "sourceTruncated": prose.endswith(("...", "…")),
                     "fullArticleFetched": False, "sourceLanguageEvidence": language_evidence(prose),
                     "genre": genre(source_title, prose), "literalDateEvidence": date_evidence(prose),
                     "riteEvidence": rite_evidence(prose),
                     "publicationDateWording": space(text(publications[0])) if publications else None,
                     "publicationURLYearMonth": "/".join(source_url.split("/")[-3:-1]),
                     "creditCandidates": [{"sourceWording": line, "kind": "credit-or-reference", "reviewStatus": "unreviewed"}
                                          for line in prose.splitlines() if CREDIT.search(line)],
                     "indexOccurrences": [{"sourceURL": url, "cardPosition": position, "sourceHTMLSHA256": sha(value)}],
                     "reviewStatus": "identity-genre-date-attribution-and-reuse-required", "nativeImportAllowed": False})
    links = []
    for href in root.xpath("//*[@id='wp_page_numbers']//a/@href"):
        target = canonical_url(href, url, "index")
        if not target:
            raise ValueError(f"Pagination escaped the allowed category: {href}")
        if target != url and target not in links:
            links.append(target)
    page = int(url.rsplit("/", 1)[1]) if "/page/" in url else 1
    return {"pageNumber": page, "sourceURL": url, "sourceHTMLSHA256": sha(value),
            "documentLanguageTag": root.get("lang"), "cardCount": len(rows), "articles": rows,
            "paginationURLs": links, "policyEvidence": policy_evidence(root)}


def parse_article(value: bytes | str, url: str) -> dict:
    if canonical_url(url, kind="article") != url:
        raise ValueError("Not an allowed published article URL")
    root = document(value)
    titles = root.xpath(f"//h1[{cls('main-type')}]")
    bodies = root.xpath(f"//*[{cls('single-content')}]")
    if len(titles) != 1 or len(bodies) != 1:
        raise ValueError("Unrecognized or ambiguous full article template")
    raw = text(bodies[0], frozenset({"author-wrap"}))
    paragraphs = [space(line) for line in raw.splitlines() if space(line)]
    prose = "\n".join(paragraphs)
    credits = [space(text(n)) for n in root.xpath(f"//*[{cls('author_single')}]") if space(text(n))]
    credits += [p for p in paragraphs if CREDIT.search(p)]
    publication = root.xpath(f"//*[{cls('single_cenpage')}]//span[{cls('compost')}]")
    chronology = []
    current_year = dt.datetime.now(dt.timezone.utc).year
    for p in paragraphs:
        for match in re.finditer(r"\b(\d{4})\s*[–—-]\s*(\d{4})\b", p):
            first, last = int(match[1]), int(match[2])
            if last < first or last - first > 130 or last > current_year + 1:
                chronology.append({"sourceWording": match.group(), "context": p, "reviewStatus": "implausible-year-range-needs-review"})
    facts = []
    # This bounded manual audit refers to one verified source identity. Keep its
    # original words; a primary-source conflict never silently edits a quotation.
    if url.rsplit("/", 1)[-1] == "69985" and "Тереза від Дитяти Ісуса" in space(text(titles[0])):
        primary_bio = "https://www.vatican.va/news_services/liturgy/documents/ns_lit_doc_19101997_stherese_en.html"
        doctor_letter = "https://www.vatican.va/content/john-paul-ii/en/apost_letters/1997/documents/hf_jp-ii_apl_19101997_divini-amoris.html"
        for p in paragraphs:
            if "(1944)" in p and "місій" in p:
                facts.append({"sourceWording": p, "issue": "mission-patronage-year-conflicts-with-primary-source",
                              "primarySourceDate": "1927-12-14", "primarySourceURL": primary_bio,
                              "reviewStatus": "source-words-retained-do-not-republish-without-editorial-review"})
            if "(1999)" in p and "Вчителем" in p:
                facts.append({"sourceWording": p, "issue": "doctor-of-church-year-conflicts-with-primary-source",
                              "primarySourceDate": "1997-10-19", "primarySourceURL": doctor_letter,
                              "reviewStatus": "source-words-retained-do-not-republish-without-editorial-review"})
    return {"sourceURL": url, "title": space(text(titles[0])), "paragraphs": paragraphs,
            "sourceHTMLSHA256": sha(value), "sourceTextSHA256": sha(prose),
            "coverage": "representative-full-page-audit", "sourceLanguageEvidence": language_evidence(prose),
            "publicationDateWording": space(text(publication[0])) if publication else None,
            "literalDateEvidence": date_evidence(raw), "riteEvidence": rite_evidence(raw),
            "creditCandidates": [{"sourceWording": c, "kind": "credit-or-reference", "reviewStatus": "unreviewed"} for c in dict.fromkeys(credits)],
            "policyEvidence": policy_evidence(root), "chronologyReview": chronology, "sourceFactReview": facts,
            "reviewStatus": "source-preservation-audit-not-editorial-approval", "nativeImportAllowed": False}


def robots_policy(body: bytes, status: int, content_type: str) -> Protego:
    source = body.decode("utf-8")
    if status != 200 or "html" in content_type.lower() or re.search(r"<(?:html|script|!doctype)\b", source, re.I):
        raise ValueError("Robots response is unavailable or an HTML/challenge document; permission is unknown")
    if not re.search(r"(?im)^\s*User-agent\s*:", source):
        raise ValueError("Robots response has no recognizable user-agent policy")
    return Protego.parse(source)


def save(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=path.parent, delete=False) as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
        temporary = Path(handle.name)
    temporary.replace(path)


class BoundedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Only category/article routes already permitted on the same source host.
        if not canonical_url(newurl):
            raise urllib.error.URLError("Redirect left the public category/article boundary")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


class Client:
    def __init__(self, args):
        self.args = args
        self.cache = args.cache_dir
        self.cache.mkdir(parents=True, exist_ok=True)
        self.last_request = {}  # monotonic clocks per host; no parallel downloads
        self.policies = {}
        self.delays = {"credo.pro": 30.0, "rkc.org.ua": 2.0}
        self.stats = {"networkRequests": 0, "cacheHits": 0, "downloadedBytes": 0}
        self.provenance = []
        # Ordinary curl negotiates this host's TLS successfully on the research
        # machine; urllib's normal TLS handshake fails. No browser impersonation,
        # challenge execution, cookies, or redirect following is involved.

    def download(self, url):
        with tempfile.TemporaryDirectory() as directory:
            body_path = Path(directory) / "body"
            headers_path = Path(directory) / "headers"
            proc = subprocess.run(["curl", "--silent", "--show-error", "--compressed", "--max-time", "45",
                                   "--max-filesize", str(self.args.max_response_bytes), "--proto", "=https",
                                   "--user-agent", USER_AGENT, "--header", "Accept: text/html,text/plain;q=0.9",
                                   "--dump-header", str(headers_path), "--output", str(body_path),
                                   "--write-out", "%{http_code}\n%{content_type}\n%{url_effective}", url],
                                  capture_output=True, text=True, timeout=55, check=False)
            if proc.returncode:
                raise OSError("Ordinary curl download failed: " + space(proc.stderr)[:300])
            fields = proc.stdout.splitlines()
            if len(fields) != 3 or fields[2] != url:
                raise ValueError("Unexpected curl response URL/metadata")
            if body_path.stat().st_size > self.args.max_response_bytes:
                raise ValueError("Decompressed response exceeded the byte budget")
            body = body_path.read_bytes()
            retry_after = ""
            for line in headers_path.read_text(encoding="iso-8859-1").splitlines():
                if line.lower().startswith("retry-after:"):
                    retry_after = line.partition(":")[2].strip()
            return body, int(fields[0]), fields[1], retry_after

    def fetch(self, url: str, *, robots: bool = False) -> dict:
        host = urlsplit(url).hostname
        if robots:
            if url not in {ROBOTS, RKC_ROBOTS}:
                raise ValueError("Unexpected robots endpoint")
        elif not canonical_url(url) or host not in self.policies or not self.policies[host].can_fetch(url, USER_AGENT):
            raise ValueError("URL escaped the scope or is not permitted by verified robots")
        cache_path = self.cache / (sha(url) + ".json")
        if cache_path.exists():
            item = json.loads(cache_path.read_text(encoding="utf-8"))
            body = base64.b64decode(item["bodyBase64"], validate=True)
            age = time.time() - dt.datetime.fromisoformat(item["fetchedAt"]).timestamp()
            if item["sourceURL"] != url or sha(body) != item["sourceHTMLSHA256"]:
                raise ValueError("Corrupt or mismatched HTTP cache entry")
            if item["status"] == 200 and (age < 86400 or self.args.offline):
                self.stats["cacheHits"] += 1
                result = {**item, "body": body, "cacheHit": True}
                self.provenance.append({k: v for k, v in result.items() if k not in {"body", "bodyBase64"}})
                return result
        if self.args.offline:
            raise ValueError(f"Offline cache miss: {url}")
        for attempt in range(3):
            if self.stats["networkRequests"] >= self.args.max_requests:
                raise ValueError("Network request budget reached")
            delay = self.delays[host]
            if host in self.last_request:
                time.sleep(max(0, self.last_request[host] + delay - time.monotonic()))
            self.last_request[host] = time.monotonic()
            self.stats["networkRequests"] += 1
            print(f"Request {self.stats['networkRequests']}: {url}", flush=True)
            try:
                body, status, content_type, retry_after = self.download(url)
            except OSError:
                if attempt == 2:
                    raise
                time.sleep(max(delay, 30 * (2 ** attempt)))
                continue
            self.stats["downloadedBytes"] += len(body)
            if len(body) > self.args.max_response_bytes or self.stats["downloadedBytes"] > self.args.max_bytes:
                raise ValueError("HTTP response or total byte budget reached")
            result = {"sourceURL": url, "responseURL": url, "status": status,
                      "contentType": content_type, "fetchedAt": now(), "sourceHTMLSHA256": sha(body),
                      "body": body, "cacheHit": False, "transport": "ordinary-curl-no-redirects"}
            if status in {429, 500, 502, 503, 504} and attempt < 2:
                try:
                    seconds = float(retry_after)
                except ValueError:
                    try:
                        seconds = parsedate_to_datetime(retry_after).timestamp() - time.time()
                    except (ValueError, TypeError):
                        seconds = 30 * (2 ** attempt)
                # Never shorten a source's requested retry interval.
                time.sleep(max(delay, seconds))
                continue
            if status == 200:
                save(cache_path, {k: v for k, v in result.items() if k not in {"body", "cacheHit"}} |
                     {"bodyBase64": base64.b64encode(body).decode("ascii")})
            self.provenance.append({k: v for k, v in result.items() if k != "body"})
            return result
        raise ValueError("Retries exhausted")

    def establish_policy(self) -> dict:
        response = self.fetch(ROBOTS, robots=True)
        policy = robots_policy(response["body"], response["status"], response["contentType"])
        self.policies["credo.pro"] = policy
        self.delays["credo.pro"] = max(2.0, float(policy.crawl_delay(USER_AGENT) or 0), 30.0)
        return {"sourceURL": ROBOTS, "status": response["status"], "sourceHTMLSHA256": response["sourceHTMLSHA256"],
                "sourceWording": response["body"].decode("utf-8"), "effectiveDelaySeconds": self.delays["credo.pro"]}


def catalogue(args) -> tuple[dict, int]:
    client = Client(args)
    result = {"schemaVersion": 1, "provider": "CREDO", "languageCode": "uk", "generatedAt": now(),
              "sourceURL": INDEX, "scope": "all published cards reachable through the Saints/Feasts category pagination",
              "coverage": "category-excerpts-with-representative-full-page-audits",
              "complete": False, "fullBiographyCollectionComplete": False, "wholeLiturgicalYearClaimed": False,
              "nativeImportAllowed": False, "reuseStatus": "written-editorial-permission-required-not-obtained",
              "calendarAppointmentsChanged": False, "indexPages": [], "articles": [], "excluded": [],
              "quarantined": [], "fullPageAudits": [], "blockedProviders": [], "errors": [],
              "limits": {"maxPages": args.max_pages, "maxRequests": args.max_requests,
                         "maxBytes": args.max_bytes, "maxResponseBytes": args.max_response_bytes},
              "review": {"identity": "unreviewed", "dateAppointment": "not-imported", "attribution": "unreviewed",
                         "sourceFacts": "unreviewed", "language": "actual-Ukrainian-prose-check",
                         "genre": "conservative-title-and-explicit-rite-label-candidates"}}
    rows = {}
    pending = deque([INDEX])
    visited = set()
    discovered = {INDEX}
    try:
        try:
            probe = client.fetch(RKC_ROBOTS, robots=True)
            try:
                robots_policy(probe["body"], probe["status"], probe["contentType"])
                problem = "RKC is outside this chosen CREDO excerpt scope; no events requested"
            except ValueError as error:
                problem = str(error)
            result["blockedProviders"].append({"provider": "Roman Catholic Church in Ukraine", "sourceURL": RKC_ROBOTS,
                                               "status": probe["status"], "sourceHTMLSHA256": probe["sourceHTMLSHA256"],
                                               "problem": problem, "eventsFetched": 0, "challengeBypassed": False})
        except (ValueError, OSError) as error:
            prior_diagnostic = []
            if args.offline and args.output.exists():
                previous = json.loads(args.output.read_text(encoding="utf-8"))
                prior_diagnostic = [p for p in previous.get("blockedProviders", []) if p.get("sourceURL") == RKC_ROBOTS]
            if prior_diagnostic:
                result["blockedProviders"].extend({**p, "lastLiveDiagnosticPreserved": True} for p in prior_diagnostic)
            else:
                result["blockedProviders"].append({"provider": "Roman Catholic Church in Ukraine", "sourceURL": RKC_ROBOTS,
                                                   "problem": str(error), "eventsFetched": 0, "challengeBypassed": False})
        result["robots"] = client.establish_policy()
        while pending:
            url = pending.popleft()
            if url in visited:
                continue
            if len(visited) >= args.max_pages:
                raise ValueError("Category page budget reached before published pagination ended")
            response = client.fetch(url)
            if response["status"] != 200:
                raise ValueError(f"Category HTTP {response['status']}: {url}")
            parsed = parse_index(response["body"], url)
            visited.add(url)
            page_rows = parsed.pop("articles")
            result["indexPages"].append(parsed)
            for row in page_rows:
                if row["sourceURL"] in rows:
                    previous = rows[row["sourceURL"]]
                    previous["indexOccurrences"].extend(row["indexOccurrences"])
                    if previous["sourceTextSHA256"] != row["sourceTextSHA256"] or previous["title"] != row["title"]:
                        previous.setdefault("indexVariants", []).append({k: v for k, v in row.items() if k != "indexOccurrences"})
                else:
                    rows[row["sourceURL"]] = row
            for target in parsed["paginationURLs"]:
                discovered.add(target)
                if target not in visited and target not in pending:
                    pending.append(target)
            print(f"Category {parsed['pageNumber']}: {parsed['cardCount']} cards; {len(rows)} distinct URLs", flush=True)
            result["discovery"] = {"paginationURLs": sorted(discovered), "visitedPaginationURLs": sorted(visited),
                                   "publishedArticleURLs": sorted(rows), "rawCardCount": sum(p["cardCount"] for p in result["indexPages"])}
            result["stats"] = dict(client.stats)
            result["articles"] = list(rows.values())
            save(args.output, result)
        # Require every numbered page between the first and published last page.
        page_numbers = sorted(p["pageNumber"] for p in result["indexPages"])
        if page_numbers != list(range(1, max(page_numbers) + 1)):
            raise ValueError("Published pagination has a numbered gap; completeness is unverified")
        result["termination"] = {"reason": "all-published-pagination-links-visited", "lastPageNumber": max(page_numbers),
                                 "numberedPageGap": False, "remainingPaginationURLs": sorted(discovered - visited)}
        # Audit a real Latin biography, a feast, and a Byzantine/mixed source when present.
        samples = []
        predicates = [lambda r: r["title"].startswith("Свята Тереза від Дитяти Ісуса"),
                      lambda r: any(e["rite"] == "byzantine" for e in r["riteEvidence"]),
                      lambda r: r["genre"] == "feast-description-candidate"]
        for predicate in predicates:
            sample = next((r for r in rows.values() if predicate(r) and r["sourceURL"] not in samples), None)
            if sample:
                samples.append(sample["sourceURL"])
        samples.extend(r["sourceURL"] for r in rows.values() if r["sourceURL"] not in samples)
        for url in samples[:args.sample_count]:
            response = client.fetch(url)
            if response["status"] != 200:
                raise ValueError(f"Full-page audit HTTP {response['status']}: {url}")
            audit = parse_article(response["body"], url)
            row = rows[url]
            prefix = row["sourceExcerpt"].rstrip(".…")
            full = space("\n".join(audit["paragraphs"]))
            audit["excerptIsSourcePrefixAfterWhitespace"] = full.startswith(space(prefix))
            audit["categoryTitleMatchesArticleTitle"] = row["title"] == audit["title"]
            result["fullPageAudits"].append(audit)
            row["fullArticleFetched"] = True
            if not audit["excerptIsSourcePrefixAfterWhitespace"] or not audit["categoryTitleMatchesArticleTitle"]:
                row.setdefault("sourceReviewIssues", []).append("category-excerpt-or-title-differs-from-current-full-article")
        accepted, excluded, quarantine = [], [], []
        for row in rows.values():
            if row["sourceLanguageEvidence"]["languageCode"] != "uk" or not row["sourceExcerpt"]:
                quarantine.append(row)
            elif row["genre"] == "other-article-review-required":
                excluded.append(row)
            else:
                accepted.append(row)
        result.update(articles=accepted, excluded=excluded, quarantined=quarantine)
        identities = {}
        ids = {}
        for row in rows.values():
            identity = unicodedata.normalize("NFC", row["title"]).casefold()
            identities.setdefault(identity, []).append(row["sourceURL"])
            ids.setdefault(row["sourceID"], []).append(row["sourceURL"])
        result["duplicateReview"] = {"sourceIDAliases": [urls for urls in ids.values() if len(urls) > 1],
                                     "exactTitleGroups": [{"title": key, "sourceURLs": urls, "reviewStatus": "possible-reprint-or-shared-identity-no-auto-merge"}
                                                          for key, urls in identities.items() if len(urls) > 1]}
        result["complete"] = True
    except (ValueError, OSError, KeyboardInterrupt) as error:
        result["errors"].append({"message": str(error) or "interrupted", "type": type(error).__name__})
        result["articles"] = list(rows.values())
        result["remainingPaginationURLs"] = sorted(discovered - visited)
    finally:
        result["generatedAt"] = now()
        result["stats"] = client.stats
        result["responseProvenance"] = client.provenance
        result["counts"] = {key: len(result[key]) for key in ["articles", "excluded", "quarantined", "indexPages", "fullPageAudits"]}
        save(args.output, result)
    return result, 0 if result["complete"] else 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/credo-saints-uk.json")
    parser.add_argument("--cache-dir", type=Path, default=Path(tempfile.gettempdir()) / "prosary-credo-saints-http-cache")
    parser.add_argument("--offline", action="store_true")
    parser.add_argument("--max-pages", type=int, default=50)
    parser.add_argument("--max-requests", type=int, default=65)
    parser.add_argument("--max-bytes", type=int, default=30_000_000)
    parser.add_argument("--max-response-bytes", type=int, default=2_000_000)
    parser.add_argument("--sample-count", type=int, default=3)
    parser.add_argument("--parse-html", type=Path)
    parser.add_argument("--parse-url", default=INDEX)
    parser.add_argument("--parse-kind", choices=["index", "article"], default="index")
    args = parser.parse_args()
    if min(args.max_pages, args.max_requests, args.max_bytes, args.max_response_bytes) <= 0 or args.sample_count < 0:
        parser.error("Budgets must be positive and sample count must not be negative")
    if args.parse_html:
        result = (parse_index if args.parse_kind == "index" else parse_article)(args.parse_html.read_bytes(), args.parse_url)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    result, status = catalogue(args)
    print(json.dumps({"complete": result["complete"], "counts": result["counts"], "stats": result["stats"], "errors": result["errors"]}, ensure_ascii=False))
    return status


if __name__ == "__main__":
    sys.exit(main())
