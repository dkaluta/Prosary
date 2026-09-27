#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Guarded reader-only import of the user's pinned, pointed Peshitta OT.

The prayer importer deliberately remains unchanged. This adapter neither repairs
source words nor infers missing verses. Its checked review lists every rejected
chapter, and changing the source or its observed defects fails closed.
"""
from collections import Counter
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import re
import xml.etree.ElementTree as ET

SHA256 = "4f71fe418a1d23f6b65d63d155f838a228dbdb6e4857834f4503afdcf009ea88"
REVIEW_PATH = Path(__file__).with_name("peshitta-supplied-ot-review.json")
# Names, not the damaged NT numeric IDs, identify books. Both fields must agree.
BOOKS = {
    "GEN": (1, "Genesis"), "EXO": (2, "Exodus"), "LEV": (3, "Leviticus"),
    "NUM": (4, "Numbers"), "DEU": (5, "Deuteronomy"), "JOS": (6, "Joshua"),
    "JDG": (7, "Judges"), "RUT": (8, "Ruth"), "1SA": (9, "1 Samuel"),
    "2SA": (10, "2 Samuel"), "1KI": (11, "1 Kings"), "2KI": (12, "2 Kings"),
    "1CH": (13, "1 Chronicles"), "2CH": (14, "2 Chronicles"),
    "EZR": (15, "Ezra"), "NEH": (16, "Nehemiah"), "EST": (17, "Esther"),
    "JOB": (18, "Job"), "PSA": (19, "Psalms"), "PRO": (20, "Proverbs"),
    "ECC": (21, "Ecclesiastes"), "SNG": (22, "Song of Songs"),
    "ISA": (23, "Isaiah"), "JER": (24, "Jeremiah"), "LAM": (25, "Lamentations"),
    "EZK": (26, "Ezekiel"), "DAN": (27, "Daniel"), "HOS": (28, "Hosea"),
    "JOL": (29, "Joel"), "AMO": (30, "Amos"), "OBA": (31, "Obadiah"),
    "JON": (32, "Jonah"), "MIC": (33, "Micah"), "NAM": (34, "Nahum"),
    "HAB": (35, "Habakkuk"), "ZEP": (36, "Zephaniah"), "HAG": (37, "Haggai"),
    "ZEC": (38, "Zechariah"), "MAL": (39, "Malachi"),
    "WIS": (67, "Wisdom of Solomon"), "SIR": (68, "Ecclesiaticus"),
    "TOB": (69, "Tobit"), "JDT": (70, "Judith"),
    "1MA": (72, "1 Maccabees"), "2MA": (73, "2 Maccabees"),
}


@lru_cache(maxsize=1)
def review():
    value = json.loads(REVIEW_PATH.read_text())
    if value["sourceSHA256"] != SHA256 or value["schemaVersion"] != 1:
        raise ValueError("Unrecognized supplied Peshitta OT review")
    return value


def chapter_issues(chapter, *, book: str) -> list[str]:
    """Describe source defects without silently deduplicating or renumbering."""
    issues, numbers = [], []
    for verse in chapter:
        if verse.tag != "VERS" or list(verse):
            raise ValueError("Supplied Peshitta OT contains unsupported inline markup")
        label = verse.get("vnumber", "")
        if not re.fullmatch(r"[1-9][0-9]*", label):
            raise ValueError("Supplied Peshitta OT has a nonpositive/noninteger verse label")
        number = int(label)
        if number == 999 and book == "PSA":
            # The complete Psalm book is withheld by the mapping review. 999
            # marks prose introductions, not an ordinary verse or verse zero.
            continue
        numbers.append(number)
        text = verse.text or ""
        if not re.search(r"[\u0710-\u072f]", text):
            issues.append(f"verse {number} has no Syriac letters")
        if not re.search(r"[\u0730-\u073d]", text):
            issues.append(f"verse {number} has no Syriac vowel signs")
    if not numbers:
        issues.append("no ordinary verses")
    duplicates = sorted(number for number, count in Counter(numbers).items() if count > 1)
    if duplicates:
        issues.append("duplicate verse labels: " + ",".join(map(str, duplicates)))
    if numbers != sorted(numbers):
        issues.append("verse labels are out of order")
    if numbers:
        missing = sorted(set(range(1, max(numbers) + 1)) - set(numbers))
        if missing:
            issues.append("missing verse labels: " + ",".join(map(str, missing)))
    return issues


@lru_cache(maxsize=1)
def parsed_books(raw: bytes):
    if hashlib.sha256(raw).hexdigest() != SHA256:
        raise ValueError("The supplied Peshitta OT does not match its reviewed SHA-256")
    root = ET.fromstring(raw)
    if root.tag != "XMLBIBLE":
        raise ValueError("The supplied Peshitta OT is not Zefania XML")
    return root.findall("BIBLEBOOK")


def load_supplied_ot(source: dict, raw: bytes) -> dict:
    book = source.get("book")
    if book not in BOOKS:
        raise ValueError("Unreviewed supplied Peshitta OT book")
    identifier, name = BOOKS[book]
    candidates = [node for node in parsed_books(raw) if node.get("bname") == name]
    if (len(candidates) != 1 or candidates[0].get("bnumber") != str(identifier)
            or source.get("bookName") != name):
        raise ValueError("Supplied Peshitta OT book name/number does not match its review")
    chapters = candidates[0].findall("CHAPTER")
    numbers = []
    for chapter in chapters:
        label = chapter.get("cnumber", "")
        if not re.fullmatch(r"[1-9][0-9]*", label):
            raise ValueError("Supplied Peshitta OT has a nonpositive/noninteger chapter label")
        numbers.append(int(label))
    if numbers != review()["chapterLabels"][book]:
        raise ValueError("Supplied Peshitta OT chapter labels changed")
    repeated = {number for number, count in Counter(numbers).items() if count > 1}
    observed, values = {}, {}
    for chapter, number in zip(chapters, numbers):
        issues = chapter_issues(chapter, book=book)
        if number in repeated:
            issues.append("duplicate chapter label")
        if issues:
            observed.setdefault(str(number), []).extend(issues)
            continue
        for verse in chapter:
            verse_number = int(verse.attrib["vnumber"])
            if book == "PSA" and verse_number == 999:
                continue
            key = (number, verse_number)
            if key in values:
                raise ValueError("Supplied Peshitta OT would overwrite a verse")
            values[key] = verse.text
    if observed != review()["excludedSourceChapters"].get(book, {}):
        raise ValueError("Supplied Peshitta OT defects differ from their explicit review")
    for chapter, allowed in review().get("reviewedSparseChapters", {}).get(book, {}).items():
        chapter = int(chapter)
        if not set(allowed) <= {verse for c, verse in values if c == chapter}:
            raise ValueError("Supplied Peshitta OT lost a previously reviewed verse")
        values = {key: text for key, text in values.items()
                  if key[0] != chapter or key[1] in allowed}
    return values
