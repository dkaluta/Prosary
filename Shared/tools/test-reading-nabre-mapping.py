#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only NABRE graph regressions; fixtures contain no Scripture."""
import json
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from nabre_versification import NabreInventory
from reading_nabre_mapping import NabreMapper, Unavailable, atom, atoms, load_word_counts


def inventory(chapters):
    """A numeric fixture, explicitly incomplete and never shipped as a scrape."""
    books = {}
    for (book, chapter), numbers in chapters.items():
        entry = books.setdefault(book, {"slug": book.lower(), "chapterOrder": [], "chapters": {}})
        chapter = str(chapter)
        entry["chapterOrder"].append(chapter)
        labels = list(map(str, range(1, numbers + 1))) if isinstance(numbers, int) else list(map(str, numbers))
        entry["chapters"][chapter] = {"verseOrder": labels, "omittedVerses": [], "duplicateVerses": [],
            "sourcePages": [{"url": "https://bible.usccb.org/bible/" + book.lower() + "/" + chapter.lower(),
                             "sha256": "a" * 64}]}
    data = {"schemaVersion": 1, "edition": "NABRE", "source": {
        "indexURL": "https://bible.usccb.org/bible", "indexSHA256": "b" * 64},
        "complete": False, "errors": [], "books": books}
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "fixture.json"
        path.write_text(json.dumps(data))
        return NabreInventory(path, require_complete=False)


class RuleGrammarTests(unittest.TestCase):
    def test_lettered_esther_and_cross_chapter_join(self):
        self.assertEqual(atom("Esg.A:1").source, ("EST", "A", "1"))
        self.assertEqual([a.source for a in atoms("Rev.12:18; 13:1")],
                         [("REV", "12", "18"), ("REV", "13", "1")])

    def test_parts_preserve_a_whole_verse_without_hiding_additions(self):
        self.assertEqual(atom("Sir.28:6!b").standard, ("SIR", 28, 6))
        with self.assertRaises(Unavailable):
            _ = atom("Esg.1:1*a").standard

    def test_reversed_and_cross_chapter_ranges_are_not_guessed(self):
        for reference in ["Gen.1:9-2", "Gen.1:9-2:1"]:
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                atoms(reference)


