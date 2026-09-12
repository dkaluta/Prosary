#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Reference-only alignment groups for documented variable verse divisions.

The pinned STEP TVTMS methodology (lines 59-64) records these clause boundaries
as variable between editions. Expanded numeric rules deliberately keep their
numbers unchanged. The enclosing pair, rather than an individual verse, is a
safe unit for complete alignment. No Scripture wording is retained.

Source and CC BY 4.0 attribution: versification/step/sources.json.
https://github.com/STEPBible/STEPBible-Data/tree/master/Versification
"""

# Values identify the Standard verse AFTER each variable boundary.
# Explicit 2 Corinthians 13 splits and Philippians 1 swaps have their own rules.
_BOUNDARIES = {
    "MAT": [(15, 6), (17, 15), (20, 5)],
    "MRK": [(3, 20), (12, 15), (16, 8)],
    "LUK": [(1, 74), (6, 18), (7, 19)],
    "JHN": [(7, 1)],
    "ACT": [(2, 11), (3, 20), (4, 6), (5, 40), (9, 29), (13, 39), (24, 19)],
    "ROM": [(1, 10), (3, 26), (7, 10), (9, 12)],
    "2CO": [(1, 7), (8, 14), (10, 5)],
    "GAL": [(2, 20)],
    "EPH": [(1, 11), (2, 15), (5, 14)],
    "PHP": [(2, 8)],
    "COL": [(1, 22)],
    "1TH": [(1, 3), (2, 7), (2, 12)],
    "HEB": [(3, 10), (7, 21), (12, 23)],
    "1PE": [(3, 16)],
    "1JN": [(2, 14)],
    "REV": [(2, 28), (12, 13), (17, 10)],
}


def alignment_groups() -> tuple[frozenset[tuple[str, int, int]], ...]:
    result = []
    for book, boundaries in _BOUNDARIES.items():
        for chapter, verse in boundaries:
            # John 7:1 follows 6:71; John 7:0 is not a published numbered verse.
            before = (book, 6, 71) if (book, chapter, verse) == ("JHN", 7, 1) else (book, chapter, verse - 1)
            result.append(frozenset({before, (book, chapter, verse)}))
    return tuple(result)
