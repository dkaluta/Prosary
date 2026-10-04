# Printed Bible source structure

Archive version 3 preserves printed structures that cannot fit a unique numeric
verse array. Versions 1 and 2 retain their existing behavior and byte identity.
The catalog root remains version 1; an edition containing these structures declares
`archiveSchemaVersion: 3`, and its manifest and every chapter use version 3.
Older clients reject that archive instead of silently omitting text. The extension
is for the Bible reader; daily appointments still require separately reviewed,
unambiguous source mappings.

## Primary addresses and presentation

Each chapter retains its existing `verses` array as the unique, nonoverlapping
primary address index. `verseCount` still counts that array. Optional, nonempty
`contentBlocks` supplies the complete physical display order for that chapter.
Without it, the ordinary verse-array renderer is unchanged.

Each block has a stable book-wide `id` matching `[a-z0-9][a-z0-9-]*` and one of these
exact shapes. Optional fields are marked with `?` here, not in JSON:

```text
{id, kind: "verse", chapter, verse, printedLabel?}
{id, kind: "witness", text, printedLabel, addresses, sourceNotes?}
{id, kind: "passage", text, sourceNotes?}
{id, kind: "heading", text}
{id, kind: "colophon", text, sourceNotes?}
```

A `verse` block references a primary unit's exact starting chapter/verse in the same
book. It never duplicates its text. A `witness` is a distinct printed scriptural
unit, including a second occurrence or overlapping part of an existing address.
Its nonempty `addresses` array contains `{chapter, verse, endVerse?, part?}` records;
`part` is a nonempty literal source part label. Addresses are positive integers no
greater than 1000, `endVerse >= verse`, and their chapters must exist in this book.
Duplicate effective addresses within one witness are invalid: an absent `endVerse`
equals an explicit `endVerse` matching `verse`. Witness addresses
may overlap primary units and other witnesses deliberately; block identity keeps
the distinct printed occurrences separate. Each witness requires its literal,
nonempty `printedLabel`.

A `passage` contains unnumbered scripture, including a printed lacuna. A `heading`
is a source section heading; a `colophon` is source closing metadata. Neither is
a numbered scripture unit. All text is nonempty and remains in the source language.
There are no nested block references. Unknown kinds or fields, null optional fields,
and paired-script block payloads are invalid in this first extension. Version 3
editions reject either paired-script metadata field, including when a particular
chapter has no blocks. Ordinary paired-script books continue to use versions 1/2.

`sourceNotes` on a witness, passage or colophon follows the same exact anchor/point rules as
verse notes. Note IDs remain unique across primary verses and all textual blocks
in the book. Headings cannot carry point notes. Colophon notes describe source
limitations in the closing metadata and never turn that metadata into scripture.

## Cross-chapter routing and installation

Catholic placement denotations in book/chapter `canonicalReference` metadata do not
change any source address or route. For example, Kahana Letter of Jeremiah retains
work ID `LJE` and source chapter 1 while its picker and heading display Baruch 6.
Its verse labels remain explicitly printed source labels; they cannot be presented
as Baruch 6 citations without a separately reviewed verse crosswalk. The same rule
applies to Daniel and Esther additions. Esther's source chapter 7 retains its
existing unnumbered translation colophon under the Esther F placement. See
[BIBLE-VIEWER.markdown](BIBLE-VIEWER.markdown) for placements and primary sources.

Book metadata may contain a nonempty `addressRoutes` array of
`{chapter, verse, displayChapter, blockId}`. Each route identifies the exact starting
address of a primary unit displayed by a `verse` block in a different chapter.
There must be exactly one route for every such moved unit, and none for unmoved
units. Do not infer routes from verse numbers. Routes must have unique source
addresses and point to the actual block and display chapter.

Validate the whole book before installation. Every primary unit is presented
exactly once, counting ordinary chapters without `contentBlocks` as implicit
references to their own verses. Every reference resolves; IDs are unique; routes
match the actual placement. A chapter cannot leave out its ordinary primary units
unless another chapter explicitly references them with a matching route. Keep all
existing size/hash/path limits and atomic installation behavior. Versions 1/2 reject
`contentBlocks` and `addressRoutes`, even if their arrays are empty.

The reader loads only the selected display chapter and any primary chapters directly
referenced by its blocks. A requested numeric address first resolves its containing
primary range and then its explicit route. It lands on that unit's one presentation.
There is no recursive block expansion.

When a primary unit is displayed in a different chapter, its row and picker label
include its source chapter (`11:34`, for example), with both components formatted
using the selected edition's numbering conventions. Ordinary same-chapter row
labels retain the existing verse-only format. Do not insert an invented heading.

## Reader behavior

Render primary units, witnesses and unnumbered passages as selectable scripture with
the selected edition's direction, font and source notes. Render source headings
separately and colophons in attribution styling with any source notes directly
after their text; neither joins copied scripture.
Never collapse or hide a witness as an editorial note. Preserve physical block order.

The verse picker follows the displayed blocks. Primary references and witnesses
have choices; unnumbered passages, headings and colophons do not invent verse choices.
Use stable block IDs for selection and scrolling. Witness choices use the printed
label plus a localized occurrence distinction when addresses repeat. Numeric jumps
prefer the primary unit; an explicit witness choice lands on that witness.

If a primary block has `printedLabel`, keep its normal numeric address for navigation
and show a visible, localized `Printed label: {label}` annotation beside the unit.
The label itself is literal source text in source direction. This preserves the
Susanna margin `כ–כא` at the independently located 40–41 unit without silently
changing either the print or the navigation address. Witnesses display their literal
labels directly. Interface labels ship in all eight supported languages.

## Authoring and review

Canonical Hebrew books remain source schema 1. Chapters may contain the same
`contentBlocks`, and the book may contain `addressRoutes`. Every self-contained
textual block additionally requires `sourcePages` and `textSHA256`; the latter hashes
its exact `text`. A reference block has neither because its primary unit owns them.
The archive generator strips these authoring evidence fields, preserves all blocks
and routes, and validates again before writing version 3.

All textual block pages count toward the complete-book review. All block fields and
routes enter the book digest. The independent approval additionally pins an ordered
`contentBlocks` inventory of `{number, ids}` for chapters that have blocks, and the
exact `addressRoutes` array (absent means empty for both). No source material kept
under `review` is imported as production text. Migrating draft material into blocks
does not approve its wording, points, source identity or completeness.

The Hebrew completion gate counts numbered source labels from both primary ranges
and validated witness addresses. A witness counts toward its addressed chapter,
even when printed in another chapter; overlapping ranges count each number once.
Unnumbered passages, headings and colophons cannot fill a numeric gap. A label
present only in a witness is not an omitted source label. This is label coverage,
not a claim that a labeled part contains an entire standard-edition verse: literal
part labels remain visible, and every printed word and boundary still requires
review. The complete digest pins the witness text and addresses, while the
independent block inventory pins its presence and physical order. Actual omitted
labels still require explicit source-gap evidence and a partial-chapter label.

Concrete fixtures must cover the 11:33 / 12:1 / 11:34 / 12:2 interleaving, repeated
51:13, overlapping 41:14ב and 14א–16, the unnumbered thanksgiving hymn, colophons and
the Susanna printed-label discrepancy. Reject missing or duplicated presentations,
dangling references, incorrect routes, forged hashes and unsupported versions.
