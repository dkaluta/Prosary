#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""NABRE metadata validation and reference-boundary tests; no Scripture fixtures."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from nabre_versification import InvalidInventory, NabreInventory


def chapter(order, omitted=(), repeated=()):
    return {"verseOrder": order, "omittedVerses": list(omitted),
            "duplicateVerses": list(repeated),
            "sourcePages": [{"url": "https://bible.usccb.org/bible/esther/1", "sha256": "a" * 64}]}


class InventoryTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "structure.json"
        self.data = {
            "schemaVersion": 1, "edition": "NABRE", "complete": False, "errors": [],
            "source": {"indexURL": "https://bible.usccb.org/bible", "indexSHA256": "b" * 64},
            "books": {"EST": {"slug": "esther", "chapterOrder": ["A", "1", "B"],
                               "chapters": {"A": chapter(["1", "2"]),
                                            "1": chapter(["1", "3", "4"], omitted=["2"]),
                                            "B": chapter(["1", "2"])}},
                      "SIR": {"slug": "sirach", "chapterOrder": ["30"],
                               "chapters": {"30": chapter(["1", "3", "2", "4"])}}}}

    def load(self, data=None, complete=False):
        self.path.write_text(json.dumps(data or self.data), encoding="utf-8")
        return NabreInventory(self.path, require_complete=complete)

    def test_omitted_verses_are_not_synthesized(self):
        result = self.load()
        self.assertEqual(result.span("EST", 1, 1, 1, 4),
                         [("EST", "1", "1"), ("EST", "1", "3"), ("EST", "1", "4")])
        self.assertFalse(result.contains("EST", 1, 2))
        with self.assertRaisesRegex(InvalidInventory, "absent or omitted"):
            result.span("EST", 1, 2, 1, 4)

    def test_lettered_chapters_follow_published_order(self):
        self.assertEqual(self.load().span("EST", "A", 2, "B", 1),
                         [("EST", "A", "2"), ("EST", "1", "1"), ("EST", "1", "3"),
                          ("EST", "1", "4"), ("EST", "B", "1")])

    def test_relocated_verses_retain_source_order(self):
        result = self.load()
        self.assertEqual(result.span("SIR", 30, 1, 30, 4),
                         [("SIR", "30", str(n)) for n in [1, 3, 2, 4]])
        with self.assertRaisesRegex(InvalidInventory, "Reversed"):
            result.span("SIR", 30, 2, 30, 3)

    def test_a_partial_crawl_cannot_claim_complete_coverage(self):
        with self.assertRaisesRegex(InvalidInventory, "incomplete"):
            self.load(complete=True)
        incomplete = copy.deepcopy(self.data)
        incomplete["complete"] = True
        with self.assertRaisesRegex(InvalidInventory, "incomplete"):
            self.load(incomplete, complete=True)

    def test_scripture_and_unknown_fields_are_rejected(self):
        for where in [(), ("books", "EST"), ("books", "EST", "chapters", "1")]:
            bad = copy.deepcopy(self.data)
            node = bad
            for key in where:
                node = node[key]
            node["text"] = "Synthetic forbidden content"
            with self.subTest(where=where), self.assertRaises(InvalidInventory):
                self.load(bad)

    def test_unreported_duplicates_are_rejected_and_reported_duplicates_cannot_map(self):
        bad = copy.deepcopy(self.data)
        bad["books"]["EST"]["chapters"]["A"]["verseOrder"] = ["1", "1", "2"]
        with self.assertRaisesRegex(InvalidInventory, "Unreported"):
            self.load(bad)
        bad["books"]["EST"]["chapters"]["A"]["duplicateVerses"] = ["1"]
        result = self.load(bad)
        self.assertFalse(result.contains("EST", "A", 1))
        with self.assertRaisesRegex(InvalidInventory, "ambiguous"):
            result.span("EST", "A", 1, "A", 2)

    def test_provenance_must_be_official_numeric_metadata(self):
        for url in ["http://bible.usccb.org/bible/esther/1", "https://example.com/bible/esther/1"]:
            bad = copy.deepcopy(self.data)
            bad["books"]["EST"]["chapters"]["A"]["sourcePages"][0]["url"] = url
            with self.subTest(url=url), self.assertRaises(InvalidInventory):
                self.load(bad)


if __name__ == "__main__":
    unittest.main()
