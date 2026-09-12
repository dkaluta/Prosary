#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Whole-reference bridge from STEP Standard to SIL English (never Bible text).

STEP's machine-table Standard is the KJV reference hub. SIL's English table is
the RSV-style inventory and differs at 3 John 1:14-15 and Revelation 12:18/13:1.
The published STEP rows 27462-27472 record those complete units. Philippians
1:16-17 is a within-chapter swap that SIL does not describe; keep the pair as a
single alignment unit rather than guessing which source edition order applies.

Pinned sources and licenses: versification/step/sources.json and
versification/sources.json. Only the existing 66-book SIL mapping domain is
supported. Additional books, verse-zero titles and unknown endpoints fail closed.
"""
from functools import lru_cache
from typing import Iterable

from reading_boundary_groups import alignment_groups
from reading_step_mapping import Unavailable, load_rules
from reading_versification import SUPPORTED_BOOKS, Versification

Reference = tuple[str, int, int]
_SPLITS = {
    ("3JN", 1, 14): (("3JN", 1, 14), ("3JN", 1, 15)),
    ("REV", 13, 1): (("REV", 12, 18), ("REV", 13, 1)),
}
_STANDARD_MAXIMA = {("3JN", 1): 14, ("REV", 12): 17}
_PHILIPPIANS = frozenset({("PHP", 1, 16), ("PHP", 1, 17)})


@lru_cache(maxsize=1)
def _sil() -> Versification:
    # Verify both sets of source pins before trusting the bridge. These endpoint
    # checks also ensure a future metadata update cannot silently reuse the old
    # two-verse groups after changing either reference system.
    converter = Versification()
    if (converter.expected_chapter_max("eng", "3JN", 1) != 15
            or converter.expected_chapter_max("eng", "REV", 12) != 18):
        raise ValueError("Review the STEP/SIL bridge against the new SIL inventory")
    rows = {row[0]: row for row in load_rules()}
    required = {
        27463: ("3Jn.1:14-15", "3Jn.1:14"),
        27470: ("Rev.12:18; 13:1", "Rev.13:1"),
        27455: ("Php.1:16", "Php.1:17"),
        27456: ("Php.1:17", "Php.1:16"),
    }
    if any(line not in rows or tuple(rows[line][2:4]) != pair for line, pair in required.items()):
        raise ValueError("Review the STEP/SIL bridge against the new STEP relations")
    return converter


def standard_chapter_max(book: str, chapter: int) -> int | None:
    if book not in SUPPORTED_BOOKS or type(chapter) is not int or chapter < 1:
        return None
    return _STANDARD_MAXIMA.get((book, chapter), _sil().expected_chapter_max("eng", book, chapter))


def standard_to_sil_english(references: Iterable[Reference]) -> tuple[list[Reference], bool]:
    """Return complete SIL-English units and whether extra Standard verses enter.

    A split into two SIL references is exact when both represent the requested
    complete Standard verse. A variable-boundary pair adds the envelope flag
    when the caller requested only one side. The target edition's actual text
    and chapter inventory must still be validated after this numeric bridge.
    """
    requested = list(dict.fromkeys(tuple(ref) for ref in references))
    if not requested:
        raise Unavailable("Empty STEP Standard reference sequence")
    for reference in requested:
        if (len(reference) != 3 or reference[0] not in SUPPORTED_BOOKS
                or any(type(value) is not int or value < 1 for value in reference[1:])):
            raise Unavailable("STEP reference is outside the reviewed SIL-English bridge")
        maximum = standard_chapter_max(reference[0], reference[1])
        if maximum is None or reference[2] > maximum:
            raise Unavailable("STEP reference is outside its Standard chapter")
    selected = set(requested)
    groups = alignment_groups() + (_PHILIPPIANS,)
    expanded = []
    whole = False
    for reference in requested:
        unit = {reference}
        for group in groups:
            if reference in group:
                unit.update(group)
                whole |= not group <= selected
        expanded.extend(sorted(unit))
    result = []
    for reference in dict.fromkeys(expanded):
        result.extend(_SPLITS.get(reference, (reference,)))
    return list(dict.fromkeys(result)), whole
