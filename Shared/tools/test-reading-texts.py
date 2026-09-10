#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Network-free regression checks for the offline passage builder and shipped corpus."""
import importlib.util
import hashlib
import json
from pathlib import Path
import re
import tempfile
import unittest
from unittest.mock import patch

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("reading_text_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class CitationTests(unittest.TestCase):
    def test_ordered_omissions_and_cross_chapter(self):
        self.assertEqual(builder.parse_citation("John 3:16,18–20; 4:1–5:2"),
                         ("JHN", [(3, 16, 3, 16), (3, 18, 3, 20), (4, 1, 5, 2)]))

    def test_psalm_has_one_canonical_book(self):
        self.assertEqual(builder.parse_citation("Psalm 23:1–6")[0], "PSA")

    def test_does_not_guess_partial_verses_or_repair_bad_references(self):
        for citation in ("John 3:16a", "John 3:16a,16b", "John 3:16–2:5", "John;",
                         "John 3:16;", "John 0:1", "John 3:18–16", "Unknown 1:1",
                         "John 3:16 or 3:18", "John 3:16; Luke 2:1"):
            with self.subTest(citation=citation), self.assertRaises(builder.Unavailable):
                builder.parse_citation(citation)

    def test_partial_verses_expand_only_when_explicitly_requested(self):
        self.assertEqual(builder.parse_citation("1 Corinthians 8:1b–7; 8:11–13", expand_subverses=True),
                         ("1CO", [(8, 1, 8, 7), (8, 11, 8, 13)]))
        self.assertEqual(builder.parse_citation("Psalm 139:1–3; 139:13–14ab; 139:23–24", expand_subverses=True),
                         ("PSA", [(139, 1, 139, 3), (139, 13, 139, 14), (139, 23, 139, 24)]))
        self.assertEqual(builder.parse_citation("John 3:16ac; 4:1b–5:2a", expand_subverses=True),
                         ("JHN", [(3, 16, 3, 16), (4, 1, 5, 2)]))

    def test_disjoint_subverses_do_not_repeat_the_enclosing_verse(self):
        for citation in ("John 3:16a,16b", "John 3:16a; 3:16bc"):
            self.assertEqual(builder.parse_citation(citation, expand_subverses=True), ("JHN", [(3, 16, 3, 16)]))
        self.assertEqual(builder.parse_citation("John 3:16b–18a,18bc–20", expand_subverses=True),
                         ("JHN", [(3, 16, 3, 20)]))

    def test_expansion_does_not_accept_malformed_or_overlapping_references(self):
        for citation in ("John 3:16 or 3:18", "John 3:16; Luke 2:1", "John 3:16a;", "John 0:1a",
                         "John 3:16o", "John 3:16ba", "John 3:16aa", "John 3:16b–16a",
                         "John 3:16b,16a", "John 3:16a,16a", "John 3:16,16b", "John 3:16–18,18–20"):
            with self.subTest(citation=citation), self.assertRaises(builder.Unavailable):
                builder.parse_citation(citation, expand_subverses=True)


class HebrewTests(unittest.TestCase):
    def test_divine_name_keeps_source_cantillation(self):
        # This is an actual source token from Genesis 2:4, not reconstructed Scripture.
        self.assertEqual(builder.preserve_divine_name_accents("יְהוָ֥ה"), "יהו֥ה")
        self.assertEqual(builder.preserve_divine_name_accents("לַֽ֭יהוָה"), "לַֽ֭יהוה")

    def test_surrounding_vowels_and_accents_unchanged(self):
        text = "אֵ֣לֶּה יְהוָ֥ה אֱלֹהִ֖ים"
        self.assertEqual(builder.preserve_divine_name_accents(text), "אֵ֣לֶּה יהו֥ה אֱלֹהִ֖ים")

    def test_unpointed_delitzsch_is_not_repointed(self):
        text = "יהוה עמך"
        self.assertEqual(builder.preserve_divine_name_accents(text), text)

    def test_idempotent(self):
        text = builder.preserve_divine_name_accents("יְהוִ֨ה")
        self.assertEqual(builder.preserve_divine_name_accents(text), text)


class ReviewedSourceTests(unittest.TestCase):
    edition = {"id": "review-fixture", "languageCode": "ar", "otSystem": "vul",
               "ntSystem": "vul", "coveragePolicy": "reviewed-units"}

    def corpus(self, units):
        return builder.ReviewedCorpus(
            {("ACT", 1): {verse: f"fixture {verse}" for verse in range(6, 12)}},
            self.edition["id"], units)

    def test_complete_reviewed_unit_works_in_a_sparse_chapter(self):
        corpus = self.corpus([tuple(("ACT", 1, verse) for verse in range(9, 12))])
        verses = builder.resolve("daily|Acts 1:9–11", {"roman"}, self.edition, corpus)
        self.assertEqual([verse["verse"] for verse in verses], [9, 10, 11])

    def test_available_words_do_not_authorize_unreviewed_subsets(self):
        corpus = self.corpus([tuple(("ACT", 1, verse) for verse in range(9, 12))])
        for citation in ("Acts 1:9", "Acts 1:9–10", "Acts 1:10–11", "Acts 1:6–11"):
            with self.subTest(citation=citation), self.assertRaisesRegex(builder.Unavailable, "reviewed passage"):
                builder.resolve("daily|" + citation, {"roman"}, self.edition, corpus)

    def test_subverse_expansion_preserves_reviewed_unit_boundaries(self):
        corpus = self.corpus([tuple(("ACT", 1, verse) for verse in range(9, 12))])
        result = builder.resolve("daily|Acts 1:9b–11a", {"roman"}, self.edition, corpus)
        self.assertEqual([verse["verse"] for verse in result], [9, 10, 11])
        with self.assertRaisesRegex(builder.Unavailable, "reviewed passage"):
            builder.resolve("daily|Acts 1:9b–10a", {"roman"}, self.edition, corpus)

    def test_exact_concatenation_preserves_every_reviewed_boundary(self):
        corpus = self.corpus([tuple(("ACT", 1, verse) for verse in range(6, 9)),
                              tuple(("ACT", 1, verse) for verse in range(9, 12))])
        result = builder.resolve("daily|Acts 1:6–11", {"roman"}, self.edition, corpus)
        self.assertEqual([verse["verse"] for verse in result], list(range(6, 12)))

    def test_old_jesuit_luke_boundary_cannot_be_split_by_numeric_identity(self):
        # The 1897 print places "and he shall reign ..." in Luke 1:32;
        # generic SIL mappings cannot certify that verse's textual boundary.
        corpus = builder.ReviewedCorpus({("LUK", 1): {32: "fixture 32", 33: "fixture 33"}},
                                       self.edition["id"], [(('LUK', 1, 32), ('LUK', 1, 33))])
        for verse in (32, 33):
            with self.assertRaisesRegex(builder.Unavailable, "reviewed passage"):
                builder.resolve(f"daily|Luke 1:{verse}", {"roman"}, self.edition, corpus)
        self.assertEqual(len(builder.resolve("daily|Luke 1:32–33", {"roman"}, self.edition, corpus)), 2)

    def test_reviewed_unit_cannot_fill_a_missing_or_empty_verse(self):
        corpus = self.corpus([tuple(("ACT", 1, verse) for verse in range(9, 12))])
        del corpus[("ACT", 1)][10]
        with self.assertRaisesRegex(builder.Unavailable, "verse unavailable"):
            builder.resolve("daily|Acts 1:9–11", {"roman"}, self.edition, corpus)
        corpus[("ACT", 1)][10] = " "
        with self.assertRaisesRegex(builder.Unavailable, "verse unavailable"):
            builder.resolve("daily|Acts 1:9–11", {"roman"}, self.edition, corpus)

    def test_other_editions_still_require_complete_chapters(self):
        ordinary = {**self.edition, "id": "ordinary-fixture", "languageCode": "en"}
        del ordinary["coveragePolicy"]
        sparse = {("ACT", 1): {9: "fixture 9", 10: "fixture 10", 11: "fixture 11"}}
        with self.assertRaisesRegex(builder.Unavailable, "chapter incomplete"):
            builder.resolve("daily|Acts 1:9–11", {"roman"}, ordinary, sparse)
        with self.assertRaisesRegex(ValueError, "verified reviewed source"):
            builder.resolve("daily|Acts 1:9–11", {"roman"}, self.edition, sparse)

    def source_fixture(self):
        return {"edition": {"id": self.edition["id"]},
                "verses": {"Acts": {"1": {str(v): f"fixture {v}" for v in range(9, 12)}}},
                "pages": {"Acts": {"1": {str(v): 456 for v in range(9, 12)}}},
                "reviewUnits": ["Acts 1:9–11"]}

    def load_fixture(self, value, alter_after_pin=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "Shared/content/fixture.json"
            path.parent.mkdir(parents=True)
            raw = json.dumps(value).encode()
            path.write_bytes(raw + (b" " if alter_after_pin else b""))
            source = {"id": "fixture", "editionId": self.edition["id"],
                      "format": "reviewed-verses", "path": "Shared/content/fixture.json",
                      "sha256": hashlib.sha256(raw).hexdigest()}
            with patch.object(builder, "ROOT", root):
                return builder.load_source(source)

    def test_reviewed_local_source_is_pinned_and_keeps_page_evidence(self):
        source = self.load_fixture(self.source_fixture())
        self.assertIsInstance(source, builder.ReviewedCorpus)
        self.assertEqual(source[("ACT", 1)][10], "fixture 10")
        with self.assertRaisesRegex(ValueError, "checksum changed"):
            self.load_fixture(self.source_fixture(), alter_after_pin=True)

    def test_no_unreviewed_page_missing_word_or_wrong_edition(self):
        for defect in ("page", "word", "unit", "edition"):
            value = self.source_fixture()
            if defect == "page":
                del value["pages"]["Acts"]["1"]["10"]
            elif defect == "word":
                value["verses"]["Acts"]["1"]["10"] = ""
            elif defect == "unit":
                value["reviewUnits"] = ["Acts 1:9–12"]
            else:
                value["edition"]["id"] = "different-edition"
            with self.subTest(defect=defect), self.assertRaises(ValueError):
                self.load_fixture(value)


class ShippedCorpusTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.payload = json.loads((builder.DATA / "readings-texts.json").read_text())
        cls.metadata = json.loads((builder.DATA / "readings-editions.json").read_text())

    def test_metadata_is_identical_and_editions_are_existing_choices(self):
        self.assertEqual(self.payload["editions"], self.metadata["editions"])
        self.assertEqual({edition["languageCode"] for edition in self.metadata["editions"]},
                         {"en", "he", "ar", "ru", "tl", "fr", "it", "uk"})

    def test_hebrew_metadata_identifies_the_vocalized_1901_edition(self):
        edition = next(edition for edition in self.metadata["editions"] if edition["id"] == "masoretic-delitzsch")
        self.assertEqual(edition["languageCode"], "he")
        self.assertIn("1901", edition["name"])
        self.assertIn("1901", edition["attribution"])
        self.assertIn("delitz.fr", edition["attribution"])
        self.assertEqual(edition["sourceURL"], "https://delitz.fr/12/")

    def test_every_shipped_hebrew_new_testament_verse_is_vocalized(self):
        passages_checked = 0
        for key, translations in self.payload["passages"].items():
            verses = translations.get("masoretic-delitzsch", [])
            book, _ = builder.parse_citation(key.split("|", 1)[1], expand_subverses=True)
            if not verses or book not in builder.NT:
                continue
            passages_checked += 1
            for verse in verses:
                with self.subTest(citation=key, chapter=verse["chapter"], verse=verse["verse"]):
                    self.assertRegex(verse["text"], r"[\u05b0-\u05bb\u05c7]")
        self.assertGreater(passages_checked, 0)

    def test_partial_verse_metadata_preserves_raw_lookup_keys(self):
        keys = self.payload["wholeVersePassages"]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertTrue(set(keys) <= self.payload["passages"].keys())
        for key in self.payload["passages"]:
            if builder.includes_whole_verses(key.split("|", 1)[1]):
                self.assertIn(key, keys)
        self.assertNotIn("daily|Luke 6:27–38", keys)

    def test_september_10_roman_readings_use_complete_source_verses(self):
        first = "daily|1 Corinthians 8:1b–7; 8:11–13"
        psalm = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"
        for key in (first, psalm):
            self.assertIn(key, self.payload["wholeVersePassages"])
        verses = self.payload["passages"][first]["douay-rheims-1899"]
        self.assertEqual([(verse["chapter"], verse["verse"]) for verse in verses],
                         [(8, verse) for verse in [1, 2, 3, 4, 5, 6, 7, 11, 12, 13]])
        psalm_verses = self.payload["passages"][psalm]["douay-rheims-1899"]
        self.assertEqual([(verse["chapter"], verse["verse"]) for verse in psalm_verses],
                         [(138, verse) for verse in [1, 2, 3, 4, 13, 14, 23, 24]])

    def test_old_jesuit_complete_announcement_has_exact_reviewed_words(self):
        source = json.loads((builder.ROOT / "Shared/content/arabic-jesuit-1897.json").read_text())
        verses = self.payload["passages"]["daily|Luke 1:26–38"]["jesuit-arabic-1897"]
        self.assertEqual([verse["verse"] for verse in verses], list(range(26, 39)))
        self.assertEqual([verse["text"] for verse in verses],
                         [source["verses"]["Luke"]["1"][str(verse)] for verse in range(26, 39)])
        # These are real calendar appointments with available source words but
        # unreviewed shortened boundaries; they must not be silently sliced.
        for citation in ("Luke 1:26–31", "Luke 1:26–28"):
            self.assertNotIn("jesuit-arabic-1897", self.payload["passages"].get("daily|" + citation, {}))

    def test_only_real_appointments_and_nonempty_verses_are_shipped(self):
        appointments = builder.appointments()
        editions = {edition["id"] for edition in self.metadata["editions"]}
        for key, translations in self.payload["passages"].items():
            self.assertIn(key, appointments)
            self.assertTrue(translations)
            self.assertTrue(set(translations) <= editions)
            for verses in translations.values():
                self.assertTrue(verses)
                self.assertEqual(len(verses), len({(verse["chapter"], verse["verse"]) for verse in verses}))
                self.assertTrue(all(verse["text"].strip() and verse["chapter"] > 0 and verse["verse"] > 0 for verse in verses))

    def test_hebrew_divine_name_transformation_is_complete(self):
        marks = r"[\u0591-\u05bd\u05bf\u05c1\u05c2\u05c4\u05c5\u05c7]*"
        divine_name = re.compile("י" + marks + "ה" + marks + "ו" + marks + "ה" + marks)
        names_checked = 0
        for translations in self.payload["passages"].values():
            for verse in translations.get("masoretic-delitzsch", []):
                self.assertEqual(verse["text"], builder.preserve_divine_name_accents(verse["text"]))
                for match in divine_name.finditer(verse["text"]):
                    names_checked += 1
                    # Independently check the product requirement: calling the
                    # same transformation twice alone would miss a broken no-op.
                    self.assertNotRegex(match.group(), r"[\u05b0-\u05bc\u05c7]")
        self.assertGreater(names_checked, 0)

    def test_shipped_torah_retains_source_vowels_and_cantillation_around_the_name(self):
        verses = self.payload["passages"]["torah|Deuteronomy 11:26–16:17"]["masoretic-delitzsch"]
        verse = next(verse for verse in verses if (verse["chapter"], verse["verse"]) == (11, 27))
        # Pinned hbo source, Deuteronomy 11:27. The Name keeps its accent;
        # every other word retains the source's vowel and cantillation marks.
        self.assertEqual(verse["text"],
                         "אֶֽת־הַבְּרָכָ֑ה אֲשֶׁ֣ר תִּשְׁמְע֗וּ אֶל־מִצְוֹת֙ יהו֣ה אֱלֹֽהֵיכֶ֔ם אֲשֶׁ֧ר אָנֹכִ֛י מְצַוֶּ֥ה אֶתְכֶ֖ם הַיֹּֽום׃")

    def test_known_corrupt_appointments_are_not_repaired(self):
        for citation in ("Galatians 6:21–31", "Mark 14:32–42; 26:47–56", "John 18:12–16; 18:24; 22:54–65"):
            self.assertNotIn("daily|" + citation, self.payload["passages"])

    def test_ambiguous_numbering_does_not_assume_english_from_book_labels(self):
        edition = {"id": "fixture", "languageCode": "en", "otSystem": "eng", "ntSystem": "eng"}
        with self.assertRaisesRegex(builder.Unavailable, "numbering|chapter"):
            builder.resolve("daily|Romans 16:25–27", {"ugcc"}, edition, {})

    def test_french_incomplete_chapter_is_not_partially_displayed(self):
        self.assertNotIn("crampon-1923", self.payload["passages"].get("daily|John 11:1–13", {}))

    def test_full_text_copies_are_byte_identical(self):
        for name in ("readings-editions.json", "readings-texts.json"):
            expected = (builder.DATA / name).read_bytes()
            for directory in builder.TARGETS:
                self.assertEqual((directory / name).read_bytes(), expected)


if __name__ == "__main__":
    unittest.main()
