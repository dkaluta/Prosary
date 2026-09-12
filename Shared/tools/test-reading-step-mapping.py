#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only STEP regressions and pinned public-domain edition checks."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import reading_step_mapping as step
from reading_psalm_mapping import DRA_PSALM_SOURCE_OVERLAPS

TOOLS = Path(__file__).resolve().parent


def mapper(corpus, rows):
    with patch.object(step, "load_rules", return_value=tuple(rows)):
        return step.StepMapper(corpus, source_types={"Test"})


class StepMappingTests(unittest.TestCase):
    def test_cross_chapter_summary_yields_to_complete_detailed_edges(self):
        rows = [(1, "Test", "1Sa.20:2-21:1", "1Sa.20:2", "Concatenation", ""),
                (2, "Test", "1Sa.20:2", "1Sa.20:2!a", "Renumber verse", ""),
                (3, "Test", "1Sa.21:1", "1Sa.20:2!b", "DividedPrev verse", "")]
        subject = mapper({("1SA", 20): {1: 2, 2: 3}, ("1SA", 21): {1: 4, 2: 5}}, rows)
        self.assertEqual(subject.from_standard([("1SA", 20, 2)]),
                         ([("1SA", 20, 2), ("1SA", 21, 1)], False))
        with patch.object(step, "load_rules", return_value=rows):
            incomplete = step.StepMapper(subject.corpus, source_types={"Test"},
                                         excluded_chapters={("1SA", 21)})
        with self.assertRaises(step.Unavailable):
            incomplete.from_standard([("1SA", 20, 2)])

    def test_absent_generic_label_does_not_block_specific_moved_verse(self):
        rows = [(1, "AllBibles", "Rom.16:27", "Rom.16:27", "Keep verse", ""),
                (2, "Test", "Rom.14:26", "Rom.16:27", "Renumber verse", "")]
        subject = mapper({("ROM", 14): {26: 9}}, rows)
        self.assertEqual(subject.from_standard([("ROM", 16, 27)]), ([("ROM", 14, 26)], False))

    def test_excluded_chapter_is_unknown_not_evidence_of_a_shorter_bible(self):
        corpus = {("GEN", 1): {1: 2, 2: 3}, ("GEN", 2): {1: 4}}
        with patch.object(step, "load_rules", return_value=()):
            subject = step.StepMapper(corpus, source_types={"Test"}, excluded_chapters={("GEN", 1)})
        for condition in ("Gen.1:2=Last", "Gen.1:3=NotExist", "Gen.1:1=Exist",
                          "Gen.1:Title=NotExist", "Gen.1:TextBeforeV1=NotExist",
                          "Gen.1:1.1=NotExist", "Gen.1:1<Gen.2:1"):
            self.assertIsNone(subject.test(condition), condition)
        with self.assertRaises(step.Unavailable):
            subject.to_standard([("GEN", 1, 1)])

    def test_explicit_local_rule_selection_and_exclusion(self):
        rows = [(1, "Other", "Gen.1:1", "Gen.1:2", "Renumber", ""),
                (2, "Other", "Gen.1:2", "Gen.1:1", "Renumber", "")]
        with patch.object(step, "load_rules", return_value=rows):
            subject = step.StepMapper({("GEN", 1): {1: 2, 2: 3}}, source_types={"Other"},
                                      local_rule_lines={1}, excluded_rule_lines={2})
        self.assertEqual(subject.forward[("GEN", 1, 1)], {("GEN", 1, 2)})
        self.assertEqual(subject.forward[("GEN", 1, 2)], {("GEN", 1, 2)})

    def test_word_count_predicates_do_not_use_character_count(self):
        subject = mapper({("GEN", 1): {1: "lengthy", 2: "a b c", 3: "one two"}}, [])
        self.assertTrue(subject.test("Gen.1:1 < Gen.1:2"))
        self.assertTrue(subject.test("Gen.1:1 + Gen.1:3 > Gen.1:3"))
        self.assertFalse(subject.test("Gen.1:1*2 > Gen.1:2"))
        self.assertIsNone(subject.test("Gen.1:4 > Gen.1:1"))

    def test_predicates_require_numbering_evidence_not_missing_chapters(self):
        subject = mapper({("GEN", 1): {1: 2, 2: 4}, ("GEN", 2): {1: 1, 3: 2}}, [])
        self.assertTrue(subject.test("Gen.1:3=NotExist"))
        self.assertFalse(subject.test("Gen.1:4=NotExist"))
        self.assertFalse(subject.test("Exo.1:5=NotExist"))
        self.assertTrue(subject.test("Gen.1:2=Last"))
        self.assertFalse(subject.test("Gen.2:3=Last"))
        self.assertIsNone(subject.test("Gen.1:1.a=Exist"))
        self.assertIsNone(subject.test("unknown operation"))

    def test_subverse_absence_requires_an_explicit_complete_label_inventory(self):
        corpus = {("GEN", 1): {1: 2}}
        with patch.object(step, "load_rules", return_value=()):
            unknown = step.StepMapper(corpus, source_types={"Test"})
            undivided = step.StepMapper(corpus, source_types={"Test"}, subverse_labels=())
            divided = step.StepMapper(corpus, source_types={"Test"},
                                      subverse_labels={("GEN", 1, 1, ".1")})
        self.assertIsNone(unknown.test("Gen.1:1.1=NotExist"))
        self.assertTrue(undivided.test("Gen.1:1.1=NotExist"))
        self.assertFalse(undivided.test("Gen.1:2.1=NotExist"))
        self.assertTrue(divided.test("Gen.1:1.1=Exist"))
        self.assertFalse(divided.test("Gen.1:1.1=NotExist"))

    def test_lettered_chapters_and_compound_references_preserve_labels(self):
        self.assertEqual(step.reference_atoms("Est.A:1-2"),
                         (("EST", "A", 1, ""), ("EST", "A", 2, "")))
        self.assertEqual(step.reference_atoms("Sir.41:23-24; 42:1"),
                         (("SIR", 41, 23, ""), ("SIR", 41, 24, ""), ("SIR", 42, 1, "")))
        with self.assertRaises(step.Unavailable):
            step.reference_atoms("Est.A:1-B:2")

    def test_short_condition_inherits_only_the_explicit_rule_book(self):
        subject = mapper({("SIR", 33): {1: 1, 2: 2}}, [])
        self.assertIsNone(subject.test("33:2=Exist"))
        self.assertTrue(subject.test("33:2=Exist", default_book="Sir"))
        self.assertFalse(subject.test("33:2=Exist", default_book="Gen"))

    def test_divided_and_merged_verses_keep_whole_source_envelopes(self):
        rows = [
            [1, "Test", "Gen.1:1.a", "Gen.1:1", "DividedNext verse", ""],
            [2, "Test", "Gen.1:1.b", "Gen.1:2", "DividedPrev verse", ""],
            [3, "Test", "Gen.1:2", "Gen.1:3.a", "MergedNext verse", ""],
            [4, "Test", "Gen.1:3", "Gen.1:3.b", "MergedPrev verse", ""],
        ]
        subject = mapper({("GEN", 1): {1: 1, 2: 1, 3: 1}}, rows)
        self.assertEqual(subject.from_standard([("GEN", 1, 1)]), ([("GEN", 1, 1)], True))
        self.assertEqual(subject.from_standard([("GEN", 1, 1), ("GEN", 1, 2)]),
                         ([("GEN", 1, 1)], False))
        self.assertEqual(subject.from_standard([("GEN", 1, 3)]),
                         ([("GEN", 1, 2), ("GEN", 1, 3)], False))
        self.assertEqual(subject.to_standard([("GEN", 1, 2)]), ([("GEN", 1, 3)], True))
        self.assertEqual(subject.to_standard([("GEN", 1, 2), ("GEN", 1, 3)]),
                         ([("GEN", 1, 3)], False))

    def test_additions_do_not_become_ordinary_numbered_verses(self):
        rows = [[1, "Test", "Gen.1:1", "Gen.1:1*a-b", "MovedFrom verse", ""]]
        subject = mapper({("GEN", 1): {1: 1}}, rows)
        with self.assertRaises(step.Unavailable):
            subject.from_standard([("GEN", 1, 1)])
        with self.assertRaises(step.Unavailable):
            subject.to_standard([("GEN", 1, 1)])

    def test_empty_placeholders_and_generic_notes_cannot_undo_renumbering(self):
        rows = [
            [1, "Test", "Gen.1:1", "Gen.1:2", "Renumber verse", ""],
            [2, "Test", "Gen.1:1", "Gen.1:1", "IfEmpty verse", ""],
            [3, "AllBibles", "Gen.1:1", "Gen.1:1", "Keep verse", ""],
        ]
        subject = mapper({("GEN", 1): {1: 1}}, rows)
        self.assertEqual(subject.to_standard([("GEN", 1, 1)]), ([("GEN", 1, 2)], False))
        with self.assertRaises(step.Unavailable):
            subject.from_standard([("GEN", 1, 1)])

    def test_bad_summary_is_replaced_only_by_complete_valid_details(self):
        rows = [
            [1, "Test", "Jdt.2:8", "Jdt.2:16-8", "Concatenation", ""],
            [2, "Test", "Jdt.2:8!a", "Jdt.2:16", "Renumber verse", ""],
            [3, "Test", "Jdt.2:8!b", "Jdt.2:17", "MergedPrev verse", ""],
        ]
        subject = mapper({("JDT", 2): {8: 1}}, rows)
        self.assertEqual(subject.to_standard([("JDT", 2, 8)]),
                         ([("JDT", 2, 16), ("JDT", 2, 17)], False))
        subject = mapper({("JDT", 2): {8: 1}}, rows[:1])
        with self.assertRaises(step.Unavailable):
            subject.to_standard([("JDT", 2, 8)])

    def test_conflicting_rules_and_unknown_conditions_are_unavailable(self):
        for rows in (
            [[1, "Test", "Gen.1:1", "Gen.2:1", "Renumber verse", ""],
             [2, "Test", "Gen.1:1", "Gen.2:2", "Renumber verse", ""]],
            [[1, "Test", "Gen.1:1", "Gen.2:1", "Renumber verse", "Gen.1:1.a=Exist"]],
        ):
            subject = mapper({("GEN", 1): {1: 1}}, rows)
            with self.assertRaises(step.Unavailable):
                subject.to_standard([("GEN", 1, 1)])
            with self.assertRaises(step.Unavailable):
                subject.from_standard([("GEN", 2, 1)])

    def test_missing_verse_does_not_silently_remove_part_of_a_passage(self):
        subject = mapper({("GEN", 1): {1: 1, 2: "", 3: 1}}, [])
        for operation in (subject.from_standard, subject.to_standard):
            with self.assertRaises(step.Unavailable):
                operation([("GEN", 1, verse) for verse in range(1, 4)])

    def test_variable_boundaries_require_the_complete_group(self):
        subject = mapper({("LUK", 1): {73: 1, 74: 1}}, [])
        self.assertEqual(subject.from_standard([("LUK", 1, 73)]),
                         ([("LUK", 1, 73), ("LUK", 1, 74)], True))
        self.assertEqual(subject.from_standard([("LUK", 1, 73), ("LUK", 1, 74)]),
                         ([("LUK", 1, 73), ("LUK", 1, 74)], False))
        partial = mapper({("LUK", 1): {73: 1}}, [])
        with self.assertRaises(step.Unavailable):
            partial.from_standard([("LUK", 1, 73)])

    def test_cross_chapter_variable_boundary_never_invents_verse_zero(self):
        subject = mapper({("JHN", 6): {71: 1}, ("JHN", 7): {1: 1}}, [])
        self.assertEqual(subject.from_standard([("JHN", 7, 1)]),
                         ([("JHN", 6, 71), ("JHN", 7, 1)], True))

    def test_only_audited_edition_has_automatic_tradition_selection(self):
        with self.assertRaises(ValueError):
            step.StepMapper({}, "synodal-1876")
        self.assertIn("Latin2-DRA", step._default_types("douay-rheims-1899"))

    def test_metadata_pin_rejects_a_modified_rules_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            for name in ("rules.json", "sources.json"):
                (path / name).write_bytes((step.DIRECTORY / name).read_bytes())
            (path / "rules.json").write_bytes((path / "rules.json").read_bytes() + b" ")
            step.load_rules.cache_clear()
            with patch.object(step, "DIRECTORY", path), self.assertRaises(ValueError):
                step.load_rules()
            step.load_rules.cache_clear()

    def test_complete_import_contains_only_reference_fields(self):
        data = json.loads((step.DIRECTORY / "rules.json").read_text())
        self.assertEqual(set(data), {"schemaVersion", "fields", "rules"})
        self.assertEqual(data["fields"], ["sourceLine", "sourceType", "source", "standard", "action", "tests"])
        self.assertEqual(len(data["rules"]), 22874)
        self.assertTrue(all(len(row) == 6 for row in data["rules"]))
        self.assertGreater(len(step.rules_for_source_type("Hebrew")), 2000)
        self.assertTrue(all(not row[5] for row in step.rules_for_source_type("Hebrew", unconditional_only=True)))


