#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Registry provenance, incomplete-source, and cross-edition unit regressions."""
from contextlib import contextmanager
import copy
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import reading_edition_mapping as registry
from reading_step_mapping import Unavailable


def references(book, chapter, first, last):
    return [(book, chapter, verse) for verse in range(first, last + 1)]


def fixture_record():
    return {"sourcePins": {"fixture": "a" * 64}, "corpusSHA256": "b" * 64,
            "systems": {"ot": "eng", "nt": "eng"},
            "chapters": [["PHM", 1, [[verse, 2] for verse in range(1, 26)]]]}


def fixture_mapper(record=None):
    record = record if record is not None else fixture_record()
    profile = {"source_pin_digest": registry.source_pin_digest(record["sourcePins"]),
               "source_types": set(), "local_rule_lines": set(), "overrides": {},
               "blocked_chapters": set(), "reviewed_inventory_exceptions": set()}
    return registry.EditionMapper("ang-dating-biblia-1905", record, profile=profile)


class InventoryValidationTests(unittest.TestCase):
    def test_numeric_inventory_preserves_zero_counts_for_completeness_checks(self):
        record = fixture_record()
        record["chapters"][0][2][4][1] = 0
        corpus = registry.validate_record(record)
        self.assertEqual(corpus["PHM", 1][5], 0)
        mapper = fixture_mapper(record)
        self.assertFalse(mapper.chapter_available("PHM", 1))
        for method in (mapper.to_standard, mapper.from_standard):
            with self.assertRaises(Unavailable):
                method([("PHM", 1, 1)])

    def test_missing_interior_or_final_source_verse_blocks_the_whole_chapter(self):
        for index in (4, -1):
            record = fixture_record()
            record["chapters"][0][2].pop(index)
            mapper = fixture_mapper(record)
            self.assertIn(("PHM", 1), mapper.excluded_chapters)
            self.assertFalse(mapper.chapter_available("PHM", 1))
            with self.assertRaises(Unavailable):
                mapper.from_standard([("PHM", 1, 1)])

    def test_reviewed_maximum_exception_still_requires_every_interior_label(self):
        record = fixture_record()
        record["chapters"][0][2].pop(4)
        profile = {"source_pin_digest": registry.source_pin_digest(record["sourcePins"]),
                   "source_types": set(), "overrides": {},
                   "reviewed_inventory_exceptions": {("PHM", 1)}}
        subject = registry.EditionMapper("ang-dating-biblia-1905", record, profile=profile)
        self.assertIn(("PHM", 1), subject.excluded_chapters)
        with self.assertRaises(Unavailable):
            subject.to_standard([("PHM", 1, 1)])

    def test_corrupt_metadata_cannot_be_used_as_bible_words_or_numbering(self):
        mutations = (
            lambda r: r.update(text="Scripture is not inventory metadata"),
            lambda r: r.pop("systems"),
            lambda r: r.update(sourcePins={}),
            lambda r: r.update(sourcePins={"fixture": "not-a-hash"}),
            lambda r: r.update(corpusSHA256="not-a-hash"),
            lambda r: r.update(systems={"ot": "guessed", "nt": "eng"}),
            lambda r: r.update(systems={"ot": [], "nt": "eng"}),
            lambda r: r.update(chapters=[]),
            lambda r: r["chapters"][0].__setitem__(0, "AAA"),
            lambda r: r["chapters"][0].__setitem__(1, True),
            lambda r: r["chapters"].append(copy.deepcopy(r["chapters"][0])),
            lambda r: r["chapters"][0][2].append([1, 2]),
            lambda r: r["chapters"][0][2].__setitem__(0, [True, 2]),
            lambda r: r["chapters"][0][2].__setitem__(0, [1, True]),
            lambda r: r["chapters"][0][2].__setitem__(0, [0, 2]),
            lambda r: r["chapters"][0][2].__setitem__(0, [1, -1]),
            lambda r: r["chapters"][0][2].__setitem__(0, [1, 10001]),
            lambda r: r["chapters"][0][2].__setitem__(0, [1, "unreviewed words"]),
        )
        for index, mutate in enumerate(mutations):
            record = fixture_record()
            mutate(record)
            with self.subTest(mutation=index), self.assertRaises(ValueError):
                registry.validate_record(record)

    def test_public_references_reject_boolean_and_float_integer_aliases(self):
        mapper = fixture_mapper()
        self.assertEqual(mapper.to_standard([("PHM", 1, 1)]), ([("PHM", 1, 1)], False))
        for requested in ([], [("PHM", True, 1)], [("PHM", 1, True)],
                          [("PHM", 1.0, 1)], [("PHM", 1, 1.0)],
                          [("PHM", 0, 1)], [("PHM", 1, -1)],
                          [("PHM", 1, 1, "a")], [(["PHM"], 1, 1)],
                          [("PHM", "1", 1)], [("PHM", "AA", 1)]):
            for method in (mapper.to_standard, mapper.from_standard):
                with self.subTest(refs=requested, method=method.__name__), self.assertRaises(Unavailable):
                    method(requested)

    def test_builder_source_verification_binds_words_inventory_and_source_pins(self):
        corpus = {("PHM", 1): {verse: f"fixture {verse}" for verse in range(1, 26)}}
        record = fixture_record()
        record["corpusSHA256"] = registry.corpus_digest(corpus)
        mapper = fixture_mapper(record)
        mapper.validate_source(corpus, record["sourcePins"])
        for text in ("changed fixture", "", "fixture 1 extra"):
            changed = copy.deepcopy(corpus)
            changed["PHM", 1][1] = text
            with self.assertRaises(ValueError):
                mapper.validate_source(changed, record["sourcePins"])
        missing = copy.deepcopy(corpus)
        del missing["PHM", 1][1]
        with self.assertRaises(ValueError):
            mapper.validate_source(missing, record["sourcePins"])
        with self.assertRaises(ValueError):
            mapper.validate_source(corpus, {"fixture": "c" * 64})
        with self.assertRaises(ValueError):
            registry.EditionMapper("ang-dating-biblia-1905", record,
                profile={"source_pin_digest": "0" * 64})


