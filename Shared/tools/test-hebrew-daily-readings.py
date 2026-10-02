#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Synthetic boundary-gate tests; fixtures cannot approve real Scripture mappings."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from hebrew_daily_readings import Resolver, Unavailable, digest, load_reviews

KEY = "daily|Daniel 13:12–14"


class HebrewDailyTests(unittest.TestCase):
    def setUp(self):
        self.note = {"id": "word-dot", "kind": "unreadablePoint", "anchor": "קּ", "occurrence": 1,
            "letterIndex": 1, "mark": "vowel", "sourcePages": [1], "sourceURL": "https://example.org/scan#page=1"}
        self.book = {"book": "SUS", "title": "מקור לדוגמה", "attribution": "Synthetic source credit",
            "sourceURL": "https://example.org/edition", "review": {"status": "complete"}, "chapters": [
                {"number": 1, "isComplete": False, "verses": [
                    {"verse": 12, "endVerse": 13, "text": "קּ התחלה", "sourceNotes": [self.note]},
                    {"verse": 14, "text": "סוף"}, {"verse": 15, "text": "נוסף"}]}]}
        self.review = {"status": "complete", "contexts": ["roman1962"], "sourceBook": "SUS",
            "sourceContentSHA256": digest(self.book), "selections": [{"chapter": 1, "verse": 12}, {"chapter": 1, "verse": 14}],
            "includesWholeVerses": False, "openingText": "קּ", "closingText": "סוף", "method": "Synthetic endpoint review",
            "evidence": [{"path": "evidence.json", "sha256": hashlib.sha256(b"fixture evidence").hexdigest()}],
            "excludedSourceBlocks": []}

    def resolver(self):
        return Resolver([self.book], {KEY: self.review})

    def repin(self):
        self.review["sourceContentSHA256"] = digest(self.book)

    def test_redirect_credit_partial_source_and_whole_units_survive(self):
        original = copy.deepcopy(self.book)
        passage = self.resolver().resolve(KEY, {"roman1962"})
        self.assertEqual(passage.source["book"], "SUS")
        self.assertEqual(passage.source["name"], self.book["title"])
        self.assertEqual(passage.source["attribution"], self.book["attribution"])
        self.assertFalse(passage.source["isComplete"])
        self.assertEqual([row["verse"] for row in passage.verses], [12, 14])
        self.assertEqual(passage.verses[0]["endVerse"], 13)
        self.assertEqual(passage.verses[0]["sourceNotes"], [self.note])
        self.assertTrue(passage.includes_whole_verses)
        self.assertEqual([row["verse"] for row in passage.source["contentBlocks"]], [12, 14])
        self.assertEqual(self.book, original)

    def test_citation_reordering_is_not_sorted_back_to_source_numbers(self):
        self.review.update(selections=[{"chapter": 1, "verse": 15}, {"chapter": 1, "verse": 12}],
                           openingText="נוסף", closingText="התחלה")
        passage = self.resolver().resolve(KEY, {"roman1962"})
        self.assertEqual([row["verse"] for row in passage.verses], [15, 12])
        self.assertEqual([row["verse"] for row in passage.source["contentBlocks"]], [15, 12])

    def test_unreviewed_citations_and_contexts_never_use_number_equality(self):
        subject = self.resolver()
        self.assertTrue(subject.handles("daily|Wisdom 1:1", "WIS"))
        self.assertTrue(subject.handles(KEY, "DAN"))
        self.assertFalse(subject.handles("daily|Daniel 7:1", "DAN"))
        for key, contexts in [(KEY, set()), (KEY, {"roman"}), (KEY, {"roman1962", "syriac"}),
                              (KEY.replace("12", "13"), {"roman1962"})]:
            with self.subTest(key=key, contexts=contexts), self.assertRaises(Unavailable):
                subject.resolve(key, contexts)
        self.review["status"] = "pending"
        with self.assertRaises(Unavailable):
            self.resolver().resolve(KEY, {"roman1962"})

    def test_closed_all_book_gate_and_stale_source_cannot_emit(self):
        with self.assertRaisesRegex(Unavailable, "not complete"):
            Resolver([], {KEY: self.review}).resolve(KEY, {"roman1962"})
        self.book["chapters"][0]["verses"][0]["text"] += " changed"
        with self.assertRaisesRegex(ValueError, "source changed"):
            self.resolver().resolve(KEY, {"roman1962"})

    def test_reviewed_recension_gap_stays_unavailable_and_requires_current_evidence(self):
        self.review = {key: value for key, value in self.review.items()
                       if key in {"contexts", "sourceBook", "sourceContentSHA256", "method", "evidence"}}
        self.review.update(status="unavailable", reason="The printed source lacks an appointed clause")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "evidence.json").write_bytes(b"fixture evidence")
            path = root / "reviews.json"
            path.write_text(json.dumps({"schemaVersion": 1, "appointments": {KEY: self.review}}))
            reviews = load_reviews(path, root=root)
            with self.assertRaisesRegex(Unavailable, "lacks an appointed clause"):
                Resolver([self.book], reviews).resolve(KEY, {"roman1962"})
            self.book["chapters"][0]["verses"][0]["text"] += " changed"
            with self.assertRaisesRegex(ValueError, "source changed"):
                Resolver([self.book], reviews).resolve(KEY, {"roman1962"})
            (root / "evidence.json").write_bytes(b"changed")
            with self.assertRaisesRegex(ValueError, "evidence changed"):
                load_reviews(path, root=root)

    def test_ranges_cannot_be_sliced_and_units_cannot_be_duplicated(self):
        for selections in [[{"chapter": 1, "verse": 13}], [{"chapter": 1, "verse": 12}] * 2]:
            with self.subTest(selections=selections), self.assertRaises(ValueError):
                self.review["selections"] = selections
                self.resolver().resolve(KEY, {"roman1962"})

    def structured(self):
        witness = {"id": "alternative", "kind": "witness", "printedLabel": "12א", "text": "ו",
            "addresses": [{"chapter": 1, "verse": 12}], "sourcePages": [1],
            "textSHA256": hashlib.sha256("ו".encode()).hexdigest(), "sourceNotes": [
                {**self.note, "id": "block-dot", "anchor": "ו", "mark": "shuruq"}]}
        self.book["chapters"][0]["contentBlocks"] = [
            {"id": "first", "kind": "verse", "chapter": 1, "verse": 12, "printedLabel": "יב–יג"},
            witness, {"id": "last", "kind": "verse", "chapter": 1, "verse": 14},
            {"id": "more", "kind": "verse", "chapter": 1, "verse": 15}]
        self.repin()

    def test_whole_witness_and_its_notes_keep_exact_display_position(self):
        self.structured()
        self.review["selections"].insert(1, {"blockId": "alternative"})
        passage = self.resolver().resolve(KEY, {"roman1962"})
        self.assertEqual([block["id"] for block in passage.source["contentBlocks"]], ["first", "alternative", "last"])
        witness = passage.source["contentBlocks"][1]
        self.assertEqual(witness["sourceNotes"][0]["mark"], "shuruq")
        self.assertNotIn("sourcePages", witness)
        self.assertNotIn("textSHA256", witness)
        self.assertEqual(len(passage.verses), 2)  # No invented verse for the witness.

    def test_skipped_scripture_blocks_need_exact_exclusion_evidence(self):
        self.structured()
        with self.assertRaisesRegex(ValueError, "exact reviewed exclusions"):
            self.resolver().resolve(KEY, {"roman1962"})
        self.review["excludedSourceBlocks"] = [{"blockId": "alternative", "reason": "Synthetic distinct witness not appointed"}]
        self.resolver().resolve(KEY, {"roman1962"})
        self.review["excludedSourceBlocks"].append({"blockId": "unrelated", "reason": "Not in this passage"})
        with self.assertRaisesRegex(ValueError, "exact reviewed exclusions"):
            self.resolver().resolve(KEY, {"roman1962"})

    def test_reordered_witness_is_selected_not_excluded(self):
        self.structured()
        self.review["selections"].append({"blockId": "alternative"})
        self.review["closingText"] = "ו"
        passage = self.resolver().resolve(KEY, {"roman1962"})
        self.assertEqual([block["id"] for block in passage.source["contentBlocks"]],
                         ["first", "last", "alternative"])
        self.assertEqual(passage.source["contentBlocks"][-1]["sourceNotes"][0]["id"], "block-dot")
        self.review["excludedSourceBlocks"] = [{"blockId": "alternative", "reason": "Already selected"}]
        with self.assertRaisesRegex(ValueError, "exact reviewed exclusions"):
            self.resolver().resolve(KEY, {"roman1962"})

    def test_changed_endpoint_or_invalid_note_does_not_shorten_passage(self):
        self.review["closingText"] = "wrong ending"
        with self.assertRaisesRegex(ValueError, "opening or closing"):
            self.resolver().resolve(KEY, {"roman1962"})
        self.review["closingText"] = "סוף"
        self.note["anchor"] = "not in source"
        self.repin()
        with self.assertRaises(ValueError):
            self.resolver().resolve(KEY, {"roman1962"})

    def test_evidence_pins_and_manifest_shape_are_strict(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            evidence = root / "evidence.json"
            evidence.write_bytes(b"fixture evidence")
            path = root / "reviews.json"
            data = {"schemaVersion": 1, "appointments": {KEY: self.review}}
            path.write_text(json.dumps(data))
            self.assertEqual(load_reviews(path, root=root)[KEY], self.review)
            for malformed in [None, "complete", []]:
                path.write_text(json.dumps({"schemaVersion": 1, "appointments": {KEY: malformed}}))
                with self.assertRaisesRegex(ValueError, "must be an object"):
                    load_reviews(path, root=root)
            bad_path = copy.deepcopy(data)
            bad_path["appointments"][KEY]["evidence"][0]["path"] = None
            path.write_text(json.dumps(bad_path))
            with self.assertRaisesRegex(ValueError, "evidence path"):
                load_reviews(path, root=root)
            path.write_text(json.dumps(data))
            evidence.write_bytes(b"changed source review")
            with self.assertRaisesRegex(ValueError, "evidence changed"):
                load_reviews(path, root=root)
            evidence.write_bytes(b"fixture evidence")
            self.review["selections"][0]["verseEnd"] = 13
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, "unknown fields"):
                load_reviews(path, root=root)

    def test_real_manifest_is_valid_without_approving_pending_reviews(self):
        reviews = load_reviews()
        self.assertGreaterEqual(len(reviews), 30)
        for key, review in reviews.items():
            if review["status"] == "pending":
                with self.assertRaises(Unavailable):
                    Resolver([], reviews).resolve(key, set(review["contexts"]))

    def test_mapping_audit_rejects_lost_text_notes_and_source_credit(self):
        spec = importlib.util.spec_from_file_location("hebrew_daily_audit", Path(__file__).with_name("audit-reading-mappings.py"))
        audit = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(audit)
        expected = self.resolver().resolve(KEY, {"roman1962"})
        data = {"passages": {KEY: {"masoretic-delitzsch": expected.verses}},
                "wholeVersePassages": [KEY], "passageSources": {KEY: {"masoretic-delitzsch": expected.source}}}
        with mock.patch.object(audit, "default_resolver", return_value=self.resolver()):
            result = audit.audit_hebrew_supplements(data, {KEY: {"roman1962"}})
            self.assertEqual(result["reviewedHebrewAppointments"], 1)
            for defect in ("text", "notes", "credit", "notice", "missingDescriptor", "boolChapter", "numericCompleteness"):
                changed = copy.deepcopy(data)
                if defect == "text": changed["passages"][KEY]["masoretic-delitzsch"][0]["text"] += " changed"
                elif defect == "notes": changed["passages"][KEY]["masoretic-delitzsch"][0].pop("sourceNotes")
                elif defect == "credit": changed["passageSources"][KEY]["masoretic-delitzsch"]["attribution"] = "Base credit"
                elif defect == "notice": changed["wholeVersePassages"] = []
                elif defect == "boolChapter": changed["passages"][KEY]["masoretic-delitzsch"][0]["chapter"] = True
                elif defect == "numericCompleteness": changed["passageSources"][KEY]["masoretic-delitzsch"]["isComplete"] = 0
                else: changed.pop("passageSources")
                with self.subTest(defect=defect), self.assertRaises(ValueError):
                    audit.audit_hebrew_supplements(changed, {KEY: {"roman1962"}})
            with self.assertRaisesRegex(ValueError, "Unavailable Hebrew"):
                audit.audit_hebrew_supplements(data, {KEY: {"roman"}})

    def test_daily_builder_routes_before_generic_mapping_and_emits_source_descriptor(self):
        spec = importlib.util.spec_from_file_location("hebrew_daily_builder", Path(__file__).with_name("build-reading-texts.py"))
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        edition = {"id": "masoretic-delitzsch", "languageCode": "he", "name": "Fixture Bible",
                   "attribution": "Base credit", "sourceURL": "https://example.org/base"}
        with mock.patch("hebrew_daily_readings.default_resolver", return_value=self.resolver()), \
             mock.patch.object(builder, "load_pinned_corpora", return_value=({"editions": [edition]}, {edition["id"]: {}})), \
             mock.patch.object(builder, "appointments", return_value={KEY: {"roman1962"}}):
            output = builder.build()
        data = json.loads(output["readings-texts.json"])
        self.assertEqual(data["passageSources"][KEY][edition["id"]]["book"], "SUS")
        self.assertEqual(data["passages"][KEY][edition["id"]][0]["endVerse"], 13)
        self.assertIn(KEY, data["wholeVersePassages"])
        self.assertEqual(data["editions"][0]["attribution"], "Base credit")


if __name__ == "__main__":
    unittest.main()
