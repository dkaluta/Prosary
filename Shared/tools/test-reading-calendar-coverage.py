#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Registry, source-calendar numbering and legacy-key isolation regressions."""
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from reading_appointment_keys import DATA, LEGACY_DATASETS, appointments, passage_key, registry_datasets, split_passage_key
from reading_calendar_numbering import Unavailable, chapter_system, profile_for, standard_units
from reading_appointment_reviews import reviewed_appointment

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("calendar_coverage_builder", TOOLS / "build-reading-texts.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class CalendarCoverageTests(unittest.TestCase):
    def test_registry_and_pascha_variants_include_every_published_table(self):
        files = registry_datasets()
        self.assertEqual(files["roman"]["calendarIds"], {"lpj", "roman"})
        for dataset in ("stjames", "franciscan-conventual-italy", "augustinian-discalced",
                        "ugcc", "ugcc-gregorian", "ugcc-julian"):
            self.assertIn(dataset, files)
        keys = appointments()
        self.assertIn("daily|stjames|Psalm 80:9–20", keys)
        self.assertIn("daily|franciscan-conventual-italy|Psalm 121", keys)
        self.assertIn("daily|augustinian-discalced|Psalm 66", keys)

    def test_adding_a_table_cannot_alter_or_borrow_an_existing_citation_review(self):
        old = "daily|Psalm 139:1–3; 139:13–14ab; 139:23–24"
        new = passage_key(split_passage_key(old)[1], "stjames")
        keys = appointments()
        self.assertEqual(keys[old], {"roman"})
        self.assertIsNotNone(reviewed_appointment(old, {"roman"}))
        self.assertIsNone(reviewed_appointment(new, {"stjames"}))
        for dataset in LEGACY_DATASETS:
            self.assertEqual(passage_key("John 3:16", dataset), "daily|John 3:16")
        self.assertEqual(passage_key("John 3:16", "lpj"), "daily|John 3:16")

    def test_future_registered_table_is_discovered_without_a_code_list(self):
        with tempfile.TemporaryDirectory() as directory:
            data = Path(directory)
            (data / "calendars.json").write_text(json.dumps({"calendars": [
                {"id": "future-rite", "readingsFile": "readings-future-rite",
                 "paschaVariants": {"other": {"readingsFile": "readings-future-pascha"}}},
                {"id": "empty-rite", "readingsFile": "readings-empty-rite"},
            ]}))
            for table, citation in (("future-rite", "John 3:16"), ("future-pascha", "Luke 1:1")):
                (data / f"readings-{table}.json").write_text(json.dumps({"days": {
                    "2026-10-06": {"readings": [{"full": citation}]}}}))
            self.assertEqual(appointments(data), {
                "daily|future-rite|John 3:16": {"future-rite"},
                "daily|future-pascha|Luke 1:1": {"future-pascha"},
            })
            self.assertIn("empty-rite", registry_datasets(data))

    def test_stjames_uses_proved_hebrew_numbers_including_title_offsets(self):
        profile = profile_for("stjames", {"stjames"})
        book, spans = builder.parse_citation("Psalm 80:9–20", expand_subverses=True)
        refs, _ = standard_units("Psalm 80:9–20", spans, profile)
        self.assertEqual(book, "PSA")
        self.assertEqual(refs, [("PSA", 80, verse) for verse in range(8, 20)])
        _, spans = builder.parse_citation("Psalm 2:6–12", expand_subverses=True)
        self.assertEqual(standard_units("Psalm 2:6–12", spans, profile)[0][-1], ("PSA", 2, 12))
        _, spans = builder.parse_citation("Psalm 67:2–8", expand_subverses=True)
        self.assertEqual(standard_units("Psalm 67:2–8", spans, profile)[0],
                         [("PSA", 67, verse) for verse in range(1, 8)])

    def test_stjames_is_scoped_to_every_dated_bilingual_row_and_retains_printed_gaps(self):
        profile = profile_for("stjames", {"stjames"})
        self.assertEqual(len(profile["appointments"]), 261)
        self.assertEqual(sum(len(rows) for rows in profile["appointments"].values()), 373)
        for citation in profile["unavailableAppointments"]:
            with self.subTest(citation=citation), self.assertRaisesRegex(builder.Unavailable, "source correction"):
                builder.resolve(passage_key(citation, "stjames"), {"stjames"}, {"id": "fixture"}, {})
        with self.assertRaisesRegex(Unavailable, "exact bilingual source review"):
            standard_units("Psalm 90:12", [(90, 12, 90, 12)], profile)

    def test_order_whole_psalm_is_not_the_same_numbered_english_psalm(self):
        for dataset, citation, standard_chapter, maximum in (
            ("franciscan-conventual-italy", "Psalm 121", 122, 9),
            ("augustinian-discalced", "Psalm 66", 67, 7),
        ):
            profile = profile_for(dataset, {dataset})
            _, spans = builder.parse_citation(citation, expand_subverses=True,
                                               psalm_chapter_system=chapter_system(profile))
            self.assertEqual(standard_units(citation, spans, profile)[0],
                             [("PSA", standard_chapter, verse) for verse in range(1, maximum + 1)])

    def test_split_latin_chapters_do_not_import_unlisted_identity_bodies(self):
        profile = profile_for("augustinian-discalced", {"augustinian-discalced"})
        expected = {
            113: [("PSA", 114, verse) for verse in range(1, 9)] + [("PSA", 115, verse) for verse in range(1, 19)],
            114: [("PSA", 116, verse) for verse in range(1, 10)],
            115: [("PSA", 116, verse) for verse in range(10, 20)],
            146: [("PSA", 147, verse) for verse in range(1, 12)],
            147: [("PSA", 147, verse) for verse in range(12, 21)],
        }
        for chapter, wanted in expected.items():
            citation = f"Psalm {chapter}"
            _, spans = builder.parse_citation(citation, psalm_chapter_system=chapter_system(profile))
            with self.subTest(chapter=chapter):
                self.assertEqual(standard_units(citation, spans, profile), (wanted, False))

    def test_whole_psalms_and_unknown_verse_conventions_require_a_calendar_review(self):
        with self.assertRaises(builder.Unavailable): builder.parse_citation("Psalm 121", expand_subverses=True)
        with self.assertRaises(Unavailable): profile_for("stjames", {"roman", "stjames"})
        with self.assertRaises(Unavailable): profile_for("unregistered-rite", {"unregistered-rite"})
        with self.assertRaisesRegex(builder.Unavailable, "namespace"):
            builder.resolve("daily|John 3:16", {"stjames"}, {"id": "fixture"}, {})
        profile = profile_for("augustinian-discalced", {"augustinian-discalced"})
        _, spans = builder.parse_citation("Psalm 66:1–3", expand_subverses=True)
        with self.assertRaisesRegex(Unavailable, "verse boundaries"):
            standard_units("Psalm 66:1–3", spans, profile)

    def test_new_calendar_cannot_emit_different_actual_closing_clauses(self):
        legacy = "daily|2 Corinthians 13:11–13"
        scoped = "daily|augustinian-discalced|2 Corinthians 13:11–13"
        editions = [{"id": identifier, "languageCode": "en", "name": "Fixture",
                     "attribution": "Synthetic source", "sourceURL": "https://example.org"}
                    for identifier in ("ordinary", "merged-ending")]
        def passage(key, contexts, edition, corpus):
            return builder.ResolvedPassage([{"chapter": 13, "verse": 13,
                                             "text": edition["id"]}])
        def converter(identifier, corpus):
            target = 13 if identifier == "ordinary" else 14
            return SimpleNamespace(to_standard=lambda references: ([("2CO", 13, target)], False))
        with patch.object(builder, "load_pinned_corpora", return_value=(
                {"editions": editions}, {edition["id"]: {} for edition in editions})), \
             patch.object(builder, "appointments", return_value={legacy: {"roman"}, scoped: {"augustinian-discalced"}}), \
             patch.object(builder, "resolve", side_effect=passage), \
             patch.object(builder, "edition_mapper", side_effect=converter), \
             patch("reading_appointment_keys.registry_datasets", return_value={}):
            built = builder.build()
        payload = json.loads(built["readings-texts.json"])
        coverage = json.loads(built["readings-text-coverage.json"])
        self.assertIn(legacy, payload["passages"], "Original six-table key contract stays unchanged")
        self.assertNotIn(scoped, payload["passages"])
        self.assertEqual(set(coverage["unavailable"][scoped]), {edition["id"] for edition in editions})
        self.assertTrue(all("boundaries remain unreviewed" in reason
                            for reason in coverage["unavailable"][scoped].values()))


if __name__ == "__main__":
    unittest.main()
