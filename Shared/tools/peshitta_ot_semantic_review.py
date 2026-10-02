#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Exact, source-pinned Peshitta OT reading units and editorial exclusions.

The catalog records a completed semantic review, not an inferred chapter profile.
Scripture words are never filled from the comparison Bible or website witness.
"""
from functools import lru_cache
import hashlib
import json
from pathlib import Path

from peshitta_supplied_ot import BOOKS, SHA256

REVIEW_PATH = Path(__file__).with_name("peshitta-supplied-ot-semantic-review.json")


@lru_cache(maxsize=1)
def semantic_review() -> dict:
    value = json.loads(REVIEW_PATH.read_text())
    if value.get("schemaVersion") != 1 or value.get("sourceSHA256") != SHA256:
        raise ValueError("Unrecognized supplied Peshitta semantic review")
    coordinates = set()
    for book, chapters in value["reviewedCoordinates"].items():
        if book not in BOOKS:
            raise ValueError("Semantic review contains an unknown OT book")
        for chapter, verses in chapters.items():
            if (not chapter.isdecimal() or int(chapter) < 1 or not verses
                    or any(type(v) is not int or v < 1 for v in verses)
                    or verses != sorted(set(verses))):
                raise ValueError("Malformed semantic review coordinates")
            coordinates.update((book, int(chapter), verse) for verse in verses)
    if len(coordinates) != sum(row["coordinateCount"] for row in value["reviewEvidence"]):
        raise ValueError("Semantic review scope differs from its recorded evidence")
    assigned = set()
    for unit in value["compoundUnits"]:
        sources = {(unit["book"], unit["chapter"], v) for v in unit["sourceVerses"]}
        if (not sources <= coordinates or sources & assigned
                or len(sources) != len(unit["sourceVerses"])
                or unit["sourceVerses"] != list(range(min(unit["sourceVerses"]), max(unit["sourceVerses"])+1))
                or unit["standardVerses"] != unit["sourceVerses"] or not unit["reason"]):
            raise ValueError("Unreviewed, overlapping or malformed semantic unit")
        assigned.update(sources)
    withheld = [tuple(row["reference"]) for row in value["withheldSourceQueries"]]
    if len(withheld) != len(set(withheld)) or not set(withheld) <= coordinates:
        raise ValueError("Unreviewed or duplicated withheld source query")
    retained = [tuple(row["reference"]) for row in value["retainedSourceVariants"]]
    if (len(retained) != len(set(retained)) or not set(retained) <= coordinates
            or set(retained) & set(withheld)):
        raise ValueError("Unreviewed, duplicated or withheld retained source variant")
    headings = set()
    for row in value["editorialExclusions"]:
        ref = row["book"], row["chapter"], row["verse"]
        if (ref not in coordinates or ref in headings or row["position"] not in {"prefix", "suffix"}
                or not row["text"] or len(row["sourceVerseSHA256"]) != 64):
            raise ValueError("Unreviewed or duplicated editorial exclusion")
        headings.add(ref)
    return value


def reviewed_mapping() -> tuple[set, dict]:
    """Only explicitly read coordinates can acquire a source/Standard edge."""
    value = semantic_review()
    allowed = {(book, int(chapter), verse)
               for book, chapters in value["reviewedCoordinates"].items()
               for chapter, verses in chapters.items() for verse in verses}
    allowed -= {tuple(row["reference"]) for row in value["withheldSourceQueries"]}
    groups = []
    for unit in value["compoundUnits"]:
        group = {(unit["book"], unit["chapter"], v) for v in unit["sourceVerses"]}
        # An unresolved member withholds the complete unit, never a partial text.
        if not group <= allowed:
            allowed -= group
        else:
            groups.append(group)
    overrides = {ref: (ref,) for ref in allowed}
    for group in groups:
        for ref in group:
            overrides[ref] = tuple(sorted(group))
    return allowed, overrides


def reading_text(book: str, chapter: int, verse: int, original: str) -> str:
    """Remove a reviewed caption only when the complete original verse matches."""
    for row in semantic_review()["editorialExclusions"]:
        if (row["book"], row["chapter"], row["verse"]) != (book, chapter, verse):
            continue
        if hashlib.sha256(original.encode()).hexdigest() != row["sourceVerseSHA256"]:
            raise ValueError("Peshitta editorial exclusion source verse changed")
        fragment = row["text"]
        if row["position"] == "prefix" and original.startswith(fragment):
            result = original[len(fragment):]
        elif row["position"] == "suffix" and original.endswith(fragment):
            result = original[:-len(fragment)]
        else:
            raise ValueError("Peshitta editorial exclusion no longer matches")
        if not result.strip():
            raise ValueError("Peshitta editorial exclusion would erase the verse")
        return result
    return original
