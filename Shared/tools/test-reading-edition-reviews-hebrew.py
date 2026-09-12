#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Whole-corpus and boundary regressions against the exact cached editions.

No downloads and no copied Scripture fixtures. Missing ignored source caches
skip integration tests; every available source is SHA-verified before import.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

from delitzsch_numbering import chapter_matches
from reading_edition_reviews_hebrew import PROFILES, TITLE_PSALMS
from reading_step_mapping import StepMapper, Unavailable
from reading_versification import SUPPORTED_BOOKS, Versification

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("hebrew_review_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class PinnedEditionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads(builder.LOCK.read_text())
        sources = {row["id"]: row for row in lock["sources"]}
        editions = {row["id"]: row for row in lock["editions"]}
        required = {part["id"] for key in PROFILES for part in editions[key]["sources"]}
        if any(not (builder.CACHE / sources[key]["cache"]).exists() for key in required):
            raise unittest.SkipTest("The three exact pinned source caches are not all present")
        cls.corpora, cls.pins, cls.mappers = {}, {}, {}
        cls.tables = Versification().tables
        for key, profile in PROFILES.items():
            corpus, pins = {}, {}
            for part in editions[key]["sources"]:
                source = sources[part["id"]]
                pins[source["id"]] = source["sha256"]
                for chapter, verses in builder.load_source(source).items():
                    if ((part.get("testament") == "ot" and chapter[0] in builder.NT)
                            or (part.get("testament") == "nt" and chapter[0] not in builder.NT)):
                        continue
                    if chapter in corpus:
                        raise AssertionError("Overlapping edition source chapters")
                    corpus[chapter] = verses
            cls.corpora[key], cls.pins[key] = corpus, pins
            cls.mappers[key] = StepMapper(corpus, source_types=profile["source_types"],
                local_rule_lines=profile["local_rule_lines"], overrides=profile["overrides"],
                excluded_chapters=profile["blocked_chapters"], subverse_labels=())

    def test_exact_assembled_source_pins_and_complete_imported_inventories(self):
        expected = {"masoretic-delitzsch": (261, 31174),
                    "ang-dating-biblia-1905": (1, 31102), "kulish-1905": (1, 31082)}
        for key, corpus in self.corpora.items():
            with self.subTest(edition=key):
                pins = self.pins[key]
                digest = hashlib.sha256(json.dumps(pins, sort_keys=True,
                    separators=(",", ":")).encode()).hexdigest()
                self.assertEqual(digest, PROFILES[key]["source_pin_digest"])
                self.assertEqual((len(pins), sum(map(len, corpus.values()))), expected[key])
                self.assertEqual({book for book, _ in corpus}, SUPPORTED_BOOKS)
                self.assertEqual(len(corpus), 1189)
                for chapter, verses in corpus.items():
                    self.assertEqual(set(verses), set(range(1, max(verses) + 1)), chapter)
                    self.assertTrue(all(value.strip() for value in verses.values()), chapter)

    def test_inventory_exceptions_cover_every_actual_difference(self):
        for key, corpus in self.corpora.items():
            profile = PROFILES[key]
            for chapter, verses in corpus.items():
                if key == "masoretic-delitzsch" and chapter[0] in builder.NT:
                    matches = chapter_matches(*chapter, verses)
                else:
                    system = "org" if key == "masoretic-delitzsch" else "eng"
                    maximum = self.tables[system].maxima[chapter]
                    matches = set(verses) == set(range(1, maximum + 1))
                if not matches:
                    self.assertIn(chapter, profile["reviewed_inventory_exceptions"]
                        | profile["blocked_chapters"], (key, chapter))

    def test_every_accepted_source_maps_and_round_trip_contains_its_whole_verse(self):
        for key, corpus in self.corpora.items():
            mapper, profile = self.mappers[key], PROFILES[key]
            self.assertFalse(mapper.blocked_targets, key)
            for chapter, verses in corpus.items():
                for verse in verses:
                    source = (*chapter, verse)
                    if chapter in profile["blocked_chapters"]:
                        with self.assertRaises(Unavailable):
                            mapper.to_standard([source])
                        continue
                    targets, _ = mapper.to_standard([source])
                    self.assertTrue(targets, (key, source))
                    back, _ = mapper.from_standard(targets)
                    self.assertIn(source, back, (key, source, targets))
                    for target in targets:
                        maximum = {("3JN", 1): 14, ("REV", 12): 17}.get(
                            target[:2], self.tables["eng"].maxima.get(target[:2], 0))
                        self.assertLessEqual(target[2], maximum, (key, source, target))
                        self.assertGreaterEqual(target[2], 0)
                        if target[2] == 0:
                            self.assertEqual(target[0], "PSA")
                            self.assertIn(target[1], TITLE_PSALMS)

    def test_complete_standard_coverage_exposes_only_reviewed_absences(self):
        for key, mapper in self.mappers.items():
            expected = ({("NEH", 7, 68)} if key == "masoretic-delitzsch" else
                        {("SNG", 1, 1)} if key == "kulish-1905" else set())
            for chapter in PROFILES[key]["blocked_chapters"]:
                expected.update((*chapter, verse) for verse in
                    range(1, self.tables["eng"].maxima[chapter] + 1))
            actual = set()
            for chapter, maximum in self.tables["eng"].maxima.items():
                if chapter[0] not in SUPPORTED_BOOKS:
                    continue
                maximum = {("3JN", 1): 14, ("REV", 12): 17}.get(chapter, maximum)
                actual.update((*chapter, verse) for verse in range(1, maximum + 1)
                    if (*chapter, verse) not in mapper.reverse)
            self.assertEqual(actual, expected, key)

    def test_all_psalm_titles_are_represented_or_explicitly_absent(self):
        for key, mapper in self.mappers.items():
            expected = (TITLE_PSALMS if key == "masoretic-delitzsch" else
                        TITLE_PSALMS - {98, 123} if key == "kulish-1905" else set())
            actual = {chapter for book, chapter, verse in mapper.reverse if book == "PSA" and verse == 0}
            self.assertEqual(actual, expected)
            for chapter in TITLE_PSALMS - expected:
                with self.assertRaises(Unavailable):
                    mapper.from_standard([("PSA", chapter, 0)])

    def test_hebrew_separate_and_merged_psalm_titles(self):
        mapper = self.mappers["masoretic-delitzsch"]
        self.assertEqual(mapper.to_standard([("PSA", 3, 1)]), ([("PSA", 3, 0)], False))
        self.assertEqual(mapper.to_standard([("PSA", 11, 1)]),
            ([("PSA", 11, 0), ("PSA", 11, 1)], False))
        self.assertEqual(mapper.from_standard([("PSA", 11, 1)]), ([("PSA", 11, 1)], True))

    def test_hebrew_malachi_order_and_cross_chapter_samuel_boundary(self):
        mapper = self.mappers["masoretic-delitzsch"]
        for verse in range(19, 25):
            self.assertEqual(mapper.to_standard([("MAL", 3, verse)]),
                ([("MAL", 4, verse - 18)], False))
        self.assertEqual(mapper.to_standard([("1SA", 20, 42)]), ([("1SA", 20, 42)], True))
        self.assertEqual(mapper.to_standard([("1SA", 20, 42), ("1SA", 21, 1)]),
            ([("1SA", 20, 42)], False))
        self.assertEqual(mapper.from_standard([("1SA", 20, 42)]),
            ([("1SA", 20, 42), ("1SA", 21, 1)], False))

    def test_previously_reviewed_delitzsch_internal_divisions(self):
        mapper = self.mappers["masoretic-delitzsch"]
        for book, chapter, standard, sources in (
                ("JHN", 1, 38, (38, 39)), ("JHN", 1, 51, (52,)),
                ("ROM", 7, 25, (25, 26)), ("1CO", 13, 12, (12, 13)),
                ("1CO", 13, 13, (14,)), ("2TH", 3, 16, (16, 17)),
                ("2TH", 3, 17, (18,)), ("2TH", 3, 18, (19,))):
            self.assertEqual(mapper.from_standard([(book, chapter, standard)]),
                ([(book, chapter, verse) for verse in sources], False))

    def test_same_count_philippians_reversal_is_edition_specific(self):
        for key, mapper in self.mappers.items():
            for verse in (16, 17):
                target = 33 - verse if key == "ang-dating-biblia-1905" else verse
                self.assertEqual(mapper.to_standard([("PHP", 1, verse)]),
                    ([("PHP", 1, target)], False))

    def test_corinthians_john_and_revelation_boundaries(self):
        for key, mapper in self.mappers.items():
            if key == "ang-dating-biblia-1905":
                self.assertEqual(mapper.from_standard([("2CO", 13, 12)]), ([("2CO", 13, 12)], False))
                self.assertEqual(mapper.from_standard([("3JN", 1, 14)]), ([("3JN", 1, 14)], False))
            else:
                self.assertEqual(mapper.from_standard([("2CO", 13, 12)]), ([("2CO", 13, 12)], True))
                self.assertEqual(mapper.from_standard([("2CO", 13, 12), ("2CO", 13, 13)]),
                    ([("2CO", 13, 12)], False))
                self.assertEqual(mapper.from_standard([("3JN", 1, 14)]),
                    ([("3JN", 1, 14), ("3JN", 1, 15)], False))
            self.assertEqual(mapper.from_standard([("REV", 13, 1)]), ([("REV", 13, 1)], False))

    def test_kulish_internal_merges_cannot_be_replaced_by_tail_offsets(self):
        mapper = self.mappers["kulish-1905"]
        for source, targets in {
            ("GEN", 3, 1): (("GEN", 3, 1), ("GEN", 3, 2)),
            ("GEN", 3, 2): (("GEN", 3, 3),),
            ("GEN", 6, 20): (("GEN", 6, 20), ("GEN", 6, 21)),
            ("NUM", 23, 21): (("NUM", 23, 20), ("NUM", 23, 21)),
            ("NUM", 23, 22): (("NUM", 23, 21),),
            ("NUM", 23, 29): (("NUM", 23, 28), ("NUM", 23, 29)),
            ("DEU", 28, 69): (("DEU", 29, 1),),
            ("DEU", 29, 1): (("DEU", 29, 2),),
            ("DEU", 29, 2): (("DEU", 29, 2),),
            ("LEV", 5, 24): (("LEV", 6, 5),),
            ("LEV", 5, 25): (("LEV", 6, 5),),
            ("LEV", 6, 22): (("LEV", 6, 29), ("LEV", 6, 30)),
            ("PHM", 1, 24): (("PHM", 1, 25),),
        }.items():
            self.assertEqual(set(mapper.to_standard([source])[0]), set(targets), source)
        self.assertEqual(mapper.from_standard([("GEN", 3, 1)]), ([("GEN", 3, 1)], True))
        self.assertEqual(mapper.from_standard([("PHM", 1, 25)]), ([("PHM", 1, 24)], False))

    def test_kulish_psalm_heading_and_body_boundaries(self):
        mapper = self.mappers["kulish-1905"]
        self.assertEqual(mapper.from_standard([("PSA", 60, 0)]),
            ([("PSA", 60, 1), ("PSA", 60, 2)], False))
        self.assertEqual(mapper.from_standard([("PSA", 60, 1)]), ([("PSA", 60, 3)], False))
        self.assertEqual(mapper.from_standard([("PSA", 13, 6)]), ([("PSA", 13, 5)], True))
        self.assertEqual(mapper.from_standard([("PSA", 127, 5)]),
            ([("PSA", 127, 5), ("PSA", 127, 6)], False))

    def test_kulish_missing_chapters_never_prove_structural_predicates(self):
        mapper = self.mappers["kulish-1905"]
        for predicate in ("Lev.21:23=Last", "Lev.21:24=NotExist", "Psa.148:13=Last", "Psa.148:14=NotExist"):
            self.assertIsNone(mapper.test(predicate), predicate)
        for reference in (("LEV", 21, 1), ("PSA", 148, 1), ("SNG", 1, 1)):
            with self.assertRaises(Unavailable):
                mapper.from_standard([reference])


if __name__ == "__main__":
    unittest.main()
