#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exercise release gates without treating a transcription draft as verified text."""
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from hebrew_deuterocanon import CONTENT, digest, load_books, validate_book


class HebrewReviewTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((CONTENT / "hebrew-kahana-source-catalog.json").read_text())
        scan = next(row for row in self.catalog["referenceScans"] if row["volume"] == "A2")
        self.book = {
            "schemaVersion": 1, "book": "LJE", "title": "אגרת ירמיהו",
            "translator": "אליהו ש' הרטום", "collectionEditor": "אברהם כהנא",
            "attribution": "Synthetic validation fixture; not Scripture.",
            "sourceURL": "https://example.org/reference",
            "scan": {key: scan[key] for key in ("volume", "sha256", "pageCount")},
            "review": {"status": "complete", "method": "Synthetic fixture", "reviewedPages": [14],
                       "unresolvedFindings": []},
            "chapters": [{"number": 1, "lastVerse": 4, "verses": [
                self.row(1), self.row(3, 4), self.row(2)]}],
        }
        self.book["scan"]["textPages"] = [14]
        self.approval = {"contentSHA256": digest(self.book), "scanSHA256": scan["sha256"],
                         "textPages": [14], "method": "Synthetic independent inventory", "hasIntroduction": False,
                         "chapters": [{"number": 1, "units": [[1, 1], [3, 4], [2, 2]]}]}

    @staticmethod
    def row(number, end=None):
        text = f"Test unit {number}"
        row = {"verse": number, "text": text, "sourcePages": [14],
               "textSHA256": hashlib.sha256(text.encode()).hexdigest()}
        if end is not None:
            row["endVerse"] = end
        return row

    def repin(self):
        self.approval["contentSHA256"] = digest(self.book)

    def test_source_order_and_combined_units_are_preserved(self):
        report = validate_book(self.book, self.catalog, self.approval)
        self.assertEqual(report["units"], 3)
        self.assertEqual([row["verse"] for row in self.book["chapters"][0]["verses"]], [1, 3, 2])

    def test_recomputed_verse_hash_cannot_reuse_completed_review(self):
        row = self.book["chapters"][0]["verses"][0]
        row["text"] += " changed"
        row["textSHA256"] = hashlib.sha256(row["text"].encode()).hexdigest()
        with self.assertRaisesRegex(ValueError, "digest is stale"):
            validate_book(self.book, self.catalog, self.approval)

    def test_missing_source_unit_cannot_be_hidden_by_new_digest(self):
        self.book["chapters"][0]["verses"].pop()
        self.repin()
        with self.assertRaisesRegex(ValueError, "source units"):
            validate_book(self.book, self.catalog, self.approval)

    def test_printed_gap_requires_explicit_inventory_and_partial_label(self):
        chapter = self.book["chapters"][0]
        chapter["verses"].pop()
        self.approval["chapters"][0]["units"].pop()
        self.repin()
        with self.assertRaisesRegex(ValueError, "omitted labels"):
            validate_book(self.book, self.catalog, self.approval)
        self.approval["sourceGaps"] = {"1": {"omittedLabels": [2], "reason": "Synthetic source lacuna"}}
        with self.assertRaisesRegex(ValueError, "partial chapter"):
            validate_book(self.book, self.catalog, self.approval)
        chapter["isComplete"] = False
        self.repin()
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["units"], 2)

    def test_wrong_translator_or_scan_and_overlap_are_rejected(self):
        for change, message in (
            (lambda b: b.update(translator="אברהם כהנא"), "translator"),
            (lambda b: b["scan"].update(sha256="0" * 64), "scan"),
            (lambda b: b["chapters"][0]["verses"].append(self.row(4)), "overlapping"),
        ):
            with self.subTest(message=message):
                altered = copy.deepcopy(self.book)
                change(altered)
                with self.assertRaisesRegex(ValueError, message):
                    validate_book(altered, self.catalog, self.approval)

    def test_unreviewed_page_open_finding_and_missing_inventory_prevent_completion(self):
        for change, message in (
            (lambda b: b["review"].update(reviewedPages=[]), "every source page"),
            (lambda b: b["review"].update(unresolvedFindings=["uncertain letter"]), "unresolved"),
        ):
            with self.subTest(message=message):
                altered = copy.deepcopy(self.book)
                change(altered)
                with self.assertRaisesRegex(ValueError, message):
                    validate_book(altered, self.catalog, self.approval)
        with self.assertRaisesRegex(ValueError, "independent source inventory"):
            validate_book(self.book, self.catalog)

    def test_whole_supplement_is_required_even_if_one_book_is_complete(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "LJE.json").write_text(json.dumps(self.book))
            inventory = directory / "review.json"
            inventory.write_text(json.dumps({"schemaVersion": 1, "books": {"LJE": self.approval}}))
            books, report = load_books(directory, inventory_path=inventory)
            self.assertEqual(books, [])
            self.assertEqual(next(row for row in report if row["book"] == "LJE")["status"], "complete")
            with self.assertRaisesRegex(ValueError, "not release-ready"):
                load_books(directory, inventory_path=inventory, require_complete=True)

    def test_unnumbered_opening_is_pinned_and_required_by_inventory(self):
        self.book.update(introduction="Test opening", introductionSourcePages=[14],
                         introductionTextSHA256=hashlib.sha256(b"Test opening").hexdigest())
        self.repin()
        with self.assertRaisesRegex(ValueError, "opening inventory"):
            validate_book(self.book, self.catalog, self.approval)
        self.approval["hasIntroduction"] = True
        validate_book(self.book, self.catalog, self.approval)
        self.book["introduction"] += " changed"
        with self.assertRaisesRegex(ValueError, "opening hash"):
            validate_book(self.book, self.catalog, self.approval)

    def test_disclosed_point_requires_exact_review_and_approval_inventories(self):
        row = self.book["chapters"][0]["verses"][0]
        row["text"] = "קּ"
        row["textSHA256"] = hashlib.sha256(row["text"].encode()).hexdigest()
        row["sourceNotes"] = [{"id": "test-qoph", "kind": "unreadablePoint", "anchor": "קּ",
            "occurrence": 1, "letterIndex": 1, "mark": "vowel", "sourcePages": [14],
            "sourceURL": "https://example.org/source.pdf#page=14"}]
        self.repin()
        with self.assertRaisesRegex(ValueError, "source-note review inventory"):
            validate_book(self.book, self.catalog, self.approval)
        self.book["review"]["acceptedSourceNoteIds"] = ["test-qoph"]
        self.approval["sourceNoteIds"] = ["test-qoph"]
        validate_book(self.book, self.catalog, self.approval)
        self.book["review"]["unresolvedFindings"] = ["An unread consonant remains"]
        with self.assertRaisesRegex(ValueError, "unresolved"):
            validate_book(self.book, self.catalog, self.approval)


if __name__ == "__main__":
    unittest.main()
