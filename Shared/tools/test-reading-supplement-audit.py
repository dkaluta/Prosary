#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Mutation checks assembled from pinned source rows, never passage resolvers.

The fixtures use reviewed source memberships and literal original wording. The
auditor must reject lost clauses even when verse coordinates still look valid.
"""
from contextlib import ExitStack
import copy
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

from arabic_daily_psalms import default_resolver as arabic_source
from greek_daily_psalms import default_resolver as greek_source
from martini_daily_psalms import default_resolver as martini_source
from reading_calendar_numbering import chapter_system, profile_for, standard_units
from reading_supplement_audit import audit_psalm_supplements

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("supplement_audit_parser", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

SUN = "daily|Psalm 19:2–3; 19:4–5"
WISDOM = "daily|Psalm 90:3–4; 90:5–6; 90:12–13; 90:14; 90:17"
FAITHFUL = "daily|Psalm 145:8–9; 145:10–11; 145:12–13ab; 145:13cd–14"
SCOPED_HEARING = "daily|stjames|Psalm 95:1–7"
UNPUBLISHED_WISDOM = "daily|stjames|Psalm 90:12"


class ReadingSupplementAuditTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # These constructors verify source hashes and expose original rows and
        # human-reviewed facts; none of their passage resolution methods is used.
        cls.arabic, cls.greek, cls.martini = arabic_source(), greek_source(), martini_source()

    def setUp(self):
        self.artifact = {"passages": {}, "passageSources": {}, "wholeVersePassages": []}
        self.contexts = {}
        self.add_original_rows(SUN, "jesuit-arabic-1897", self.arabic)
        self.add_original_rows(SUN, "martini", self.martini)
        self.add_original_rows(WISDOM, "jesuit-arabic-1897", self.arabic)

        review = self.greek.reviews[FAITHFUL]
        chapter = review["sourceChapter"]
        rows, blocks = [], []
        for label in review["sourceLabels"]:
            if label.isdigit():
                rows.append({"chapter": chapter, "verse": int(label), "text": self.greek.rows[chapter, label]})
                blocks.append({"id": f"grcbrent-psa-{chapter}-{label}", "kind": "verse",
                               "chapter": chapter, "verse": int(label)})
            else:
                blocks.append({"id": f"grcbrent-psa-{chapter}-{label}", "kind": "witness",
                               "printedLabel": label, "text": self.greek.rows[chapter, label],
                               "addresses": [{"chapter": chapter, "verse": int(label[:-1]), "part": "a"}]})
        descriptor = {"book": "PSA", "name": "Brenton Septuagint — Psalms",
                      "attribution": "Greek Septuagint, compiled by Sir Lancelot C. L. Brenton. Public domain; eBible.org grcbrent.",
                      "sourceURL": f"https://ebible.org/grcbrent/PSA{chapter:03d}.htm",
                      "isComplete": review["isComplete"], "contentBlocks": blocks}
        self.add(FAITHFUL, "brenton-lxx", rows, descriptor, review["includesWholeVerses"])

    def add(self, key, edition, rows, descriptor, wider, context="roman"):
        self.artifact["passages"].setdefault(key, {})[edition] = rows
        self.artifact["passageSources"].setdefault(key, {})[edition] = descriptor
        self.contexts[key] = {context}
        if wider and key not in self.artifact["wholeVersePassages"]:
            self.artifact["wholeVersePassages"].append(key)

    def arabic_descriptor(self, references):
        notes = [self.arabic.notes[ref] for ref in references if ref in self.arabic.notes]
        return {"book": "PSA", "name": "المزامير — الكتاب المقدس، بيروت 1897",
                "attribution": "Old Jesuit Arabic translation, Jesuit Press, Beirut, 1897. " + " ".join(notes),
                "sourceURL": ("https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/243" if notes
                              else "https://archive.org/details/AlKitabAlMoqadas"),
                "isComplete": True}

    def add_original_rows(self, key, edition, source):
        review = source.reviews[key]
        references = [tuple(ref) for ref in review["sourceReferences"]]
        rows = [{"chapter": chapter, "verse": verse, "text": source.rows[chapter, verse]}
                for chapter, verse in references]
        descriptor = (self.arabic_descriptor(references) if edition == "jesuit-arabic-1897" else
                      {"book": "PSA", "name": "Salmi — Bibbia Martini", "isComplete": True,
                       "attribution": "Bibbia Martini (1769–1781). Giovanni Novelli / Parola Viva, CC BY 4.0.",
                       "sourceURL": "https://parolaviva.art/opendata"})
        self.add(key, edition, rows, descriptor, review["includesWholeVerses"])

    def audit(self, artifact=None, contexts=None):
        # An accidentally circular audit cannot silently pass this suite.
        with ExitStack() as patches:
            forbidden = AssertionError("Expected rows must come from pinned source facts, not passage resolution")
            patches.enter_context(patch.object(builder, "resolve", side_effect=forbidden))
            for source in (self.arabic, self.greek, self.martini):
                patches.enter_context(patch.object(source, "resolve", side_effect=forbidden))
                if hasattr(source, "resolve_standard"):
                    patches.enter_context(patch.object(source, "resolve_standard", side_effect=forbidden))
            return audit_psalm_supplements(artifact if artifact is not None else self.artifact,
                                          contexts if contexts is not None else self.contexts, builder)

    def rename(self, old, new, context):
        self.artifact["passages"][new] = self.artifact["passages"].pop(old)
        self.artifact["passageSources"][new] = self.artifact["passageSources"].pop(old)
        self.contexts.pop(old)
        self.contexts[new] = {context}
        self.artifact["wholeVersePassages"] = [new if key == old else key
                                                for key in self.artifact["wholeVersePassages"]]

    def add_published_scoped_arabic_rows(self):
        citation = SCOPED_HEARING.split("|", 2)[2]
        profile = profile_for("stjames", {"stjames"})
        self.assertIn(citation, profile["appointments"])
        _, spans = builder.parse_citation(citation, expand_subverses=True,
                                         psalm_chapter_system=chapter_system(profile))
        requested, source_whole = standard_units(citation, spans, profile)
        wanted = set(requested)
        units = [(refs, targets) for refs, targets in self.arabic.units if wanted & targets]
        covered = set().union(*(targets for _, targets in units))
        self.assertTrue(wanted <= covered, "The published fixture needs unreviewed source clauses")
        references = sorted({ref for refs, _ in units for ref in refs})
        self.add(SCOPED_HEARING, "jesuit-arabic-1897",
                 [{"chapter": chapter, "verse": verse, "text": self.arabic.rows[chapter, verse]}
                  for chapter, verse in references],
                 self.arabic_descriptor(references), source_whole or bool(covered - wanted), "stjames")

    def test_literal_source_rows_and_incomplete_greek_witness_are_accepted(self):
        self.assertFalse(self.artifact["passageSources"][FAITHFUL]["brenton-lxx"]["isComplete"])
        self.assertEqual(self.audit()["sourcePinnedPsalmSupplementChecks"], 4)

    def test_deleted_requested_ending_row_or_clause_is_rejected(self):
        for remove_row in (False, True):
            changed = copy.deepcopy(self.artifact)
            rows = changed["passages"][SUN]["martini"]
            self.assertEqual((rows[-1]["chapter"], rows[-1]["verse"]), (18, 5))
            ending = "Ha posto nel sole il suo padiglione, "
            self.assertTrue(rows[-1]["text"].startswith(ending))
            if remove_row:
                rows.pop()
            else:
                rows[-1]["text"] = rows[-1]["text"][len(ending):]
            with self.subTest(remove_row=remove_row), self.assertRaisesRegex(ValueError, "Pinned Psalm source rows changed"):
                self.audit(changed)

    def test_same_coordinate_with_another_original_source_row_is_rejected(self):
        substitutions = [(SUN, "martini", self.martini.rows[18, 4]),
                         (WISDOM, "jesuit-arabic-1897", self.arabic.rows[89, 13]),
                         (FAITHFUL, "brenton-lxx", self.greek.rows[144, "9"])]
        for key, edition, wrong_text in substitutions:
            changed = copy.deepcopy(self.artifact)
            row = changed["passages"][key][edition][0]
            self.assertNotEqual(row["text"], wrong_text)
            row["text"] = wrong_text
            with self.subTest(edition=edition), self.assertRaisesRegex(ValueError, "Pinned Psalm source rows changed"):
                self.audit(changed)

    def test_missing_wider_unit_notice_is_rejected(self):
        for key in (SUN, FAITHFUL):
            changed = copy.deepcopy(self.artifact)
            changed["wholeVersePassages"].remove(key)
            with self.subTest(appointment=key), self.assertRaisesRegex(ValueError, "Wider Psalm source envelope lacks notice"):
                self.audit(changed)

    def test_wrong_or_empty_exact_calendar_context_is_rejected(self):
        for key in (SUN, WISDOM, FAITHFUL):
            for wrong in (set(), {"syriac"}, {"roman", "syriac"}):
                contexts = copy.deepcopy(self.contexts)
                contexts[key] = wrong
                with self.subTest(appointment=key, contexts=wrong), self.assertRaisesRegex(ValueError, "scope changed"):
                    self.audit(contexts=contexts)

    def test_greek_exact_witness_cannot_be_moved_to_another_dataset_namespace(self):
        self.rename(FAITHFUL, "daily|stjames|" + FAITHFUL.split("|", 1)[1], "stjames")
        with self.assertRaisesRegex(ValueError, "Greek source scope changed|lacks its exact bilingual source review"):
            self.audit()

    def test_torah_namespace_cannot_use_a_daily_psalm_supplement(self):
        self.rename(WISDOM, "torah|" + WISDOM.split("|", 1)[1], "torah")
        with self.assertRaisesRegex(ValueError, "escaped its scope"):
            self.audit()

    def test_verified_published_dataset_can_select_original_arabic_hearing_rows(self):
        self.add_published_scoped_arabic_rows()
        self.assertEqual(self.audit()["sourcePinnedPsalmSupplementChecks"], 5)
        contexts = copy.deepcopy(self.contexts)
        contexts[SCOPED_HEARING] = {"franciscan-conventual-italy"}
        with self.assertRaisesRegex(ValueError, "outside its registered source context"):
            self.audit(contexts=contexts)

    def test_unpublished_dataset_citation_cannot_borrow_an_available_original_row(self):
        ref = (89, 12)
        self.add(UNPUBLISHED_WISDOM, "jesuit-arabic-1897",
                 [{"chapter": ref[0], "verse": ref[1], "text": self.arabic.rows[ref]}],
                 self.arabic_descriptor([ref]), False, "stjames")
        with self.assertRaisesRegex(ValueError, "lacks its exact bilingual source review"):
            self.audit()

    def test_emitted_bounded_and_scoped_passages_require_their_source_descriptors(self):
        self.add_published_scoped_arabic_rows()
        cases = [(SUN, "jesuit-arabic-1897"), (SUN, "martini"), (FAITHFUL, "brenton-lxx"),
                 (SCOPED_HEARING, "jesuit-arabic-1897")]
        for key, edition in cases:
            changed = copy.deepcopy(self.artifact)
            del changed["passageSources"][key][edition]
            with self.subTest(appointment=key, edition=edition), self.assertRaisesRegex(
                    ValueError, "Pinned Psalm source descriptor disappeared"):
                self.audit(changed)
        changed = copy.deepcopy(self.artifact)
        del changed["passageSources"]
        with self.assertRaisesRegex(ValueError, "Pinned Psalm source descriptor disappeared"):
            self.audit(changed)

    def test_numeric_verse_one_cannot_be_replaced_by_true(self):
        changed = copy.deepcopy(self.artifact)
        first = changed["passages"][SUN]["martini"][0]
        self.assertEqual(first["verse"], 1)
        first["verse"] = True
        with self.assertRaisesRegex(ValueError, "Pinned Psalm source rows changed"):
            self.audit(changed)

    def test_lost_or_changed_greek_printed_thirteen_a_witness_is_rejected(self):
        for mutation in ("delete", "text", "label"):
            changed = copy.deepcopy(self.artifact)
            blocks = changed["passageSources"][FAITHFUL]["brenton-lxx"]["contentBlocks"]
            witness = next(block for block in blocks if block["kind"] == "witness")
            self.assertEqual(witness["printedLabel"], "13a")
            self.assertEqual(witness["text"], self.greek.rows[144, "13a"])
            if mutation == "delete":
                blocks.remove(witness)
            elif mutation == "text":
                witness["text"] = self.greek.rows[144, "13"]
            else:
                witness["printedLabel"] = "13"
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, "Greek printed witness changed"):
                self.audit(changed)

    def test_arabic_uncertainty_note_and_independent_witness_credit_are_required(self):
        note = self.arabic.notes[89, 12]
        self.assertIn("فاتي", self.arabic.rows[89, 12])
        for mutation in ("note", "url"):
            changed = copy.deepcopy(self.artifact)
            descriptor = changed["passageSources"][WISDOM]["jesuit-arabic-1897"]
            self.assertIn(note, descriptor["attribution"])
            if mutation == "note":
                descriptor["attribution"] = descriptor["attribution"].replace(note, "")
                reason = "Arabic printed uncertainty note disappeared"
            else:
                descriptor["sourceURL"] = "https://archive.org/details/AlKitabAlMoqadas"
                reason = "Arabic source credit changed"
            with self.subTest(mutation=mutation), self.assertRaisesRegex(ValueError, reason):
                self.audit(changed)

    def test_greek_completeness_requires_a_boolean(self):
        changed = copy.deepcopy(self.artifact)
        changed["passageSources"][FAITHFUL]["brenton-lxx"]["isComplete"] = 0
        with self.assertRaisesRegex(ValueError, "Greek source completeness changed"):
            self.audit(changed)


if __name__ == "__main__":
    unittest.main()
