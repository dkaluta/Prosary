#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Audit shipped Bible downloads against pinned text, exclusions and native copies."""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import unittest
import zipfile

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parents[1]
spec = importlib.util.spec_from_file_location("bible_library_builder", TOOLS / "build-bible-library.py")
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)


class BibleLibraryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.builder = library.reading_builder()
        cls.lock, cls.corpora = cls.builder.load_pinned_corpora()
        cls.catalog_bytes = (ROOT / "Shared/data/bible-catalog.json").read_bytes()
        cls.catalog = json.loads(cls.catalog_bytes)
        cls.editions = {edition["id"]: edition for edition in cls.catalog["editions"]}

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
                with zipfile.ZipFile(path) as archive:
                    manifest = json.loads(archive.read("manifest.json"))
                    self.assertEqual(manifest, {"schemaVersion": 1, "editionId": edition_id,
                                              "revision": edition["revision"], "books": edition["books"]})
                    self.assertEqual(sum(i.file_size for i in archive.infolist()), edition["unpackedByteCount"])
                    self.assertLessEqual(edition["unpackedByteCount"], library.MAX_UNPACKED)
                    expected_paths = {"manifest.json"}
                    book_ids = [book["id"] for book in edition["books"]]
                    self.assertEqual(len(book_ids), len(set(book_ids)))
                    for book in edition["books"]:
                        self.assertTrue(book["name"].strip())
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
                            self.assertEqual(payload["schemaVersion"], 1)
                            self.assertEqual(payload["editionId"], edition_id)
                            self.assertEqual(payload["book"], key[0])
                            self.assertEqual(payload["chapter"], key[1])
                            rows = payload["verses"]
                            self.assertEqual(len(rows), chapter["verseCount"])
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


if __name__ == "__main__":
    unittest.main()
