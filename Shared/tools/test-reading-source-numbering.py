#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Appointment-scope, mapper-integration and pinned-source regression tests."""
from copy import deepcopy
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

from nabre_versification import InvalidInventory
from reading_nabre_mapping import NabreMapper
from reading_source_numbering_reviews import load_reviews, reviewed_numbering

TOOLS = Path(__file__).resolve().parent


def module(name, filename):
    spec = importlib.util.spec_from_file_location(name, TOOLS / filename)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


builder = module("source_numbering_builder", "build-reading-texts.py")
fixtures = module("source_numbering_fixtures", "test-reading-nabre-mapping.py")
SIRACH = "daily|Sirach 27:30; 28:1–7"
PSALM = "daily|Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12"


class SourceNumberingReviewTests(unittest.TestCase):
    def test_known_reviews_cannot_fall_back_when_calendar_context_changes(self):
        edition = {'id': 'douay-rheims-1899', 'ntSystem': 'vul', 'otSystem': 'vul'}
        cases = (
            ('daily|2 Corinthians 13:3–13', {'ugcc', 'syriac'}),
            ('daily|Mark 3:20–30', {'roman'}),
            ('daily|Mark 3:13–19', {'ugcc', 'ugcc-gregorian', 'syriac', 'maronite'}),
            (PSALM, {'roman', 'syriac'}),
            (SIRACH, {'maronite'}),
        )
        with patch('reading_versification.map_reference', side_effect=AssertionError('No legacy fallback')):
            for key, contexts in cases:
                with self.subTest(key=key, contexts=contexts):
                    with self.assertRaisesRegex(builder.Unavailable, 'calendar context outside reviewed'):
                        builder.resolve(key, contexts, edition, {})

    def test_every_bundled_psalm_has_an_exact_roman_numbering_review(self):
        keys = {key: contexts for key, contexts in builder.appointments().items()
                if key.startswith('daily|Psalm ')}
        self.assertEqual(len(keys), 103)
        for key, contexts in keys.items():
            with self.subTest(key=key):
                self.assertEqual(contexts, {'roman'})
                review = reviewed_numbering(key, contexts)
                self.assertIsNotNone(review)
                self.assertIsNone(reviewed_numbering(key, {'roman', 'syriac'}))
                code = review['evidence']['readingCode']
                self.assertTrue(all(part.startswith('Ps ') for part in code.split('#')))
                source_citation = 'Psalm ' + '; '.join(
                    re.sub(r'^(\d+),', r'\1:', part.removeprefix('Ps ')) for part in code.split('#'))
                self.assertEqual(builder.parse_citation(source_citation, expand_subverses=True),
                                 builder.parse_citation(key.split('|', 1)[1], expand_subverses=True))

    def test_hebrew_psalm_review_cannot_change_another_book(self):
        data = json.loads((TOOLS / 'reading-source-numbering-reviews.json').read_text())
        data['appointments'][SIRACH]['sourceSystem'] = 'hebrew-psalms'
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'reviews.json'
            path.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError, 'cannot cover another book'):
                load_reviews(path)

    def test_shipped_psalms_are_available_in_every_complete_psalm_edition(self):
        data = json.loads((builder.DATA / 'readings-texts.json').read_text())
        expected = {'douay-rheims-1899', 'masoretic-delitzsch', 'synodal-1876',
                    'ang-dating-biblia-1905', 'crampon-1923', 'kulish-1905'}
        for key in builder.appointments():
            if not key.startswith('daily|Psalm '):
                continue
            with self.subTest(key=key):
                self.assertEqual(set(data['passages'][key]), expected)
                for verses in data['passages'][key].values():
                    self.assertTrue(verses)
                    self.assertTrue(all(row['text'].strip() for row in verses))
        key = 'daily|Psalm 33:2–3; 33:4–5; 33:12; 33:22'
        self.assertEqual([(row['chapter'], row['verse'])
                          for row in data['passages'][key]['douay-rheims-1899']],
                         [(32, verse) for verse in (2, 3, 4, 5, 12, 22)])

    def test_shipped_nt_boundary_reviews_keep_the_closing_unit_and_notice(self):
        data = json.loads((builder.DATA / 'readings-texts.json').read_text())
        for start in (3, 5):
            key = f'daily|2 Corinthians 13:{start}–13'
            for edition, rows in data['passages'][key].items():
                last = 14 if edition in {'ang-dating-biblia-1905', 'peshitta-1905'} else 13
                self.assertEqual([(row['chapter'], row['verse']) for row in rows],
                                 [(13, verse) for verse in range(start, last + 1)])
            self.assertIn('Espiritu Santo', data['passages'][key]['ang-dating-biblia-1905'][-1]['text'])
            self.assertIn('Holy Ghost', data['passages'][key]['douay-rheims-1899'][-1]['text'])
            self.assertNotIn(key, data['wholeVersePassages'])
        key = 'daily|1 Peter 3:8–15'
        self.assertIn(key, data['wholeVersePassages'])
        for rows in data['passages'][key].values():
            self.assertEqual([(row['chapter'], row['verse']) for row in rows],
                             [(3, verse) for verse in range(8, 16)])

    def test_shipped_gospels_include_source_clauses_across_verse_boundaries(self):
        data = json.loads((builder.DATA / 'readings-texts.json').read_text())
        key = 'daily|Mark 3:20–30'
        self.assertIn(key, data['wholeVersePassages'])
        for edition, rows in data['passages'][key].items():
            first = 19 if edition in {'ang-dating-biblia-1905', 'peshitta-1905'} else 20
            self.assertEqual([row['verse'] for row in rows], list(range(first, 31)))
        self.assertIn('bahay', data['passages'][key]['ang-dating-biblia-1905'][0]['text'])
        self.assertIn('ܠܒ݂ܰܝܬ݁ܳܐ', data['passages'][key]['peshitta-1905'][0]['transliteratedText'])
        key = 'daily|Luke 7:11–18'
        self.assertIn(key, data['wholeVersePassages'])
        for rows in data['passages'][key].values():
            self.assertEqual([row['verse'] for row in rows], list(range(11, 20)))
        self.assertIn('two of his disciples', data['passages'][key]['douay-rheims-1899'][-1]['text'])
        for key in ('daily|Ephesians 5:3–13', 'daily|Mark 16:1–7',
                    'daily|Acts 3:13–15; 3:17–19'):
            self.assertIn(key, data['wholeVersePassages'])

    def test_cached_hebrew_psalm_publications_match_reviewed_source_markers(self):
        reviews = [row for row in load_reviews().values() if row['sourceSystem'] == 'hebrew-psalms']
        source = next(row for row in json.loads(builder.LOCK.read_text())['sources'] if row['id'] == 'hbo')
        cache = builder.CACHE / 'psalm-appointments-2026'
        files = {row['evidence']['appointmentURL'].rsplit('/', 1)[-1]: row for row in reviews}
        if not (builder.CACHE / source['cache']).exists() or any(
                not (cache / f'{date}-HE.json').exists() for date in files):
            self.skipTest('Pinned HE Psalm publication or Masoretic source caches are absent; offline scope and corpus tests remain mandatory')
        corpus = builder.load_source(source)
        normalize = lambda text: ''.join(char for char in text if '\u05d0' <= char <= '\u05ea')
        checked = 0
        for date, review in files.items():
            evidence = review['evidence']
            raw = (cache / f'{date}-HE.json').read_bytes()
            self.assertEqual(hashlib.sha256(raw).hexdigest(), evidence['appointmentSHA256'])
            self.assertEqual(evidence['corroboratingSHA256'], source['sha256'])
            psalm = next(row for row in json.loads(raw)['data']['readings']
                         if row.get('reading_code') == evidence['readingCode'])
            for marker in re.finditer(r'\[\[Ps (\d+),(\d+)[^\]]*\]\](.*?)(?=\[\[|$)', psalm['text'], re.S):
                chapter, verse = int(marker[1]), int(marker[2])
                excerpt = normalize(marker[3])
                original = normalize(corpus[('PSA', chapter)][verse])
                self.assertTrue(excerpt)
                if (chapter, verse) == (117, 1):
                    original = original.replace('האמים', 'האמות')  # Documented source spelling, never reader text.
                self.assertIn(excerpt, original, (date, chapter, verse))
                checked += 1
        self.assertGreater(checked, 600)

    def test_review_requires_exact_key_and_every_calendar_context(self):
        for key in (SIRACH, PSALM):
            self.assertEqual(reviewed_numbering(key, {"roman"})["sourceSystem"], "nabre")
            self.assertIsNone(reviewed_numbering(key, {"syriac"}))
            self.assertIsNone(reviewed_numbering(key, {"roman", "syriac"}))
            self.assertIsNone(reviewed_numbering(key, set()))
        self.assertIsNone(reviewed_numbering("daily|Psalm 103:1–2", {"roman"}))
        self.assertIsNone(reviewed_numbering(SIRACH.replace("daily|", "torah|"), {"torah"}))

    def test_manifest_rejects_missing_evidence_or_unexpected_text_fields(self):
        original = json.loads((TOOLS / "reading-source-numbering-reviews.json").read_text())
        for defect in ("text", "pin", "scope", "contexts"):
            data = deepcopy(original)
            row = data["appointments"][SIRACH]
            if defect == "text":
                row["evidence"]["text"] = "No Scripture belongs in this manifest"
            elif defect == "pin":
                row["evidence"]["appointmentSHA256"] = ""
            elif defect == "scope":
                row["sourceSystem"] = "english"
            else:
                row["contexts"] = ["roman", "roman"]
            with tempfile.TemporaryDirectory() as directory:
                path = Path(directory) / "reviews.json"
                path.write_text(json.dumps(data))
                with self.subTest(defect=defect), self.assertRaises(ValueError):
                    load_reviews(path)


class SourceNumberingIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        lock = json.loads(builder.LOCK.read_text())
        if any(source["format"] != "reviewed-verses" and not (builder.CACHE / source["cache"]).exists()
               for source in lock["sources"]):
            raise unittest.SkipTest("Pinned Bible source assemblies are not cached")
        cls.lock, cls.corpora = builder.load_pinned_corpora()
        cls.source = next(source for source in cls.lock["sources"] if source["id"] == "engDRA")
        cls.edition = next(edition for edition in cls.lock["editions"] if edition["id"] == "douay-rheims-1899")
        cls.chapters = builder.load_source(cls.source)  # Verifies the actual source hash.
        cls.nabre = NabreMapper(fixtures.inventory({("SIR", 27): 30, ("SIR", 28): 26,
                                                  ("PSA", 103): 22, ("LUK", 1): 80}))

    def corpus(self):
        return builder.PinnedCorpus(deepcopy(self.chapters), {"engDRA": self.source["sha256"]})

    def resolve(self, key, corpus=None, contexts=None):
        with patch("reading_nabre_mapping.mapper", return_value=self.nabre):
            return builder.resolve(key, {"roman"} if contexts is None else contexts,
                                   self.edition, self.corpus() if corpus is None else corpus)

    def test_september_13_runs_through_source_mapper_and_pinned_dra_target(self):
        corpus = self.corpus()
        sirach = self.resolve(SIRACH, corpus)
        self.assertEqual([(row["chapter"], row["verse"]) for row in sirach],
                         [(27, 33)] + [(28, verse) for verse in range(1, 10)])
        self.assertFalse(sirach.includes_whole_verses)
        for row in sirach:
            self.assertEqual(row["text"], self.chapters[("SIR", row["chapter"])][row["verse"]])
        cached_mapper = builder.edition_mapper(self.edition["id"], corpus)
        psalm = self.resolve(PSALM, corpus)
        self.assertEqual([(row["chapter"], row["verse"]) for row in psalm],
                         [(102, verse) for verse in (1, 2, 3, 4, 9, 10, 11, 12)])
        self.assertIs(builder.edition_mapper(self.edition["id"], corpus), cached_mapper)

    def test_complete_live_nabre_snapshot_resolves_the_verified_appointments(self):
        path = TOOLS / "versification/nabre/structure.json"
        if not path.exists() or not json.loads(path.read_text()).get("complete"):
            self.skipTest("The complete live NABRE marker inventory has not been produced yet")
        corpus = self.corpus()
        for key, expected in (
            (SIRACH, [(27, 33)] + [(28, verse) for verse in range(1, 10)]),
            (PSALM, [(102, verse) for verse in (1, 2, 3, 4, 9, 10, 11, 12)]),
        ):
            with self.subTest(key=key):
                rows = builder.resolve(key, {"roman"}, self.edition, corpus)
                self.assertEqual([(row["chapter"], row["verse"]) for row in rows], expected)

    def test_shared_key_cannot_reinterpret_an_unreviewed_calendar(self):
        for key in (SIRACH, PSALM):
            with self.subTest(key=key), self.assertRaises(builder.Unavailable):
                self.resolve(key, contexts={"roman", "syriac"})

    def test_september_13_psalm_uses_each_existing_edition_source(self):
        source_ids = {"hbo", "russyn", "TagAngBiblia", "FreCrampon", "ukr1871"}
        sources = {source["id"]: source for source in self.lock["sources"] if source["id"] in source_ids}
        if any(not (builder.CACHE / source["cache"]).exists() for source in sources.values()):
            self.skipTest("One or more pinned edition source caches are not present")
        expected_chapters = {"masoretic-delitzsch": 103, "synodal-1876": 102,
                             "ang-dating-biblia-1905": 103, "crampon-1923": 103, "kulish-1905": 103}
        for edition in self.lock["editions"]:
            if edition["id"] not in expected_chapters:
                continue
            corpus = self.corpora[edition["id"]]
            with self.subTest(edition=edition["id"]), patch("reading_nabre_mapping.mapper", return_value=self.nabre):
                rows = builder.resolve(PSALM, {"roman"}, edition, corpus)
                self.assertEqual([(row["chapter"], row["verse"]) for row in rows],
                                 [(expected_chapters[edition["id"]], verse) for verse in (1, 2, 3, 4, 9, 10, 11, 12)])
                for row in rows:
                    source_text = corpus[("PSA", row["chapter"])][row["verse"]]
                    if edition["languageCode"] == "he":
                        source_text = builder.preserve_divine_name_accents(source_text)
                    self.assertEqual(row["text"], source_text)

    def test_new_mapper_does_not_replace_the_september_10_source_review(self):
        key = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"
        with patch("reading_nabre_mapping.mapper", side_effect=AssertionError("Must use the existing review")):
            result = builder.resolve(key, {"roman"}, self.edition, self.corpus())
        self.assertEqual([(row["chapter"], row["verse"]) for row in result],
                         [(138, verse) for verse in (1, 2, 3, 4, 13, 14, 23, 24)])
        self.assertTrue(result.includes_whole_verses)

    def test_exact_nt_review_uses_target_labels_without_second_delitzsch_conversion(self):
        key = 'daily|2 Corinthians 13:3–13'
        edition = next(row for row in self.lock['editions'] if row['id'] == 'masoretic-delitzsch')
        corpus = self.corpora[edition['id']]
        with patch('delitzsch_numbering.source_references', side_effect=AssertionError('Already target labels')):
            rows = builder.resolve(key, {'ugcc', 'ugcc-gregorian'}, edition, corpus)
        self.assertEqual([row['verse'] for row in rows], list(range(3, 14)))
        self.assertIn('רוּחַ הַקֹּדֶשׁ', rows[-1]['text'])

    def test_legacy_appointment_path_retains_independent_source_exclusions(self):
        corpus = self.corpus()
        with patch.object(builder, "edition_mapper", return_value=SimpleNamespace(excluded_chapters={("MAT", 18)})):
            with self.assertRaisesRegex(builder.Unavailable, "excluded by its edition review"):
                builder.resolve("daily|Matthew 18:21–35", {"roman"}, self.edition, corpus)

    def test_edition_mapper_preserves_actual_delitzsch_complete_units(self):
        edition = next(row for row in self.lock["editions"] if row["id"] == "masoretic-delitzsch")
        source_ids = {"delitzsch-1901-3JN-1", "delitzsch-1901-REV-12", "delitzsch-1901-REV-13"}
        sources = [row for row in self.lock["sources"] if row["id"] in source_ids]
        if any(not (builder.CACHE / source["cache"]).exists() for source in sources):
            self.skipTest("Pinned Delitzsch source chapters are not present")
        corpus = self.corpora[edition["id"]]
        converter = NabreMapper(fixtures.inventory({("3JN", 1): 15, ("REV", 12): 18, ("REV", 13): 18}))
        for key, expected in (
            ("daily|3 John 1:15", [(1, 14), (1, 15)]),
            ("daily|Revelation 12:18", [(13, 1)]),
        ):
            with (self.subTest(key=key),
                  patch("reading_source_numbering_reviews.reviewed_numbering", return_value={"sourceSystem": "nabre"}),
                  patch("reading_nabre_mapping.mapper", return_value=converter)):
                rows = builder.resolve(key, {"roman"}, edition, corpus)
            self.assertEqual([(row["chapter"], row["verse"]) for row in rows], expected)
            self.assertTrue(rows.includes_whole_verses)
            book = "3JN" if "John" in key else "REV"
            for row in rows:
                self.assertEqual(row["text"], builder.preserve_divine_name_accents(
                    corpus[(book, row["chapter"])][row["verse"]]))

    def test_live_sirach_33_preserves_source_and_target_internal_boundaries(self):
        from reading_nabre_mapping import mapper
        source = mapper()
        target = self.corpus().dra_mapper()
        self.assertEqual(max(int(verse) for verse in source.inventory.chapter("SIR", 33)["verseOrder"]
                             if verse.isdigit()), max(self.chapters[("SIR", 33)]))
        for labels, expected, whole in (
            (("20a",), (20,), True),
            (("20a", "20b"), (20,), False),
            (("23",), (23, 24), True),
            (("24",), (24,), True),
            (("27",), (27, 28), True),
            (("28", "29"), (28, 29), True),
            (("31",), (31, 32, 33), True),
        ):
            standard, source_whole = source.to_standard([("SIR", 33, label) for label in labels])
            result, target_whole = target.from_standard(standard)
            with self.subTest(labels=labels):
                self.assertEqual(result, [("SIR", 33, verse) for verse in expected])
                self.assertEqual(source_whole or target_whole, whole)
        full_source = source.inventory.span("SIR", 33, 1, 33, 33)
        standard, source_whole = source.to_standard(full_source)
        result, target_whole = target.from_standard(standard)
        self.assertEqual(result, [("SIR", 33, verse) for verse in range(1, 34)])
        self.assertFalse(source_whole or target_whole)

    def test_target_source_pin_cannot_be_replaced_or_mixed(self):
        for pins in ({"engDRA": "0" * 64}, {"engDRA": self.source["sha256"], "other": "1" * 64}):
            corpus = builder.PinnedCorpus(self.chapters, pins)
            with self.subTest(pins=pins), self.assertRaisesRegex(ValueError, "differs from the source reviewed"):
                self.resolve(SIRACH, corpus)
        with self.assertRaisesRegex(ValueError, "hash-checked source assembly"):
            self.resolve(SIRACH, self.chapters)

    def test_missing_or_empty_source_verse_invalidates_the_whole_chapter(self):
        for defect in ("missing", "empty"):
            corpus = self.corpus()
            self.resolve(SIRACH, corpus)  # Also exercise the already-cached mapper.
            if defect == "missing":
                del corpus[("SIR", 28)][1]
            else:
                corpus[("SIR", 28)][1] = ""
            with self.subTest(defect=defect), self.assertRaises(builder.Unavailable):
                self.resolve(SIRACH, corpus)

    def test_partial_nabre_inventory_stops_regeneration_instead_of_hiding_an_error(self):
        with patch("reading_nabre_mapping.mapper", side_effect=InvalidInventory("incomplete inventory")):
            with self.assertRaisesRegex(InvalidInventory, "incomplete inventory"):
                builder.resolve(SIRACH, {"roman"}, self.edition, self.corpus())

    def test_existing_native_notice_carries_mapper_envelope_without_schema_change(self):
        key = "daily|Luke 1:73"
        small_lock = {"sources": [self.source], "editions": [self.edition]}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "sources.json"
            path.write_text(json.dumps(small_lock))
            with (patch.object(builder, "LOCK", path), patch.object(builder, "appointments", return_value={key: {"roman"}}),
                  patch("reading_source_numbering_reviews.reviewed_numbering", return_value={"sourceSystem": "nabre"}),
                  patch("reading_nabre_mapping.mapper", return_value=self.nabre)):
                payload = json.loads(builder.build()["readings-texts.json"])
        self.assertEqual(payload["schemaVersion"], 1)
        self.assertEqual(payload["wholeVersePassages"], [key])
        rows = payload["passages"][key][self.edition["id"]]
        self.assertEqual([row["verse"] for row in rows], [73, 74])
        self.assertTrue(all(set(row) == {"chapter", "verse", "text"} for row in rows))


if __name__ == "__main__":
    unittest.main()
