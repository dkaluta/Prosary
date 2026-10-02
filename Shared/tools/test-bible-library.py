#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Audit shipped Bible downloads against pinned text, exclusions and native copies."""
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import re
from types import SimpleNamespace
import unittest
from unittest import mock
import zipfile

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
spec = importlib.util.spec_from_file_location("bible_library_builder", TOOLS / "build-bible-library.py")
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)


def assert_supplement_chapter(test, payload, source, preserve_text):
    """Compare published contents with approved source units, in printed order."""
    expected = []
    for unit in source["verses"]:
        row = {"chapter": source["number"], "verse": unit["verse"],
               "text": preserve_text(unit["text"])}
        for key in ("endVerse", "sourceNotes"):
            if key in unit:
                row[key] = unit[key]
        expected.append(row)
    test.assertEqual(payload["verses"], expected)
    if "contentBlocks" in source:
        blocks = [{key: (preserve_text(value) if key == "text" else value)
                   for key, value in block.items() if key not in ("sourcePages", "textSHA256")}
                  for block in source["contentBlocks"]]
        test.assertEqual(payload.get("contentBlocks"), blocks)
    else:
        test.assertNotIn("contentBlocks", payload)


class BibleLibraryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = library.reading_builder()
        cls.lock, cls.corpora = cls.builder.load_pinned_corpora()
        cls.catalog_bytes = (ROOT / "Shared/data/bible-catalog.json").read_bytes()
        cls.catalog = json.loads(cls.catalog_bytes)
        cls.editions = {edition["id"]: edition for edition in cls.catalog["editions"]}
        supplement, cls.supplement_review = library.load_hebrew_supplement()
        cls.supplement = {book["book"]: book for book in supplement}

    def test_catalog_ids_metadata_and_native_parity(self):
        self.assertEqual(self.catalog["schemaVersion"], 1)
        self.assertEqual(set(self.editions), {row["id"] for row in self.lock["editions"]})
        self.assertEqual(len(self.editions), len(self.catalog["editions"]))
        for directory in library.TARGETS:
            self.assertEqual((directory / "bible-catalog.json").read_bytes(), self.catalog_bytes)
        for edition in self.lock["editions"]:
            entry = self.editions[edition["id"]]
            for key in ("name", "attribution", "sourceURL", "languageCode"):
                self.assertEqual(entry[key], edition[key])

    def test_every_archive_and_verse_matches_pinned_sources(self):
        from peshitta_reading_source import paired_text
        from peshitta_ot_semantic_review import reviewed_mapping
        from peshitta_supplied_ot import BOOKS
        allowed, _ = reviewed_mapping()
        for edition_id, edition in self.editions.items():
            with self.subTest(edition=edition_id):
                filename = edition["downloadURL"].removeprefix(library.DOWNLOAD_ROOT)
                self.assertRegex(filename, rf"^{re.escape(edition_id)}-[0-9a-f]{{64}}\.zip$")
                path = library.DIST / filename
                raw = path.read_bytes()
                self.assertEqual(hashlib.sha256(raw).hexdigest(), edition["archiveSHA256"])
                self.assertEqual(len(raw), edition["archiveByteCount"])
                self.assertLessEqual(len(raw), library.MAX_ARCHIVE)
                corpus = self.corpora[edition_id]
                mapper = self.builder.edition_mapper(edition_id, corpus)
                seen = set()
                supplement = self.supplement if edition_id == "masoretic-delitzsch" else {}
                expected_version = (3 if any("addressRoutes" in book or any(
                    "contentBlocks" in chapter for chapter in book["chapters"])
                    for book in supplement.values()) else 2 if any(
                        "sourceNotes" in row for book in supplement.values()
                        for chapter in book["chapters"] for row in chapter["verses"]) else 1)
                self.assertEqual(edition.get("archiveSchemaVersion", 1), expected_version)
                with zipfile.ZipFile(path) as archive:
                    manifest = json.loads(archive.read("manifest.json"))
                    self.assertEqual(manifest, {"schemaVersion": expected_version, "editionId": edition_id,
                                              "revision": edition["revision"], "books": edition["books"]})
                    self.assertEqual(sum(i.file_size for i in archive.infolist()), edition["unpackedByteCount"])
                    self.assertLessEqual(edition["unpackedByteCount"], library.MAX_UNPACKED)
                    expected_paths = {"manifest.json"}
                    book_ids = [book["id"] for book in edition["books"]]
                    self.assertEqual(len(book_ids), len(set(book_ids)))
                    for book in edition["books"]:
                        self.assertTrue(book["name"].strip())
                        source_book = supplement.get(book["id"])
                        if source_book:
                            self.assertEqual(book["name"], source_book["title"])
                            for field in ("attribution", "sourceURL", "addressRoutes"):
                                self.assertEqual(book.get(field), source_book.get(field))
                            opening = source_book.get("introduction")
                            self.assertEqual(book.get("introduction"),
                                self.builder.preserve_divine_name_accents(opening) if opening else None)
                            source_chapters = {row["number"]: row for row in source_book["chapters"]}
                            self.assertEqual([row["number"] for row in book["chapters"]], list(source_chapters))
                        numbers = [row["number"] for row in book["chapters"]]
                        self.assertEqual(numbers, sorted(set(numbers)))
                        for chapter in book["chapters"]:
                            key = book["id"], chapter["number"]
                            self.assertNotIn(key, mapper.excluded_chapters)
                            chapter_path = f"chapters/{key[0]}/{key[1]}.json"
                            expected_paths.add(chapter_path)
                            chapter_bytes = archive.read(chapter_path)
                            self.assertLessEqual(len(chapter_bytes), library.MAX_CHAPTER)
                            payload = json.loads(chapter_bytes)
                            self.assertEqual(payload["schemaVersion"], expected_version)
                            self.assertEqual(payload["editionId"], edition_id)
                            self.assertEqual(payload["book"], key[0])
                            self.assertEqual(payload["chapter"], key[1])
                            rows = payload["verses"]
                            self.assertEqual(len(rows), chapter["verseCount"])
                            if source_book:
                                source = source_chapters[key[1]]
                                self.assertEqual(chapter["isComplete"], source.get("isComplete", True))
                                assert_supplement_chapter(self, payload, source,
                                    self.builder.preserve_divine_name_accents)
                                for row in rows:
                                    ref = *key, row["verse"]
                                    self.assertNotIn(ref, seen)
                                    seen.add(ref)
                                continue
                            labels = [row["verse"] for row in rows]
                            self.assertEqual(labels, sorted(set(labels)))
                            self.assertTrue(rows)
                            if chapter["isComplete"]:
                                self.assertEqual(set(labels), set(corpus[key]))
                                self.assertEqual(labels, list(range(1, max(labels)+1)))
                            for row in rows:
                                ref = *key, row["verse"]
                                self.assertNotIn(ref, seen)
                                seen.add(ref)
                                self.assertEqual(row["chapter"], key[1])
                                original = corpus[key][row["verse"]]
                                self.assertTrue(original.strip())
                                if edition_id == "peshitta-1905":
                                    if key[0] in BOOKS:
                                        self.assertIn(ref, allowed)
                                    primary, secondary = paired_text(original)
                                    self.assertEqual(row["text"], primary)
                                    self.assertEqual(row["transliteratedText"], secondary)
                                else:
                                    expected = (self.builder.preserve_divine_name_accents(original)
                                                if edition["languageCode"] == "he" else original)
                                    self.assertEqual(row["text"], expected)
                                    self.assertNotIn("transliteratedText", row)
                    self.assertEqual(set(archive.namelist()), expected_paths)
                    self.assertEqual(len(archive.namelist()), len(expected_paths))
                    self.assertIsNone(archive.testzip())
                # An archive cannot quietly lose a permitted verse while still validating
                # each retained row. Check the independently assembled allowed inventory.
                expected_refs = {(book, chapter, verse) for (book, chapter), values in corpus.items()
                    if (book, chapter) not in mapper.excluded_chapters for verse in values
                    if edition_id != "peshitta-1905" or book not in BOOKS or (book, chapter, verse) in allowed}
                expected_refs.update((book["book"], chapter["number"], row["verse"])
                    for book in supplement.values() for chapter in book["chapters"] for row in chapter["verses"])
                self.assertEqual(seen, expected_refs)

    def test_known_gaps_are_not_labeled_complete(self):
        arabic = self.editions["jesuit-arabic-1897"]
        self.assertTrue(all(not chapter["isComplete"] for book in arabic["books"] for chapter in book["chapters"]))
        self.assertEqual(sum(chapter["verseCount"] for book in arabic["books"] for chapter in book["chapters"]), 665)
        peshitta = self.editions["peshitta-1905"]
        exodus = next(book for book in peshitta["books"] if book["id"] == "EXO")
        for number in (12, 15):
            self.assertFalse(next(chapter for chapter in exodus["chapters"] if chapter["number"] == number)["isComplete"])

    def test_full_native_books_are_available_beyond_daily_appointments(self):
        # This catches accidentally building the new viewer from daily snippets.
        for edition_id in ("douay-rheims-1899", "masoretic-delitzsch"):
            books = {book["id"]: book for book in self.editions[edition_id]["books"]}
            self.assertEqual(len(books["GEN"]["chapters"]), 50)
            self.assertEqual(len(books["PSA"]["chapters"]), 150)
            self.assertEqual(len(books["REV"]["chapters"]), 22)
        self.assertEqual(len(self.editions["douay-rheims-1899"]["books"]), 73)

    def test_source_book_titles_do_not_include_publisher_navigation(self):
        for edition in self.editions.values():
            for book in edition["books"]:
                self.assertNotIn(book["name"], {"Go!", "Next", "Previous", "Home"})
        expected_scripts = {"masoretic-delitzsch": r"[א-ת]", "brenton-lxx": r"[Α-ω]"}
        for edition_id, script in expected_scripts.items():
            for book in self.editions[edition_id]["books"]:
                self.assertRegex(book["name"], script)


