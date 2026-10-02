#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Validate precisely anchored Hebrew point omissions and disclosed letter restorations."""
from __future__ import annotations

import re
import unicodedata
from urllib.parse import urlsplit

FIELDS = {"id", "kind", "anchor", "occurrence", "letterIndex", "mark", "sourcePages", "sourceURL"}
VOWELS = {chr(code) for code in range(0x05B0, 0x05BC)} | {"\u05c7"}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate_source_notes(row: dict, *, label="Scripture", source_pages: set[int] | None = None) -> list[str]:
    """Return IDs in presentation order; caller enforces book-wide uniqueness."""
    if "sourceNotes" not in row:
        return []
    notes = row["sourceNotes"]
    require(isinstance(notes, list) and bool(notes), f"{label}: sourceNotes must be nonempty")
    require("transliteratedText" not in row, f"{label}: paired source-note anchors are unsupported")
    text = row.get("text")
    require(isinstance(text, str) and bool(text.strip()), f"{label}: missing source-note text")
    ids, positions = [], set()
    for note in notes:
        require(isinstance(note, dict) and FIELDS <= set(note) <= FIELDS | {"retainedVowels"},
                f"{label}: invalid source-note fields")
        note_id = note["id"]
        require(isinstance(note_id, str) and re.fullmatch(r"[a-z0-9][a-z0-9-]*", note_id),
                f"{label}: invalid source-note ID")
        require(note_id not in ids, f"{label}: duplicate source-note ID")
        require(isinstance(note["kind"], str) and isinstance(note["mark"], str) and
                (note["kind"], note["mark"]) in {
                    ("unreadablePoint", "vowel"), ("unreadablePoint", "dagesh"),
                    ("restoredLetter", "consonant")},
                f"{label}: unknown source-note kind or mark")
        retained = note.get("retainedVowels", [])
        if "retainedVowels" in note:
            require(note["mark"] == "vowel" and isinstance(retained, list) and len(retained) == 1 and
                    isinstance(retained[0], str) and retained[0] in VOWELS,
                    f"{label}: invalid retained vowel")
        anchor, occurrence, index = note["anchor"], note["occurrence"], note["letterIndex"]
        require(isinstance(anchor, str) and bool(anchor.strip()), f"{label}: empty source-note anchor")
        require(type(occurrence) is int and 0 < occurrence <= text.count(anchor),
                f"{label}: dangling source-note anchor")
        letters = [position for position, char in enumerate(anchor) if "א" <= char <= "ת"]
        require(type(index) is int and 0 < index <= len(letters), f"{label}: invalid source-note letter")
        start = letters[index - 1]
        # Resolve the actual position as well as its quote, so overlapping quotes
        # cannot attach two notes to the same omitted mark.
        offset = -len(anchor)
        for _ in range(occurrence):
            offset = text.find(anchor, offset + len(anchor))
        position = (offset + start, note["mark"])
        require(position not in positions, f"{label}: duplicate source-note position")
        # A quote ending at a bare letter must not hide its following vowel in text.
        end = offset + start + 1
        actual = []
        while end < len(text) and unicodedata.combining(text[end]):
            actual.append(text[end])
            end += 1
        if note["mark"] == "vowel":
            require([char for char in actual if char in VOWELS] == retained,
                    f"{label}: unreadable mark is still present or retained vowel does not match")
        elif note["mark"] == "dagesh":
            require("\u05bc" not in actual, f"{label}: unreadable mark is still present")
        pages = note["sourcePages"]
        require(isinstance(pages, list) and bool(pages) and
                all(type(page) is int and page > 0 for page in pages) and pages == sorted(set(pages)),
                f"{label}: invalid source-note pages")
        require(source_pages is None or set(pages) <= source_pages,
                f"{label}: source note outside unit pages")
        url = note["sourceURL"]
        require(isinstance(url, str) and not any(char.isspace() for char in url),
                f"{label}: invalid source-note URL")
        try:
            parsed = urlsplit(url)
            valid = parsed.scheme == "https" and bool(parsed.hostname) and not parsed.username and not parsed.password
        except ValueError:
            valid = False
        require(valid, f"{label}: invalid source-note URL")
        positions.add(position)
        ids.append(note_id)
    return ids
