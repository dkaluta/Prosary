#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reviewed English-to-Delitzsch 1901 whole-verse boundaries.

Only use with the pinned delitz.fr/12 transcription. Calendar references must
first resolve unambiguously to SIL English numbering. Returned chapter/verse
numbers are the source's published labels; Scripture words are never altered.
See DELITZSCH-NUMBERING.markdown for the six inspected chapter differences.
"""
from __future__ import annotations

from typing import Iterable

from reading_versification import chapter_verse_count

Reference = tuple[str, int, int]
NEW_TESTAMENT = frozenset((
    "MAT MRK LUK JHN ACT ROM 1CO 2CO GAL EPH PHP COL 1TH 2TH 1TI 2TI TIT PHM "
    "HEB JAS 1PE 2PE 1JN 2JN 3JN JUD REV"
).split())
CHAPTER_MAXIMA = {
    ("JHN", 1): 52,
    ("ROM", 7): 26,
    ("1CO", 13): 14,
    ("2CO", 13): 13,
    ("2TH", 3): 19,
    ("REV", 12): 17,
}
MERGED_UNITS = (
    ((("2CO", 13, 12), ("2CO", 13, 13)), ("2CO", 13, 12)),
    ((("REV", 12, 18), ("REV", 13, 1)), ("REV", 13, 1)),
)


def chapter_matches(book: str, chapter: int, keys: Iterable[int]) -> bool:
    """Accept only the complete source inventory, including reviewed maxima."""
    if book not in NEW_TESTAMENT or type(chapter) is not int or chapter < 1:
        return False
    maximum = CHAPTER_MAXIMA.get((book, chapter)) or chapter_verse_count(book, chapter, "eng")
    if maximum is None:
        return False
    keys = list(keys)
    return (all(type(key) is int for key in keys) and len(keys) == maximum
            and set(keys) == set(range(1, maximum + 1)))


def source_references(english_refs: Iterable[Reference]) -> list[Reference]:
    """Return ordered source verses; refuse incomplete or reordered merged units.

    Splitting one English verse into two complete source verses preserves its
    entire text. A source verse combining two English verses is usable only when
    both are requested consecutively, in their published order. Repeated input
    or overlapping output is an error, not permission to silently drop a verse.
    """
    references = list(english_refs)
    for reference in references:
        if (not isinstance(reference, (tuple, list)) or len(reference) != 3
                or reference[0] not in NEW_TESTAMENT
                or any(type(number) is not int or number < 1 for number in reference[1:])):
            raise ValueError("Invalid English New Testament reference")
        maximum = chapter_verse_count(reference[0], reference[1], "eng")
        if maximum is None or reference[2] > maximum:
            raise ValueError("Reference outside English chapter")
    references = [tuple(reference) for reference in references]
    if len(references) != len(set(references)):
        raise ValueError("Repeated English reference")

    result = []
    position = 0
    while position < len(references):
        reference = references[position]
        unit = next((unit for unit in MERGED_UNITS if reference in unit[0]), None)
        if unit is not None:
            required, target = unit
            if tuple(references[position:position + len(required)]) != required:
                raise ValueError("Incomplete or reordered merged Delitzsch verse")
            result.append(target)
            position += len(required)
            continue

        book, chapter, verse = reference
        source_verses = [verse]
        if (book, chapter) == ("JHN", 1):
            if verse == 38:
                source_verses = [38, 39]
            elif verse > 38:
                source_verses = [verse + 1]
        elif (book, chapter, verse) == ("ROM", 7, 25):
            source_verses = [25, 26]
        elif (book, chapter) == ("1CO", 13):
            if verse == 12:
                source_verses = [12, 13]
            elif verse == 13:
                source_verses = [14]
        elif (book, chapter, verse) == ("2CO", 13, 14):
            source_verses = [13]
        elif (book, chapter) == ("2TH", 3):
            if verse == 16:
                source_verses = [16, 17]
            elif verse > 16:
                source_verses = [verse + 1]
        result.extend((book, chapter, source_verse) for source_verse in source_verses)
        position += 1

    if len(result) != len(set(result)):
        raise ValueError("Overlapping Delitzsch source references")
    return result