class NabreMappingTests(unittest.TestCase):
    def test_source_range_uses_the_published_chapter_boundary(self):
        mapper = NabreMapper(inventory({("1SA", 20): 42, ("1SA", 21): 16}))
        self.assertEqual(mapper.to_standard([("1SA", 20, 42)]), ([("1SA", 20, 42)], True))
        self.assertEqual(mapper.to_standard([("1SA", 20, 42), ("1SA", 21, 1)]),
                         ([("1SA", 20, 42)], False))

    def test_rearranged_sirach_parts_keep_the_whole_verse_envelope(self):
        mapper = NabreMapper(inventory({("SIR", 33): [*range(1,20), "20a", "21", "20b", *range(22,34)],
            ("SIR", 41): ["14b", "15", "14a", "16a", "16b", "17", "18", "19", "21", "20a", "21c", "20b", "22"],
            ("SIR", 47): [*range(1, 11), "9b", "10b", *range(11, 26)]}))
        for chapter, first, second, verse in [(33,"20a","20b",19), (41,"14a","14b",14),
                (41,"16a","16b",16), (41,"20a","20b",20), (41,"21","21c",21),
                (47,"9","9b",9), (47,"10","10b",10)]:
            with self.subTest(chapter=chapter, verse=verse):
                self.assertEqual(mapper.to_standard([("SIR",chapter,first)]),
                                 ([("SIR",chapter,verse)], True))
                self.assertEqual(mapper.to_standard([("SIR",chapter,first),("SIR",chapter,second)]),
                                 ([("SIR",chapter,verse)], False))

    def test_sirach_33_internal_boundaries_do_not_follow_matching_labels(self):
        mapper = NabreMapper(inventory({("SIR",33): [*range(1,20),"20a","21","20b",*range(22,34)]}))
        self.assertEqual(mapper.to_standard([("SIR",33,16),("SIR",33,17)]),
                         ([("SIR",33,16)],False))
        self.assertEqual(mapper.to_standard([("SIR",33,21)]), ([("SIR",33,20)],False))
        self.assertEqual(mapper.to_standard([("SIR",33,30)]),
                         ([("SIR",33,28),("SIR",33,29)],False))
        self.assertEqual(mapper.to_standard([("SIR",33,31)]),
                         ([("SIR",33,30),("SIR",33,31)],True))
        self.assertEqual(mapper.to_standard([("SIR",33,v) for v in (31,32,33)]),
                         ([("SIR",33,30),("SIR",33,31)],False))

    def test_sirach_unused_labels_do_not_mean_a_missing_passage(self):
        mapper = NabreMapper(inventory({("SIR",36): [*range(1,14),*range(16,32)],
                                      ("SIR",44):23}),
            word_counts={("SIR","36","16"):12,("SIR","36","17"):15})
        self.assertEqual(mapper.to_standard([("SIR",36,13),("SIR",36,16)]),
                         ([("SIR",36,11)],False))
        self.assertEqual(mapper.to_standard([("SIR",44,22),("SIR",44,23)]),
                         ([("SIR",44,22)],False))

    def test_numeric_measurements_select_only_the_supported_predicate(self):
        mapper = NabreMapper(inventory({("PHP",1):30}),
            word_counts={("PHP","1","16"):12,("PHP","1","17"):20})
        self.assertTrue(mapper.test("Php.1:16*2>Php.1:17"))
        self.assertTrue(mapper.test("1:16+1:17>1:17", "Php"))
        self.assertFalse(mapper.test("Php.1:16>Php.1:17"))
        self.assertIsNone(mapper.test("Php.1:15<Php.1:16"))
        self.assertEqual(mapper.to_standard([("PHP",1,16)]), ([("PHP",1,17)],False))

    def test_hebrew_chapter_boundaries_are_translated_by_published_rules(self):
        mapper = NabreMapper(inventory({("GEN", 31): 54, ("GEN", 32): 33,
                                       ("EXO", 7): 29, ("EXO", 8): 28}))
        self.assertEqual(mapper.to_standard([("GEN", 32, 1), ("GEN", 32, 2)]),
                         ([("GEN", 31, 55), ("GEN", 32, 1)], False))
        self.assertEqual(mapper.to_standard([("EXO", 7, 26)]), ([("EXO", 8, 1)], False))

    def test_esther_lettered_additions_keep_their_own_standard_references(self):
        mapper = NabreMapper(inventory({("EST", "A"): 17, ("EST", 1): 22,
            ("EST", "B"): 7, ("EST", 3): 15, ("EST", "C"): 30, ("EST", 4): 17,
            ("EST", "D"): 16, ("EST", 5): 14, ("EST", "E"): 24, ("EST", 8): 17,
            ("EST", "F"): 11, ("EST", 10): 3}))
        for source, chapter, verse in [("A", 11, 2), ("B", 13, 1), ("C", 13, 8),
                                       ("D", 15, 1), ("E", 16, 1), ("F", 10, 4)]:
            with self.subTest(source=source):
                self.assertEqual(mapper.to_standard([("EST", source, 1)]),
                                 ([("EST", chapter, verse)], False))

    def test_daniel_additions_use_separate_standard_books(self):
        mapper = NabreMapper(inventory({("DAN", 3): 100, ("DAN", 4): 34,
                                       ("DAN", 13): 64, ("DAN", 14): 42}))
        for source, target in [(('DAN', 3, 24), ('S3Y', 1, 1)),
                               (('DAN', 3, 91), ('DAN', 3, 24)),
                               (('DAN', 4, 1), ('DAN', 4, 4)),
                               (('DAN', 13, 1), ('SUS', 1, 1)),
                               (('DAN', 14, 1), ('BEL', 1, 2))]:
            with self.subTest(source=source):
                self.assertEqual(mapper.to_standard([source]), ([target], False))

    def test_new_testament_merges_and_splits_flag_only_enlarged_envelopes(self):
        mapper = NabreMapper(inventory({("2CO", 13): 13, ("3JN", 1): 15,
                                       ("REV", 12): 18, ("REV", 13): 18}))
        self.assertEqual(mapper.to_standard([("2CO", 13, 12)]),
                         ([("2CO", 13, 12), ("2CO", 13, 13)], False))
        self.assertEqual(mapper.to_standard([("3JN", 1, 15)]), ([("3JN", 1, 14)], True))
        self.assertEqual(mapper.to_standard([("3JN", 1, 14), ("3JN", 1, 15)]),
                         ([("3JN", 1, 14)], False))
        self.assertEqual(mapper.to_standard([("REV", 12, 18)]), ([("REV", 13, 1)], True))

    def test_september_13_sirach_uses_the_standard_greek_numbering(self):
        mapper = NabreMapper(inventory({("SIR", 27): 30, ("SIR", 28): 26}))
        refs = [("SIR", 27, 30)] + [("SIR", 28, v) for v in range(1, 8)]
        self.assertEqual(mapper.to_standard(refs), (refs, False))

    def test_acts_48_and_49_are_one_standard_verse_envelope(self):
        mapper = NabreMapper(inventory({("ACT", 10): 49}))
        self.assertEqual(mapper.to_standard([("ACT", 10, 49)]), ([("ACT", 10, 48)], True))
        self.assertEqual(mapper.to_standard([("ACT", 10, 48), ("ACT", 10, 49)]),
                         ([("ACT", 10, 48)], False))

    def test_psalm_numbered_superscription_and_split(self):
        mapper = NabreMapper(inventory({("PSA", 13): 6, ("PSA", 51): 21}))
        self.assertEqual(mapper.to_standard([("PSA", 13, 6)]),
                         ([("PSA", 13, 5), ("PSA", 13, 6)], False))
        self.assertEqual(mapper.to_standard([("PSA", 51, 1)]), ([("PSA", 51, 0)], True))

    def test_omitted_and_unknown_verses_cannot_be_identity_guesses(self):
        mapper = NabreMapper(inventory({("MAT", 17): [1, 2, 4]}))
        for reference in [("MAT", 17, 3), ("MAT", 18, 1), ("MAT", 17, 9)]:
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                mapper.to_standard([reference])

    def test_structural_tests_do_not_measure_or_require_scripture(self):
        mapper = NabreMapper(inventory({("GEN", 1): 31}))
        self.assertTrue(mapper.test("Gen.1:31=Last & Gen.1:32=NotExist"))
        self.assertFalse(mapper.test("Gen.1:30=Last"))
        self.assertIsNone(mapper.test("Gen.1:1>Gen.1:2"))
        self.assertTrue(mapper.test("Gen.99:2=NotExist"))
        self.assertIsNone(mapper.test("Exo.1:2=NotExist"))
        mapper.inventory.books["GEN"]["chapterOrder"].append("2")
        self.assertIsNone(mapper.test("Gen.2:2=NotExist"))
        mapper.inventory.books["GEN"]["pageOrder"] = ["1", "2", "3"]
        mapper.inventory.books["GEN"]["pageSources"] = {"1": {}}
        self.assertIsNone(mapper.test("Gen.3:2=NotExist"))
        self.assertIsNone(mapper.test("Gen.1:31=Last"))

    def test_conflicting_rules_are_unavailable(self):
        rules = [(1, "SyntheticA", "Gen.1:1", "Gen.1:2", "Renumber verse", "Gen.1:31=Last"),
                 (2, "SyntheticB", "Gen.1:1", "Gen.1:3", "Renumber verse", "Gen.1:31=Last")]
        with patch("reading_nabre_mapping.load_rules", return_value=rules):
            mapper = NabreMapper(inventory({("GEN", 1): 31}))
        with self.assertRaisesRegex(Unavailable, "conflicting"):
            mapper.to_standard([("GEN", 1, 1)])

    def test_an_unanswered_length_condition_cannot_fall_through_to_identity(self):
        rules = [(1, "Synthetic", "Gen.1:1", "Gen.1:2", "Renumber verse", "Gen.1:1>Gen.1:2")]
        with patch("reading_nabre_mapping.load_rules", return_value=rules):
            mapper = NabreMapper(inventory({("GEN", 1): 31}))
        with self.assertRaisesRegex(Unavailable, "beyond verse markers"):
            mapper.to_standard([("GEN", 1, 1)])

    def test_documented_clause_boundaries_use_the_full_alignment_pair(self):
        mapper = NabreMapper(inventory({("ROM", 3): 31}))
        self.assertEqual(mapper.to_standard([("ROM", 3, 26)]),
                         ([("ROM", 3, 25), ("ROM", 3, 26)], True))
        self.assertEqual(mapper.to_standard([("ROM", 3, 25), ("ROM", 3, 26)]),
                         ([("ROM", 3, 25), ("ROM", 3, 26)], False))

    def test_a_boundary_pair_cannot_hide_a_missing_constituent(self):
        mapper = NabreMapper(inventory({("ROM", 3): [24, 26, 27]}))
        with self.assertRaisesRegex(Unavailable, "incomplete whole-verse boundary"):
            mapper.to_standard([("ROM", 3, 26)])

    def test_a_generic_keep_rule_does_not_cancel_an_active_local_rule(self):
        rules = [(1, "Synthetic", "Gen.1:1", "Gen.1:2", "Renumber verse", "Gen.1:31=Last"),
                 (2, "AllBibles", "Gen.1:1", "Gen.1:1", "Keep verse", "")]
        with patch("reading_nabre_mapping.load_rules", return_value=rules):
            mapper = NabreMapper(inventory({("GEN", 1): 31}))
        self.assertEqual(mapper.to_standard([("GEN", 1, 1)])[0], [("GEN", 1, 2)])

    def test_empty_requests_are_not_successful_mappings(self):
        mapper = NabreMapper(inventory({("GEN", 1): 31}))
        with self.assertRaises(Unavailable):
            mapper.to_standard([])


