#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lingua-language-detector>=2,<3"]
# ///
"""Review collected saint sources without joining them to native calendars.

Reconcile published collection coverage and independently recompute stored prose
digests. Preserve source/editorial flags in one report. This is an integrity and
source-selection review, not certification of every historical statement.
"""
from __future__ import annotations

import argparse
import calendar
import datetime as dt
import hashlib
import json
import re
from collections import Counter
from functools import lru_cache
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

TOOLS = Path(__file__).resolve().parent
CATALOGUES = {
    "he": "catholic-hebrew-saints.json",
    "en": "catholic-saints-en.json",
    "fr": "catholic-saints-fr.json",
    "it": "catholic-saints-it.json",
    "ru": "catholic-saints-ru.json",
    "ar": "evangelizo-saints-ar.json",
    "tl": "tagalog-saints.json",
    "uk": "rkc-saints-uk.json",
}
THERESE = "https://www.vatican.va/content/john-paul-ii/en/apost_letters/1997/documents/hf_jp-ii_apl_19101997_divini-amoris.html"
PIO = "https://www.vatican.va/news_services/liturgy/saints/ns_lit_doc_20020616_padre-pio_en.html"
FISHER = "https://www.vaticannews.va/it/santo-del-giorno/06/22/santi-giovanni-fisher--vescovo-di-rochester--e-tommaso-more--mar.html"


def digest(text: str | bytes) -> str:
    return hashlib.sha256(text.encode("utf-8") if isinstance(text, str) else text).hexdigest()


def record_key(record: dict) -> str:
    return str(record.get("recordId") or record.get("sourceSubjectID") or
               record.get("articleId") or record.get("sourceID") or record.get("sourceURL"))


def editorial_record_fingerprint(record: dict) -> str:
    # Titles, dates, genre, flags and contributor evidence matter alongside prose.
    return digest(json.dumps(record, ensure_ascii=False, sort_keys=True, separators=(",", ":")))


class VisibleSourceText(HTMLParser):
    """Independent character-order audit, allowing HTML whitespace normalization."""
    excluded = {"script", "style", "noscript", "iframe", "form", "object", "nav", "footer"}
    void = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack = []
        self.text = []

    def handle_starttag(self, tag, attrs):
        classes = dict(attrs).get("class", "").split()
        skip = tag in self.excluded or bool({"sfsiaftrpstwpr", "post-views"} & set(classes))
        if tag not in self.void:
            self.stack.append((tag, skip or any(value for _, value in self.stack)))

    def handle_startendtag(self, tag, attrs):
        pass

    def handle_endtag(self, tag):
        for index in range(len(self.stack) - 1, -1, -1):
            if self.stack[index][0] == tag:
                del self.stack[index:]
                break

    def handle_data(self, value):
        if not any(skip for _, skip in self.stack):
            self.text.append(value)


def visible_character_stream(markup: str) -> str:
    parser = VisibleSourceText()
    parser.feed(markup)
    parser.close()
    return re.sub(r"\s+", "", "".join(parser.text))


@lru_cache(maxsize=1)
def russian_biography_detector():
    from lingua import Language, LanguageDetectorBuilder
    return LanguageDetectorBuilder.from_languages(
        Language.RUSSIAN, Language.UKRAINIAN, Language.BELARUSIAN,
        Language.BULGARIAN, Language.SERBIAN, Language.POLISH,
        Language.ENGLISH, Language.FRENCH, Language.ITALIAN,
        Language.TAGALOG, Language.HEBREW, Language.ARABIC).build()


def demonstrably_russian_biography(markup: str) -> bool:
    """Conservatively hold short, mixed or foreign prose regardless of API edition."""
    from lingua import Language
    parser = VisibleSourceText()
    parser.feed(markup)
    parser.close()
    text = " ".join(parser.text)
    if sum(character.isalpha() for character in text) < 80:
        return False
    scores = russian_biography_detector().compute_language_confidence_values(text)
    return (scores[0].language == Language.RUSSIAN and scores[0].value >= 0.7
            and scores[0].value - scores[1].value >= 0.2)


