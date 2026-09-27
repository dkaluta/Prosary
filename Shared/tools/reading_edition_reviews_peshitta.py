#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Source-pinned numeric profile for explicitly reviewed Peshitta reading units.

See Shared/content/PESHITTA-SOURCES.markdown. Source wording stays untouched.
Luke 10/11 and Revelation 12/13 are excluded for incomplete/ambiguous boundaries;
Philippians 1 and 3 John await independent local boundary review. Matching a
chapter's verse count never enables an exceptional boundary automatically. The
reader-only supplied OT review admits only individually read source coordinates
and complete compound units. Matching counts or website consonants cannot enable
any additional OT coordinate. Damaged chapters and unresolved wording remain
unavailable; the existing NT profile is unchanged.
"""
from peshitta_supplied_ot import BOOKS, review
from peshitta_ot_semantic_review import reviewed_mapping

REVIEWED_ISAIAH = frozenset({(7, 14), (9, 2), (11, 2), (11, 3), (11, 4),
                           (11, 5), (11, 10), (22, 22), (28, 16)})

_OT_REVIEW = review()
_SPARSE = {(book, int(chapter)): set(verses)
           for book, chapters in _OT_REVIEW["reviewedSparseChapters"].items()
           for chapter, verses in chapters.items()}
_LOCAL_BOUNDARIES = {(book, chapter)
                    for book, chapters in _OT_REVIEW["reviewedOrdinaryBoundaryChapters"].items()
                    for chapter in chapters}
_OT_BLOCKED = ({(book, chapter)
                for book, chapters in _OT_REVIEW["stepBoundaryRiskChapters"].items()
                for chapter in chapters} - _LOCAL_BOUNDARIES)
# A local boundary review cannot waive a damaged source chapter.
_OT_BLOCKED |= {(book, int(chapter))
                for field in ("additionalBlockedChapters", "excludedSourceChapters")
                for book, chapters in _OT_REVIEW[field].items()
                for chapter in chapters}
_OT_BLOCKED -= _SPARSE.keys()

# These supplied verses were individually checked: murder, adultery, theft.
# STEP's ordinary-order rules instead inspect Exo.37:29, whose chapter remains
# unreviewed here. Keep the local textual evidence independent of that unknown
# predicate; do not enable Exodus 37 or relax any other edition's rule.
_REVIEWED_OT_REFERENCES, _REVIEWED_OT_OVERRIDES = reviewed_mapping()

PROFILES = {
    "peshitta-1905": {
        "source_pin_digest": _OT_REVIEW["sourcePinDigest"],
        "source_corpus_sha256": "407731d14cad1ba1ae5bc8f12355e44806b6c980772246b42fa2543e1ade616b",
        "source_types": {"Eng-KJV"},
        "local_rule_lines": set(),
        "overrides": _REVIEWED_OT_OVERRIDES,
        "reviewed_source_references": _REVIEWED_OT_REFERENCES,
        "review_required_books": set(BOOKS),
        "excluded_rule_lines": {4361, 4362, 4363},
        "blocked_chapters": {("LUK", 10), ("LUK", 11), ("PHP", 1), ("3JN", 1),
                             ("REV", 12), ("REV", 13)} | _OT_BLOCKED,
        "reviewed_inventory_exceptions": set(),
        "reviewed_sparse_chapters": _SPARSE,
        "notes": "Pinned BFBS1905 NT TEI and user-supplied pointed OT XML. "
                 "Luke11 duplicate42 excluded during import; Luke10 incomplete final verse. "
                 "Revelation12/13, Philippians1 and3John remain blocked pending boundary review. "
                 "OT admits only the explicit semantic-review coordinates and complete compound units; "
                 "unresolved source queries remain withheld. Exact source-pinned editorial captions "
                 "are excluded without changing the surrounding Scripture. "
                 "Psalm and deuterocanonical numbering remains withheld. Original nine Isaiah prayer "
                 "verses and NT source files are unchanged. No inferred subverse cuts, word corrections "
                 "or fallback edition; OT edition/rights remain unresolved.",
    },
}
