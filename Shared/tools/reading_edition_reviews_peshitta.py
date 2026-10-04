#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Source-pinned numeric profile for explicitly reviewed Peshitta reading units.

See Shared/content/PESHITTA-SOURCES.markdown. Source wording stays untouched.
Luke 10/11 and Revelation 12/13 are excluded for incomplete/ambiguous boundaries;
Philippians 1 and 3 John await independent local boundary review. Matching a
chapter's verse count never enables an exceptional boundary automatically. The
Patriarchate2020 website OT profile admits only coordinates corroborating the
prior independent semantic review, separately inspected appointment endpoints,
and complete compound units. Matching counts alone cannot enable a coordinate.
Source gaps, damaged chapters and unresolved wording remain unavailable; the
existing NT profile is unchanged.
"""
from peshitta_supplied_ot import BOOKS
from peshitta_eu_source import reviewed_mapping, review as website_review

REVIEWED_ISAIAH = frozenset({(7, 14), (9, 2), (11, 2), (11, 3), (11, 4),
                           (11, 5), (11, 10), (22, 22), (28, 16)})

# These supplied verses were individually checked: murder, adultery, theft.
# STEP's ordinary-order rules instead inspect Exo.37:29, whose chapter remains
# unreviewed here. Keep the local textual evidence independent of that unknown
# predicate; do not enable Exodus 37 or relax any other edition's rule.
_REVIEWED_OT_REFERENCES, _REVIEWED_OT_OVERRIDES = reviewed_mapping()
_WEBSITE = website_review()

PROFILES = {
    "peshitta-1905": {
        "source_pin_digest": _WEBSITE["sourcePinDigest"],
        "source_corpus_sha256": _WEBSITE["corpusSHA256"],
        "source_types": {"Eng-KJV"},
        "local_rule_lines": set(),
        "overrides": _REVIEWED_OT_OVERRIDES,
        "reviewed_source_references": _REVIEWED_OT_REFERENCES,
        "review_required_books": set(BOOKS),
        "excluded_rule_lines": {4361, 4362, 4363},
        "blocked_chapters": {("LUK", 10), ("LUK", 11), ("PHP", 1), ("3JN", 1),
                             ("REV", 12), ("REV", 13)},
        "reviewed_inventory_exceptions": {reference[:2] for reference in _REVIEWED_OT_REFERENCES},
        "reviewed_sparse_chapters": {},
        "notes": "Pinned BFBS1905 NT TEI and peshitta.eu Patriarchate2020 OT HTML. "
                 "Luke11 duplicate42 excluded during import; Luke10 incomplete final verse. "
                 "Revelation12/13, Philippians1 and3John remain blocked pending boundary review. "
                 "OT admits only source-pinned website coordinates corroborating the explicit prior semantic review, "
                 "independently inspected Job42 endpoints, and complete compound units; "
                 "unresolved source queries remain withheld. Exact source-pinned editorial captions "
                 "are excluded without changing the surrounding Scripture. "
                 "Unreviewed Psalm and deuterocanonical numbering remains withheld. Original nine Isaiah prayer "
                 "verses and NT source files are unchanged. No inferred subverse cuts, word corrections "
                 "or fallback edition; website2020 publication identified, redistribution license unstated.",
    },
}
