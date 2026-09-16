#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# ///
"""Conservative numeric profile for the exact Peshitta reader source assembly.

See Shared/content/PESHITTA-SOURCES.markdown. Source wording stays untouched.
Luke 10/11 and Revelation 12/13 are excluded for incomplete/ambiguous boundaries;
Philippians 1 and 3 John await independent local boundary review. Matching a
chapter's verse count never enables an exceptional boundary automatically.
"""

REVIEWED_ISAIAH = frozenset({(7, 14), (9, 2), (11, 2), (11, 3), (11, 4),
                           (11, 5), (11, 10), (22, 22), (28, 16)})

PROFILES = {
    "peshitta-1905": {
        "source_pin_digest": "ae92f0a0444e2d37faea9b5601e311a116aeab5302d722506a11a0a9c745aa42",
        "source_types": {"Eng-KJV"},
        "local_rule_lines": set(),
        "overrides": {},
        "blocked_chapters": {("LUK", 10), ("LUK", 11), ("PHP", 1), ("3JN", 1),
                             ("REV", 12), ("REV", 13)},
        "reviewed_inventory_exceptions": set(),
        "reviewed_sparse_chapters": {
            ("ISA", chapter): {verse for c, verse in REVIEWED_ISAIAH if c == chapter}
            for chapter, _ in REVIEWED_ISAIAH
        },
        "notes": "Pinned BFBS1905 NT TEI and exactly nine accepted supplied Isaiah verses. "
                 "Luke11 duplicate42 excluded during import; Luke10 incomplete final verse. "
                 "Revelation12/13, Philippians1 and3John remain blocked pending boundary review. "
                 "No new OT text, inferred subverse cuts, source corrections or fallback edition.",
    },
}
