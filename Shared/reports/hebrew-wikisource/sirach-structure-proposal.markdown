# Sirach source structure: bounded reader proposal

This is a proposal, not an implemented data contract or transcription approval.
The first draft covers supplied volume B PDF pages 449–530: 51 chapter containers
and 1,333 primary integer-labelled units. All 82 pages still require independent
word, point, punctuation and margin-label review. `sirach-print-inventory.json`
records the current draft's structures; it is not an independently approved inventory.

## Structures the numeric verse array cannot represent

| Printed structure | Concrete evidence | Required behavior |
|---|---|---|
| Reordered numeric units | 3:24,26,27,25,28; 48:6,8,7,9; 50:1,3,2,4 | Keep array order. Already supported. |
| Interleaved chapters | PDF468: 11:33,12:1,11:34,12:2 | Keep each printed identity and physical order; do not duplicate11:34 or silently renumber it. |
| Repeated main-text witnesses | 20:13 on479/480; 31:22 twice on495; 51:13,19,20 twice on530 | Distinct stable display identities and visible source labels, with each text shown once. They are not below-rule apparatus. |
| Subverse/range overlap | PDF514: 41:14ב,15, heading,14א–16,17 | Preserve printed part letters/range. Numeric14 alone does not identify a witness; ordinary nonoverlap rules cannot adjudicate this source. |
| Internal section headings | Before31:12, before41:14א–16, before44:1 | Display separate source headings in scripture language, not verse text or selectable verse labels. |
| Unnumbered scriptural material | Thanksgiving hymn across529–530 after51:12; closing blessing after51:30 | Display full text at its anchor, without invented verse numbers. |
| Unnumbered lacuna | PDF502 between35:26 and36:1 | Keep the visible gap at its physical position; don't infer its lost address. |
| Colophons | Three centered closing lines on530 | Preserve separately as source closing metadata; do not call them numbered scripture. |

There are also provisional identities requiring review before schema migration:
several unlabelled main rows currently follow the preceding explicit label, whereas
parallel ruled manuscript blocks sometimes label them separately. The main source's
identity must be resolved visually, not borrowed from the alternate manuscript.

## Recommended small extension

Keep current `verses` as the unique primary address index. Add an optional ordered
`contentBlocks` presentation list for exceptional books/chapters. Each entry has a
stable source-derived `id` and one of four kinds:

- `verse`: reference an existing primary verse by `chapter` and `verse`; no duplicate
  text payload. Optional `printedLabel` preserves a source part/range label such as
  `ידב` on the primary41:14 unit.
- `witness`: self-contained distinct source text, a literal `printedLabel`, and a
  structured `addresses` list (`chapter`, `verse`, optional `endVerse` and part).
  It is scripture, not a collapsible editorial note. Its stable ID distinguishes
  repeated51:19 from the first51:19. Do not merge it with the primary verse.
- `passage`: unnumbered scriptural text, including a printed lacuna. It has no
  invented address or verse-picker entry.
- `heading`: source section heading, shown above the next block, with no verse entry.

All self-contained textual blocks need the same source-page/hash/full-review evidence
as verses. Preserve optional paired-script text where relevant. A source heading is
not an interface translation. Ordinary books omit `contentBlocks` and retain the
current verse-list renderer.

Use a versioned archive/catalog contract before publishing this extension. Old apps
must reject a richer unsupported book, rather than download it and silently omit the
hymn or alternate witnesses. The source authoring contract and approval digest must
include every block; metadata tucked under `review` cannot be a production text source.

## Cross-chapter physical order

For the single known11/12 interleaving, let the chapter12 presentation list reference
primary11:34, after12:1. Omit11:34 from chapter11's presentation list. The primary
index remains in chapter11's data file; lazy loading requires at most that additional
chapter for this exception. The catalog needs an explicit small address-route entry
for11:34 → display chapter12/block ID, so a verse jump lands on the one physical
presentation instead of showing a second copy. Do not infer routes from array order.

This requires validation across the entire book at installation: every primary verse
has exactly one presentation reference, every block ID is unique, each reference
exists, and every exceptional route agrees with the block that actually displays it.
There is no cyclic nested block expansion: references point only to primary verse
text, not another presentation list. Keep the existing archive-size limits.

## Navigation and review decisions

The verse picker follows source blocks. Repeated addresses have separate choices
using the printed label plus a localized distinction such as “second occurrence”;
tapping a number without an occurrence chooses the first physical matching unit.
A combined or subverse unit can satisfy a numeric jump by its declared address range,
but this must not be mistaken for a daily-reading boundary crosswalk. Daily readings
continue to require separately reviewed unambiguous units.

This proposal does not choose whether the final unnumbered blessing is part of51:30,
nor approve any uncertain margin identity. It preserves the material while those
source decisions are reviewed. The centered closing colophons should remain explicit
book closing metadata, with their own text/hash/pages, and can be displayed after the
last scriptural block under source attribution styling.

Implementation should follow only after the parent confirms the shared shape and all
three native ports can validate, navigate and render it. Focused fixtures should use
actual source sequences:41:14ב/15/14א–16,51:13 repeated, the thanksgiving hymn, and
11:33/12:1/11:34/12:2. Tests must reject dangling references, duplicated physical
presentations, address-route mismatches, forged source hashes and unsupported schemas.
