# STEP verse-reference metadata

`rules.json` is a reference-only adaptation of **TVTMS — Translators Versification
Traditions with Methodology for Standardisation**, published by **STEP Bible**, based
on work at **Tyndale House Cambridge**, under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

The [upstream source](https://github.com/STEPBible/STEPBible-Data/tree/master/Versification)
and the pinned commit, source checksum, generated checksum and adaptation statement
are recorded in `sources.json`. The import retains all **22,874** machine-table
rows, with their original line numbers, source traditions, source and Standard
references, actions and numerical predicates. Scripture, notes, examples and
explanatory prose are excluded. The imported source is processed in memory and
is never saved to the Scripture cache. No NABRE text is included.

Regenerate or verify the metadata with:

```sh
uv run --script Shared/tools/fetch-step-mapping.py
uv run --script Shared/tools/fetch-step-mapping.py --check
```

The importer checks the upstream checksum before extracting fields. A source
update requires deliberate review and a new pin. Do not hand-edit `rules.json`.

## Interpretation

`reading_step_mapping.py` uses STEP's **English Standard** (KJV) as its reference hub.
That hub is distinct from NABRE, SIL Original and SIL English; callers must select an explicit
source adapter before using its references. Automatic tradition selection is
currently audited for the pinned **Douay–Rheims American Edition, 1899** source
only. Selecting a language is insufficient evidence to select another edition's
numbering rules.

`reading_standard_bridge.py` preserves the differences from SIL English's RSV-style
inventory: Standard 3 John 1:14 contains English 1:14–15, and Standard Revelation
13:1 contains English 12:18 and 13:1. Philippians 1:16–17 stays a complete pair
because verse order differs within that chapter. Unsupported books and title
slots remain unavailable through this bridge. DRA maps directly from STEP, using
six specifically reviewed local rule rows for its Greek-style 2 Corinthians 13
and Philippians 1 boundaries; this does not enable a global Greek tradition.

Sirach 33 is an explicit exception to the expanded table: it supplies no rows
for the chapter even though its verse divisions differ. The pinned DRA chapter
is independently aligned to the [KJV reference boundaries](https://ebible.org/eng-kjv/SIR33.htm)
in `DRA_SIRACH_33_TARGETS`. Matching chapter lengths cannot justify identity:
DRA 33:23–24 overlaps Standard 33:22–23, and DRA 33:31–33 overlaps Standard
33:30–31. The source and target adapters preserve each entire source verse and
mark any extra material. This review is confined to the hash-pinned DRA source.

The mapper evaluates the published `Exist`, `NotExist` and `Last` predicates
against the actual source inventory. Length comparisons count **words**. A
missing chapter cannot establish a verse's absence, and an incomplete chapter
cannot establish its final verse. Separate subverse-label absence requires a
complete explicit label inventory; the audited DRA VPL parser accepts whole
integer labels only. Unknown source formats retain an unknown result.

`IfEmpty` actions describe empty placeholders after renumbering and do not create
text correspondences. Edition-specific rules take precedence over generic
`AllBibles` annotations. Detailed subverse rows take precedence over concatenation
summaries, including the upstream `Jdt.2:16-8` summary typo. Unresolved conflicts
and unsupported details remain unavailable. The import itself remains unchanged.

Source verses are indivisible. Many-to-one and one-to-many relations retain the
smallest complete source-verse envelope and report when it includes additional
material. Additional Standard segments are not silently assigned to the ordinary
numbered verse. Lettered chapters and compound references retain their labels
and order. No words or subverse text boundaries are manufactured.

STEP's methodology separately lists variable clause boundaries whose numbers
remain unchanged in its expanded table. `reading_boundary_groups.py` retains
these as complete adjacent-verse alignment groups, shared by the NABRE and
target-edition adapters. An incomplete group is unavailable; requesting only
one side returns the complete group with the envelope flag.

The Psalm adapter has separately reviewed DRA title and overlapping clause
boundaries. These apply only to the DRA VPL
payload whose SHA-256 is
`96282bfa7c89a74680cea66fe873aafa5e7cd446407f0ff2531a723e19eee2c2`.
The source file is identified in `reading-text-sources.json`; replacement text
requires review of those boundaries.

## Verification

```sh
uv run --script Shared/tools/test-reading-step-mapping.py
uv run --script Shared/tools/test-reading-psalm-mapping.py
uv run --script Shared/tools/test-reading-standard-bridge.py
```

The tests cover split/merged verses, empty placeholders, ambiguous rules,
addition segments, incomplete source chapters, title slots, compound and
lettered references, source pins, and the September 13, 2026 Sirach and Psalm
readings. When the hash-pinned DRA cache is present, all **2,526** published
NABRE Psalm markers are checked against all **150** actual source Psalms, and
the DRA map is checked for extant-source round trips across the Bible. The bridge
checks the complete **1,189**-chapter SIL English body inventory and pinned
Delitzsch source regressions at both cross-system endpoint differences.
Numerical consistency does not establish that two editions have identical text.

All three native About screens credit STEP Bible and link to the source and
license. The separate NABRE structure import verifies NABRE's published labels;
it does not grant permission to reproduce NABRE wording.