class MeasurementMetadataTests(unittest.TestCase):
    def test_only_numeric_metadata_with_matching_source_pin_is_accepted(self):
        source = inventory({("GEN",1):31})
        with tempfile.TemporaryDirectory() as directory:
            source.path = Path(directory) / "structure.json"
            source.path.write_text(json.dumps(source.data))
            path = Path(directory) / "measurements.json"
            data = {"schemaVersion":1,"edition":"NABRE",
                "method":"whitespace-delimited-verse-body-tokens-v1",
                "structureSHA256":hashlib.sha256(source.path.read_bytes()).hexdigest(),
                "measurements":[{"reference":["GEN","1","1"],"words":12,
                    "sourcePages":source.chapter("GEN",1)["sourcePages"]}]}
            path.write_text(json.dumps(data))
            self.assertEqual(load_word_counts(source,path),{("GEN","1","1"):12})
            for mutation in [lambda d:d.update(structureSHA256="0"*64),
                    lambda d:d["measurements"][0].update(text="unexpected"),
                    lambda d:d["measurements"][0].update(words=True),
                    lambda d:d["measurements"][0].update(reference=["GEN","1","32"]),
                    lambda d:d["measurements"][0]["sourcePages"][0].update(sha256="0"*64)]:
                bad = json.loads(json.dumps(data))
                mutation(bad)
                path.write_text(json.dumps(bad))
                with self.assertRaises(ValueError):
                    load_word_counts(source,path)


