#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep source differences visible when Wikisource is used to review Hebrew OCR."""
import unittest

from hebrew_ocr_baseline import align, compare, tokens


class HebrewOCRBaselineTests(unittest.TestCase):
    def test_niqqud_and_punctuation_do_not_change_consonantal_comparison(self):
        self.assertEqual(tokens("כִּי־טוֹב: לְעוֹלָם!"), ["כי", "טוב", "לעולם"])
        self.assertEqual(compare("כִּי־טוֹב", "כי טוב", "same-translation")["wordOperations"]["equal"], 2)

    def test_source_spelling_and_ocr_noise_remain_observable(self):
        result = compare("ירושלם מלך", "ירושלים מלכ ABC 123", "same-translation")
        self.assertEqual(result["observedWords"], 4)
        self.assertEqual(result["wordOperations"]["equal"], 0)
        self.assertNotIn("consonantalWordErrorRate", result)
        self.assertFalse(result["productionEligible"])

    def test_other_translation_cannot_be_an_ocr_accuracy_standard(self):
        result = compare("שופטי הארץ אהבו צדק", "שופטי ארץ אהבו צדק", "related-translation", "scan-checked")
        self.assertEqual(result["wordOperations"], {"equal": 3, "replace": 1, "delete": 0, "insert": 0})
        self.assertNotIn("consonantalWordErrorRate", result)
        exact = compare("שופטי הארץ אהבו צדק", "שופטי ארץ אהבו צדק", "same-translation", "scan-checked")
        self.assertEqual(exact["consonantalWordErrorRate"], .25)

    def test_omissions_and_insertions_cannot_disappear_in_alignment(self):
        expected = tokens("כי טוב לעולם חסדו")
        observed = tokens("כי טוב מאד חסדו")
        segments = align(expected, observed)
        self.assertEqual([word for part in segments for word in part["reference"]], expected)
        self.assertEqual([word for part in segments for word in part["observed"]], observed)
        for part in segments:
            self.assertEqual(expected[part["referenceStart"]:part["referenceEnd"]], part["reference"])
            self.assertEqual(observed[part["observedStart"]:part["observedEnd"]], part["observed"])
        self.assertEqual(align(["א", "ב", "ג"], ["א", "ג"])[1]["kind"], "delete")
        self.assertEqual(align(["א", "ג"], ["א", "ב", "ג"])[1]["kind"], "insert")

    def test_empty_excerpts_are_not_reported_as_matching(self):
        with self.assertRaises(ValueError):
            compare("...", "טקסט", "same-translation")


if __name__ == "__main__":
    unittest.main()
