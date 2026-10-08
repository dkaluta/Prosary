#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Verify provisional source/date boundaries, exact prose and deterministic native copies."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import unittest
from copy import deepcopy

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("mission_calendar", TOOLS / "import-mission-calendar.py")
importer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(importer)


class MissionCalendarTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = importer.SOURCE.read_bytes()
        cls.corrections = json.loads(importer.CORRECTIONS.read_text())
        cls.document = importer.build(cls.raw, cls.corrections)
        cls.events = importer.parse(cls.raw)[1]

    def test_explicit_source_dates_only(self):
        self.assertEqual(self.document["sourceEventCount"], 475)
        self.assertEqual(len(self.document["days"]), 365)
        self.assertEqual(set(self.document["days"]), {event["date"] for event in self.events})
        self.assertEqual(self.document["coverageStart"], "2026-01-01")
        self.assertEqual(self.document["coverageEnd"], "2026-12-31")
        self.assertFalse(any(key.startswith("2027-") for key in self.document["days"]))

    def test_source_prose_and_recurrence_preserved_without_execution(self):
        by_uid = {part["sourceUID"]: part for day in self.document["days"].values() for part in day["observances"]}
        for event in self.events:
            part = by_uid[event["UID"]]
            self.assertEqual(part["sourceTitleByLanguage"]["he"], event["SUMMARY"])
            self.assertEqual(part["sourceDescriptionByLanguage"]["he"], event["DESCRIPTION"])
            self.assertEqual(part["sourceRecurrence"], event.get("RRULE", ""))
            self.assertEqual(part["descriptionByLanguage"]["he"],
                             event["DESCRIPTION"].replace("נקודה לערעור:", "נקודה להרהור:"))
            self.assertTrue(part["reflectionByLanguage"]["he"])
            self.assertEqual(part["categories"], [])  # Source has not supplied categories yet.
            self.assertIn("© Evangelizo", part["descriptionCreditByLanguage"]["he"])

    def test_separate_mission_feasts_use_the_chosen_evangelizo_syriac_readings(self):
        registry = json.loads((importer.ROOT / "Shared/data/calendars.json").read_text())
        calendar = next(row for row in registry["calendars"] if row["id"] == "mission-provisional")
        self.assertTrue(calendar["provisional"])
        self.assertEqual(calendar["scope"], "Mission")
        self.assertEqual(calendar["readingsFile"], "readings-syriac")
        syriac = next(row for row in registry["calendars"] if row["id"] == "syriac")
        self.assertEqual(calendar["readingsFile"], syriac["readingsFile"])
        self.assertNotEqual(calendar["file"], next(row for row in registry["calendars"] if row["id"] == "syriac")["file"])
        self.assertEqual(set(calendar["nameByLanguage"]), {"he", "ar", "ru", "tl", "fr", "it", "uk"})
        readings = json.loads((importer.ROOT / "Shared/data/readings-syriac.json").read_text())
        self.assertIn("publication edition SYE", readings["$comment"])
        self.assertEqual([item["full"] for item in readings["days"]["2026-10-08"]["readings"]],
                         ["Ephesians 6:10–24", "John 15:12–24"])

    def test_regeneration_restores_only_the_explicit_mission_readings_mapping(self):
        registry = json.loads((importer.ROOT / "Shared/data/calendars.json").read_text())
        original = deepcopy(registry)
        mission = next(row for row in registry["calendars"] if row["id"] == "mission-provisional")
        for previous in [None, "readings-roman"]:
            with self.subTest(previous=previous):
                if previous is None:
                    mission.pop("readingsFile", None)
                else:
                    mission["readingsFile"] = previous
                self.assertEqual(importer.configure_registry(registry), original)
                self.assertEqual(mission.get("readingsFile"), previous)
        self.assertEqual(importer.configure_registry(original), original)

    def test_rebuild_is_byte_stable_and_native_copies_match(self):
        expected = (json.dumps(self.document, ensure_ascii=False, indent=2) + "\n").encode()
        self.assertEqual(importer.OUTPUT.read_bytes(), expected)
        for directory in ("iOS/Prosary/Data", "Android/app/src/main/assets/data", "Windows/Prosary/Data"):
            self.assertEqual((importer.ROOT / directory / importer.OUTPUT.name).read_bytes(), expected)
            self.assertEqual((importer.ROOT / directory / "calendars.json").read_bytes(),
                             (importer.ROOT / "Shared/data/calendars.json").read_bytes())
            self.assertEqual((importer.ROOT / directory / "readings-syriac.json").read_bytes(),
                             (importer.ROOT / "Shared/data/readings-syriac.json").read_bytes())

    def test_folded_unicode_and_escaped_categories(self):
        header, events = importer.parse("BEGIN:VCALENDAR\r\nBEGIN:VEVENT\r\nUID:test\r\nDTSTART;VALUE=DATE:20260301\r\nSUMMARY:שלום\\,\r\n  עולם\r\nCATEGORIES:Prayer\\, Hymn,Reflection\r\nEND:VEVENT\r\nEND:VCALENDAR".encode())
        self.assertEqual(events[0]["SUMMARY"], "שלום, עולם")
        self.assertEqual(importer.split_categories(events[0]["CATEGORIES"]), ["Prayer, Hymn", "Reflection"])
        self.assertEqual(importer.split_categories(r"Prayer\\,Reflection"), ["Prayer\\", "Reflection"])

    def test_changed_source_requires_review(self):
        with self.assertRaisesRegex(ValueError, "review"):
            importer.build(self.raw + b"\n", self.corrections)


if __name__ == "__main__":
    unittest.main()
