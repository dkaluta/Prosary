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
            "schemaVersion": 1, "book": "BAR", "title": "ספר ברוך",
            "translator": "אברהם כהנא", "collectionEditor": "אברהם כהנא",
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

    def test_work_editor_override_is_exact_and_requires_new_review(self):
        work = next(row for row in self.catalog["works"] if row.get("scriptureBook") == "BAR")
        work["collectionEditor"] = "Synthetic replacement editor"
        with self.assertRaisesRegex(ValueError, "wrong editor credit"):
            validate_book(self.book, self.catalog, self.approval)
        self.book["collectionEditor"] = work["collectionEditor"]
        with self.assertRaisesRegex(ValueError, "digest is stale"):
            validate_book(self.book, self.catalog, self.approval)
        self.repin()
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["status"], "complete")

    def test_no_collection_editor_is_explicit_and_source_specific(self):
        self.book["collectionEditor"] = None
        self.repin()
        with self.assertRaisesRegex(ValueError, "wrong editor credit"):
            validate_book(self.book, self.catalog, self.approval)
        work = next(row for row in self.catalog["works"] if row.get("scriptureBook") == "BAR")
        work["collectionEditor"] = None
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["status"], "complete")
        del self.book["collectionEditor"]
        self.repin()
        with self.assertRaisesRegex(ValueError, "wrong editor credit"):
            validate_book(self.book, self.catalog, self.approval)

    def test_editor_override_cannot_be_empty_or_an_invalid_type(self):
        work = next(row for row in self.catalog["works"] if row.get("scriptureBook") == "BAR")
        for invalid in ("", "  ", False, [], {}):
            with self.subTest(editor=invalid):
                work["collectionEditor"] = invalid
                self.book["collectionEditor"] = invalid
                self.repin()
                with self.assertRaisesRegex(ValueError, "invalid source editor credit"):
                    validate_book(self.book, self.catalog, self.approval)

    def test_replacement_source_requires_its_translator_scan_and_new_inventory(self):
        work = next(row for row in self.catalog["works"] if row.get("scriptureBook") == "BAR")
        original_scan = copy.deepcopy(self.book["scan"])
        work.update(translatorCredit="Synthetic replacement translator", collectionEditor=None,
                    referenceVolume="synthetic-replacement")
        scan = {"volume": "synthetic-replacement", "sha256": "1" * 64, "pageCount": 100}
        self.catalog["referenceScans"].append(scan)
        self.book["collectionEditor"] = None
        with self.assertRaisesRegex(ValueError, "wrong translator credit"):
            validate_book(self.book, self.catalog, self.approval)
        self.book["translator"] = work["translatorCredit"]
        with self.assertRaisesRegex(ValueError, "mismatched scan volume"):
            validate_book(self.book, self.catalog, self.approval)
        self.book["scan"] = dict(scan, textPages=[14])
        with self.assertRaisesRegex(ValueError, "digest is stale"):
            validate_book(self.book, self.catalog, self.approval)
        self.repin()
        with self.assertRaisesRegex(ValueError, "inventory uses another scan"):
            validate_book(self.book, self.catalog, self.approval)
        self.approval["scanSHA256"] = scan["sha256"]
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["status"], "complete")
        # Changing the approval as well cannot legitimize the unselected old scan.
        self.book["scan"] = original_scan
        self.approval["scanSHA256"] = original_scan["sha256"]
        self.repin()
        with self.assertRaisesRegex(ValueError, "mismatched scan volume"):
            validate_book(self.book, self.catalog, self.approval)

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
            (lambda b: b.update(translator="אליהו ש' הרטום"), "translator"),
            (lambda b: b["scan"].update(sha256="0" * 64), "scan"),
            (lambda b: b["chapters"][0]["verses"].append(self.row(4)), "overlapping"),
        ):
            with self.subTest(message=message):
                altered = copy.deepcopy(self.book)
                change(altered)
                with self.assertRaisesRegex(ValueError, message):
                    validate_book(altered, self.catalog, self.approval)

    def test_printed_witness_can_supply_a_label_absent_from_primary_index(self):
        chapter = self.book["chapters"][0]
        chapter["verses"].pop()
        self.approval["chapters"][0]["units"].pop()
        chapter["contentBlocks"] = [
            {"id": "unit-1", "kind": "verse", "chapter": 1, "verse": 1},
            {"id": "second-source", "kind": "witness", "printedLabel": "1a–2",
             "text": "Synthetic distinct source text", "addresses": [
                 {"chapter": 1, "verse": 1, "endVerse": 2, "part": "a"}],
             "sourcePages": [14],
             "textSHA256": hashlib.sha256(b"Synthetic distinct source text").hexdigest()},
            {"id": "unit-3", "kind": "verse", "chapter": 1, "verse": 3},
        ]
        self.approval["contentBlocks"] = [
            {"number": 1, "ids": ["unit-1", "second-source", "unit-3"]}]
        self.repin()
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["units"], 2)
        # A changed display label on an unnumbered passage cannot cover verse2.
        block = chapter["contentBlocks"][1]
        block["kind"] = "passage"
        del block["addresses"], block["printedLabel"]
        self.repin()
        with self.assertRaisesRegex(ValueError, "omitted labels"):
            validate_book(self.book, self.catalog, self.approval)

    def test_witness_coverage_uses_addressed_chapter_not_display_chapter(self):
        first = self.book["chapters"][0]
        first["verses"].pop()
        self.approval["chapters"][0]["units"].pop()
        self.book["chapters"].append({"number": 2, "lastVerse": 1, "verses": [self.row(1)],
            "contentBlocks": [
                {"id": "second-chapter", "kind": "verse", "chapter": 2, "verse": 1},
                {"id": "earlier-witness", "kind": "witness", "printedLabel": "1:2",
                 "text": "Synthetic earlier source", "addresses": [{"chapter": 1, "verse": 2}],
                 "sourcePages": [14],
                 "textSHA256": hashlib.sha256(b"Synthetic earlier source").hexdigest()},
            ]})
        self.approval["chapters"].append({"number": 2, "units": [[1, 1]]})
        self.approval["contentBlocks"] = [
            {"number": 2, "ids": ["second-chapter", "earlier-witness"]}]
        self.repin()
        self.assertEqual(validate_book(self.book, self.catalog, self.approval)["chapters"], 2)

    def test_witness_cannot_extend_the_reviewed_terminal_source_label(self):
        chapter = self.book["chapters"][0]
        chapter["contentBlocks"] = [{"id": f"unit-{r['verse']}", "kind": "verse", "chapter": 1,
                                     "verse": r["verse"]} for r in chapter["verses"]]
        chapter["contentBlocks"].append({"id": "beyond-end", "kind": "witness", "printedLabel": "5",
            "text": "Synthetic witness", "addresses": [{"chapter": 1, "verse": 5}],
            "sourcePages": [14], "textSHA256": hashlib.sha256(b"Synthetic witness").hexdigest()})
        self.approval["contentBlocks"] = [
            {"number": 1, "ids": ["unit-1", "unit-3", "unit-2", "beyond-end"]}]
        self.repin()
        with self.assertRaisesRegex(ValueError, "label exceeds"):
            validate_book(self.book, self.catalog, self.approval)

    def test_draft_witness_range_is_bounded_before_label_expansion(self):
        self.book["review"]["status"] = "draft"
        chapter = self.book["chapters"][0]
        chapter["contentBlocks"] = [{"id": f"unit-{r['verse']}", "kind": "verse", "chapter": 1,
                                     "verse": r["verse"]} for r in chapter["verses"]]
        witness = {"id": "bounded-witness", "kind": "witness", "printedLabel": "1–1000",
                   "text": "Synthetic witness", "addresses": [{"chapter": 1, "verse": 1,
                                                               "endVerse": 1000}],
                   "sourcePages": [14], "textSHA256": hashlib.sha256(b"Synthetic witness").hexdigest()}
        chapter["contentBlocks"].append(witness)
        self.assertEqual(validate_book(self.book, self.catalog)["status"], "draft")
        for address in ({"chapter": 1, "verse": 1, "endVerse": 1001},
                        {"chapter": 1, "verse": 1001}):
            with self.subTest(address=address):
                witness["addresses"] = [address]
                with self.assertRaisesRegex(ValueError, "invalid witness address"):
                    validate_book(self.book, self.catalog)

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
            (directory / "BAR.json").write_text(json.dumps(self.book))
            inventory = directory / "review.json"
            inventory.write_text(json.dumps({"schemaVersion": 1, "books": {"BAR": self.approval}}))
            books, report = load_books(directory, inventory_path=inventory)
            self.assertEqual(books, [])
            self.assertEqual(next(row for row in report if row["book"] == "BAR")["status"], "complete")
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

    def test_source_blocks_require_independent_order_inventory_and_page_review(self):
        chapter = self.book["chapters"][0]
        chapter["contentBlocks"] = [{"id": f"unit-{r['verse']}", "kind": "verse", "chapter": 1,
                                     "verse": r["verse"]} for r in chapter["verses"]]
        chapter["contentBlocks"].insert(1, {"id": "hymn", "kind": "passage", "text": "Test hymn",
            "sourcePages": [15], "textSHA256": hashlib.sha256(b"Test hymn").hexdigest()})
        self.book["scan"]["textPages"] = [14, 15]
        self.repin()
        with self.assertRaisesRegex(ValueError, "source block review inventory"):
            validate_book(self.book, self.catalog, self.approval)
        self.approval["contentBlocks"] = [{"number": 1, "ids": ["unit-1", "hymn", "unit-3", "unit-2"]}]
        self.approval["textPages"] = [14, 15]
        with self.assertRaisesRegex(ValueError, "every source page"):
            validate_book(self.book, self.catalog, self.approval)
        self.book["review"]["reviewedPages"] = [14, 15]
        validate_book(self.book, self.catalog, self.approval)
        chapter["contentBlocks"].pop(1)
        self.repin()
        with self.assertRaisesRegex(ValueError, "source block review inventory"):
            validate_book(self.book, self.catalog, self.approval)