def source_prose(record: dict, language: str) -> tuple[str | None, str]:
    if language in {"he", "en", "fr", "it", "ru"}:
        if language == "he" and record.get("preservedHebrewProse") and not record.get("fullSourceProse"):
            return None, "Foreign flag attempt preserves only a bounded preview; full digest cannot be recomputed."
        original = record.get("fullSourceProse", record)
        return "\n".join([original["introduction"], *original["paragraphs"]]), "sourceTextSHA256"
    if language == "tl":
        if record.get("sourceCapture", {}).get("contentCaptured") is False:
            return None, "Index metadata only; this article body has not been captured."
        return "\n".join(record["sourceParagraphs"]), "sourceTextSHA256"
    if language == "uk":
        if "sourceExcerpt" in record:
            return record["sourceExcerpt"], "sourceTextSHA256"
        return "\n".join(record["paragraphs"]), "sourceTextSHA256"
    return "\n".join(record["paragraphs"]), "sourceTextSHA256"


def issue_codes(record: dict) -> list[str]:
    result = []
    if record.get("rejectionReason"):
        result.append(record["rejectionReason"])
    review = record.get("review", {})
    for issue in review.get("issues", []):
        result.append(issue.get("code", "unspecified-issue") if isinstance(issue, dict) else issue)
    result.extend(review.get("reasons", []))
    return sorted(set(result))


def independent_snapshot_review(source_dir: Path) -> dict:
    path = source_dir / "saint-source-independent-audits.json"
    if not path.exists():
        return {"available": False, "errors": ["independent-audit-file-missing"]}
    raw = path.read_bytes()
    audit = json.loads(raw)
    providers = list(audit["audits"])
    additional = []
    retry_path = source_dir / "saint-source-retry-independent-audits.json"
    if retry_path.exists():
        retry_raw = retry_path.read_bytes()
        providers.extend(json.loads(retry_raw)["audits"])
        additional.append({"file": retry_path.name, "fileSHA256": digest(retry_raw)})
    results, errors = [], []
    for provider in providers:
        snapshots = provider.get("snapshots", [provider])
        for snapshot in snapshots:
            if "cataloguePath" not in snapshot:
                continue
            filename = Path(snapshot["cataloguePath"]).name
            captured = (source_dir / filename).read_bytes()
            matches = digest(captured) == snapshot["catalogueSHA256"]
            results.append({"catalogue": filename, "snapshotMatches": matches})
            if not matches:
                errors.append("independent-audit-snapshot-changed:" + filename)
    return {"available": True, "file": path.name, "fileSHA256": digest(raw),
            "additionalAuditFiles": additional, "sourceSnapshots": results, "errors": errors}


