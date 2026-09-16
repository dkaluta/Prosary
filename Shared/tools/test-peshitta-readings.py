#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Network-free Peshitta script-pair, provenance and coverage regressions."""
import importlib.util
import json
from pathlib import Path
import unittest

from aramaic_script_converter import to_hebrew
from peshitta_reading_source import load_verses, paired_text, scripture_importer
from reading_edition_mapping import mapper
from reading_edition_reviews_peshitta import REVIEWED_ISAIAH
from reading_step_mapping import Unavailable

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("peshitta_reader_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class SourceTests(unittest.TestCase):
    def test_existing_reviewed_fixture_preserves_both_scripts(self):
        raw = (TOOLS / "fixtures/peshitta-luke-1.xml").read_bytes()
        values = load_verses({"format": "peshitta-tei", "bookName": "Luke"}, raw)
        self.assertEqual(set(values), {(1, 26), (1, 27), (1, 28)})
        for syriac in values.values():
            hebrew, alternate = paired_text(syriac)
            self.assertEqual(alternate, syriac)
            self.assertEqual(hebrew, to_hebrew(syriac))
            self.assertRegex(hebrew, r"[\u05d0-\u05ea]")
            self.assertRegex(alternate, r"[\u0730\u0733\u0736\u073a\u073d]")

    def test_incomplete_pair_never_falls_back(self):
        for value in ("", "English substitute", "טקסט", None):
            with self.subTest(value=value), self.assertRaises(ValueError):
                paired_text(value)

    def test_isaiah_inventory_is_identical_to_existing_approval(self):
        self.assertEqual(REVIEWED_ISAIAH, scripture_importer().REVIEWED_ISAIAH_VERSES)
        self.assertEqual(len(REVIEWED_ISAIAH), 9)

    def test_unexpected_source_errors_are_not_silently_skipped(self):
        raw = (TOOLS / "fixtures/peshitta-luke-1.xml").read_bytes()
        with self.assertRaisesRegex(ValueError, "not Matthew"):
            load_verses({"format": "peshitta-tei", "bookName": "Matthew"}, raw)
        with self.assertRaisesRegex(ValueError, "no longer matches"):
            load_verses({"format": "peshitta-tei", "bookName": "Luke",
                         "excludedChapters": {"1": "invented exclusion"}}, raw)


class ShippedPeshittaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads((builder.DATA / "readings-texts.json").read_text())
        cls.lock = json.loads(builder.LOCK.read_text())

    def test_metadata_declares_actual_source_and_script_pair(self):
        edition = next(row for row in self.payload["editions"] if row["id"] == "peshitta-1905")
        self.assertEqual(edition["languageCode"], "arc")
        self.assertEqual((edition["textScript"], edition["transliteratedTextScript"]), ("Hebr", "Syrc"))
        for credit in ("1905", "Kiraz", "Walters", "CC BY 4.0", "nine", "unresolved"):
            self.assertIn(credit, edition["attribution"])

    def test_every_shipped_pair_is_exactly_the_established_projection(self):
        passages = 0
        for key, translations in self.payload["passages"].items():
            verses = translations.get("peshitta-1905", [])
            if not verses:
                continue
            passages += 1
            book, _ = builder.parse_citation(key.split("|", 1)[1], expand_subverses=True)
            self.assertIn(book, builder.NT | {"ISA"})
            for verse in verses:
                self.assertEqual(verse["text"], to_hebrew(verse["transliteratedText"]))
                self.assertRegex(verse["text"], r"[\u05d0-\u05ea]")
                self.assertRegex(verse["transliteratedText"], r"[\u0710-\u072f]")
                if book == "ISA":
                    self.assertIn((verse["chapter"], verse["verse"]), REVIEWED_ISAIAH)
        self.assertGreater(passages, 100)

    def test_shipped_syriac_is_identical_to_its_pinned_source_verse(self):
        sources = [source for source in self.lock["sources"] if source["id"].startswith("peshitta-")]
        missing = [source["cache"] for source in sources if not (builder.CACHE / source["cache"]).is_file()]
        if missing:
            self.skipTest(f"Exact source comparison requires {len(missing)} uncached pinned files; "
                          "run build-reading-texts.py --fetch first. All offline contract checks still run.")
        source_verses = {}
        for source in sources:
            for (book, chapter), verses in builder.load_source(source).items():
                source_verses.update({(book, chapter, number): text for number, text in verses.items()})
        for key, translations in self.payload["passages"].items():
            book, _ = builder.parse_citation(key.split("|", 1)[1], expand_subverses=True)
            for verse in translations.get("peshitta-1905", []):
                self.assertEqual(verse["transliteratedText"],
                                 source_verses[book, verse["chapter"], verse["verse"]])

    def test_luke_passage_is_available_in_both_scripts(self):
        verses = self.payload["passages"]["daily|Luke 6:27–38"]["peshitta-1905"]
        self.assertEqual([verse["verse"] for verse in verses], list(range(27, 39)))
        self.assertTrue(all(verse.get("transliteratedText") for verse in verses))

    def test_unreviewed_source_chapters_are_unavailable(self):
        subject = mapper("peshitta-1905")
        for reference in (("LUK", 10, 1), ("LUK", 11, 1), ("PHP", 1, 16),
                          ("3JN", 1, 14), ("REV", 12, 1), ("REV", 13, 1)):
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                subject.from_standard([reference])
        with self.assertRaises(Unavailable):
            subject.from_standard([("GEN", 1, 1)])

    def test_source_manifest_pins_every_nt_book_and_only_scoped_isaiah(self):
        sources = [row for row in self.lock["sources"] if row["id"].startswith("peshitta-")]
        self.assertEqual(len(sources), 28)
        self.assertEqual({row["book"] for row in sources}, builder.NT | {"ISA"})
        isaiah = next(row for row in sources if row["book"] == "ISA")
        self.assertEqual(isaiah["sha256"], scripture_importer().SUPPLIED_PESHITTA_SHA256)


if __name__ == "__main__":
    unittest.main()
