#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["lingua-language-detector>=2,<3"]
# ///
"""Regression checks for incomplete collections and altered source evidence."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("saint_source_review", Path(__file__).with_name("review-saint-source-catalogues.py"))
review = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(review)


class SourceReviewTests(unittest.TestCase):
    def tagalog_record(self):
        return {"recordId": "tl-source", "sourceURL": "https://example.org/saint",
            "sourceAtomID": "tag:published-feed-post-1", "sourceLabels": ["SAINT"],
            "sourceCapture": {"contentCaptured": True}, "sourceParagraphs": ["Original biography."],
            "sourceHTML": "<p>Original biography.</p>", "sourceHTMLSHA256": review.digest("<p>Original biography.</p>"),
            "sourceTextSHA256": review.digest("Original biography."), "sections": {"biography": ["Original biography."]},
            "biographyTextSHA256": review.digest("Original biography."), "classification": "Tagalog-biography-review-candidate"}

    def catalogue(self, language="en", *, completed=True):
        url = f"https://www.catholic.co.il/?id=3889&view=article&lang={language}"
        prose = "Source introduction\nSource body 19897"
        return {"completed": completed, "errors": [],
                "indexPages": [{"articleIDs": ["3889"], "articleCount": 1}],
                "crawl": {"discoveredArticles": 1, "naturalPaginationEnd": True},
                "articles": [{"articleId": "3889", "sourceURL": url, "requestURL": url,
                    "introduction": "Source introduction", "paragraphs": ["Source body 19897"],
                    "sourceTextSHA256": review.digest(prose), "indexEntry": {"url": url},
                    "review": {"issues": []}}], "quarantine": []}

    def run_review(self, source, language="en", editorial=None):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "source.json"
            path.write_text(json.dumps(source))
            return review.review_catalogue(language, path, editorial)

    def availability(self):
        registry = json.dumps({"data": [{"code": "en", "versions": [{"code": "AM"}]}]})
        response = json.dumps({"data": [], "pagination": {"total": 0}})
        url = "https://publication.evangelizo.ws/RU/saints?month=10&day=1"
        return {"completed": True, "scope": "Published registry and dated probes",
            "registry": {"originalResponseJSON": registry, "sourceResponseSHA256": review.digest(registry),
                "sourceLanguageCount": 1, "sourceEditionCount": 1, "responseStatus": 200,
                "sourceURL": "https://publication.evangelizo.ws/languages"},
            "requestedLanguageAvailability": [{"requestedLanguage": code,
                "status": "not-listed-in-current-published-registry", "matchingPublishedEditions": []} for code in ["tl", "uk"]],
            "responses": [{"sourceURL": url, "originalResponseJSON": response,
                "sourceResponseSHA256": review.digest(response)}],
            "russian": {"probes": [{"sourceURL": url, "returnedCount": 0, "reportedTotal": 0}],
                "linkedBiographySamples": [], "usableRussianBiographySampleCount": 0,
                "interpretation": "No biographies in sampled dates"}}

    def run_availability(self, source):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / "availability.json"
            path.write_text(json.dumps(source))
            return review.evangelizo_availability_review(path)

    def test_availability_uses_actual_registry_and_probe_bytes(self):
        self.assertTrue(self.run_availability(self.availability())["integrityReviewPassed"])
        source = self.availability()
        source["registry"]["sourceResponseSHA256"] = "stale"
        self.assertIn("evangelizo-registry-response-digest-mismatch", self.run_availability(source)["errors"])

    def test_unlisted_language_claim_cannot_override_published_registry(self):
        source = self.availability()
        raw = json.dumps({"data": [{"code": "fil", "versions": [{"code": "TL"}]}]})
        source["registry"].update(originalResponseJSON=raw, sourceResponseSHA256=review.digest(raw))
        self.assertIn("evangelizo-language-absence-disagrees-with-registry", self.run_availability(source)["errors"])

    def test_russian_probe_summary_must_match_actual_collection(self):
        source = self.availability()
        source["russian"]["probes"][0]["returnedCount"] = 1
        self.assertIn("evangelizo-russian-probe-summary-disagrees-with-source", self.run_availability(source)["errors"])

    def test_russian_biography_count_is_recomputed_from_source_samples(self):
        source = self.availability()
        source["russian"]["usableRussianBiographySampleCount"] = 42
        report = self.run_availability(source)
        self.assertIn("evangelizo-russian-biography-sample-count-mismatch", report["errors"])
        self.assertEqual(report["russian"]["usableRussianBiographySampleCount"], 0)

    def test_language_status_and_matching_editions_are_both_verified(self):
        for altered in [{"status": "listed-in-current-published-registry"}, {"matchingPublishedEditions": ["TL"]}]:
            with self.subTest(altered=altered):
                source = self.availability()
                source["requestedLanguageAvailability"][0].update(altered)
                self.assertFalse(self.run_availability(source)["integrityReviewPassed"])

    def test_russian_endpoint_does_not_make_foreign_prose_a_russian_biography(self):
        for text in [
            "This article describes the life of a saint and the people who knew him. The entire biography is written in English, including its account of his childhood and education.",
            "Цей опис написано українською мовою. Його оригінальне джерело збережено разом із відомостями про життя, навчання та подальшу діяльність згаданої людини. Він не є російським перекладом."]:
            with self.subTest(text=text):
                source = self.availability()
                url = "https://publication.evangelizo.ws/RU/saints/example"
                raw = json.dumps({"data": {"bio": "<p>" + text + "</p>"}})
                source["responses"].append({"sourceURL": url, "originalResponseJSON": raw,
                    "sourceResponseSHA256": review.digest(raw)})
                source["russian"].update(linkedBiographySamples=[{"sourceURL": url}], usableRussianBiographySampleCount=1)
                result = self.run_availability(source)
                self.assertFalse(result["integrityReviewPassed"])
                self.assertEqual(result["russian"]["usableRussianBiographySampleCount"], 0)

    def test_russian_language_check_recognizes_substantial_actual_russian_prose(self):
        self.assertTrue(review.demonstrably_russian_biography(
            "<p>Этот текст написан по-русски. Оригинальное описание подробно рассказывает о жизни человека, его детстве, образовании и дальнейшей деятельности. Все сведения сохранены вместе с указанием источника и датой публикации.</p>"))

    def test_complete_collection_passes(self):
        report = self.run_review(self.catalogue())
        self.assertTrue(report["integrityReviewPassed"])
        self.assertEqual(report["counts"]["proseDigestsVerified"], 1)

    def test_text_mutation_fails_independently_of_crawl_flag(self):
        source = self.catalogue()
        source["articles"][0]["paragraphs"] = ["Changed wording"]
        report = self.run_review(source)
        self.assertFalse(report["availableRecordIntegrityPassed"])
        self.assertIn("source-prose-digest-mismatch:3889", report["integrityErrors"])

    def test_missing_published_id_fails(self):
        source = self.catalogue()
        source["indexPages"][0]["articleIDs"].append("9999")
        source["crawl"]["discoveredArticles"] = 2
        report = self.run_review(source)
        self.assertIn("unaccounted-published-article-ids", report["integrityErrors"])
        self.assertEqual(report["coverage"]["missingArticleIDs"], ["9999"])

    def test_incomplete_crawl_retains_available_record_result(self):
        report = self.run_review(self.catalogue(completed=False))
        self.assertFalse(report["integrityReviewPassed"])
        self.assertTrue(report["availableRecordIntegrityPassed"])

    def test_source_snapshot_hash_changes_with_metadata(self):
        source = self.catalogue()
        first = self.run_review(source)["sourceSnapshotSHA256"]
        source["generatedAt"] = "new snapshot"
        self.assertNotEqual(first, self.run_review(source)["sourceSnapshotSHA256"])

    def test_confirmed_therese_typo_does_not_correct_source(self):
        source = self.catalogue("ru")
        report = self.run_review(source, "ru")
        self.assertEqual(report["confirmedEditorialFindings"][0]["sourceLiteral"], "19897")
        self.assertIn("19897", source["articles"][0]["paragraphs"][0])

    def test_mixed_hebrew_hash_uses_full_original_prose(self):
        source = self.catalogue("he")
        record = source["articles"].pop()
        record["fullSourceProse"] = {"introduction": record["introduction"], "paragraphs": record["paragraphs"]}
        record["paragraphs"] = ["Hebrew-only subset"]
        record["preservedHebrewProse"] = {"paragraphs": 1}
        source["quarantine"] = [record]
        self.assertTrue(self.run_review(source, "he")["integrityReviewPassed"])

    def test_short_foreign_preview_is_explicitly_partial(self):
        record = {"introduction": "", "paragraphs": [], "preservedHebrewProse": {"paragraphs": 0}}
        prose, explanation = review.source_prose(record, "he")
        self.assertIsNone(prose)
        self.assertIn("cannot be recomputed", explanation)

    def test_non_https_source_fails(self):
        source = self.catalogue()
        source["articles"][0]["sourceURL"] = "http://example.org/source"
        self.assertFalse(self.run_review(source)["availableRecordIntegrityPassed"])

    def test_visible_html_audit_keeps_prose_order_and_ignores_inert_code(self):
        self.assertEqual(review.visible_character_stream("<p>First &amp; second<br>line.</p><script>hidden</script><p>Last.</p>"),
                         "First&secondline.Last.")

    def test_metadata_only_record_is_never_counted_as_a_biography(self):
        prose, explanation = review.source_prose({"sourceCapture": {"contentCaptured": False}}, "tl")
        self.assertIsNone(prose)
        self.assertIn("has not been captured", explanation)

    def test_confirmed_arabic_source_month_error_is_held_verbatim(self):
        subject = "006312a1-9f6c-46af-bbad-394664a3a656"
        text = "حُكم عليه بالموت في 22 آب عام 1535."
        markup = "<p>" + text + "</p>"
        source = {"completed": True, "errors": [], "crawl": {},
            "collections": [{"month": 6, "day": 22, "subjectIDs": [subject], "total": 1}],
            "articles": [{"sourceSubjectID": subject, "sourceURL": "https://publication.evangelizo.ws/AR/saints/" + subject,
                "paragraphs": [text], "sourceTextSHA256": review.digest(text),
                "rawBiographyHTML": markup, "sourceBiographyHTMLSHA256": review.digest(markup)}]}
        report = self.run_review(source, "ar")
        self.assertEqual(report["confirmedEditorialFindings"][0]["sourceLiteral"], "22 آب عام 1535")
        self.assertEqual(source["articles"][0]["paragraphs"], [text])
        self.assertIn("missing-valid-month-day-collection", report["integrityErrors"])

    def test_manual_review_does_not_silently_follow_changed_source_text(self):
        source = self.catalogue()
        entry = {"catalogue": "source.json", "record": "3889", "sourceURL": source["articles"][0]["sourceURL"],
                 "sourceTextSHA256": "stale fingerprint"}
        result = self.run_review(source, editorial=[entry])
        self.assertFalse(result["integrityReviewPassed"])
        self.assertIn("editorial-review-source-changed:3889", result["integrityErrors"])

    def test_independent_audit_is_bound_to_exact_source_snapshot(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            (path / "source.json").write_text("original bytes")
            audit = {"audits": [{"cataloguePath": "Shared/tools/sources/source.json",
                                 "catalogueSHA256": review.digest("original bytes")}]}
            (path / "saint-source-independent-audits.json").write_text(json.dumps(audit))
            self.assertEqual(review.independent_snapshot_review(path)["errors"], [])
            (path / "source.json").write_text("altered bytes")
            self.assertEqual(review.independent_snapshot_review(path)["errors"], ["independent-audit-snapshot-changed:source.json"])

    def test_retry_independent_audit_is_also_bound_to_exact_source_snapshot(self):
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp)
            (path / "saint-source-independent-audits.json").write_text(json.dumps({"audits": []}))
            (path / "retry.json").write_text("source bytes")
            (path / "saint-source-retry-independent-audits.json").write_text(json.dumps({"audits": [
                {"cataloguePath": "Shared/tools/sources/retry.json", "catalogueSHA256": review.digest("source bytes")}]}))
            self.assertEqual(review.independent_snapshot_review(path)["errors"], [])
            (path / "retry.json").write_text("changed source bytes")
            self.assertEqual(review.independent_snapshot_review(path)["errors"], ["independent-audit-snapshot-changed:retry.json"])

    def test_editorial_review_pins_subject_dates_and_credits_beyond_prose(self):
        for metadata in ({"title": "Different saint – 9 December"}, {"credits": [{"text": "Different author"}]},
                         {"sourceDateLabel": "9 December"}):
            with self.subTest(metadata=metadata):
                source = self.catalogue()
                record = source["articles"][0]
                entry = {"catalogue": "source.json", "record": "3889", "sourceURL": record["sourceURL"],
                    "sourceTextSHA256": record["sourceTextSHA256"], "sourceRecordSHA256": review.editorial_record_fingerprint(record)}
                self.assertTrue(self.run_review(source, editorial=[entry])["integrityReviewPassed"])
                record.update(metadata)
                self.assertIn("editorial-review-source-changed:3889", self.run_review(source, editorial=[entry])["integrityErrors"])

    def test_metadata_records_do_not_fill_a_completed_biography_collection(self):
        source = {"completed": True, "errors": [], "crawl": {"publishedTotal": 1, "publishedPages": 1},
            "collectionPages": [{}], "selectedBiographyCandidateIds": [], "duplicateGroups": [],
            "records": [{"recordId": "metadata", "sourceURL": "https://example.org/saint",
                "sourceCapture": {"contentCaptured": False}, "sourceHTML": "", "sourceHTMLSHA256": review.digest(""),
                "sections": {"biography": []}, "biographyTextSHA256": review.digest("")}]}
        result = self.run_review(source, "tl")
        self.assertEqual(result["contentShapes"], {"index-metadata-only": 1})
        self.assertEqual(result["counts"]["recordsWithPreservedProse"], 0)
        self.assertIn("metadata-only-records-in-completed-biography-collection", result["integrityErrors"])

    def test_published_blogger_feed_and_saint_totals_must_both_reconcile(self):
        source = {"completed": True, "records": [self.tagalog_record()], "errors": [],
            "crawl": {"publishedFeedTotal": 1}, "otherFeedEntryMetadata": [],
            "sourcePolicyEvidence": {"homeSaintLabelCounter": ["1"]},
            "feedPages": [{"sourceURL": "https://example.org/feed", "sourceTotal": 1, "startIndex": 1,
                           "entryCount": 1, "nextURL": None}]}
        self.assertTrue(self.run_review(source, "tl")["integrityReviewPassed"])
        source["records"][0]["sourceCapture"]["contentCaptured"] = False
        metadata = self.run_review(source, "tl")
        self.assertIn("metadata-only-records-in-completed-biography-collection", metadata["integrityErrors"])
        self.assertEqual(metadata["coverage"]["capturedArticleBodies"], 0)
        self.assertEqual(metadata["coverage"]["selectedBiographyCandidates"], 0)
        source["records"][0]["sourceCapture"]["contentCaptured"] = True
        source["sourcePolicyEvidence"]["homeSaintLabelCounter"] = ["2"]
        self.assertIn("published-blogger-saint-subset-mismatch", self.run_review(source, "tl")["integrityErrors"])

    def test_published_blogger_feed_unfollowed_next_link_fails(self):
        source = {"completed": True, "records": [self.tagalog_record()], "errors": [],
            "crawl": {"publishedFeedTotal": 1}, "otherFeedEntryMetadata": [],
            "sourcePolicyEvidence": {"homeSaintLabelCounter": ["1"]},
            "feedPages": [{"sourceURL": "https://example.org/feed", "sourceTotal": 1, "startIndex": 1,
                           "entryCount": 1, "nextURL": "https://example.org/feed/next"}]}
        self.assertIn("published-blogger-feed-pagination-not-exhausted", self.run_review(source, "tl")["integrityErrors"])

    def test_monthly_archive_review_requires_every_published_article(self):
        url = "https://example.org/saint"
        archive = "https://example.org/2011/10/"
        source = {"completed": True, "articles": [self.tagalog_record()], "errors": [],
            "crawl": {"naturalPaginationEnd": True}, "selectedBiographyCandidateIds": ["tl-source"],
            "discovery": {"publishedArticleURLs": [url], "archiveSeeds": [{"url": archive}]},
            "indexPages": [{"sourceURL": archive, "posts": [{"url": url}], "pagination": []}],
            "unfetchedArticleURLs": [], "remainingPaginationURLs": []}
        self.assertTrue(self.run_review(source, "tl")["integrityReviewPassed"])
        source["articles"][0]["sourceCapture"]["contentCaptured"] = False
        metadata = self.run_review(source, "tl")
        self.assertIn("metadata-only-records-in-completed-biography-collection", metadata["integrityErrors"])
        self.assertEqual(metadata["coverage"]["capturedArticleBodies"], 0)
        self.assertEqual(metadata["coverage"]["selectedBiographyCandidates"], 0)
        source["discovery"]["publishedArticleURLs"].append("https://example.org/unfetched")
        self.assertIn("published-tvmaria-article-links-unaccounted", self.run_review(source, "tl")["integrityErrors"])

    def test_monthly_archive_review_rejects_unfollowed_published_pagination(self):
        archive = "https://example.org/2011/10/"
        source = {"completed": True, "articles": [], "errors": [],
            "crawl": {"naturalPaginationEnd": True}, "selectedBiographyCandidateIds": [],
            "discovery": {"publishedArticleURLs": [], "archiveSeeds": [{"url": archive}]},
            "indexPages": [{"sourceURL": archive, "posts": [], "pagination": [{"url": archive + "page/2/"}]}],
            "unfetchedArticleURLs": [], "remainingPaginationURLs": []}
        self.assertIn("published-tvmaria-archive-pagination-not-exhausted", self.run_review(source, "tl")["integrityErrors"])


if __name__ == "__main__":
    unittest.main()
