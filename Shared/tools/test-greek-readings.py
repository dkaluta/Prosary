#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Greek-source labels, mapping, missing-layout and native-asset regressions."""
import hashlib
import copy
import importlib.util
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch
from reading_appointment_keys import split_passage_key

from brenton_reading_source import SOURCE_SHA256, load_verses, parse_source
from reading_edition_mapping import mapper
from reading_edition_reviews_greek import sil_english_ot_to_standard
from reading_step_mapping import Unavailable
from greek_daily_psalms import (Resolver as GreekPsalmResolver, default_resolver as daily_psalm_resolver,
                               load_reviews, load_whole_reviews)
from reading_calendar_numbering import profile_for, chapter_system, standard_units

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("greek_reading_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def citation_book(key):
    citation = split_passage_key(key)[1]
    return builder.BOOKS.get(citation.split(":", 1)[0].rsplit(" ", 1)[0])


class GreekSourceTests(unittest.TestCase):
    def test_lettered_or_missing_labels_withhold_entire_chapter(self):
        chapters, excluded = parse_source(b"GEN 1:1 One\nGEN 1:1a Addition\nGEN 2:1 One\nGEN 2:3 Three\nGEN 3:1 Complete\n")
        self.assertEqual(chapters, {("GEN", 3): {1: "Complete"}})
        self.assertEqual(excluded, {("GEN", 1), ("GEN", 2)})

    def test_separate_greek_books_and_combined_ezra_are_not_renamed_into_canonical_books(self):
        chapters, excluded = parse_source(b"DNG 1:1 Greek Daniel\nESG 1:1 Greek Esther\nEZR 11:1 Nehemiah\nSIR 33:1 Unreviewed\n")
        self.assertFalse(chapters)
        self.assertEqual(excluded, {("DNG", 1), ("ESG", 1), ("EZR", 11), ("SIR", 33)})

    def test_parser_rejects_new_testament_malformed_and_duplicate_rows(self):
        for raw in (b"MAT 1:1 NT", b"GEN 1:0 Zero", b"GEN 1:1 ", b"GEN 1:1 A\nGEN 1:1 B"):
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                parse_source(raw)
        with self.assertRaisesRegex(ValueError, "source changed"):
            load_verses(b"GEN 1:1 An unreviewed replacement")

    def test_old_testament_bridge_does_not_assume_new_testament_identity(self):
        self.assertEqual(sil_english_ot_to_standard([("GEN", 1, 1)]), [("GEN", 1, 1)])
        for reference in (("3JN", 1, 15), ("REV", 12, 18), ("PSA", 3, 0), ("SIR", 1, 1)):
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                sil_english_ot_to_standard([reference])


class GreekMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.subject = mapper("brenton-lxx")

    def test_greek_psalm_and_isaiah_numbers_are_not_generic_latin_or_english_numbers(self):
        cases = [([("PSA", 103, n) for n in (1, 2, 3, 4, 9, 10, 11, 12)],
                  [("PSA", 102, n) for n in (1, 2, 3, 4, 9, 10, 11, 12)]),
                 ([("ISA", 9, 2)], [("ISA", 9, 1)]),
                 ([("GEN", 1, 1)], [("GEN", 1, 1)])]
        for standard, greek in cases:
            with self.subTest(standard=standard):
                self.assertEqual(self.subject.from_standard(standard)[0], greek)
                self.assertEqual(self.subject.to_standard(greek)[0], standard)

    def test_unrepresentable_source_chapters_remain_unavailable(self):
        for ref in (("GEN", 31, 50), ("EXO", 25, 5), ("SIR", 33, 1), ("DAN", 1, 1),
                    ("EST", 1, 1), ("NEH", 1, 1), ("MAT", 1, 1)):
            with self.subTest(ref=ref), self.assertRaises(Unavailable):
                self.subject.from_standard([ref])

    def test_every_accepted_mapping_round_trips_the_complete_source_verse(self):
        accepted = 0
        for (book, chapter), verses in self.subject.corpus.items():
            for verse in verses:
                source = (book, chapter, verse)
                try:
                    standard, _ = self.subject.to_standard([source])
                except Unavailable:
                    continue
                self.assertIn(source, self.subject.from_standard(standard)[0], source)
                accepted += 1
        self.assertGreater(accepted, 20000)


class GreekBundledTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((builder.DATA / "readings-texts.json").read_text())

    def test_choice_is_a_single_credited_old_testament_source(self):
        metadata = next(e for e in self.data["editions"] if e["id"] == "brenton-lxx")
        self.assertEqual(metadata["languageCode"], "el")
        self.assertIn("Old Testament only", metadata["attribution"])
        lock = json.loads(builder.LOCK.read_text())
        edition = next(e for e in lock["editions"] if e["id"] == "brenton-lxx")
        self.assertEqual(edition["sources"], [{"id": "grcbrent", "testament": "ot"}])
        source = next(s for s in lock["sources"] if s["id"] == "grcbrent")
        self.assertEqual(source["sha256"], SOURCE_SHA256)
        self.assertEqual(source["license"], "Public domain")

    def test_no_new_testament_passage_is_borrowed(self):
        count = 0
        for key, editions in self.data["passages"].items():
            if "brenton-lxx" not in editions:
                continue
            book = citation_book(key)
            self.assertNotIn(book, builder.NT, key)
            count += 1
        self.assertGreater(count, 100)

    def test_source_text_is_unchanged_and_every_selected_chapter_is_complete(self):
        lock = json.loads(builder.LOCK.read_text())
        source = next(s for s in lock["sources"] if s["id"] == "grcbrent")
        if not (builder.CACHE / source["cache"]).exists():
            self.skipTest("Pinned Greek source cache unavailable; metadata tests remain offline")
        self.assert_pinned_source_passages(source)

    def assert_pinned_source_passages(self, source):
        raw = builder.source_bytes(source)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), SOURCE_SHA256)
        corpus = load_verses(raw)
        self.assertEqual((len(corpus), sum(map(len, corpus.values()))), (908, 22377))
        # Reviewed Psalm supplements use the same pinned VPL bytes, but intentionally do
        # not add the lettered/gapped chapters to the ordinary complete-chapter corpus.
        psalms = GreekPsalmResolver(raw, load_reviews(), whole_reviews=load_whole_reviews())
        contexts = builder.appointments()
        for key, editions in self.data["passages"].items():
            book = citation_book(key)
            selected = editions.get("brenton-lxx", [])
            descriptor = self.data.get("passageSources", {}).get(key, {}).get("brenton-lxx")
            if descriptor is not None:
                self.assertEqual(book, "PSA", key)
                if psalms.handles(key):
                    expected = psalms.resolve(key, contexts[key])
                else:
                    _, citation, dataset = split_passage_key(key)
                    self.assertIsNotNone(dataset, key)
                    profile = profile_for(dataset, contexts[key])
                    _, spans = builder.parse_citation(citation, expand_subverses=True,
                        psalm_chapter_system=chapter_system(profile))
                    references, whole = standard_units(citation, spans, profile)
                    expected = psalms.resolve_standard(references,
                        includes_whole_verses=whole or builder.includes_whole_verses(citation))
                # Compare the complete selected bodies and printed witnesses, rather than
                # merely accepting any row that happens to exist in an excluded chapter.
                self.assertEqual(json.dumps(selected, ensure_ascii=False, sort_keys=True),
                    json.dumps(expected.verses, ensure_ascii=False, sort_keys=True), key)
                self.assertEqual(json.dumps(descriptor, ensure_ascii=False, sort_keys=True),
                    json.dumps(expected.source, ensure_ascii=False, sort_keys=True), key)
                # This list is the union of wider-unit notices across all editions.
                if expected.includes_whole_verses:
                    self.assertIn(key, self.data["wholeVersePassages"], key)
                continue
            for verse in selected:
                self.assertEqual(verse["text"], corpus[book, verse["chapter"]][verse["verse"]], key)

    def test_verification_needs_only_a_fresh_pinned_greek_cache(self):
        lock = json.loads(builder.LOCK.read_text())
        source = next(s for s in lock["sources"] if s["id"] == "grcbrent")
        cached = builder.CACHE / source["cache"]
        if not cached.exists():
            self.skipTest("Pinned Greek source cache unavailable")
        with tempfile.TemporaryDirectory() as directory:
            cache = Path(directory)
            shutil.copyfile(cached, cache / source["cache"])
            with patch.object(builder, "CACHE", cache), patch.object(builder.urllib.request, "urlopen",
                side_effect=AssertionError("Source verification must not fetch unrelated payloads")):
                self.assert_pinned_source_passages(source)
            self.assertEqual({path.name for path in cache.iterdir()}, {source["cache"]})

    def test_supplement_verification_rejects_changed_words_and_dropped_printed_witnesses(self):
        source = next(s for s in json.loads(builder.LOCK.read_text())["sources"] if s["id"] == "grcbrent")
        if not (builder.CACHE / source["cache"]).exists():
            self.skipTest("Pinned Greek source cache unavailable")
        key = "daily|augustinian-discalced|Psalm 115"
        for change in ("text", "witness"):
            altered = copy.deepcopy(self.data)
            if change == "text":
                altered["passages"][key]["brenton-lxx"][0]["text"] += " Unreviewed change"
            else:
                blocks = altered["passageSources"][key]["brenton-lxx"]["contentBlocks"]
                altered["passageSources"][key]["brenton-lxx"]["contentBlocks"] = [
                    block for block in blocks if block["kind"] != "witness"]
            with self.subTest(change=change), patch.object(self, "data", altered), self.assertRaises(AssertionError):
                self.assert_pinned_source_passages(source)

    def test_all_roman_psalm_appointments_have_a_source_faithful_greek_passage(self):
        appointments = [key for key, contexts in builder.appointments().items()
                        if key.startswith("daily|Psalm ") and contexts == {"roman"}]
        self.assertEqual(len(appointments), 103)
        for key in appointments:
            with self.subTest(key=key):
                self.assertIn("brenton-lxx", self.data["passages"].get(key, {}))
        key = "daily|Psalm 145:8–9; 145:10–11; 145:12–13ab; 145:13cd–14"
        source = self.data["passageSources"][key]["brenton-lxx"]
        witness = next(block for block in source["contentBlocks"] if block["kind"] == "witness")
        self.assertEqual(witness["printedLabel"], "13a")
        self.assertEqual(witness["text"], daily_psalm_resolver().rows[144, "13a"])
        self.assertIn(key, self.data["wholeVersePassages"])


if __name__ == "__main__":
    unittest.main()