class RegistryProvenanceTests(unittest.TestCase):
    def tearDown(self):
        registry.mapper.cache_clear()
        registry.load_inventory.cache_clear()

    @contextmanager
    def staged_inventory(self, *, mutate_data=None, mutate_provenance=None, corrupt_bytes=False):
        data = {"schemaVersion": 1, "standard": "STEP", "method": registry.METHOD,
                "editions": {edition: fixture_record() for edition in registry.EDITION_IDS}}
        if mutate_data:
            mutate_data(data)
        raw = json.dumps(data, separators=(",", ":")).encode()
        provenance = {"schemaVersion": 1, "inventorySHA256": hashlib.sha256(raw).hexdigest(),
                      "reviewFiles": {name: hashlib.sha256((registry.TOOLS / name).read_bytes()).hexdigest()
                                      for name in registry.REVIEW_FILES}, "coverage": {}}
        if mutate_provenance:
            mutate_provenance(provenance)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            inventory = path / "inventories.json"
            inventory.write_bytes(raw + (b" " if corrupt_bytes else b""))
            (path / "sources.json").write_text(json.dumps(provenance))
            with patch.object(registry, "INVENTORIES", inventory), patch.object(registry, "DIRECTORY", path):
                registry.load_inventory.cache_clear()
                try:
                    yield
                finally:
                    registry.load_inventory.cache_clear()

    def test_corrupt_bytes_and_missing_or_changed_review_pins_fail_closed(self):
        changes = (
            {"corrupt_bytes": True},
            {"mutate_provenance": lambda p: p.update(reviewFiles={})},
            {"mutate_provenance": lambda p: p["reviewFiles"].pop("reading_edition_reviews_arabic.py")},
            {"mutate_provenance": lambda p: p["reviewFiles"].update({"reading_step_mapping.py": "0" * 64})},
            {"mutate_provenance": lambda p: p["reviewFiles"].update({"../../outside.py": "0" * 64})},
        )
        for change in changes:
            with self.subTest(change=list(change)), self.staged_inventory(**change), self.assertRaises(ValueError):
                registry.load_inventory()

    def test_wrong_schema_hub_method_or_edition_set_cannot_load(self):
        mutations = (
            lambda d: d.update(schemaVersion=2), lambda d: d.update(standard="SIL"),
            lambda d: d.update(method="unreviewed"), lambda d: d["editions"].pop("martini"),
            lambda d: d["editions"].update({"unknown": fixture_record()}),
        )
        for mutate in mutations:
            with self.staged_inventory(mutate_data=mutate), self.assertRaises(ValueError):
                registry.load_inventory()


class BundledEditionMappingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.records = registry.load_inventory()

    def test_standalone_all_editions_and_conversion_never_open_bible_wording(self):
        original_bytes, original_text = Path.read_bytes, Path.read_text
        def check(path):
            absolute = path.resolve()
            if (".scripture-cache" in absolute.parts or "content" in absolute.parts
                    or absolute.name == "readings-texts.json"):
                raise AssertionError(f"Standalone mapper opened Bible wording: {absolute.name}")
        def read_bytes(path, *args, **kwargs):
            check(path)
            return original_bytes(path, *args, **kwargs)
        def read_text(path, *args, **kwargs):
            check(path)
            return original_text(path, *args, **kwargs)
        registry.mapper.cache_clear()
        registry.load_inventory.cache_clear()
        with patch.object(Path, "read_bytes", read_bytes), patch.object(Path, "read_text", read_text):
            for edition in sorted(registry.EDITION_IDS):
                mapper = registry.mapper(edition)
                self.assertGreater(mapper.coverage()["labels"], 0)
            self.assertEqual(registry.convert_references("ang-dating-biblia-1905", "masoretic-delitzsch",
                [("JHN", 1, 38)]), ([("JHN", 1, 38), ("JHN", 1, 39)], False))
            self.assertEqual(registry.convert_references("jesuit-arabic-1897", "douay-rheims-1899",
                references("LUK", 1, 26, 38)), (references("LUK", 1, 26, 38), False))

    def test_known_split_merge_and_psalm_correspondences_preserve_complete_units(self):
        cases = (
            ("douay-rheims-1899", "masoretic-delitzsch", [("PSA", 50, 3)], [("PSA", 51, 3)], False),
            ("ang-dating-biblia-1905", "masoretic-delitzsch", [("3JN", 1, 14)], references("3JN", 1, 14, 15), False),
            ("masoretic-delitzsch", "ang-dating-biblia-1905", [("3JN", 1, 15)], [("3JN", 1, 14)], True),
            ("kulish-1905", "douay-rheims-1899", [("GEN", 3, 1)], references("GEN", 3, 1, 2), False),
            ("douay-rheims-1899", "kulish-1905", [("GEN", 3, 1)], [("GEN", 3, 1)], True),
            ("masoretic-delitzsch", "douay-rheims-1899", [("JHN", 1, 38)], [("JHN", 1, 38)], True),
            ("masoretic-delitzsch", "douay-rheims-1899", references("JHN", 1, 38, 39), [("JHN", 1, 38)], False),
        )
        for source, target, requested, expected, whole in cases:
            with self.subTest(source=source, target=target, refs=requested):
                self.assertEqual(registry.convert_references(source, target, requested), (expected, whole))

    def test_reviewed_standard_titles_remain_available_as_metadata(self):
        mapper = registry.mapper("masoretic-delitzsch")
        self.assertEqual(mapper.from_standard([("PSA", 3, 0)]), ([("PSA", 3, 1)], False))

    def test_every_explicitly_blocked_chapter_is_unavailable_in_both_directions(self):
        cases = (("crampon-1923", "JHN", 11), ("crampon-1923", "PSA", 50),
                 ("martini", "JHN", 11), ("martini", "1PE", 5),
                 ("kulish-1905", "LEV", 21), ("kulish-1905", "PSA", 148))
        for edition, book, chapter in cases:
            mapper = registry.mapper(edition)
            self.assertFalse(mapper.chapter_available(book, chapter))
            for method in (mapper.to_standard, mapper.from_standard):
                with self.subTest(edition=edition, ref=(book, chapter, 1), method=method.__name__), self.assertRaises(Unavailable):
                    method([(book, chapter, 1)])

    def test_arabic_units_never_certify_complete_chapters_or_partial_passages(self):
        mapper = registry.mapper("jesuit-arabic-1897")
        self.assertEqual(mapper.coverage()["labels"], 239)
        self.assertEqual(mapper.coverage()["policy"], "reviewed-units")
        self.assertFalse(mapper.chapter_available("LUK", 1))
        full = references("LUK", 1, 26, 38)
        self.assertEqual(registry.convert_references("douay-rheims-1899", "jesuit-arabic-1897", full), (full, False))
        for request in ([("LUK", 1, 32)], references("LUK", 1, 32, 33), references("LUK", 22, 43, 44)):
            with self.subTest(refs=request), self.assertRaises(Unavailable):
                registry.convert_references("douay-rheims-1899", "jesuit-arabic-1897", request)

    def test_arabic_outer_inventory_must_match_every_inner_reviewed_verse(self):
        for mode in ("missing", "empty", "different"):
            record = copy.deepcopy(self.records["jesuit-arabic-1897"])
            values = next(row[2] for row in record["chapters"] if row[:2] == ["LUK", 1])
            index = next(index for index, pair in enumerate(values) if pair[0] == 35)
            if mode == "missing":
                values.pop(index)
            else:
                values[index][1] = 0 if mode == "empty" else values[index][1] + 1
            with self.subTest(mode=mode), self.assertRaisesRegex(ValueError, "Arabic.*inventory differ"):
                registry.EditionMapper("jesuit-arabic-1897", record)

    def test_corrupt_source_pins_and_unknown_editions_cannot_dispatch(self):
        record = copy.deepcopy(self.records["ang-dating-biblia-1905"])
        record["sourcePins"][next(iter(record["sourcePins"]))] = "0" * 64
        with self.assertRaisesRegex(ValueError, "sources differ"):
            registry.EditionMapper("ang-dating-biblia-1905", record)
        for edition in ("unknown", "NABRE", "", None):
            with self.subTest(edition=edition), self.assertRaises(ValueError):
                registry.mapper(edition)


if __name__ == "__main__":
    unittest.main()
