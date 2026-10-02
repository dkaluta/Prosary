# /// script
# requires-python = ">=3.12"
# dependencies = ["beautifulsoup4", "pymupdf"]
# ///
"""Regression checks for source-preserving 1 Maccabees OCR comparison."""
import importlib.util
from pathlib import Path
import sys
import unittest

spec = importlib.util.spec_from_file_location("maccabees_ocr", Path(__file__).with_name("compare-1maccabees-ocr.py"))
module = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = module
spec.loader.exec_module(module)


class BaselineTests(unittest.TestCase):
    def test_pointing_punctuation_ignored_but_matres_finals_and_noise_preserved(self):
        words = module.tokens("וַיְהִי אֶת־ירושלם: ירושלים, הן הם OCR42")
        self.assertEqual([word.key for word in words], ["ויהי", "את", "ירושלם", "ירושלים", "הן", "הם", "OCR42"])
        self.assertEqual(words[0].raw, "וַיְהִי")

    def test_true_source_spelling_difference_is_not_an_equal_block(self):
        matched, differences = module.alignment(module.tokens("ירושלים בתיהם"), module.tokens("ירושלם בתיהן", page=105))
        self.assertEqual(matched, [])
        self.assertEqual(differences[0]["referenceWords"], ["ירושלים", "בתיהם"])
        self.assertEqual(differences[0]["observedWords"], ["ירושלם", "בתיהן"])
        self.assertEqual(differences[0]["status"], "unresolved")

    def test_line_breaks_separate_words_without_inventing_spaces_inside_inline_markup(self):
        first = '<ol style="list-style-type: hebrew;"><li>זקנים<br/>בתולות</li><li>בני<span style="display:inline-block; inline-size:2em"></span>ישראל</li>' + '<li>ו<span>יהי</span></li>' * 62 + '</ol>'
        rest = '<ol style="list-style-type: hebrew;"><li>דבר</li></ol>' * 15
        rows = module.online_chapter((first + rest).encode())
        self.assertEqual(rows[0]["text"], "זקנים בתולות")
        self.assertEqual(rows[1]["text"], "בני ישראל")
        self.assertEqual(rows[2]["text"], "ויהי")

    def test_missing_word_and_latin_noise_remain_visible(self):
        matched, differences = module.alignment(module.tokens("ויהי דבר המלך", verse=1), module.tokens("ויהי XYZ המלך", page=97))
        self.assertEqual(matched, [(0, 0), (2, 2)])
        self.assertEqual(differences[0]["observedWords"], ["XYZ"])
        self.assertEqual(differences[0]["referenceVerses"], [1])
        self.assertEqual(differences[0]["observedPages"], [97])

    def test_vocabulary_excludes_entire_test_chapter(self):
        first = '<ol style="list-style-type: hebrew;">' + '<li>בדיקה</li>' * 64 + '</ol>'
        rest = '<ol style="list-style-type: hebrew;"><li>שָׁלוֹם<br/>שלום אחר</li></ol>' * 15
        self.assertEqual(module.held_out_vocabulary((first + rest).encode()), ["אחר", "שלום"])

    def test_page_reference_requires_a_unique_printed_opening(self):
        draft = {"chapters": [{"number": 1, "verses": [
            {"verse": 55, "text": "וְעַל פִּתְחֵי הַבָּתִּים וּבָרְחוֹבוֹת"},
            {"verse": 56, "text": "וַיְקָרְעוּ"}]}]}
        self.assertEqual([word.key for word in module.tokens(module.page_105_reference(draft))],
                         ["הבתים", "וברחובות", "ויקרעו"])
        draft["chapters"][0]["verses"][0]["text"] += " הבתים"
        with self.assertRaises(ValueError):
            module.page_105_reference(draft)

    def test_margin_labels_and_merged_boxes_are_kept_out_of_scripture_alignment(self):
        metadata = {"words": [
            {"text": "דבר", "bbox": {"x0": 600, "x1": 700}},
            {"text": "יא", "bbox": {"x0": 900, "x1": 920}},
            {"text": "ידלעשות", "bbox": {"x0": 820, "x1": 920}}]}
        body, excluded = module.scripture_ocr(metadata, 100, 1000)
        self.assertEqual(body, "דבר")
        self.assertEqual([word["classification"] for word in excluded],
                         ["printed_margin", "mixed_margin_body_unresolved"])
        # B99's overhanging prose is retained by that page's reviewed wider body.
        body, excluded = module.scripture_ocr({"words": [metadata["words"][1]]}, 99, 1000)
        self.assertEqual(body, "יא")
        self.assertEqual(excluded, [])


if __name__ == "__main__":
    unittest.main()
