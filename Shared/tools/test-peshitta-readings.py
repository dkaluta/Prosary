#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Network-free Peshitta script-pair, provenance and coverage regressions."""
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

from aramaic_script_converter import to_hebrew
from peshitta_reading_source import load_verses, paired_text, scripture_importer
from reading_edition_mapping import mapper
from reading_edition_reviews_peshitta import REVIEWED_ISAIAH
from reading_step_mapping import StepMapper, Unavailable
from peshitta_supplied_ot import (BOOKS, SHA256, chapter_issues, load_supplied_ot,
                                 parsed_books, review)

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
        for value in ("", "English substitute", "טקסט", None, "ܐܰܒ݁ܳܐܑ"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                paired_text(value)

    def test_ot_source_defects_are_explicit_not_overwritten(self):
        duplicate = ET.fromstring('<CHAPTER cnumber="1"><VERS vnumber="1">ܐܰ</VERS>'
                                 '<VERS vnumber="1">ܒܰ</VERS><VERS vnumber="3">ܓܰ</VERS></CHAPTER>')
        self.assertEqual(chapter_issues(duplicate, book="GEN"),
                         ["duplicate verse labels: 1", "missing verse labels: 2"])
        for bad in ('<VERS vnumber="1a">ܐܰ</VERS>',
                    '<VERS vnumber="0">ܐܰ</VERS>',
                    '<VERS vnumber="1"><NOTE>ܐܰ</NOTE></VERS>'):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                chapter_issues(ET.fromstring('<CHAPTER cnumber="1">'+bad+'</CHAPTER>'), book="GEN")

    def test_ot_hash_and_book_identity_are_required(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            parsed_books(b'<XMLBIBLE/>')
        node = ET.fromstring('<BIBLEBOOK bname="Genesis" bnumber="7"/>')
        with patch('peshitta_supplied_ot.parsed_books', return_value=[node]):
            with self.assertRaisesRegex(ValueError, "name/number"):
                load_supplied_ot({'book':'GEN','bookName':'Genesis'}, b'')

    def test_ot_exclusions_must_match_the_observed_source_defect(self):
        node = ET.fromstring('<BIBLEBOOK bname="Genesis" bnumber="1"><CHAPTER cnumber="1">'
                            '<VERS vnumber="1">ܐܰ</VERS><VERS vnumber="1">ܒܰ</VERS>'
                            '</CHAPTER></BIBLEBOOK>')
        metadata = {'chapterLabels':{'GEN':[1]},'excludedSourceChapters':{},
                    'reviewedSparseChapters':{}}
        with patch('peshitta_supplied_ot.parsed_books', return_value=[node]), \
             patch('peshitta_supplied_ot.review', return_value=metadata):
            with self.assertRaisesRegex(ValueError, "defects differ"):
                load_supplied_ot({'book':'GEN','bookName':'Genesis'}, b'')
            metadata['excludedSourceChapters']={'GEN':{'1':['duplicate verse labels: 1']}}
            self.assertEqual(load_supplied_ot({'book':'GEN','bookName':'Genesis'}, b''), {})

    def test_ot_boundary_review_does_not_infer_genesis_six_from_counts(self):
        from reading_edition_reviews_peshitta import PROFILES
        blocked = PROFILES['peshitta-1905']['blocked_chapters']
        for key in [('GEN',2),('GEN',5),('GEN',6),('EXO',32),('PSA',114),('SIR',3)]:
            self.assertIn(key, blocked)
        self.assertNotIn(('GEN',1), blocked)
        self.assertNotIn(('NUM',6), blocked)

    def test_reference_witnesses_record_disagreements_without_importing_their_words(self):
        witnesses = json.loads((TOOLS / 'peshitta-supplied-ot-witnesses.json').read_text())
        self.assertEqual(witnesses['sourceSHA256'], SHA256)
        self.assertEqual(len(witnesses['comparisons']), 27)
        by_chapter = {(row['book'],row['chapter']):row for row in witnesses['comparisons']}
        self.assertEqual(by_chapter['GEN',2]['differences'], [4])
        self.assertEqual(by_chapter['GEN',5]['differences'], [6,28])
        self.assertEqual(by_chapter['GEN',6]['differences'], [])
        # Even an exact independent match does not erase the observed moved clause.
        self.assertIn(6, review()['stepBoundaryRiskChapters']['GEN'])
        self.assertNotIn(6, review()['reviewedOrdinaryBoundaryChapters']['GEN'])
        for row in witnesses['comparisons']:
            self.assertNotIn('text', row)
            self.assertRegex(row['witnessSHA256'], r'^[0-9a-f]{64}$')

    def test_reviewed_commandments_do_not_depend_on_unreviewed_exodus_37(self):
        from reading_edition_reviews_peshitta import PROFILES
        profile = PROFILES['peshitta-1905']
        # Numeric inventory only: the source-specific textual evidence and pins
        # live in the profile review, not inferred from these fixture counts.
        corpus = {('EXO', 20): {verse: 2 for verse in range(1, 27)},
                  ('EXO', 37): {verse: 2 for verse in range(1, 30)}}
        excluded = {('EXO', 37)}
        ordinary = StepMapper(corpus, source_types={'Eng-KJV'}, excluded_chapters=excluded)
        with self.assertRaises(Unavailable):
            ordinary.to_standard([('EXO', 20, 13)])
        subject = StepMapper(corpus, source_types=profile['source_types'],
                             overrides=profile['overrides'], excluded_chapters=excluded,
                             excluded_rule_lines=profile['excluded_rule_lines'])
        for verse in range(1, 27):
            refs = [('EXO', 20, verse)]
            self.assertEqual(subject.to_standard(refs), (refs, False))
            self.assertEqual(subject.from_standard(refs), (refs, False))
        with self.assertRaises(Unavailable):
            subject.to_standard([('EXO', 37, 29)])

    def test_cached_ot_retains_source_text_and_the_nine_prayer_verses(self):
        path = builder.CACHE / f'arc-supplied-{SHA256}.xml'
        if not path.exists():
            self.skipTest('Full supplied XML is not cached; synthetic offline guards still run')
        raw = path.read_bytes()
        genesis = load_supplied_ot({'book':'GEN','bookName':'Genesis'}, raw)
        source = next(node for node in parsed_books(raw) if node.get('bname')=='Genesis')
        expected = {(int(c.get('cnumber')), int(v.get('vnumber'))): v.text for c in source for v in c}
        self.assertEqual(genesis, expected)
        isaiah = load_supplied_ot({'book':'ISA','bookName':'Isaiah'}, raw)
        prayers = scripture_importer().parse_supplied_peshitta_isaiah(raw.decode('utf-8-sig'))
        self.assertEqual({key:isaiah[key] for key in REVIEWED_ISAIAH}, prayers)
        exodus = load_supplied_ot({'book':'EXO','bookName':'Exodus'}, raw)
        self.assertFalse(any(chapter==32 for chapter,_ in exodus))

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
        for credit in ("1905", "Kiraz", "Walters", "CC BY 4.0", "unresolved"):
            self.assertIn(credit, edition["attribution"])

    def test_every_shipped_pair_is_exactly_the_established_projection(self):
        passages = 0
        for key, translations in self.payload["passages"].items():
            verses = translations.get("peshitta-1905", [])
            if not verses:
                continue
            passages += 1
            book, _ = builder.parse_citation(key.split("|", 1)[1], expand_subverses=True)
            self.assertIn(book, builder.NT | BOOKS.keys())
            for verse in verses:
                self.assertEqual(verse["text"], to_hebrew(verse["transliteratedText"]))
                self.assertRegex(verse["text"], r"[\u05d0-\u05ea]")
                self.assertRegex(verse["transliteratedText"], r"[\u0710-\u072f]")
        self.assertGreater(passages, 1770)

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

    def test_emitted_exodus_commandments_roundtrip_through_the_reviewed_graph(self):
        subject = mapper('peshitta-1905')
        for key in ('daily|Exodus 20:12–24', 'torah|Exodus 18:1–20:23'):
            verses = self.payload['passages'][key]['peshitta-1905']
            refs = [('EXO', verse['chapter'], verse['verse']) for verse in verses]
            self.assertEqual(subject.to_standard(refs), (refs, False), key)
            self.assertEqual(subject.from_standard(refs), (refs, False), key)

    def test_unreviewed_source_chapters_are_unavailable(self):
        subject = mapper("peshitta-1905")
        for reference in (("LUK", 10, 1), ("LUK", 11, 1), ("PHP", 1, 16),
                          ("3JN", 1, 14), ("REV", 12, 1), ("REV", 13, 1)):
            with self.subTest(reference=reference), self.assertRaises(Unavailable):
                subject.from_standard([reference])
        self.assertEqual(subject.from_standard([("GEN", 1, 1)])[0], [("GEN", 1, 1)])
        for ref in [('GEN',6,1),('PSA',114,1),('SIR',3,19)]:
            with self.subTest(ref=ref), self.assertRaises(Unavailable):
                subject.from_standard([ref])

    def test_source_manifest_keeps_the_nt_and_pins_reviewed_ot_books(self):
        sources = [row for row in self.lock["sources"] if row["id"].startswith("peshitta-")]
        self.assertEqual(len(sources), 72)
        self.assertEqual({row["book"] for row in sources}, builder.NT | BOOKS.keys())
        isaiah = next(row for row in sources if row["book"] == "ISA")
        self.assertEqual(isaiah["sha256"], scripture_importer().SUPPLIED_PESHITTA_SHA256)


if __name__ == "__main__":
    unittest.main()
