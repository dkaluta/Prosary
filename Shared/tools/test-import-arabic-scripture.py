#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Offline checks for Arabic source completeness, preservation, and three-port parity."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import re
import shutil
import tempfile
import unittest
import zipfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location("arabic_scripture", TOOLS / "import-arabic-scripture.py")
assert SPEC is not None and SPEC.loader is not None
IMPORTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(IMPORTER)
ROOT = IMPORTER.ROOT


def snapshot(root: Path) -> dict[str, str]:
    return {str(path.relative_to(root)): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in root.rglob("*") if path.is_file()}


class ArabicImportTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.rows = IMPORTER.load_inventory(ROOT / IMPORTER.INVENTORY_PATH)
        files = {Path("Shared/content") / row["bundle"] / "content/ar.json" for row in self.rows}
        files |= set(IMPORTER.NATIVE_PATHS.values()) | {IMPORTER.INVENTORY_PATH}
        for relative in files:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, target)
        self.source = {
            "edition": {"id": IMPORTER.EDITION_ID, "name": "Fixture edition",
                        "sourceURL": "https://example.test/fixture",
                        "attribution": "Synthetic test coordinates, not Scripture."},
            "verses": {},
        }
        for row in self.rows:
            chapter = self.source["verses"].setdefault(row["book"], {}).setdefault(str(row["chapter"]), {})
            for verse in row["verses"]:
                chapter[str(verse)] = f"[fixture {row['book']} {row['chapter']}:{verse}]"
        self.write_source()

    def write_source(self):
        (self.root / IMPORTER.SOURCE_PATH).write_text(
            json.dumps(self.source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    def test_inventory_covers_existing_passages_without_inventing_missing_bodies(self):
        self.assertEqual(len(self.rows), 76)
        self.assertEqual(len({(row["book"], row["chapter"], v)
                              for row in self.rows for v in row["verses"]}), 239)
        self.assertEqual({row["bundle"] for row in self.rows},
                         {"rosary", "sevenSorrows", "franciscanCrown", "viaLucis", "stationsOfTheCross", "oAntiphons"})
        targets = {(row["bundle"], tuple(row["keys"])) for row in self.rows}
        self.assertNotIn(("stationsOfTheCross", ("prayers", "station06Body")), targets)
        self.assertNotIn(("sevenSorrows", ("mysteries", "seven_sorrows_04_meeting_jesus_on_the_way_of_the_cross", "description")), targets)

    def test_all_missing_verses_reported_before_any_write(self):
        del self.source["verses"]["Luke"]["1"]["35"]
        self.source["verses"]["Matthew"]["17"]["5"] = "  "
        self.write_source()
        before = snapshot(self.root)
        with self.assertRaises(IMPORTER.ImportFailure) as raised:
            IMPORTER.apply_plan(IMPORTER.build_plan(self.root), check=False)
        self.assertIn("Luke 1:35", str(raised.exception))
        self.assertIn("Matthew 17:5", str(raised.exception))
        self.assertEqual(snapshot(self.root), before)

    def test_check_reports_stale_files_and_writes_nothing(self):
        before = snapshot(self.root)
        changed = IMPORTER.apply_plan(IMPORTER.build_plan(self.root), check=True)
        self.assertEqual(len(changed), 9)
        self.assertEqual(snapshot(self.root), before)

    def test_complete_cited_verses_and_discontinuous_ranges(self):
        verses = IMPORTER.source_verses(self.source, self.rows)
        annunciation = next(row for row in self.rows if row["keys"][1] == "joyful_01_annunciation")
        text = IMPORTER.render_passage(annunciation, verses)
        for number in range(26, 39):
            self.assertEqual(text.count(f"[fixture Luke 1:{number}]"), 1)
        transfiguration = next(row for row in self.rows if row["keys"][1] == "luminous_04_transfiguration")
        text = IMPORTER.render_passage(transfiguration, verses)
        self.assertIn("[fixture Matthew 17:2] […] [fixture Matthew 17:5]", text)
        self.assertTrue(text.endswith("— متى 17:1–2، 5 (اليسوعية القديمة، 1897)"))

    def test_import_preserves_every_non_scripture_field(self):
        plan = IMPORTER.build_plan(self.root)
        for path, serialized in plan.items():
            if path.suffix != ".json":
                continue
            original = json.loads(path.read_text(encoding="utf-8"))
            rendered = json.loads(serialized)
            bundle = path.parents[1].name
            for document in (original, rendered):
                document.pop("$scriptureSource", None)
                document.pop("$scriptureImport", None)
                for row in self.rows:
                    if row["bundle"] != bundle:
                        continue
                    owner = document
                    for key in row["keys"][:-1]:
                        owner = owner[key]
                    owner[row["keys"][-1]] = "[replaced Scripture field]"
            self.assertEqual(rendered, original, str(path))

    def test_native_descriptions_match_canonical_and_escape_literal_text(self):
        sample = 'Fixture "quote", \\backslash, $literal\nnext line'
        self.source["verses"]["Luke"]["1"]["26"] = sample
        self.write_source()
        plan = IMPORTER.build_plan(self.root)
        rosary = json.loads(plan[self.root / "Shared/content/rosary/content/ar.json"])
        for language, relative in IMPORTER.NATIVE_PATHS.items():
            expression = re.compile(IMPORTER.NATIVE_PATTERNS[language]
                                    + r'(?P<body>' + IMPORTER.STRING_EXPRESSION + r')(?P<tail>\s*\))')
            original = list(expression.finditer((self.root / relative).read_text(encoding="utf-8")))
            generated = list(expression.finditer(plan[self.root / relative]))
            self.assertEqual(len(generated), 20)
            for old, new in zip(original, generated):
                self.assertEqual(old.group("head"), new.group("head"))  # Keep titles and fruits.
                literal = new.group("body")
                if language == "kotlin":
                    literal = literal.replace(r"\$", "$")
                self.assertEqual(json.loads(literal), rosary["mysteries"][new.group("key")]["description"])

    def test_broken_native_target_prevents_partial_content_writes(self):
        path = self.root / IMPORTER.NATIVE_PATHS["kotlin"]
        text = path.read_text(encoding="utf-8").replace('"joyful_01_annunciation" to', '"unknown_mystery" to')
        path.write_text(text, encoding="utf-8")
        before = snapshot(self.root)
        with self.assertRaises(IMPORTER.ImportFailure):
            IMPORTER.apply_plan(IMPORTER.build_plan(self.root), check=False)
        self.assertEqual(snapshot(self.root), before)

    def test_import_is_reproducible_and_source_hash_is_recorded(self):
        IMPORTER.apply_plan(IMPORTER.build_plan(self.root), check=False)
        self.assertEqual(IMPORTER.apply_plan(IMPORTER.build_plan(self.root), check=True), [])
        expected_hash = hashlib.sha256((self.root / IMPORTER.SOURCE_PATH).read_bytes()).hexdigest()
        for bundle in {row["bundle"] for row in self.rows}:
            text = json.loads((self.root / "Shared/content" / bundle / "content/ar.json").read_text())
            self.assertEqual(text["$scriptureImport"]["sourceSHA256"], expected_hash)
            self.assertEqual(text["$scriptureImport"]["editionId"], IMPORTER.EDITION_ID)

    def test_wrong_edition_or_ambiguous_inventory_is_rejected(self):
        self.source["edition"]["id"] = "modern-revision"
        with self.assertRaises(IMPORTER.ImportFailure):
            IMPORTER.source_verses(self.source, self.rows)
        malformed = copy.deepcopy(self.rows)
        malformed[0]["verses"] *= 2
        path = self.root / IMPORTER.INVENTORY_PATH
        path.write_text(json.dumps(malformed))
        with self.assertRaises(IMPORTER.ImportFailure):
            IMPORTER.load_inventory(path)


class CommittedArabicCorpusTests(unittest.TestCase):
    def test_source_is_complete_and_generated_outputs_are_current(self):
        plan = IMPORTER.build_plan()
        self.assertEqual(len(plan), 9)
        self.assertEqual(IMPORTER.apply_plan(plan, check=True), [])

    def test_every_transcribed_verse_has_printed_page_evidence(self):
        source = json.loads((ROOT / IMPORTER.SOURCE_PATH).read_text())
        self.assertEqual(source["provenance"]["printingYear"], 1897)
        self.assertEqual(source["provenance"]["titlePage"], 7)
        self.assertEqual(source["provenance"]["approvalDate"], "1897-11-03")
        self.assertEqual(source["provenance"]["pdfSHA256"],
                         "2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d")
        coordinates = set()
        for book, chapters in source["verses"].items():
            for chapter, verses in chapters.items():
                for verse, body in verses.items():
                    coordinates.add((book, int(chapter), int(verse)))
                    pages = source["pages"][book][chapter][verse]
                    pages = pages if isinstance(pages, list) else [pages]
                    self.assertTrue(pages)
                    self.assertTrue(all(type(page) is int and 1 <= page <= 570 for page in pages))
                    self.assertRegex(body, r"[\u0621-\u064a]")
                    self.assertNotIn("[…]", body)  # Omissions belong only between cited units.
        rows = IMPORTER.load_inventory(ROOT / IMPORTER.INVENTORY_PATH)
        self.assertEqual(coordinates, {(r["book"], r["chapter"], v) for r in rows for v in r["verses"]})

    def test_old_wording_and_printed_boundaries_cannot_be_relabelled_modern_text(self):
        verses = json.loads((ROOT / IMPORTER.SOURCE_PATH).read_text())["verses"]
        self.assertIn("يا ممتلئة نعمة", verses["Luke"]["1"]["28"])
        self.assertIn("فإنك قد نلت نعمة", verses["Luke"]["1"]["30"])
        self.assertIn("ويملك على آل يعقوب", verses["Luke"]["1"]["32"])
        self.assertEqual(verses["Luke"]["1"]["33"], "ولا يكون لملكه انقضاء.")
        self.assertIn("ولما أخذ في النزاع", verses["Luke"]["22"]["43"])
        self.assertIn("مومن", verses["John"]["20"]["27"])
        self.assertIn("خلوط", verses["John"]["19"]["39"])
        self.assertIn("عاهاتنا", verses["Isaiah"]["53"]["4"])
        self.assertIn("ملتحفة", verses["Revelation"]["12"]["1"])

    def test_all_shipped_arabic_pack_content_matches_the_canonical_source(self):
        directories = [ROOT / "Shared/dist", ROOT / "iOS/Prosary/PrayerPacks",
                       ROOT / "Android/app/src/main/assets", ROOT / "Windows/Prosary/PrayerPacks"]
        rows = IMPORTER.load_inventory(ROOT / IMPORTER.INVENTORY_PATH)
        for bundle in {row["bundle"] for row in rows}:
            canonical = (ROOT / "Shared/content" / bundle / "content/ar.json").read_bytes()
            for directory in directories:
                with self.subTest(bundle=bundle, directory=str(directory)):
                    with zipfile.ZipFile(directory / f"{bundle}.prosaryprayer") as archive:
                        self.assertEqual(archive.read("content/ar.json"), canonical)


if __name__ == "__main__":
    unittest.main(verbosity=2)
