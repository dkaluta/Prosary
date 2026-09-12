#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Pinned-corpus, reference-only regressions for the three western reviews.

Run against the existing ignored source cache; no source downloads or copied
Scripture fixtures. Cache-free checkouts skip this integration suite.
"""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

from reading_edition_mapping import EditionMapper, corpus_digest, source_pin_digest
from reading_edition_reviews_western import PROFILES
from reading_step_mapping import Unavailable
from reading_versification import Versification

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("western_review_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


def refs(book, chapter, first, last):
    return [(book, chapter, verse) for verse in range(first, last + 1)]


class WesternEditionReviewsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        sources = {row["id"]: row for row in lock["sources"]}
        required = {reference["id"] for edition in lock["editions"] if edition["id"] in PROFILES
                    for reference in edition["sources"]}
        if any(not (builder.CACHE / sources[key]["cache"]).is_file() for key in required):
            raise unittest.SkipTest("The three exact pinned western source caches are not all present")
        cls.corpora, cls.records, cls.mappers = {}, {}, {}
        for edition in lock["editions"]:
            edition_id = edition["id"]
            if edition_id not in PROFILES:
                continue
            corpus, pins = {}, {}
            for reference in edition["sources"]:
                source = sources[reference["id"]]
                # The importer verifies every actual file against its source lock.
                corpus.update(builder.load_source(source))
                pins[source["id"]] = source["sha256"]
            record = {"sourcePins": pins, "corpusSHA256": corpus_digest(corpus),
                      "systems": {"ot": edition["otSystem"], "nt": edition["ntSystem"]},
                      "chapters": [[book, chapter, [[verse, len(text.split())]
                                    for verse, text in sorted(values.items())]]
                                   for (book, chapter), values in sorted(corpus.items())]}
            cls.corpora[edition_id], cls.records[edition_id] = corpus, record
            cls.mappers[edition_id] = EditionMapper(edition_id, record)

    def test_exact_assembled_source_pins_and_inventories(self):
        expected = {"synodal-1876": (1, 1189, 31169),
                    "crampon-1923": (1, 1334, 35610), "martini": (447, 447, 13785)}
        for edition_id, (source_count, chapters, verses) in expected.items():
            record, corpus = self.records[edition_id], self.corpora[edition_id]
            with self.subTest(edition=edition_id):
                self.assertEqual(source_pin_digest(record["sourcePins"]), PROFILES[edition_id]["source_pin_digest"])
                self.assertEqual((len(record["sourcePins"]), len(corpus), sum(map(len, corpus.values()))),
                                 (source_count, chapters, verses))
                self.mappers[edition_id].validate_source(corpus, record["sourcePins"])
                changed = copy.deepcopy(record)
                changed["sourcePins"][next(iter(changed["sourcePins"]))] = "0" * 64
                with self.assertRaisesRegex(ValueError, "reviewed mapping profile"):
                    EditionMapper(edition_id, changed)

    def test_reviewed_inventory_exceptions_do_not_relax_other_chapters(self):
        counts = {"synodal-1876": 3, "crampon-1923": 118, "martini": 10}
        for edition_id, mapper in self.mappers.items():
            with self.subTest(edition=edition_id):
                profile = PROFILES[edition_id]
                self.assertEqual(len(profile["reviewed_inventory_exceptions"]), counts[edition_id])
                self.assertEqual(mapper.excluded_chapters, profile["blocked_chapters"])
                self.assertFalse(profile["blocked_chapters"] & profile["reviewed_inventory_exceptions"])
                changed = copy.deepcopy(self.records[edition_id])
                next(row for row in changed["chapters"] if row[:2] == ["GEN", 1])[2].pop()
                self.assertIn(("GEN", 1), EditionMapper(edition_id, changed).excluded_chapters)

    def test_crampon_malformed_rows_and_martini_truncations_remain_unavailable(self):
        corpus = self.corpora["crampon-1923"]
        empty = {(book, chapter) for (book, chapter), values in corpus.items()
                 if any(not text.strip() for text in values.values())}
        self.assertEqual(len(empty), 58)
        self.assertEqual(sum(not text.strip() for values in corpus.values() for text in values.values()), 124)
        self.assertEqual(empty, self.mappers["crampon-1923"].excluded_chapters)
        self.assertEqual(self.mappers["martini"].excluded_chapters, {("1PE", 5), ("1TH", 4), ("JHN", 11)})
        for edition_id, mapper in self.mappers.items():
            for chapter in mapper.excluded_chapters:
                reference = (*chapter, next(iter(self.corpora[edition_id][chapter])))
                with self.subTest(edition=edition_id, ref=reference), self.assertRaises(Unavailable):
                    mapper.to_standard([reference])
        # Valid neighboring rows cannot infer a boundary from excluded chapters.
        for reference in [("NUM", 25, 19), ("ECC", 6, 12), ("SIR", 37, 7)]:
            with self.subTest(ref=reference), self.assertRaises(Unavailable):
                self.mappers["crampon-1923"].to_standard([reference])

    def test_all_supported_source_verses_round_trip_as_whole_units(self):
        expected = {"synodal-1876": (31164, 5), "crampon-1923": (33869, 1741),
                    "martini": (13708, 77)}
        for edition_id, corpus in self.corpora.items():
            mapper = self.mappers[edition_id]
            supported = unavailable = 0
            for (book, chapter), verses in corpus.items():
                for verse in verses:
                    source = (book, chapter, verse)
                    try:
                        standard, _ = mapper.to_standard([source])
                    except Unavailable:
                        unavailable += 1
                        continue
                    supported += 1
                    restored, _ = mapper.from_standard(standard)
                    self.assertIn(source, restored, (edition_id, source))
                    self.assertTrue(all(ref[:2] not in mapper.excluded_chapters and
                                        ref[2] in corpus[ref[:2]] for ref in restored))
            self.assertEqual((supported, unavailable), expected[edition_id])

    def test_crampon_all_148_safe_psalms_preserve_the_complete_numeric_body(self):
        mapper, corpus = self.mappers["crampon-1923"], self.corpora["crampon-1923"]
        original = Versification().tables["org"]
        checked = 0
        for chapter in range(1, 151):
            if ("PSA", chapter) in mapper.excluded_chapters:
                continue
            values = corpus["PSA", chapter]
            self.assertEqual(set(values), set(range(1, original.maxima["PSA", chapter] + 1)))
            mapped, _ = mapper.to_standard(refs("PSA", chapter, 1, max(values)))
            restored, _ = mapper.from_standard(mapped)
            self.assertEqual(set(restored), set(refs("PSA", chapter, 1, max(values))))
            checked += 1
        self.assertEqual(checked, 148)
        self.assertEqual(mapper.from_standard([("PSA", 13, 0)]), ([("PSA", 13, 1)], False))
        self.assertEqual(mapper.from_standard([("PSA", 13, 1)]), ([("PSA", 13, 2)], False))
        self.assertEqual(mapper.from_standard([("PSA", 87, 1)]), ([("PSA", 87, 1)], True))

    def test_synodal_equal_length_psalms_preserve_title_and_body_boundaries(self):
        mapper = self.mappers["synodal-1876"]
        cases = [("PSA", 13, 0, 12, 1, False), ("PSA", 13, 1, 12, 2, False),
                 ("PSA", 13, 5, 12, 6, True), ("PSA", 87, 0, 86, 1, False),
                 ("PSA", 87, 1, 86, 2, True), ("PSA", 90, 1, 89, 2, False),
                 ("PSA", 90, 5, 89, 6, True), ("PSA", 142, 1, 141, 1, True)]
        for book, chapter, verse, source_chapter, source_verse, envelope in cases:
            with self.subTest(chapter=chapter, verse=verse):
                self.assertEqual(mapper.from_standard([(book, chapter, verse)]),
                                 ([(book, source_chapter, source_verse)], envelope))
        self.assertEqual(mapper.from_standard(refs("PSA", 87, 1, 2)), ([("PSA", 86, 2)], False))
        self.assertEqual(mapper.from_standard(refs("PSA", 90, 5, 6)), ([("PSA", 89, 6)], False))

    def test_synodal_local_chapter_moves_and_supplementary_verses(self):
        mapper = self.mappers["synodal-1876"]
        cases = {("JOB", 39, 31): ("JOB", 40, 1), ("JOB", 40, 1): ("JOB", 40, 6),
                 ("JOB", 40, 27): ("JOB", 41, 8), ("JOB", 41, 1): ("JOB", 41, 9),
                 ("SNG", 1, 1): ("SNG", 1, 2), ("DAN", 3, 31): ("DAN", 4, 1),
                 ("PSA", 114, 9): ("PSA", 116, 9), ("PRO", 18, 24): ("PRO", 18, 24)}
        for source, standard in cases.items():
            self.assertEqual(mapper.to_standard([source]), ([standard], False))
        self.assertEqual(mapper.from_standard(refs("ROM", 16, 25, 27)), (refs("ROM", 14, 24, 26), False))
        self.assertEqual(mapper.from_standard([("1SA", 20, 42)]), (refs("1SA", 20, 42, 43), False))
        for source in refs("JOS", 24, 34, 36) + refs("PRO", 4, 28, 29):
            with self.subTest(ref=source), self.assertRaises(Unavailable):
                mapper.to_standard([source])
        for standard in [("S3Y", 1, 1), ("SUS", 1, 1), ("SIR", 1, 1), ("SNG", 1, 1)]:
            with self.subTest(ref=standard), self.assertRaises(Unavailable):
                mapper.from_standard([standard])

    def test_crampon_integrated_additions_and_sirach_group(self):
        mapper = self.mappers["crampon-1923"]
        for source, standard in [(("DAN", 3, 24), ("S3Y", 1, 1)),
                                 (("DAN", 3, 91), ("DAN", 3, 24)),
                                 (("DAN", 3, 100), ("DAN", 4, 3)),
                                 (("DAN", 13, 64), ("SUS", 1, 64))]:
            self.assertEqual(mapper.to_standard([source]), ([standard], False))
        self.assertEqual(mapper.from_standard([("SIR", 44, 22)]), (refs("SIR", 44, 22, 23), False))
        self.assertEqual(mapper.to_standard([("SIR", 44, 23)]), ([("SIR", 44, 22)], True))
        for ref in [("EST", 10, 4), ("EST", 11, 2), ("SIR", 27, 30), ("SIR", 28, 6)]:
            self.assertEqual(mapper.from_standard([ref]), ([ref], False))
        self.assertEqual(mapper.from_standard([("1SA", 20, 42)]),
                         ([("1SA", 20, 42), ("1SA", 21, 1)], False))
        self.assertEqual(mapper.from_standard([("REV", 13, 1)]),
                         ([("REV", 12, 18), ("REV", 13, 1)], False))

    def test_nt_equal_count_swaps_and_split_final_verses(self):
        for edition_id, mapper in self.mappers.items():
            source_verse = 16 if edition_id == "synodal-1876" else 17
            self.assertEqual(mapper.from_standard([("PHP", 1, 16)]), ([("PHP", 1, source_verse)], False))
            self.assertEqual(mapper.to_standard([("2CO", 13, 12)]), (refs("2CO", 13, 12, 13), False))
            self.assertEqual(mapper.to_standard([("2CO", 13, 13)]), ([("2CO", 13, 14)], False))
        self.assertEqual(self.mappers["synodal-1876"].from_standard([("3JN", 1, 14)]),
                         (refs("3JN", 1, 14, 15), False))
        self.assertEqual(self.mappers["martini"].from_standard([("3JN", 1, 14)]), ([("3JN", 1, 14)], False))

    def test_martini_reviewed_merges_do_not_invent_missing_endings(self):
        mapper = self.mappers["martini"]
        for source, standard in [(("GEN", 5, 31), refs("GEN", 5, 31, 32)),
                                 (("2CO", 1, 23), refs("2CO", 1, 23, 24)),
                                 (("2TH", 2, 10), refs("2TH", 2, 10, 11))]:
            self.assertEqual(mapper.to_standard([source]), (standard, False))
            self.assertEqual(mapper.from_standard(standard[:1]), ([source], True))
            self.assertEqual(mapper.from_standard(standard), ([source], False))
        self.assertEqual(mapper.from_standard([("2TH", 2, 17)]), ([("2TH", 2, 16)], False))
        for source, standard in [(("DEU", 13, 1), ("DEU", 12, 32)),
                                 (("DEU", 23, 1), ("DEU", 22, 30)),
                                 (("DEU", 29, 1), ("DEU", 29, 2))]:
            self.assertEqual(mapper.to_standard([source]), ([standard], False))
        for standard in [("PSA", 1, 1), ("SIR", 1, 1), ("1TH", 4, 18), ("JHN", 11, 57)]:
            with self.subTest(ref=standard), self.assertRaises(Unavailable):
                mapper.from_standard([standard])


if __name__ == "__main__":
    unittest.main()
