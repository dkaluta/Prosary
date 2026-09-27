#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Keep printed variants, unnumbered text and cross-chapter order lossless."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import unittest
import zipfile

from bible_source_structure import published_blocks, validate_structure


def unit(verse, value="טקסט"):
    return {"verse": verse, "text": value}


def ref(identity, chapter, verse, **extra):
    return {"id": identity, "kind": "verse", "chapter": chapter, "verse": verse, **extra}


def fixture():
    return [{"number": 11, "verses": [unit(33), unit(34)],
             "contentBlocks": [ref("sir-11-33", 11, 33)]},
            {"number": 12, "verses": [unit(1), unit(2)],
             "contentBlocks": [ref("sir-12-1", 12, 1), ref("sir-11-34", 11, 34), ref("sir-12-2", 12, 2)]}], [
                {"chapter": 11, "verse": 34, "displayChapter": 12, "blockId": "sir-11-34"}]


class SourceStructureTests(unittest.TestCase):
    def test_interleaving_accounts_for_every_primary_unit_once(self):
        chapters, routes = fixture()
        result = validate_structure(chapters, routes=routes, archive_version=3)
        self.assertEqual(result["contentBlocks"][1]["ids"], ["sir-12-1", "sir-11-34", "sir-12-2"])
        self.assertEqual(result["addressRoutes"], routes)

    def test_missing_duplicate_and_dangling_presentations_rejected(self):
        for mutation in [
                lambda ch: ch[1]["contentBlocks"].pop(),
                lambda ch: ch[0]["contentBlocks"].append(ref("duplicate", 11, 34)),
                lambda ch: ch[1]["contentBlocks"].append(ref("dangling", 12, 9)),
                lambda ch: ch[1]["contentBlocks"].append(ref("sir-11-33", 12, 1))]:
            chapters, routes = fixture()
            mutation(chapters)
            with self.assertRaises(ValueError):
                validate_structure(chapters, routes=routes, archive_version=3)

    def test_implicit_ordinary_chapter_cannot_also_present_moved_unit(self):
        chapters, routes = fixture()
        del chapters[0]["contentBlocks"]
        with self.assertRaisesRegex(ValueError, "exactly one"):
            validate_structure(chapters, routes=routes)

    def test_routes_must_exactly_match_actual_placement(self):
        chapters, routes = fixture()
        for value in [None, [], routes + routes, [{**routes[0], "displayChapter": 11}],
                      [{**routes[0], "blockId": "other"}], [{**routes[0], "verse": 33}]]:
            with self.subTest(routes=value), self.assertRaises(ValueError):
                validate_structure(chapters, routes=value)

    def test_repeated_witness_overlapping_parts_and_unnumbered_text_survive(self):
        blocks = [
            ref("sir-41-14b", 41, 14, printedLabel="ידב"), ref("sir-41-15", 41, 15),
            {"id": "sir-41-heading", "kind": "heading", "text": "כותרת מקור"},
            {"id": "sir-41-14a-16", "kind": "witness", "text": "עד נוסח נפרד", "printedLabel": "ידא–טז",
             "addresses": [{"chapter": 41, "verse": 14, "endVerse": 16, "part": "א"}]}]
        chapters = [{"number": 41, "verses": [unit(14), unit(15)], "contentBlocks": blocks},
                    {"number": 51, "verses": [unit(12), unit(13)], "contentBlocks": [
                        ref("sir-51-12", 51, 12),
                        {"id": "sir-hymn", "kind": "passage", "text": "שירת תודה"},
                        ref("sir-51-13", 51, 13),
                        {"id": "sir-51-13-second", "kind": "witness", "text": "עד שני", "printedLabel": "יג",
                         "addresses": [{"chapter": 51, "verse": 13}]},
                        {"id": "sir-colophon", "kind": "colophon", "text": "חתימת מקור"}]}]
        result = validate_structure(chapters, archive_version=3)
        self.assertEqual(len(result["contentBlocks"][0]["ids"]), 4)
        self.assertEqual(result["contentBlocks"][1]["ids"][-1], "sir-colophon")

    def test_old_and_unknown_versions_reject_structure(self):
        chapters, routes = fixture()
        for version in [1, 2, 4, True]:
            with self.subTest(version=version), self.assertRaises(ValueError):
                validate_structure(chapters, routes=routes, archive_version=version)

    def test_null_empty_unknown_fields_and_paired_blocks_rejected(self):
        for blocks in [None, [], [{"id": "x", "kind": "unknown", "text": "x"}],
                       [ref("x", 1, 1, printedLabel=None)],
                       [ref("x", 1, 1, text="duplicate text")],
                       [ref("x", True, 1)]]:
            with self.subTest(blocks=blocks), self.assertRaises(ValueError):
                validate_structure([{"number": 1, "verses": [unit(1)], "contentBlocks": blocks}])
        with self.assertRaises(ValueError):
            validate_structure([{"number": 1, "verses": [unit(1)], "contentBlocks": [ref("x", 1, 1)]}], paired=True)
        with self.assertRaises(ValueError):
            validate_structure([{"number": 1, "verses": [unit(1)]}], paired=True, archive_version=3)

    def test_witness_addresses_are_strict_and_refer_to_real_chapters(self):
        for addresses in [None, [], [{"chapter": 2, "verse": 1}], [{"chapter": 1, "verse": 2, "endVerse": 1}],
                          [{"chapter": 1, "verse": 1, "part": None}],
                          [{"chapter": 1, "verse": 1}, {"chapter": 1, "verse": 1}],
                          [{"chapter": 1, "verse": 1}, {"chapter": 1, "verse": 1, "endVerse": 1}]]:
            with self.subTest(addresses=addresses), self.assertRaises(ValueError):
                validate_structure([{"number": 1, "verses": [unit(1)], "contentBlocks": [ref("x", 1, 1),
                    {"id": "w", "kind": "witness", "text": "text", "printedLabel": "א", "addresses": addresses}]}])

    def test_authoring_hash_pages_and_publishing_are_lossless(self):
        passage = {"id": "hymn", "kind": "passage", "text": "תודה", "sourcePages": [529, 530],
                   "textSHA256": hashlib.sha256("תודה".encode()).hexdigest()}
        chapters = [{"number": 51, "verses": [unit(12)], "contentBlocks": [ref("v12", 51, 12), passage]}]
        result = validate_structure(chapters, authoring=True, page_count=530)
        self.assertEqual(result["sourcePages"], {529, 530})
        self.assertEqual(published_blocks([passage]), [{"id": "hymn", "kind": "passage", "text": "תודה"}])
        for field, value in [("textSHA256", "0" * 64), ("sourcePages", [531]), ("sourcePages", [])]:
            invalid = copy.deepcopy(chapters)
            invalid[0]["contentBlocks"][1][field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                validate_structure(invalid, authoring=True, page_count=530)

    def test_notes_across_primary_and_witness_are_not_silently_duplicated(self):
        note = {"id": "unreadable", "kind": "unreadablePoint", "anchor": "אב", "occurrence": 1,
                "letterIndex": 1, "mark": "vowel", "sourcePages": [1], "sourceURL": "https://example.org/scan.pdf#page=1"}
        chapters = [{"number": 1, "verses": [{**unit(1, "אב"), "sourceNotes": [note]}], "contentBlocks": [
            ref("first", 1, 1), {"id": "second", "kind": "witness", "text": "אב", "printedLabel": "א",
                              "addresses": [{"chapter": 1, "verse": 1}], "sourceNotes": [note]}]}]
        with self.assertRaisesRegex(ValueError, "duplicate source-note"):
            validate_structure(chapters)

    def test_archive_version_three_retains_susanna_literal_label(self):
        tools = Path(__file__).resolve().parent
        spec = importlib.util.spec_from_file_location("structure_archive", tools / "build-bible-library.py")
        library = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(library)
        edition = {"id": "fixture", "languageCode": "he", "name": "Fixture", "attribution": "Source",
                   "sourceURL": "https://example.org"}
        chapters = [("SUS", 1, [{"chapter": 1, "verse": 40, "endVerse": 41, "text": "אמת"}], True)]
        blocks = [ref("sus-1-40", 1, 40, printedLabel="כ–כא")]
        _, raw, metadata = library.make_archive(edition, chapters, {"SUS": {"name": "שושנה"}}, {("SUS", 1): blocks})
        self.assertEqual(metadata["archiveSchemaVersion"], 3)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            self.assertEqual(json.loads(archive.read("manifest.json"))["schemaVersion"], 3)
            payload = json.loads(archive.read("chapters/SUS/1.json"))
            self.assertEqual(payload["contentBlocks"], blocks)
            self.assertEqual(payload["verses"][0]["verse"], 40)
            self.assertEqual(payload["verses"][0]["endVerse"], 41)


if __name__ == "__main__":
    unittest.main()