class FrenkelBoundaryTests(unittest.TestCase):
    def test_brenton_mapping_preserves_every_pointed_source_span_once_in_order(self):
        reports = CONTENT.parent / "reports" / "hebrew-wikisource"
        mapping = json.loads((reports / "LJE-frenkel-pointed-crosswalk.json").read_text())
        book = json.loads((CONTENT / "hebrew-deuterocanon" / "LJE.json").read_text())
        sections = {s["sourceOrdinal"]: s for s in mapping["sourceSections"]}
        self.assertEqual(list(sections), list(range(1, 80)))
        self.assertEqual(sections[35]["sourceLabel"], "לה")
        self.assertEqual([v["verse"] for v in mapping["verses"]], list(range(1, 74)))
        self.assertEqual([v["verse"] for v in book["chapters"][0]["verses"]], list(range(1, 74)))
        self.assertEqual(book["scan"]["sha256"], mapping["scanSHA256"])

        # A verse-count check alone misses lost words, repeated clauses, or a cut
        # inside a pointed letter. Reconstruct the source and each target exactly.
        recovered = {number: "" for number in sections}
        next_offsets = {number: 0 for number in sections}
        source_order = []
        for mapped, verse in zip(mapping["verses"], book["chapters"][0]["verses"]):
            fragments, pages = [], set()
            for span in mapped["sourceSpans"]:
                number, start, end = span["sourceOrdinal"], span["start"], span["end"]
                section = sections[number]
                self.assertEqual(start, next_offsets[number])
                self.assertGreater(end, start)
                self.assertLessEqual(end, len(section["text"]))
                if start:
                    self.assertTrue(section["text"][start - 1].isspace())
                fragment = section["text"][start:end]
                recovered[number] += fragment
                next_offsets[number] = end
                fragments.append(fragment.strip())
                source_order.append(number)
                pages.update(p["sourcePage"] for p in section["pageSpans"]
                             if p["start"] < end and p["end"] > start)
            self.assertEqual(verse["text"], " ".join(fragments))
            self.assertEqual(verse["text"], mapped["hebrew"])
            self.assertEqual(verse["sourcePages"], sorted(pages))
        self.assertEqual(source_order, sorted(source_order))
        for number, section in sections.items():
            self.assertEqual(recovered[number], section["text"])
            self.assertEqual(hashlib.sha256(section["text"].encode()).hexdigest(), section["textSHA256"])
        source_notes = [n for s in sections.values() for n in s.get("sourceNotes", [])]
        target_notes = [n for v in book["chapters"][0]["verses"] for n in v.get("sourceNotes", [])]
        self.assertEqual(source_notes, target_notes)


if __name__ == "__main__":
    unittest.main()
