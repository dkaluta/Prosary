#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Text-free mapping and source-integrity regressions for the reviewed Arabic units."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

import reading_edition_reviews_arabic as arabic
from reading_step_mapping import Unavailable

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("arabic_review_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)
EXISTING_DAILY = {
    "daily|John 19:25–27", "daily|John 19:38–42", "daily|John 20:11–18",
    "daily|John 20:24–29", "daily|John 21:15–17", "daily|Luke 1:26–38",
    "daily|Luke 2:22–24", "daily|Matthew 28:16–20", "daily|Matthew 28:1–7",
}


def refs(book, chapter, first, last):
    return [(book, chapter, verse) for verse in range(first, last + 1)]


class ArabicReviewedMapperTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.metadata = arabic.reference_metadata()
        cls.lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        cls.source = next(row for row in cls.lock["sources"] if row["id"] == arabic.SOURCE_ID)
        cls.corpus = builder.load_source(cls.source)

    def test_numeric_metadata_retains_exact_reviewed_inventory_and_no_words(self):
        metadata = self.metadata
        self.assertEqual((metadata["verseCount"], metadata["unitCount"]), (220, 64))
        self.assertEqual(len(metadata["verses"]), 220)
        self.assertEqual(len(metadata["units"]), 64)
        self.assertTrue(json.dumps(metadata, ensure_ascii=False).isascii())
        for row in metadata["verses"]:
            self.assertEqual(set(row), {"reference", "wordCount", "textSHA256", "pdfPages"})
            self.assertGreater(row["wordCount"], 0)
            self.assertTrue(row["pdfPages"])
        profile = arabic.PROFILES[arabic.EDITION_ID]
        pins = {self.source["id"]: self.source["sha256"]}
        digest = hashlib.sha256(json.dumps(pins, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        self.assertEqual(profile["source_pin_digest"], digest)
        self.assertEqual(metadata["sourcePins"], pins)
        self.assertEqual(profile["source_types"], set())
        self.assertEqual(profile["local_rule_lines"], set())
        self.assertEqual(profile["overrides"], {})
        mapper = arabic.ReviewedArabicMapper.from_metadata(metadata)
        self.assertEqual(len(mapper.verse_inventory), 24)
        self.assertNotIn(1, mapper.verse_inventory["LUK", 22], "Sparse absence is not a Last or empty-verse predicate")

    def test_all_64_complete_units_round_trip_without_any_text_access(self):
        # Standalone registry lookup must work when the canonical transcription
        # is unavailable. Its existing metadata is sufficient for unit mapping.
        with patch.object(Path, "read_bytes", side_effect=AssertionError("No Bible text access")), \
             patch.object(arabic, "reference_metadata", side_effect=AssertionError("No transcription load")):
            mapper = arabic.ReviewedArabicMapper.from_metadata(self.metadata)
            for source, standard in mapper.unit_mappings:
                with self.subTest(first=source[0], last=source[-1]):
                    self.assertEqual(mapper.from_standard(standard), (list(source), False))
                    self.assertEqual(mapper.to_standard(source), (list(standard), False))

    def test_real_source_matches_every_reviewed_unit_without_word_changes(self):
        mapper = arabic.ReviewedArabicMapper(self.corpus, self.metadata["sourcePins"])
        for unit in arabic.REVIEWED_UNITS:
            self.assertEqual(mapper.from_standard(unit), (list(unit), False))

    def test_whole_concatenations_and_explicit_gaps_are_preserved(self):
        mapper = arabic.ReviewedArabicMapper.from_metadata(self.metadata)
        for requested in (refs("JHN", 19, 38, 42), refs("LUK", 1, 26, 45),
                          refs("MAT", 17, 1, 2) + refs("MAT", 17, 5, 5),
                          refs("MRK", 14, 55, 55) + refs("MRK", 14, 60, 64)):
            with self.subTest(refs=requested):
                self.assertEqual(mapper.from_standard(requested), (requested, False))

    def test_partial_units_and_known_internal_luke_boundaries_are_never_sliced(self):
        mapper = arabic.ReviewedArabicMapper.from_metadata(self.metadata)
        partials = (refs("LUK", 1, 32, 32), refs("LUK", 1, 32, 33),
                    refs("LUK", 1, 26, 37), refs("LUK", 22, 43, 44),
                    refs("LUK", 24, 40, 40), refs("JHN", 19, 25, 25),
                    refs("MAT", 17, 1, 2), refs("MAT", 17, 1, 5))
        for requested in partials:
            for method in (mapper.from_standard, mapper.to_standard):
                with self.subTest(refs=requested, direction=method.__name__), self.assertRaises(Unavailable):
                    method(requested)
        # A smaller unit that was independently reviewed remains valid even if
        # it overlaps another review; no new subset is manufactured.
        self.assertEqual(mapper.from_standard(refs("JHN", 19, 26, 27)), (refs("JHN", 19, 26, 27), False))

    def test_missing_empty_or_changed_source_words_refuse_the_entire_unit(self):
        for replacement in (None, "", " ", "unreviewed replacement", 42):
            corpus = copy.deepcopy(self.corpus)
            mapper = arabic.ReviewedArabicMapper(corpus)
            if replacement is None:
                del corpus["LUK", 1][35]
            else:
                corpus["LUK", 1][35] = replacement
            for method in (mapper.from_standard, mapper.to_standard):
                with self.subTest(replacement=replacement, direction=method.__name__), self.assertRaisesRegex(Unavailable, "unavailable or changed"):
                    method(refs("LUK", 1, 26, 38))
        # A word count cannot certify the wording: preserve and check the pinned
        # per-verse hash as well, including a mutation with unchanged token count.
        corpus = copy.deepcopy(self.corpus)
        mapper = arabic.ReviewedArabicMapper(corpus)
        corpus["LUK", 1][35] += " "
        with self.assertRaisesRegex(Unavailable, "unavailable or changed"):
            mapper.from_standard(refs("LUK", 1, 26, 38))

    def test_wrong_source_pin_changed_review_units_or_added_verses_fail_closed(self):
        with self.assertRaisesRegex(ValueError, "source pin"):
            arabic.ReviewedArabicMapper(self.corpus, {arabic.SOURCE_ID: "0" * 64})
        corpus = copy.deepcopy(self.corpus)
        corpus.review_units = corpus.review_units[:-1]
        with self.assertRaisesRegex(ValueError, "unit inventory"):
            arabic.ReviewedArabicMapper(corpus)
        corpus = copy.deepcopy(self.corpus)
        corpus["LUK", 1][1] = "unreviewed addition"
        with self.assertRaisesRegex(ValueError, "outside its reviewed inventory"):
            arabic.ReviewedArabicMapper(corpus)
        with patch.object(Path, "read_bytes", return_value=b"unreviewed source"):
            with self.assertRaisesRegex(ValueError, "source changed"):
                arabic.reference_metadata()

    def test_incomplete_or_changed_metadata_is_not_a_sparse_identity_fallback(self):
        mutations = (
            lambda data: data["verses"].pop(),
            lambda data: data["verses"][0].update(wordCount=0),
            lambda data: data["verses"][0].update(pdfPages=[]),
            lambda data: data["units"][1]["source"].pop(),
            lambda data: data["units"][1]["standard"].pop(),
            lambda data: data.update(sourcePinDigest="0" * 64),
        )
        for mutate in mutations:
            data = copy.deepcopy(self.metadata)
            mutate(data)
            with self.assertRaises(ValueError):
                arabic.ReviewedArabicMapper.from_metadata(data)

    def test_repeated_reordered_unknown_and_malformed_references_are_unavailable(self):
        mapper = arabic.ReviewedArabicMapper.from_metadata(self.metadata)
        for requested in ([], [("JHN", 19, 1), ("JHN", 19, 1)],
                          [("JHN", 19, 3), ("JHN", 19, 2)], [("LUK", 22, 45)],
                          [("PSA", 1, 1)], [("LUK", 1, True)], [("LUK", "1", 26)],
                          [("LUK", 1, 0)], [("LUK", 0, 26)], [("LUK", 1, 26, "a")]):
            with self.subTest(refs=requested), self.assertRaises(Unavailable):
                mapper.from_standard(requested)

    def test_existing_nine_arabic_appointments_keep_the_same_exact_source_rows(self):
        payload = json.loads((TOOLS.parent / "data/readings-texts.json").read_text())
        existing = {key: editions[arabic.EDITION_ID] for key, editions in payload["passages"].items()
                    if arabic.EDITION_ID in editions}
        self.assertEqual(set(existing), EXISTING_DAILY)
        mapper = arabic.ReviewedArabicMapper(self.corpus)
        for key, rows in existing.items():
            book, _ = builder.parse_citation(key.split("|", 1)[1])
            requested = [(book, row["chapter"], row["verse"]) for row in rows]
            mapped, whole = mapper.from_standard(requested)
            self.assertEqual(mapped, requested)
            self.assertFalse(whole)
            for ref, row in zip(mapped, rows, strict=True):
                self.assertTrue(self.corpus[ref[:2]][ref[2]] == row["text"], "Previously reviewed Arabic words must remain unchanged")


if __name__ == "__main__":
    unittest.main()
