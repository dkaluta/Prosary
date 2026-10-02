#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reject editorial notes that conceal guesses or cannot identify the affected point."""
import copy
import importlib.util
import io
import json
from pathlib import Path
import unittest
import zipfile

from scripture_source_notes import validate_source_notes

TOOLS = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("bible_library_builder", TOOLS / "build-bible-library.py")
library = importlib.util.module_from_spec(spec)
spec.loader.exec_module(library)


def fixture():
    return {"chapter": 1, "verse": 9, "text": "בַּקּבָּה", "sourceNotes": [{
        "id": "lje-1-9-qoph-vowel", "kind": "unreadablePoint", "anchor": "בַּקּבָּה",
        "occurrence": 1, "letterIndex": 2, "mark": "vowel", "sourcePages": [16],
        "sourceURL": "https://example.org/source.pdf#page=16"}]}


class SourceNoteTests(unittest.TestCase):
    def test_shuruq_requires_vav_and_omits_the_actual_dot(self):
        row = fixture()
        row['text'] = 'וּ ו'
        note = row['sourceNotes'][0]
        note.update(anchor='ו', occurrence=2, letterIndex=1, mark='shuruq')
        validate_source_notes(row)
        for changes in ({'occurrence':1}, {'mark':'shuruq','retainedVowels':['ְ']},
                        {'mark':'shuruq','retainedVowels':None}, {'kind':'restoredLetter'}):
            invalid = copy.deepcopy(row)
            invalid['sourceNotes'][0].update(changes)
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                validate_source_notes(invalid)
        row['text'] = note['anchor'] = 'ב'
        note['occurrence'] = 1
        with self.assertRaisesRegex(ValueError, 'shuruq must identify vav'):
            validate_source_notes(row)

    def test_same_dot_cannot_have_separate_dagesh_and_shuruq_notes(self):
        row = fixture()
        row['text'] = 'ו'
        row['sourceNotes'][0].update(anchor='ו', letterIndex=1, mark='shuruq')
        row['sourceNotes'].append(row['sourceNotes'][0] | {'id':'duplicate-dot','mark':'dagesh'})
        with self.assertRaisesRegex(ValueError, 'duplicate source-note position'):
            validate_source_notes(row)

    def test_restored_letter_preserves_visible_vowels_and_dagesh(self):
        row = fixture()
        row['text'] = row['sourceNotes'][0]['anchor'] = 'כָּלְתָה'
        row['sourceNotes'][0].update(kind='restoredLetter', mark='consonant')
        self.assertEqual(validate_source_notes(row), ['lje-1-9-qoph-vowel'])
        self.assertEqual(row['text'], 'כָּלְתָה')
        # The note targets a consonant; it must not erase readable adjacent marks.
        row['sourceNotes'][0]['letterIndex'] = 1
        validate_source_notes(row)
        for kind, mark in [('restoredLetter', 'vowel'), ('restoredLetter', 'dagesh'),
                           ('unreadablePoint', 'consonant')]:
            changed = copy.deepcopy(row)
            changed['sourceNotes'][0].update(kind=kind, mark=mark)
            with self.subTest(kind=kind, mark=mark), self.assertRaisesRegex(ValueError, 'unknown'):
                validate_source_notes(changed)
        for retained in [None, [], ['ְ']]:
            changed = copy.deepcopy(row)
            changed['sourceNotes'][0]['retainedVowels'] = retained
            with self.subTest(retained=retained), self.assertRaisesRegex(ValueError, 'retained vowel'):
                validate_source_notes(changed)

    def test_restoration_uses_exact_occurrence_and_cannot_hide_a_second_note(self):
        row = fixture()
        row['text'] = 'כָּלְתָה כָּלְתָה'
        note = row['sourceNotes'][0]
        note.update(kind='restoredLetter', mark='consonant', anchor='כָּלְתָה', occurrence=2)
        validate_source_notes(row)
        row['sourceNotes'].append(note | {'id':'same-letter', 'anchor':'לְ', 'letterIndex':1})
        with self.assertRaisesRegex(ValueError, 'duplicate source-note position'):
            validate_source_notes(row)
        row['sourceNotes'].pop()
        note['occurrence'] = 3
        with self.assertRaisesRegex(ValueError, 'dangling'):
            validate_source_notes(row)

    def test_restoration_survives_archive_generation(self):
        row = fixture()
        row['text'] = row['sourceNotes'][0]['anchor'] = 'כָּלְתָה'
        row['sourceNotes'][0].update(kind='restoredLetter', mark='consonant')
        edition = {'id':'fixture', 'languageCode':'he', 'name':'Fixture',
                   'attribution':'Synthetic fixture', 'sourceURL':'https://example.org/'}
        _, raw, entry = library.make_archive(edition, [('WIS', 1, [row], True)], {'WIS':{'name':'Fixture'}})
        self.assertEqual(entry['archiveSchemaVersion'], 2)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            self.assertEqual(json.loads(archive.read('chapters/WIS/1.json'))['verses'][0], row)

    def test_unicode_letter_position_retains_readable_dagesh_and_other_vowels(self):
        row = fixture()
        self.assertEqual(validate_source_notes(row, source_pages={16}), ["lje-1-9-qoph-vowel"])
        self.assertEqual(row["text"], "בַּקּבָּה")

    def test_dagesh_note_can_retain_readable_vowel(self):
        row = fixture()
        row["text"] = row["sourceNotes"][0]["anchor"] = "בַּקֻבָּה"
        row["sourceNotes"][0]["mark"] = "dagesh"
        validate_source_notes(row)

    def test_actual_occurrence_is_checked_and_short_anchor_cannot_hide_vowel(self):
        row = fixture()
        row["text"] = "קֻ קּ"
        row["sourceNotes"][0].update(anchor="ק", occurrence=2, letterIndex=1)
        validate_source_notes(row)
        row["sourceNotes"][0]["occurrence"] = 1
        with self.assertRaisesRegex(ValueError, "still present"):
            validate_source_notes(row)

    def test_readable_companion_vowel_is_preserved_without_guessing_the_other(self):
        row = fixture()
        row["text"] = row["sourceNotes"][0]["anchor"] = "לִ"
        row["sourceNotes"][0].update(letterIndex=1, retainedVowels=["ִ"])
        validate_source_notes(row)
        for retained in ([], None, ["ִ", "ַ"], ["ִִ"], ["ּ"], ["ַ"]):
            altered = copy.deepcopy(row)
            altered["sourceNotes"][0]["retainedVowels"] = retained
            with self.subTest(retained=retained), self.assertRaisesRegex(ValueError, "retained vowel"):
                validate_source_notes(altered)
        for text in ("לִַ", "לִִ"):
            altered = copy.deepcopy(row)
            altered["text"] = altered["sourceNotes"][0]["anchor"] = text
            with self.assertRaisesRegex(ValueError, "still present"):
                validate_source_notes(altered)
        row["sourceNotes"][0]["mark"] = "dagesh"
        with self.assertRaisesRegex(ValueError, "retained vowel"):
            validate_source_notes(row)

    def test_invalid_notes_fail_closed(self):
        for key, value, message in (
            ("kind", "inferredWord", "unknown"), ("mark", "consonant", "unknown"),
            ("mark", [], "unknown"), ("anchor", "not present", "dangling"),
            ("occurrence", 2, "dangling"), ("occurrence", True, "dangling"),
            ("letterIndex", 5, "letter"), ("letterIndex", True, "letter"),
            ("id", "note with spaces", "ID"), ("sourcePages", [], "pages"),
            ("sourcePages", [True], "pages"), ("sourcePages", [16, 16], "pages"),
            ("sourcePages", [17], "outside"), ("sourceURL", "file:///secret", "URL"),
            ("sourceURL", "https://user:pass@example.org/scan", "URL"),
        ):
            with self.subTest(key=key, value=value):
                row = fixture()
                row["sourceNotes"][0][key] = value
                with self.assertRaisesRegex(ValueError, message):
                    validate_source_notes(row, source_pages={16})

    def test_retained_guesses_empty_notes_and_unsupported_pairs_fail(self):
        row = fixture()
        row["text"] = row["sourceNotes"][0]["anchor"] = "בַּקֻּבָּה"
        with self.assertRaisesRegex(ValueError, "still present"):
            validate_source_notes(row)
        for update, message in (({"sourceNotes": []}, "nonempty"),
                                ({"transliteratedText": "paired"}, "paired")):
            row = fixture() | update
            with self.assertRaisesRegex(ValueError, message):
                validate_source_notes(row)

    def test_duplicate_position_or_id_cannot_multiply_one_limitation(self):
        row = fixture()
        row["sourceNotes"].append(copy.deepcopy(row["sourceNotes"][0]))
        with self.assertRaisesRegex(ValueError, "duplicate source-note ID"):
            validate_source_notes(row)
        row["sourceNotes"][1]["id"] = "another-note"
        row["sourceNotes"][1].update(anchor="קּ", letterIndex=1)
        with self.assertRaisesRegex(ValueError, "duplicate source-note position"):
            validate_source_notes(row)

    def test_richer_archive_is_versioned_and_note_is_not_dropped(self):
        edition = {"id": "fixture", "languageCode": "he", "name": "Fixture",
                   "attribution": "Synthetic fixture", "sourceURL": "https://example.org/"}
        row = fixture()
        _, raw, entry = library.make_archive(edition, [("LJE", 1, [row], True)], {"LJE": {"name": "Fixture"}})
        self.assertEqual(entry["archiveSchemaVersion"], 2)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            self.assertEqual(json.loads(archive.read("manifest.json"))["schemaVersion"], 2)
            chapter = json.loads(archive.read("chapters/LJE/1.json"))
            self.assertEqual(chapter["schemaVersion"], 2)
            self.assertEqual(chapter["verses"][0], row)
        row.pop("sourceNotes")
        _, raw, entry = library.make_archive(edition, [("LJE", 1, [row], True)], {"LJE": {"name": "Fixture"}})
        self.assertNotIn("archiveSchemaVersion", entry)
        with zipfile.ZipFile(io.BytesIO(raw)) as archive:
            self.assertEqual(json.loads(archive.read("manifest.json"))["schemaVersion"], 1)


if __name__ == "__main__":
    unittest.main()
