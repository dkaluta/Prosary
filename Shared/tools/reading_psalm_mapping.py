#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Numeric Psalm correspondence for NABRE and the pinned Douay-Rheims edition.

NABRE mostly follows Hebrew/Original numbering, with local differences in Psalms
2, 66, 72, 109 and 146. STEP's Standard Psalm labels use English numbering and a
separate title slot. SIL provides the ordinary offsets; the USCCB's published
markers and the NAB/NABRE rules in reversify establish the local exceptions.
No Scripture wording is stored here. Verse zero denotes correspondence metadata
for a title; it is not permission to manufacture a missing source title.

Sources:
https://bible.usccb.org/bible/psalms/2
https://bible.usccb.org/bible/psalms/66
https://bible.usccb.org/bible/psalms/72
https://bible.usccb.org/bible/psalms/109
https://bible.usccb.org/bible/psalms/146
https://bible.usccb.org/bible/psalms/13
https://bible.usccb.org/bible/psalms/51
https://bible.usccb.org/bible/psalms/139
https://ebible.org/Scriptures/engDRA_vpl.zip (pin: reading-text-sources.json)
SIL tables and their pinned source URLs: versification/sources.json
STEP TVTMS: https://github.com/STEPBible/STEPBible-Data/tree/master/Versification
https://github.com/curiousdannii/reversify/blob/master/src/transformations.data
"""
from __future__ import annotations

from collections import defaultdict
from functools import lru_cache
from typing import Iterable

from reading_versification import Reference, Versification


@lru_cache(maxsize=1)
def _hebrew_psalm_correspondence() -> tuple[dict[Reference, frozenset[Reference]],
                                         dict[Reference, frozenset[Reference]]]:
    """Retain complete title/verse relations instead of requiring single edges."""
    converter = Versification()  # Verifies every pinned table and license hash.
    english = converter.tables["eng"]
    to_original: dict[Reference, frozenset[Reference]] = {}
    for (book, chapter), maximum in english.maxima.items():
        if book != "PSA":
            continue
        for verse in range(1, maximum + 1):
            ref = (book, chapter, verse)
            to_original[ref] = frozenset(english.explicit.get(ref, {ref}))
    # A title can cover two numbered Hebrew verses. Keeping both edges makes a
    # request for only one of them an explicitly wider title envelope.
    for ref, targets in english.explicit.items():
        if ref[0] == "PSA" and ref[2] == 0:
            to_original[ref] = frozenset(targets)
    from_original: dict[Reference, set[Reference]] = defaultdict(set)
    for target, originals in to_original.items():
        for original in originals:
            from_original[original].add(target)
    return ({key: frozenset(value) for key, value in from_original.items()}, to_original)


@lru_cache(maxsize=1)
def _psalm_correspondence() -> tuple[dict[Reference, frozenset[Reference]],
                                   dict[Reference, frozenset[Reference]]]:
    from_original = {key: set(value) for key, value in _hebrew_psalm_correspondence()[0].items()}
    # The USCCB text ends Psalm 2 at 11; that unit covers Standard 11-12.
    from_original[("PSA", 2, 11)] = {("PSA", 2, 11), ("PSA", 2, 12)}
    from_original.pop(("PSA", 2, 12))
    # Numbered titles are followed by a merged pair, so later verse numbers
    # match again. Equal chapter lengths alone cannot reveal these differences.
    for chapter in (66, 72, 109):
        from_original[("PSA", chapter, 1)] = {("PSA", chapter, 0)}
        from_original[("PSA", chapter, 2)] = {("PSA", chapter, 1), ("PSA", chapter, 2)}
    # NABRE 146:1 is the opening acclamation; 146:2 includes the rest of
    # Standard 146:1 as well as Standard 146:2. Retain both overlap edges.
    from_original[("PSA", 146, 1)] = {("PSA", 146, 1)}
    from_original[("PSA", 146, 2)] = {("PSA", 146, 1), ("PSA", 146, 2)}
    reverse: dict[Reference, set[Reference]] = defaultdict(set)
    for source, targets in from_original.items():
        for target in targets:
            reverse[target].add(source)
    return ({key: frozenset(value) for key, value in from_original.items()},
            {key: frozenset(value) for key, value in reverse.items()})


def nabre_psalm_to_standard(references: Iterable[Reference]) -> tuple[list[Reference], bool]:
    """Return STEP Standard references and whether a whole-unit envelope grew.

    All 150 Psalms are supported, including numbered superscriptions. Callers
    must check actual source availability after conversion. A source reference
    outside the NABRE Psalm inventory is an error, never an identity guess.
    """
    return _map_psalm_references(references, *_psalm_correspondence(), "NABRE")


def hebrew_psalm_to_standard(references: Iterable[Reference]) -> tuple[list[Reference], bool]:
    """Resolve verified Hebrew-numbered Psalms, without NABRE's local boundaries.

    Only explicitly reviewed appointments may use this source-numbering path.
    Numbered standalone titles retain their complete correspondence. Titles
    joined to a body verse follow SIL's body-verse relation; the chosen edition
    supplies its own existing full verse, including its title when present.
    """
    return _map_psalm_references(references, *_hebrew_psalm_correspondence(), "Hebrew")


def _map_psalm_references(references, forward, reverse, source_label):
    requested = list(references)
    if not requested:
        raise ValueError("An empty Psalm appointment has no correspondence")
    selected = set(requested)
    mapped: list[Reference] = []
    seen: set[Reference] = set()
    for ref in requested:
        if (not isinstance(ref, tuple) or len(ref) != 3 or ref[0] != "PSA"
                or type(ref[1]) is not int or type(ref[2]) is not int
                or ref[1] < 1 or ref[2] < 1 or ref not in forward):
            raise ValueError(f"Invalid {source_label} Psalm reference: {ref!r}")
        for target in sorted(forward[ref]):
            if target not in seen:
                mapped.append(target)
                seen.add(target)
    includes_whole_verses = any(not reverse[target] <= selected for target in mapped)
    return mapped, includes_whole_verses


# STEP's title conditions miss DRA Psalm 10:1 and the title merged into 12:1.
# Its generic Latin Psalm 138
# rows also omit these edition-specific clause boundaries. Each edge means OVERLAP, not a
# claim that the complete two verses are identical. These apply to the pinned
# engDRA corpus, never to all Latin-derived editions.
DRA_PSALM_SOURCE_OVERLAPS: dict[Reference, frozenset[Reference]] = {
    ("PSA", 10, 1): frozenset({("PSA", 11, 0)}),
    ("PSA", 12, 1): frozenset({("PSA", 13, 0), ("PSA", 13, 1)}),
    ("PSA", 65, 1): frozenset({("PSA", 66, 0), ("PSA", 66, 1)}),
    ("PSA", 71, 1): frozenset({("PSA", 72, 0)}),
    ("PSA", 71, 2): frozenset({("PSA", 72, 1), ("PSA", 72, 2)}),
    ("PSA", 108, 1): frozenset({("PSA", 109, 0)}),
    ("PSA", 108, 2): frozenset({("PSA", 109, 1), ("PSA", 109, 2)}),
    ("PSA", 108, 3): frozenset({("PSA", 109, 2), ("PSA", 109, 3)}),
    ("PSA", 138, 2): frozenset({("PSA", 139, 2)}),
    ("PSA", 138, 3): frozenset({("PSA", 139, 2), ("PSA", 139, 3)}),
    ("PSA", 138, 4): frozenset({("PSA", 139, 3), ("PSA", 139, 4)}),
    ("PSA", 138, 5): frozenset({("PSA", 139, 4), ("PSA", 139, 5)}),
    ("PSA", 145, 1): frozenset({("PSA", 146, 1)}),
    ("PSA", 145, 2): frozenset({("PSA", 146, 1), ("PSA", 146, 2), ("PSA", 146, 3)}),
    ("PSA", 145, 3): frozenset({("PSA", 146, 3)}),
}


def dra_psalm_standard_overrides() -> dict[Reference, frozenset[Reference]]:
    """Return replacement target edges for the source-reviewed DRA boundaries."""
    inverse: dict[Reference, set[Reference]] = defaultdict(set)
    for source, standards in DRA_PSALM_SOURCE_OVERLAPS.items():
        for standard in standards:
            inverse[standard].add(source)
    return {key: frozenset(value) for key, value in inverse.items()}
