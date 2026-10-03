#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["scrapy>=2.13,<3"]
# ///
"""Offline verification of Tagalog source boundaries, dates, prose and editions."""
from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

SCRIPT = Path(__file__).with_name("scrape-tagalog-saints.py")
SPEC = importlib.util.spec_from_file_location("tagalog_saints_scraper", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
scraper = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = scraper
SPEC.loader.exec_module(scraper)

TAGALOG = ("Si Santo Halimbawa ay naging isang banal na pari sa kanyang bayan. "
           "Noong bata siya ay mahal niya ang Diyos at ang mga taong walang tahanan. "
           "Dahil sa kanyang pananampalataya naging mabuti ang kanyang gawain para sa lahat ng tao.")


def post(body=TAGALOG, *, identity=42, title="SAINTS OF OCTOBER: SANTO HALIMBAWA", date="2026-09-29T12:00:00", rendered=None):
    rendered = rendered if rendered is not None else f"""
      <p>KAPISTAHAN: OKTUBRE 1</p><h3>A. KUWENTO NG BUHAY</h3>
      <p>{body}</p><p>Narito ang isa sa mga awiting nabuo para sa santo:</p>
      <p>HALIMBAWA, MARTIR</p><p>Refrain:</p><p>Mga lirikong dapat manatiling hiwalay.</p>
      <h3>B. HAMON SA BUHAY</h3><p>Pagninilay ng may-akda.</p>
      <h3>K. KATAGA NG BUHAY</h3><p>Salmo 1:1</p>
      <p>(from the book “Isang Sulyap sa mga Santo” by Fr. RMarcos)</p>
      <p><img src="https://example.org/image.jpg" alt="Never claim image alt as source prose"></p>
      <script>Never include script text.</script>
      <div class="sfsiaftrpstwpr">Share on Facebook</div><div class="post-views">Total Views: 30</div>
      """
    return {"id": identity, "link": f"https://www.ourparishpriest.com/2026/09/halimbawa-{identity}/",
            "date": date, "modified": date, "title": {"rendered": title},
            "content": {"rendered": rendered, "protected": False}, "categories": [5]}


class TagalogSaintTests(unittest.TestCase):
    def extract(self, **kwargs):
        return scraper.extract_post(post(**kwargs), scraper.api_url(5), "a" * 64)

    def test_robots_challenge_or_unknown_response_never_authorizes_collection(self):
        for body, status, content_type in ((b"<html>Checking your browser</html>", 200, "text/html"),
                (b"Upstream unavailable", 200, "text/plain"), (b"Denied", 403, "text/plain")):
            with self.assertRaises(ValueError):
                scraper.source_robots(body, status, content_type)

    def test_actual_robots_rules_and_published_delay_apply_to_api(self):
        policy = scraper.source_robots(b"User-agent: *\nDisallow: /wp-json/\nCrawl-delay: 7\n", 200, "text/plain")
        self.assertTrue(policy.can_fetch(scraper.INDEX, scraper.USER_AGENT))
        self.assertFalse(policy.can_fetch(scraper.api_url(5), scraper.USER_AGENT))
        self.assertEqual(policy.crawl_delay(scraper.USER_AGENT), 7)

    def test_only_real_missing_or_empty_robots_has_allow_all_semantics(self):
        for body, status in ((b"", 200), (b"Not found", 404)):
            policy = scraper.source_robots(body, status, "text/plain")
            self.assertTrue(policy.can_fetch(scraper.api_url(5), scraper.USER_AGENT))

    def test_canonical_scope_rejects_media_queries_login_credentials_and_foreign_hosts(self):
        for value in ("https://example.org/2026/09/saint/", "https://user:secret@www.ourparishpriest.com/2026/09/saint/",
                      "https://www.ourparishpriest.com.evil.example/2026/09/saint/", "javascript:alert(1)",
                      "https://www.ourparishpriest.com/wp-admin/", "https://www.ourparishpriest.com/wp-content/a.jpg",
                      "https://www.ourparishpriest.com/2026/09/saint/?download=1", "https://www.ourparishpriest.com/2026/09/saint/#part",
                      "https://www.ourparishpriest.com:443/2026/09/saint/"):
            with self.subTest(value=value):
                self.assertIsNone(scraper.source_url(value))
        self.assertEqual(scraper.source_url("/2026/09/saint/"), "https://www.ourparishpriest.com/2026/09/saint/")

    def test_api_scope_has_only_published_category_fields_and_bounded_pagination(self):
        url = scraper.api_url(5, 2)
        self.assertTrue(scraper.allowed_api_url(url, 5))
        self.assertFalse(scraper.allowed_api_url(url, 6))
        for suffix in ("&context=edit", "&page=3", "&password=x", "#fragment"):
            self.assertFalse(scraper.allowed_api_url(url + suffix, 5))
        self.assertFalse(scraper.allowed_api_url(url.replace("page=2", "page=0"), 5))
        self.assertFalse(scraper.allowed_api_url(url.replace("per_page=100", "per_page=200"), 5))

    def test_biography_separates_song_reflection_scripture_without_losing_source(self):
        record = self.extract()
        self.assertEqual(record["sections"]["biography"], [TAGALOG])
        self.assertTrue(any("Refrain" in line for line in record["sections"]["songsOrPrayers"]))
        self.assertEqual(record["sections"]["reflection"], ["Pagninilay ng may-akda."])
        self.assertIn("Salmo 1:1", record["sections"]["scriptureOrPrayerEnding"])
        self.assertIn("Mga lirikong dapat manatiling hiwalay.", record["sourceParagraphs"])
        self.assertNotIn("Never claim image alt as source prose", " ".join(record["sourceParagraphs"]))
        self.assertNotIn("Never include script", " ".join(record["sourceParagraphs"]))
        self.assertNotIn("Share on Facebook", " ".join(record["sourceParagraphs"]))
        self.assertNotIn("Total Views", " ".join(record["sourceParagraphs"]))

    def test_complete_exact_original_html_and_all_credit_lines_retained(self):
        original = post()
        record = scraper.extract_post(original, scraper.api_url(5), "b" * 64)
        self.assertEqual(record["sourceHTML"], original["content"]["rendered"])
        self.assertEqual(record["sourceHTMLSHA256"], scraper.sha256(original["content"]["rendered"]))
        self.assertEqual(record["sourceResponseSHA256"], "b" * 64)
        self.assertEqual(record["literalCredits"], ["(from the book “Isang Sulyap sa mga Santo” by Fr. RMarcos)"])
        self.assertEqual(record["sourceTextSHA256"], scraper.sha256("\n".join(record["sourceParagraphs"])))

    def test_dates_come_from_literal_preamble_not_narrative_publication_or_url(self):
        record = self.extract(body=TAGALOG + " Isinilang siya noong Enero 20, 1870.")
        self.assertEqual([(value["month"], value["day"]) for value in record["sourceFeastLabels"]], [(10, 1)])
        self.assertEqual(record["sourcePublishedAt"], "2026-09-29T12:00:00")
        self.assertEqual(record["sourceFeastLabels"][0]["literal"], "OKTUBRE 1")

    def test_date_validation_rejects_invalid_days_and_keeps_source_glyphs(self):
        labels = scraper.dates_from_labels(["Pebrero 30", "29 ng Pebrero", "SETYEMBRE 28"])
        self.assertEqual([(value["month"], value["day"]) for value in labels], [(2, 29), (9, 28)])
        self.assertEqual(labels[0]["literal"], "29 ng Pebrero")

    def test_english_body_cannot_be_mislabeled_by_filipino_heading_and_menu(self):
        english = "This is an English biography of a saint who was born in a small town and became a priest. " * 8
        record = self.extract(body=english)
        self.assertEqual(record["classification"], "quarantined-source")
        self.assertIn("biography-not-demonstrably-Tagalog", record["review"]["reasons"])
        self.assertFalse(record["languageEvidence"]["tagalogCandidate"])

    def test_real_tagalog_body_is_accepted_without_trusting_html_language(self):
        record = self.extract()
        self.assertTrue(record["languageEvidence"]["tagalogCandidate"])
        self.assertEqual(record["classification"], "Tagalog-biography-review-candidate")
        self.assertEqual(record["review"]["status"], "editorial-and-reuse-review-required")

    def test_unmarked_prayer_or_article_remains_provenance_only(self):
        rendered = "<p>KAPISTAHAN: OKTUBRE 1</p><p>PANALANGIN</p><p>" + TAGALOG + "</p>"
        record = self.extract(rendered=rendered)
        self.assertEqual(record["sections"]["biography"], [])
        self.assertIn(TAGALOG, record["sourceParagraphs"])
        self.assertIn("no-explicit-biography-section", record["review"]["reasons"])

    def test_ambiguous_printed_feast_labels_quarantine_instead_of_selecting_one(self):
        rendered = "<p>ENERO 2 O PEBRERO 3</p><p>A. KUWENTO NG BUHAY</p><p>" + TAGALOG + "</p>"
        record = self.extract(rendered=rendered)
        self.assertIn("missing-or-ambiguous-source-feast-label", record["review"]["reasons"])
        self.assertEqual(len(record["sourceFeastLabels"]), 2)

    def test_embedded_prayer_heading_is_separated_but_a_narrative_prayer_mention_is_not(self):
        rendered = "<p>ENERO 2</p><p>A. KUWENTO NG BUHAY</p><p>" + TAGALOG + "</p>"
        rendered += "<p>Itinuro niya ang panalangin sa mga tao.</p><p>PANALANGIN:</p><p>Mahal na Santo, ipanalangin mo kami.</p>"
        record = self.extract(rendered=rendered)
        self.assertIn("Itinuro niya ang panalangin sa mga tao.", record["sections"]["biography"])
        self.assertIn("Mahal na Santo, ipanalangin mo kami.", record["sections"]["songsOrPrayers"])

    def test_pio_error_is_quarantined_with_vatican_evidence_without_correcting_original(self):
        record = self.extract(title="SAINTS OF SEPTEMBER: SAN PIO NG PIETRELCINA (PADRE PIO), PARI",
            body=TAGALOG + " Namatay si Padre Pio noong 1968. Namatay si Padre Pio noong 1969.")
        self.assertIn("source-factual-error-confirmed-by-Holy-See", record["review"]["reasons"])
        finding = record["review"]["findings"][0]
        self.assertEqual(finding["sourceYears"], ["1968", "1969"])
        self.assertEqual(finding["corroboration"]["deathDate"], "1968-09-23")
        self.assertIn("1969", record["sourceHTML"])
        self.assertIn("1969", " ".join(record["sections"]["biography"]))

    def test_latest_duplicate_edition_selected_and_all_evidence_retained(self):
        first = self.extract(identity=1, date="2024-09-29T12:00:00")
        latest = self.extract(identity=2, date="2026-09-29T12:00:00")
        groups, selected = scraper.group_duplicates([first, latest])
        self.assertEqual(len(groups), 1)
        self.assertEqual(groups[0]["recordIds"], [first["recordId"], latest["recordId"]])
        self.assertEqual(groups[0]["selectedRecordId"], latest["recordId"])
        self.assertEqual(selected, [latest["recordId"]])
        self.assertEqual(groups[0]["differentBiographyHashes"], 1)

    def test_different_saint_titles_or_printed_dates_are_not_synonym_merged(self):
        one = self.extract(identity=1)
        two = self.extract(identity=2, title="SAINTS OF OCTOBER: SANTA HALIMBAWA")
        three = self.extract(identity=3, rendered="<p>OKTUBRE 2</p><p>A. KUWENTO NG BUHAY</p><p>" + TAGALOG + "</p>")
        groups, selected = scraper.group_duplicates([one, two, three])
        self.assertEqual(groups, [])
        self.assertEqual(len(selected), 3)

    def test_latest_faulty_edition_cannot_replace_valid_earlier_candidate(self):
        valid = self.extract(identity=1, date="2024-09-29T12:00:00")
        faulty = self.extract(identity=2, date="2026-09-29T12:00:00", body="This is entirely English source prose. " * 20)
        groups, selected = scraper.group_duplicates([valid, faulty])
        self.assertEqual(selected, [valid["recordId"]])
        self.assertEqual(groups[0]["selectedRecordId"], valid["recordId"])

    def test_offline_reextraction_keeps_literal_title_review_and_metadata_only_status(self):
        body = self.extract(title="SANTO &lt;HALIMBAWA&gt; &amp; KASAMA")
        body["manualSourceReview"] = {"decision": "source-only review"}
        metadata = self.extract(identity=99)
        metadata["sourceCapture"] = {"contentCaptured": False}
        metadata["sourceHTML"] = ""
        metadata["classification"] = "source-index-metadata-only"
        metadata["review"] = {"status": "source-body-not-captured", "reasons": ["source-body-not-captured"], "findings": []}
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "source.json"
            path.write_text(json.dumps({"records": [body, metadata], "crawl": {}}))
            scraper.review_existing(path)
            result = json.loads(path.read_text())["records"]
        self.assertEqual(result[0]["sourceTitle"], "SANTO <HALIMBAWA> & KASAMA")
        self.assertEqual(result[0]["manualSourceReview"], body["manualSourceReview"])
        self.assertEqual(result[1]["classification"], "source-index-metadata-only")
        self.assertFalse(result[1]["sourceCapture"]["contentCaptured"])
        self.assertEqual(result[1]["sections"]["biography"], [])

    def test_catalogue_counts_and_completion_distinguish_blocked_metadata_from_prose(self):
        path = SCRIPT.parent / "sources/tagalog-saints.json"
        if not path.exists():
            self.skipTest("Source catalogue not yet generated")
        value = json.loads(path.read_text(encoding="utf-8"))
        if value["completed"]:
            self.assertEqual(len(value["records"]), value["crawl"]["publishedTotal"])
            self.assertEqual(len(value["collectionPages"]), value["crawl"]["publishedPages"])
            self.assertFalse(value["crawl"]["budgetLimited"])
            self.assertFalse(value["errors"])
        else:
            self.assertTrue(value["errors"] or value["crawl"]["budgetLimited"])
            self.assertLess(len(value["collectionPages"]), value["crawl"]["publishedPages"] or 1)
        self.assertEqual(len(value["records"]), value["crawl"]["recordsPreserved"])
        self.assertEqual(len(value["records"]), len({record["wordPressPostID"] for record in value["records"]}))
        selected = set(value["selectedBiographyCandidateIds"])
        for record in value["records"]:
            self.assertEqual(record["sourceHTMLSHA256"], scraper.sha256(record["sourceHTML"]))
            self.assertEqual(record["sourceTextSHA256"], scraper.sha256("\n".join(record["sourceParagraphs"])))
            self.assertEqual(record["biographyTextSHA256"], scraper.sha256("\n".join(record["sections"]["biography"])))
            self.assertIsNotNone(scraper.source_url(record["sourceURL"]))
            if record.get("sourceCapture", {}).get("contentCaptured") is False:
                self.assertEqual(record["classification"], "source-index-metadata-only")
                self.assertEqual(record["sections"]["biography"], [])
                self.assertNotIn(record["recordId"], selected)
            if "originalResponseHTML" in record:
                self.assertEqual(record["sourceResponseSHA256"], scraper.sha256(record["originalResponseHTML"]))
            if record["recordId"] in selected:
                self.assertEqual(record["classification"], "Tagalog-biography-review-candidate")
                self.assertTrue(record["languageEvidence"]["tagalogCandidate"])
                self.assertEqual(record["review"]["status"], "editorial-and-reuse-review-required")
        for snapshot in value.get("discoverySnapshots", []):
            self.assertEqual(snapshot["sourceResponseSHA256"], scraper.sha256(snapshot["originalResponseJSON"]))
            self.assertEqual(snapshot["postCount"], len(json.loads(snapshot["originalResponseJSON"])))


if __name__ == "__main__":
    unittest.main(verbosity=2)