def review_catalogue(language: str, path: Path, editorial_reviews: list[dict] | None = None) -> dict:
    raw = path.read_bytes()
    source = json.loads(raw)
    errors = []
    warnings = []
    complete = source.get("completed", source.get("complete", False))
    if complete is not True:
        errors.append("source-crawl-incomplete")
    if source.get("errors"):
        errors.append("source-crawl-has-errors")
    if source.get("crawl", {}).get("budgetLimited"):
        errors.append("source-crawl-budget-limited")
    records = source.get("records", source.get("articles", []))
    quarantine = source.get("quarantine", source.get("quarantined", []))
    excluded = source.get("excluded", [])
    all_records = [*records, *quarantine, *excluded]
    keys = [record_key(r) for r in all_records]
    captured_keys = {record_key(r) for r in all_records
                     if r.get("sourceCapture", {}).get("contentCaptured") is not False}
    metadata_only = sum(r.get("sourceCapture", {}).get("contentCaptured") is False for r in all_records)
    if language == "tl" and complete and metadata_only:
        errors.append("metadata-only-records-in-completed-biography-collection")
    # Catholic flag journeys can repeat an article identity with different URLs.
    identities = [(record_key(r), r.get("requestURL", r.get("sourceURL"))) for r in all_records]
    if len(identities) != len(set(identities)):
        errors.append("duplicate-source-record-and-request")
    verified = 0
    raw_prose_audited = 0
    nonempty_prose = 0
    partial = []
    issues = Counter()
    shapes = Counter()
    genre = Counter()
    credit_count = 0
    for record in all_records:
        key = record_key(record)
        prose, field = source_prose(record, language)
        nonempty_prose += bool(prose and prose.strip())
        if prose is None:
            partial.append({"record": key, "reason": field})
        elif digest(prose) != record.get(field):
            errors.append("source-prose-digest-mismatch:" + key)
        else:
            verified += 1
        html_field = "rawBiographyHTML" if language == "ar" else "sourceHTML" if language == "tl" else None
        if prose is not None and html_field:
            if visible_character_stream(record[html_field]) != re.sub(r"\s+", "", prose):
                errors.append("visible-source-prose-differs:" + key)
            else:
                raw_prose_audited += 1
        for html, checksum in [("sourceHTML", "sourceHTMLSHA256"),
                               ("rawBiographyHTML", "sourceBiographyHTMLSHA256")]:
            if html in record and digest(record[html]) != record.get(checksum):
                errors.append("source-html-digest-mismatch:" + key)
        if language == "tl" and digest("\n".join(record["sections"]["biography"])) != record.get("biographyTextSHA256"):
            errors.append("biography-digest-mismatch:" + key)
        url = urlsplit(record.get("sourceURL", ""))
        if url.scheme != "https" or not url.netloc or url.username or url.password:
            errors.append("invalid-source-url:" + key)
        codes = issue_codes(record)
        issues.update(codes)
        if codes:
            warnings.append({"record": key, "sourceURL": record.get("sourceURL"), "issues": codes})
        shape = ("index-metadata-only" if record.get("sourceCapture", {}).get("contentCaptured") is False
                 else "bounded-foreign-preview" if prose is None
                 else "mixed-source-prose" if record.get("fullSourceProse")
                 else "missing-biography" if language == "ar" and not prose.strip()
                 else record.get("contentShape") or record.get("coverage") or "body")
        shapes.update([shape])
        genre.update([record.get("classification") or record.get("genre") or "provider-saint-calendar-subject"])
        credit_count += bool(record.get("credits") or record.get("literalCredits") or
                             record.get("creditCandidates") or record.get("underlyingCredit"))
        # A source number is evidence of a possible typo, never an automatic correction.
        long_numbers = sorted(set(re.findall(r"(?<!\d)[12]\d{4,}(?!\d)", prose or "")))
        if long_numbers:
            warnings.append({"record": key, "sourceURL": record.get("sourceURL"),
                             "issues": ["long-year-like-literal-needs-context"], "sourceNumbers": long_numbers})
    coverage = {}
    if language in {"he", "en", "fr", "it", "ru"}:
        published = {str(entry["articleId"]) for page in source["indexPages"] for entry in page.get("entries", [])}
        # Depending on extractor edition, index snapshots store articleIDs directly.
        if not published:
            published = {str(value) for page in source["indexPages"] for value in page.get("articleIDs", [])}
        if not published:
            published = {str(value) for page in source["indexPages"] for value in page.get("articleIds", [])}
        stored_index_ids = bool(published)
        if not published:
            published = {parse_qs(urlsplit(r["indexEntry"]["url"]).query)["id"][0]
                         for r in all_records if r.get("indexEntry")}
        requested_ids = {parse_qs(urlsplit(r.get("requestURL", r.get("sourceURL", ""))).query).get("id", [None])[0]
                         for r in all_records}
        missing = sorted(published - requested_ids)
        if missing:
            errors.append("unaccounted-published-article-ids")
        crawl = source["crawl"]
        if crawl.get("discoveredArticles") != len(published):
            errors.append("published-index-count-mismatch")
        if crawl.get("naturalPaginationEnd") is not True:
            errors.append("natural-pagination-end-unproven")
        coverage = {"publishedArticleIDs": len(published), "missingArticleIDs": missing,
                    "indexPages": len(source["indexPages"]), "naturalPaginationEnd": crawl.get("naturalPaginationEnd"),
                    "identityEvidence": "stored published index IDs" if stored_index_ids else
                        "record indexEntry URLs reconciled against declared discovery count; raw index audit recorded separately"}
    elif language == "ar":
        pages = source["collections"]
        dates = {(page["month"], page["day"]) for page in pages}
        expected = {(month, day) for month in range(1, 13)
                    for day in range(1, calendar.monthrange(2000, month)[1] + 1)}
        if dates != expected:
            errors.append("missing-valid-month-day-collection")
        published = {key for page in pages for key in page["subjectIDs"]}
        if published != set(keys):
            errors.append("source-subject-collection-mismatch")
        for date in dates:
            date_pages = [page for page in pages if (page["month"], page["day"]) == date]
            subjects = {key for page in date_pages for key in page["subjectIDs"]}
            if any(page["total"] != len(subjects) for page in date_pages):
                errors.append("source-collection-total-mismatch:" + str(date))
        coverage = {"coveredMonthDays": len(dates), "publishedSubjectIDs": len(published), "collectionPages": len(pages)}
    elif language == "tl" and "feedPages" in source:
        pages = source["feedPages"]
        crawl = source["crawl"]
        expected_total = crawl["publishedFeedTotal"]
        feed_entries = [*source["otherFeedEntryMetadata"], *records]
        feed_ids = [record["sourceAtomID"] for record in feed_entries]
        if len(feed_ids) != len(set(feed_ids)) or len(feed_ids) != expected_total:
            errors.append("published-blogger-feed-total-or-identity-mismatch")
        cursor = 1
        for index, page in enumerate(pages):
            if page["startIndex"] != cursor or page["sourceTotal"] != expected_total:
                errors.append("published-blogger-feed-cursor-gap")
            cursor += page["entryCount"]
            expected_next = pages[index + 1]["sourceURL"] if index + 1 < len(pages) else None
            if page["nextURL"] != expected_next:
                errors.append("published-blogger-feed-pagination-not-exhausted")
        if cursor - 1 != expected_total or not pages:
            errors.append("published-blogger-feed-count-mismatch")
        saint_total = int(source["sourcePolicyEvidence"]["homeSaintLabelCounter"][0])
        if saint_total != len(records) or any("SAINT" not in r["sourceLabels"] for r in records):
            errors.append("published-blogger-saint-subset-mismatch")
        if any("SAINT" in r["sourceLabels"] for r in source["otherFeedEntryMetadata"]):
            errors.append("published-blogger-saint-record-excluded")
        coverage = {"publishedFeedPosts": expected_total, "feedPages": len(pages),
                    "saintLabelEntries": len(records), "capturedArticleBodies": len(records) - metadata_only,
                    "metadataOnlyRecords": metadata_only,
                    "selectedBiographyCandidates": sum(r["classification"] == "Tagalog-biography-review-candidate"
                        and record_key(r) in captured_keys for r in records),
                    "selectedBiographyExcerpts": sum(r["classification"] == "Tagalog-biography-excerpt-review-candidate"
                        and record_key(r) in captured_keys for r in records),
                    "historicalArchive": True, "wholeLiturgicalYearClaimed": False,
                    "annualDuplicateGroups": len(source.get("duplicateIdentityCandidates", []))}
    elif language == "tl" and "indexPages" in source:
        published = set(source["discovery"]["publishedArticleURLs"])
        stored = {r["sourceURL"] for r in all_records}
        indexed = {p["url"] for page in source["indexPages"] for p in page["posts"]}
        if published != stored or published != indexed:
            errors.append("published-tvmaria-article-links-unaccounted")
        visited = {page["sourceURL"] for page in source["indexPages"]}
        seeds = {seed["url"] for seed in source["discovery"]["archiveSeeds"]}
        pagination = {p["url"] if isinstance(p, dict) else p
                      for page in source["indexPages"] for p in page["pagination"]}
        if not seeds <= visited or not pagination <= visited or source["remainingPaginationURLs"]:
            errors.append("published-tvmaria-archive-pagination-not-exhausted")
        if source["unfetchedArticleURLs"] or source["crawl"]["naturalPaginationEnd"] is not True:
            errors.append("published-tvmaria-articles-unfetched")
        if not set(source["selectedBiographyCandidateIds"]) <= set(keys):
            errors.append("selected-biography-id-missing")
        coverage = {"publishedPosts": len(published), "publishedMonthlyArchives": len(seeds),
                    "archivePages": len(visited), "capturedArticleBodies": len(all_records) - metadata_only,
                    "metadataOnlyRecords": metadata_only,
                    "selectedBiographyCandidates": len(set(source["selectedBiographyCandidateIds"]) & captured_keys),
                    "wholeLiturgicalYearClaimed": False}
    elif language == "tl":
        crawl = source["crawl"]
        if crawl["publishedTotal"] != len(records) or crawl["publishedPages"] != len(source["collectionPages"]):
            errors.append("published-api-total-mismatch")
        if len(set(keys)) != len(keys):
            errors.append("duplicate-wordpress-post-id")
        if not set(source["selectedBiographyCandidateIds"]).issubset(set(keys)):
            errors.append("selected-biography-id-missing")
        coverage = {"publishedPosts": crawl["publishedTotal"], "collectionPages": len(source["collectionPages"]),
                    "capturedArticleBodies": len(records) - metadata_only, "metadataOnlyRecords": metadata_only,
                    "selectedBiographyCandidates": len(set(source["selectedBiographyCandidateIds"]) & captured_keys),
                    "annualDuplicateGroups": len(source["duplicateGroups"])}
    elif language == "uk":
        if source.get("remainingPaginationURLs"):
            errors.append("published-pagination-not-exhausted")
        coverage = {"indexPages": len(source["indexPages"]), "descriptionCoverage": source.get("coverage"),
                    "wholeLiturgicalYearClaimed": source.get("wholeLiturgicalYearClaimed", False),
                    "fullPageAudits": len(source.get("fullPageAudits", []))}
        published = set(source.get("discovery", {}).get("publishedArticleURLs", []))
        if published and published != {r["sourceURL"] for r in all_records}:
            errors.append("published-ukrainian-article-links-unaccounted")
        if source.get("unfetchedArticleURLs"):
            errors.append("published-ukrainian-article-links-unfetched")
    factual = []
    for record in all_records:
        prose, _ = source_prose(record, language)
        if language == "ru" and record.get("articleId") == "3889" and "19897" in (prose or ""):
            factual.append({"record": "3889", "sourceURL": record["sourceURL"], "sourceLiteral": "19897",
                "finding": "Thérèse's death year is malformed. The Holy See gives 30 September 1897.",
                "corroboratingSourceURL": THERESE, "decision": "Hold affected source passage; retain original text."})
        if language == "ru" and record.get("articleId") == "3889" and "Папа Иоанн Павел Ш" in (prose or ""):
            factual.append({"record": "3889", "sourceURL": record["sourceURL"], "sourceLiteral": "Папа Иоанн Павел Ш",
                "finding": "The pontiff suffix is printed as Cyrillic Ш. The checked Doctor of the Church letter is by John Paul II.",
                "corroboratingSourceURL": THERESE, "decision": "Hold malformed source suffix; retain original text."})
        if (language == "ar" and record.get("sourceSubjectID") == "006312a1-9f6c-46af-bbad-394664a3a656"
                and "22 آب عام 1535" in (prose or "")):
            factual.append({"record": record_key(record), "sourceURL": record["sourceURL"],
                "sourceLiteral": "22 آب عام 1535", "finding": "John Fisher's execution is given as 22 August 1535. Vatican News gives 22 June 1535.",
                "corroboratingSourceURL": FISHER, "verifiedAt": "2026-10-03",
                "decision": "Hold affected source passage; retain original Arabic text without a silent correction."})
        for finding in record.get("review", {}).get("findings", []):
            factual.append({"record": record_key(record), "sourceURL": record["sourceURL"], **finding})
    full_page_checks = []
    for page in source.get("fullPageAudits", []):
        matches = digest("\n".join(page.get("paragraphs", page.get("sourceParagraphs", [])))) == page["sourceTextSHA256"]
        if not matches:
            errors.append("full-page-audit-prose-digest-mismatch:" + page["sourceURL"])
        if page.get("feedBodyMatchesFullPage") is False:
            errors.append("full-page-audit-feed-prose-differs:" + page["sourceURL"])
        full_page_checks.append({"sourceURL": page["sourceURL"], "title": page.get("title"),
            "proseDigestVerified": matches, "sourceTextSHA256": page["sourceTextSHA256"],
            "feedBodyMatchesFullPage": page.get("feedBodyMatchesFullPage"),
            "categoryExcerptMatchesSourcePrefix": page.get("excerptIsSourcePrefixAfterWhitespace"),
            "sourceFactReview": page.get("sourceFactReview", [])})
        for finding in page.get("sourceFactReview", []):
            factual.append({"sourceURL": page["sourceURL"], **finding})
    manual = [entry for entry in (editorial_reviews or []) if entry["catalogue"] == path.name]
    for entry in manual:
        record = next((record for record in all_records if record_key(record) == entry["record"]), None)
        if (record is None or record["sourceURL"] != entry["sourceURL"] or
                record["sourceTextSHA256"] != entry["sourceTextSHA256"] or
                editorial_record_fingerprint(record) != entry.get("sourceRecordSHA256")):
            errors.append("editorial-review-source-changed:" + entry["record"])
        factual.extend({"record": entry["record"], "sourceURL": entry["sourceURL"], **finding}
                       for finding in entry.get("confirmedEditorialFindings", []))
    record_errors = [error for error in errors if error.startswith(("source-prose-digest", "source-html-digest", "visible-source-prose-differs",
                    "biography-digest", "invalid-source-url", "duplicate-source-record", "full-page-audit"))]
    return {"language": language, "catalogue": path.name, "sourceSnapshotSHA256": digest(raw),
        "crawlComplete": complete, "integrityReviewPassed": not errors, "coverage": coverage,
        "availableRecordIntegrityPassed": not record_errors,
        "counts": {"records": len(records), "quarantinedAttempts": len(quarantine), "excluded": len(excluded),
                   "recordsWithPreservedProse": nonempty_prose,
                   "proseDigestsVerified": verified, "partialOrMetadataOnlyEvidence": len(partial),
                   "independentRawHTMLProseAudits": raw_prose_audited,
                   "recordsWithLiteralCreditCandidates": credit_count},
        "contentShapes": dict(shapes), "genreCandidates": dict(genre), "sourceIssueCounts": dict(issues),
        "sourceWarnings": warnings, "confirmedEditorialFindings": factual,
        "representativeEditorialReviews": manual, "sourceManualReviewSummary": source.get("manualReviewSummary"),
        "representativeFullPageChecks": full_page_checks,
        "partialEvidence": partial, "integrityErrors": errors, "availableRecordIntegrityErrors": record_errors,
        "historicalReview": "Representative source findings only; every assertion is not certified.",
        "calendarIdentityMapping": "unassigned", "nativeImport": False, "reuseApproval": False}


