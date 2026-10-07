#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Protect the independently witnessed omitted children/olive-plants clause."""
import hashlib
import json
import unittest

from douay_rheims_source_corrections import REVIEW_PATH, apply_source_corrections


class DouaySourceCorrectionTests(unittest.TestCase):
    def setUp(self):
        self.review = json.loads(REVIEW_PATH.read_text())
        self.row = self.review["corrections"][0]
        self.source = {"id": "engDRA", "sha256": self.review["sourceSHA256"]}
        second = self.review["corrections"][1]
        self.original = {("PSA", 127): {3: self.row["originalText"], 4: "Unchanged next verse"},
                         ("PSA", 141): {4: second["originalText"]},
                         ("PSA", 111): {7: self.review["corrections"][2]["originalText"]},
                         ("PSA", 8): {7: "Unchanged works clause"}}

    def test_missing_clause_is_restored_without_altering_source_labels_or_other_rows(self):
        corrected = apply_source_corrections(self.source, self.original)
        self.assertIn("Thy children as olive plants, round about thy table.", corrected["PSA", 127][3])
        self.assertEqual(corrected["PSA", 127][4], self.original["PSA", 127][4])
        self.assertEqual(corrected["PSA", 8], self.original["PSA", 8])
        self.assertNotIn("children", self.original["PSA", 127][3])
        self.assertIn("they have hidden a snare for me", corrected["PSA", 141][4])
        self.assertIn("he shall not fear the evil hearing", corrected["PSA", 111][7])

    def test_primary_and_independent_witnesses_quote_the_identical_full_verse(self):
        self.assertEqual(len(self.row["witnesses"]), 2)
        self.assertIn("drbo.org", self.row["witnesses"][0]["url"])
        self.assertIn("gutenberg.org", self.row["witnesses"][1]["url"])
        for witness in self.row["witnesses"]:
            self.assertEqual(witness["excerpt"], self.row["correctedText"])
        self.assertEqual(hashlib.sha256(self.row["correctedText"].encode()).hexdigest(), self.row["correctedTextSHA256"])

    def test_changed_source_payload_or_changed_original_words_are_rejected(self):
        with self.assertRaisesRegex(ValueError, "revision"):
            apply_source_corrections({"id": "engDRA", "sha256": "0" * 64}, self.original)
        changed = {("PSA", 127): {3: "Different source verse"}}
        with self.assertRaisesRegex(ValueError, "original"):
            apply_source_corrections(self.source, changed)
        self.assertIs(apply_source_corrections({"id": "another-edition"}, self.original), self.original)


if __name__ == "__main__":
    unittest.main()