class HebrewSupplementBuildTests(unittest.TestCase):
    def test_build_preserves_source_order_notes_routes_and_credit(self):
        # Exercise build's authoring-to-archive projection using synthetic text only.
        # This cannot enable a real unfinished book or write a production archive.
        builder = library.reading_builder()
        edition = {"id": "masoretic-delitzsch", "languageCode": "he", "name": "Fixture",
                   "attribution": "Synthetic test", "sourceURL": "https://example.org/base"}
        restored = {"id": "restored", "kind": "restoredLetter", "anchor": "כָּלְתָה",
                    "occurrence": 1, "letterIndex": 2, "mark": "consonant", "sourcePages": [1],
                    "sourceURL": "https://example.org/source#page=1"}
        shuruq = {"id": "closing-vav", "kind": "unreadablePoint", "anchor": "ו",
                  "occurrence": 1, "letterIndex": 1, "mark": "shuruq", "sourcePages": [2],
                  "sourceURL": "https://example.org/source#page=2"}
        source = {"book": "ESG", "title": "מקור לדוגמה", "attribution": "Fixture translator",
                  "sourceURL": "https://example.org/source", "introduction": "Synthetic opening",
                  "addressRoutes": [{"chapter": 2, "verse": 1, "displayChapter": 1, "blockId": "cross"}],
                  "chapters": [
                      {"number": 1, "isComplete": False, "verses": [
                          {"verse": 3, "endVerse": 4, "text": "כָּלְתָה", "sourceNotes": [restored]},
                          {"verse": 1, "text": "Synthetic earlier label"}], "contentBlocks": [
                              {"id": "combined", "kind": "verse", "chapter": 1, "verse": 3},
                              {"id": "cross", "kind": "verse", "chapter": 2, "verse": 1},
                              {"id": "earlier", "kind": "verse", "chapter": 1, "verse": 1}]},
                      {"number": 2, "verses": [{"verse": 1, "text": "Synthetic continuation"}],
                       "contentBlocks": [{"id": "closing", "kind": "colophon", "text": "ו",
                           "sourcePages": [2], "textSHA256": hashlib.sha256("ו".encode()).hexdigest(),
                           "sourceNotes": [shuruq]}]}]}
        with mock.patch.object(library, "reading_builder", return_value=builder), \
             mock.patch.object(builder, "load_pinned_corpora", return_value=(
                 {"editions": [edition]}, {edition["id"]: {("GEN", 1): {1: "Synthetic base"}}})), \
             mock.patch.object(builder, "edition_mapper", return_value=SimpleNamespace(excluded_chapters=set())), \
             mock.patch.object(library, "load_hebrew_supplement", return_value=([source], [])) as gate:
            catalog_bytes, archives, _ = library.build(require_hebrew_supplement=True)
        gate.assert_called_once_with(require_complete=True)
        metadata = json.loads(catalog_bytes)["editions"][0]
        self.assertEqual(metadata["archiveSchemaVersion"], 3)
        book = next(book for book in metadata["books"] if book["id"] == "ESG")
        self.assertEqual(book, {"id": "ESG", "name": source["title"],
            "attribution": source["attribution"], "sourceURL": source["sourceURL"],
            "introduction": source["introduction"], "addressRoutes": source["addressRoutes"],
            "chapters": [{"number": 1, "verseCount": 2, "isComplete": False},
                         {"number": 2, "verseCount": 1, "isComplete": True}]})
        self.assertEqual(len(archives), 1)
        with zipfile.ZipFile(io.BytesIO(next(iter(archives.values())))) as archive:
            for chapter in source["chapters"]:
                payload = json.loads(archive.read(f"chapters/ESG/{chapter['number']}.json"))
                assert_supplement_chapter(self, payload, chapter, builder.preserve_divine_name_accents)
            self.assertEqual(json.loads(archive.read("manifest.json"))["schemaVersion"], 3)


if __name__ == "__main__":
    unittest.main()