def evangelizo_availability_review(path: Path) -> dict:
    """Audit real registry/probe bytes separately from annual biography coverage."""
    raw = path.read_bytes()
    source = json.loads(raw)
    registry = source["registry"]
    parsed = json.loads(registry["originalResponseJSON"])
    languages = parsed["data"]
    editions = [edition for language in languages for edition in language["versions"]]
    errors = []
    if digest(registry["originalResponseJSON"]) != registry["sourceResponseSHA256"]:
        errors.append("evangelizo-registry-response-digest-mismatch")
    if len(languages) != registry["sourceLanguageCount"] or len(editions) != registry["sourceEditionCount"]:
        errors.append("evangelizo-registry-published-count-mismatch")
    if registry["responseStatus"] != 200 or source["completed"] is not True:
        errors.append("evangelizo-availability-investigation-incomplete")
    aliases_by_language = {"tl": {"tl", "fil", "tag"}, "uk": {"uk", "ukr"}}
    for request in source["requestedLanguageAvailability"]:
        aliases = aliases_by_language.get(request["requestedLanguage"], set())
        matching = [edition["code"] for language in languages for edition in language["versions"]
                    if language["code"].lower() in aliases or edition["code"].lower() in aliases]
        expected_status = "listed-in-current-published-registry" if matching else "not-listed-in-current-published-registry"
        if not aliases or request["status"] != expected_status:
            errors.append("evangelizo-language-absence-disagrees-with-registry")
        if request["matchingPublishedEditions"] != matching:
            errors.append("evangelizo-matching-editions-disagree-with-registry")
    for response in source["responses"]:
        if digest(response["originalResponseJSON"]) != response["sourceResponseSHA256"]:
            errors.append("evangelizo-probe-response-digest-mismatch:" + response["sourceURL"])
    for probe in source["russian"]["probes"]:
        response = next((r for r in source["responses"] if r["sourceURL"] == probe["sourceURL"]), None)
        obj = json.loads(response["originalResponseJSON"]) if response else None
        if obj is None or len(obj["data"]) != probe["returnedCount"] or obj["pagination"]["total"] != probe["reportedTotal"]:
            errors.append("evangelizo-russian-probe-summary-disagrees-with-source")
    usable_samples = 0
    sample_urls = set()
    for sample in source["russian"]["linkedBiographySamples"]:
        url = sample.get("sourceURL")
        response = next((r for r in source["responses"] if r["sourceURL"] == url), None)
        obj = json.loads(response["originalResponseJSON"]) if response else None
        data = obj.get("data", {}) if obj else {}
        bio = data.get("bio") if isinstance(data, dict) else None
        if (url in sample_urls or not isinstance(url, str) or not urlsplit(url).path.startswith("/RU/saints/")
                or not isinstance(bio, str) or not demonstrably_russian_biography(bio)):
            errors.append("evangelizo-russian-biography-sample-without-source-evidence")
        else:
            usable_samples += 1
        sample_urls.add(url)
    if usable_samples != source["russian"]["usableRussianBiographySampleCount"]:
        errors.append("evangelizo-russian-biography-sample-count-mismatch")
    return {"file": path.name, "sourceSnapshotSHA256": digest(raw), "integrityReviewPassed": not errors,
        "errors": errors, "publishedLanguageCodes": [language["code"] for language in languages],
        "publishedLanguageCount": len(languages), "publishedEditionCount": len(editions),
        "requestedLanguageAvailability": source["requestedLanguageAvailability"],
        "russian": {"probes": source["russian"]["probes"], "usableRussianBiographySampleCount": usable_samples,
                    "interpretation": source["russian"]["interpretation"]},
        "registrySourceURL": registry["sourceURL"], "scope": source["scope"],
        "calendarIdentityMapping": "unassigned", "nativeImport": False}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source-dir", type=Path, default=TOOLS / "sources")
    parser.add_argument("--output", type=Path, default=TOOLS / "sources/saint-source-review.json")
    args = parser.parse_args()
    editorial_path = args.source_dir / "saint-source-editorial-review.json"
    editorial = json.loads(editorial_path.read_text())["reviews"] if editorial_path.exists() else []
    reports = []
    for language, filename in CATALOGUES.items():
        path = args.source_dir / filename
        try:
            reports.append(review_catalogue(language, path, editorial))
        except (OSError, ValueError, KeyError, TypeError) as error:
            reports.append({"language": language, "catalogue": filename, "integrityReviewPassed": False,
                            "integrityErrors": [str(error)]})
    supplemental = []
    for language, filename in [("uk", "credo-saints-uk.json"), ("tl", "opp-blogger-saints-tl.json"),
                               ("tl", "tvmaria-saints-tl.json")]:
        path = args.source_dir / filename
        if path.exists():
            try:
                supplemental.append(review_catalogue(language, path, editorial))
            except (OSError, ValueError, KeyError, TypeError) as error:
                supplemental.append({"language": language, "catalogue": path.name, "integrityReviewPassed": False,
                                     "integrityErrors": [str(error)]})
    all_reports = [*reports, *supplemental]
    independent = independent_snapshot_review(args.source_dir)
    availability_path = args.source_dir / "evangelizo-language-availability.json"
    availability = None
    if availability_path.exists():
        try:
            availability = evangelizo_availability_review(availability_path)
        except (OSError, ValueError, KeyError, TypeError) as error:
            availability = {"file": availability_path.name, "integrityReviewPassed": False, "errors": [str(error)]}
    passed = (all(report["integrityReviewPassed"] for report in all_reports) and not independent["errors"]
              and (availability is None or availability["integrityReviewPassed"]))
    output = {"schemaVersion": 1, "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
        "allSourceCrawlsComplete": all(report.get("crawlComplete") is True for report in all_reports),
        "integrityReviewPassed": passed,
        "availableRecordIntegrityPassed": all(report.get("availableRecordIntegrityPassed") is True for report in all_reports),
        "scope": "Collection completeness, literal prose digests, source metadata and representative editorial findings",
        "nativeImport": False, "calendarDatesChanged": False, "reuseApproval": False,
        "languages": reports, "supplementalCatalogues": supplemental, "independentAuditProvenance": independent,
        "evangelizoAvailability": availability}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for report in all_reports:
        print(report["language"], report["catalogue"], "passed" if report["integrityReviewPassed"] else "needs attention",
              report.get("counts", {}), report["integrityErrors"])
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