@unittest.skipUnless((TOOLS / ".scripture-cache/daily-readings/engDRA_vpl.zip").exists(),
                     "Pinned public-domain DRA source cache is not present")
class PinnedDraMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location("reading_builder_for_step_test", TOOLS / "build-reading-texts.py")
        builder = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(builder)
        lock = json.loads((TOOLS / "reading-text-sources.json").read_text())
        source = next(row for row in lock["sources"] if row["id"] == "engDRA")
        # These reviewed overrides cannot silently attach to a replacement edition.
        if source["sha256"] != "96282bfa7c89a74680cea66fe873aafa5e7cd446407f0ff2531a723e19eee2c2":
            raise AssertionError("Review the DRA mapping overrides against the new source")
        cls.corpus = builder.load_source(source)
        cls.mapper = step.StepMapper(cls.corpus, "douay-rheims-1899", overrides=DRA_PSALM_SOURCE_OVERLAPS)

    def test_september_thirteenth_sirach_and_psalm_correspondence(self):
        requested = [("SIR", 27, 30)] + [("SIR", 28, verse) for verse in range(1, 8)]
        self.assertEqual(self.mapper.from_standard(requested),
                         ([("SIR", 27, 33)] + [("SIR", 28, verse) for verse in range(1, 10)], False))
        psalm = [("PSA", 103, verse) for verse in (1, 2, 3, 4, 9, 10, 11, 12)]
        self.assertEqual(self.mapper.from_standard(psalm),
                         ([("PSA", 102, verse) for verse in (1, 2, 3, 4, 9, 10, 11, 12)], False))

    def test_sirach_split_groups_expand_only_when_required(self):
        self.assertEqual(self.mapper.from_standard([("SIR", 28, 6)]),
                         ([("SIR", 28, 6), ("SIR", 28, 7)], False))
        self.assertEqual(self.mapper.from_standard([("SIR", 28, 7)]),
                         ([("SIR", 28, 8), ("SIR", 28, 9)], False))
        self.assertEqual(self.mapper.to_standard([("SIR", 28, 6)]), ([("SIR", 28, 6)], True))

    def test_dra_local_greek_divisions_do_not_inherit_latin_identity(self):
        self.assertEqual(self.mapper.to_standard([("2CO", 13, 12)]),
                         ([("2CO", 13, 12), ("2CO", 13, 13)], False))
        self.assertEqual(self.mapper.to_standard([("2CO", 13, 13)]),
                         ([("2CO", 13, 14)], False))
        self.assertEqual(self.mapper.from_standard([("2CO", 13, 13)]),
                         ([("2CO", 13, 12)], True))
        self.assertEqual(self.mapper.to_standard([("PHP", 1, 16)]), ([("PHP", 1, 17)], False))
        self.assertEqual(self.mapper.to_standard([("PHP", 1, 17)]), ([("PHP", 1, 16)], False))
        self.assertEqual(self.mapper.from_standard([("PHP", 1, 16)]), ([("PHP", 1, 17)], False))

    def test_sirach_33_missing_step_rows_do_not_imply_equal_numbering(self):
        self.assertEqual(self.mapper.from_standard([("SIR", 33, 19)]),
                         ([("SIR", 33, 20)], False))
        self.assertEqual(self.mapper.from_standard([("SIR", 33, 20)]),
                         ([("SIR", 33, 21)], False))
        # Equal source/NABRE chapter lengths conceal different internal clauses.
        self.assertEqual(self.mapper.from_standard([("SIR", 33, 22)]),
                         ([("SIR", 33, 23), ("SIR", 33, 24)], True))
        self.assertEqual(self.mapper.from_standard([("SIR", 33, 26)]),
                         ([("SIR", 33, 27), ("SIR", 33, 28)], True))
        self.assertEqual(self.mapper.to_standard([("SIR", 33, 31)]),
                         ([("SIR", 33, 30), ("SIR", 33, 31)], True))
        self.assertEqual(self.mapper.from_standard([("SIR", 33, 31)]),
                         ([("SIR", 33, 31), ("SIR", 33, 32), ("SIR", 33, 33)], True))
        self.assertEqual(self.mapper.from_standard([("SIR", 33, verse) for verse in range(1, 32)]),
                         ([("SIR", 33, verse) for verse in range(1, 34)], False))

    def test_sirach_33_incomplete_target_never_uses_the_reviewed_graph(self):
        from copy import deepcopy
        corpus = deepcopy(self.corpus)
        del corpus[("SIR", 33)][33]
        subject = step.StepMapper(corpus, "douay-rheims-1899")
        with self.assertRaises(step.Unavailable):
            subject.from_standard([("SIR", 33, 19)])

    def test_real_source_renumbering_survives_empty_placeholder_annotations(self):
        self.assertEqual(self.mapper.to_standard([("GEN", 49, 32)]), ([("GEN", 49, 33)], False))
        with self.assertRaises(step.Unavailable):
            self.mapper.from_standard([("GEN", 49, 32)])
        self.assertEqual(self.mapper.to_standard([("1KI", 22, 44)])[0], [("1KI", 22, 43)])
        self.assertEqual(self.mapper.to_standard([("SIR", 42, 1)])[0],
                         [("SIR", 41, 23), ("SIR", 41, 24), ("SIR", 42, 1)])
        self.assertEqual(self.mapper.to_standard([("JDT", 2, 8)])[0],
                         [("JDT", 2, 16), ("JDT", 2, 17)])

    def test_mapped_sources_always_exist_and_roundtrip_as_whole_envelopes(self):
        self.assertFalse(self.mapper.blocked_sources)
        self.assertFalse(self.mapper.blocked_targets)
        checked = 0
        for standard, sources in self.mapper.reverse.items():
            if standard in self.mapper.blocked_targets:
                continue
            mapped, _ = self.mapper.from_standard([standard])
            for source in mapped:
                self.assertTrue(self.corpus[source[:2]][source[2]].strip())
                self.assertIn(standard, self.mapper.to_standard([source])[0])
            checked += 1
        self.assertGreater(checked, 30000)


if __name__ == "__main__":
    unittest.main()