class CompleteInventoryTests(unittest.TestCase):
    def test_every_published_label_has_a_correspondence(self):
        mapper = NabreMapper()
        self.assertEqual(len(mapper.inventory.books),73)
        self.assertEqual(sum(len(b["pageSources"]) for b in mapper.inventory.books.values()),1328)
        self.assertEqual(len(mapper.labels),35519)
        self.assertFalse(mapper.unavailable)
        for reference in mapper.labels:
            targets, _ = mapper.to_standard([reference])
            self.assertTrue(targets, reference)

    def test_reviewed_boundary_groups_match_the_pinned_source_pages(self):
        mapper = NabreMapper()
        path = Path(__file__).parent / "versification/nabre/boundary-reviews.json"
        reviews = json.loads(path.read_text())
        self.assertEqual(reviews["structureSHA256"],
                         hashlib.sha256(mapper.inventory.path.read_bytes()).hexdigest())
        for review in reviews["reviews"]:
            sources = [tuple(ref) for ref in review["sourceReferences"]]
            expected = [tuple(ref) for ref in review["standardReferences"]]
            self.assertEqual(mapper.to_standard(sources),(expected,False),sources)
            actual_pages = [page for book,chapter,_ in sources
                            for page in mapper.inventory.chapter(book,chapter)["sourcePages"]]
            self.assertTrue(all(page in actual_pages for page in review["sourcePages"]))


if __name__ == "__main__":
    unittest.main()
