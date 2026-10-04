# Bible viewer

Readings contains two native modes, Daily Readings and Bible. They share the existing
`readingsEditionId` preference. Mode, book, chapter and verse position belong to the
current window; they do not change the selected prayer date. Terminal has no reader.

The Bible mode offers book, chapter and verse navigation in the selected edition's
language and numbering, previous/next available chapter, selectable text, source
credit, and the existing paired-script control. Hebrew chapter numbers use gematria.
Missing content never falls back to another edition. Partial chapters carry a visible
“Only part of this chapter is available” notice; gaps retain their source verse labels.

## Distribution contract

Only `Shared/data/bible-catalog.json` is bundled and copied into the three native
data directories. Bibles are independent, optional downloads with explicit Download
and Remove Download actions, progress and retry. Downloading is an explicit user
action. Daily passages continue to work without Bible downloads.

The catalog root is `{schemaVersion: 1, editions: [...]}`. Each edition repeats the
existing reading-edition metadata (`id`, `languageCode`, `name`, `attribution`,
`sourceURL`, and optional paired `textScript`/`transliteratedTextScript`) and adds:

- `revision`: 64 lowercase hexadecimal characters identifying the uncompressed content.
- Optional `archiveSchemaVersion`: 1, 2 or 3; absent means 1. Version 2 archives support
  disclosed source notes; version 3 also supports printed source structure. The manifest
  and every chapter must match this version.
- `downloadURL`: HTTPS URL of an immutable archive under
  `https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/`.
- `archiveSHA256`, `archiveByteCount`, `unpackedByteCount`: pinned archive identity and sizes.
- `books`: ordered `{id, name, canonicalReference?, transliteratedName?, attribution?, sourceURL?, introduction?, chapters}` records. Book IDs match
  the source adapters (uppercase letters/digits). Each chapter record is
  `{number, verseCount, isComplete, canonicalReference?}`. A chapter can exist even when only excerpts
  are available; `isComplete` must then be false. `name` and optional paired
  `transliteratedName` follow the edition's script, never the interface language.
  When supplied, book attribution and source URL are displayed alongside the edition
  credit; they identify the actual translator of a separately sourced supplement.
  Optional `introduction` preserves a source's unnumbered scriptural opening. Display
  it as scripture above the first available chapter only, in the edition's direction
  and typeface; it has no verse-picker entry. Do not include editorial introductions.

Optional book and chapter `canonicalReference` strings identify a reviewed Catholic
placement in the edition's language. They are display metadata, not source addresses
or a verse conversion. A denoted addition keeps its source work ID, source chapter
numbers, exact verse labels, text, source blocks and translator credits. Its book
`name` begins with the Catholic placement and retains the complete source title.
Use chapter `canonicalReference` in the chapter picker and reader heading instead
of a generic source chapter number. For these chapters, label verse rows and choices
as printed source labels; do not combine a Catholic chapter denotation with a source
verse label as though the two formed a reviewed Catholic citation. Source chapter
numbers remain the keys for storage, position, navigation and address routes.

The Hebrew Kahana additions have the following placements:

| Source work | Source chapter | Catholic placement |
| --- | --- | --- |
| `LJE` (Letter of Jeremiah) | 1 | Baruch 6 |
| `S3Y` (Prayer of Azariah and Song of the Three) | 1 | Daniel 3 |
| `SUS` (Susanna) | 1 | Daniel 13 |
| `BEL` (Bel and the Dragon) | 1 | Daniel 14 |
| `ESG` (Esther additions) | 1, 2, 3, 4, 5, 6, 7 | Esther A, B, C, C, D, E, F |

These whole-work and section placements follow the Catholic NABRE published by the
USCCB: [Baruch 6](https://bible.usccb.org/bible/baruch/6),
[Daniel 3](https://bible.usccb.org/bible/daniel/3),
[Daniel 13](https://bible.usccb.org/bible/daniel/13), and
[Daniel 14](https://bible.usccb.org/bible/daniel/14).
The [Esther introduction](https://bible.usccb.org/bible/esther/0) documents the A-F
scheme; [Esther 1](https://bible.usccb.org/bible/esther/1),
[Esther 4](https://bible.usccb.org/bible/esther/4), and
[Esther 10](https://bible.usccb.org/bible/esther/10) show the relevant A, C/D and F
texts alongside their placement in the book. Kahana divides the two prayers of
Esther C into separate source chapters 3 and 4. His chapter 7 contains the F dream
interpretation followed by the existing unnumbered translation colophon; the
colophon stays unnumbered even though NABRE labels its corresponding text F:11.
The Kahana and NABRE verse divisions differ, including LJE's 73 labels versus
Baruch 6's 72. No individual verse equivalence is asserted by this metadata.

Each ordinary ZIP/DEFLATE archive contains `manifest.json` and exactly the declared
`chapters/<BOOK>/<NUMBER>.json` files, with no directory entries. The manifest is
`{schemaVersion: 1, editionId, revision, books}` and its books exactly match the catalog.
Each chapter is `{schemaVersion: 1, editionId, book, chapter, verses}`, where `verses`
uses `{chapter, verse, endVerse?, text, transliteratedText?}`. Optional `endVerse`
preserves a source's indivisible combined label (for example 12–13). It is at least
`verse`. `verseCount` counts text units, not the sum of
labels in their ranges. Display the range once; jumping to either label finds that
same unit. Verse labels are positive and globally nonoverlapping, and match the
enclosing chapter. Preserve the array's source order, including editorial orderings
such as Kahana Sirach 3:24,26,27,25,28. Neither display nor navigation sorts the units;
the verse picker follows source order and a requested label finds its containing unit.
All paired verses must have both texts. The reader does not remap these labels.

Version 2 adds optional `sourceNotes` on verses, identifying an unreadable printed
point that is omitted from the transcription. Notes appear beside the affected verse
and link to its scan page; they are not included in selectable scripture text. Both
Bible and daily readers use the shared note model. Version 1 archives reject notes,
and old clients reject a version 2 manifest instead of silently dropping them.
See [SCRIPTURE-SOURCE-NOTES.markdown](SCRIPTURE-SOURCE-NOTES.markdown) for the exact
anchor, Unicode, source and review contract. Note-free archives keep version 1 and
their existing byte identity.

Version 3 adds optional chapter `contentBlocks` and explicit book `addressRoutes`.
These preserve repeated manuscript witnesses, overlapping parts, unnumbered scripture,
source headings, colophons and cross-chapter physical order. The primary `verses`
array remains the unique address index. Installation validates the complete book so
each primary unit is displayed exactly once and every route points to its actual
block. Older archive versions reject these fields. See
[BIBLE-SOURCE-STRUCTURE.markdown](BIBLE-SOURCE-STRUCTURE.markdown) for strict field,
navigation, source-note and review requirements.

Before installing, validate HTTPS, the exact byte count and SHA-256, archive paths,
manifest identity, declared chapter set, verse counts and nonempty text/pairs. Bound
downloads to 32 MiB, total expanded bytes to 128 MiB and an individual chapter to
2 MiB. Install atomically in the application's private Bible directory. Retain the
verified archive or extracted files; load chapters lazily off the UI thread. A
failed/interrupted download must not replace a working revision. Removing a download
clears that edition's local files and in-memory text without affecting daily passages.

## Sources and completeness

The generator reuses hash-pinned Scripture imports and source-specific exclusions.
On a clean checkout, `build-bible-library.py --fetch --check` downloads missing
source files into the ignored cache, verifies their pinned hashes, and checks the
committed archives and native catalogs without changing them. CI runs this source
audit separately from the offline bundle checks and caches only source downloads.
It does not infer missing verses, translate wording, or claim that every edition
contains the complete Catholic canon. Sparse reviewed Arabic material remains
explicitly partial. Peshitta Old Testament chapters now retain the native text and
numbering of [peshitta.eu](https://peshitta.eu/about.html), credited as **Old Testament -
publication of the Syriac Orthodox Patriarchate 2020**. Native book/chapter browsing
and reviewed daily correspondences have separate gates: a valid published chapter
does not establish a calendar's verse boundaries. Omission markers, invalid numbering,
copied chapter bodies and unsupported paired-script letters withhold the affected
chapter rather than turning editorial markers into Scripture. See
[PESHITTA-EU-2020-REVIEW.markdown](content/PESHITTA-EU-2020-REVIEW.markdown).
Per-book credits identify the translator when a
supplement requires a different translator; no uncredited supplement is appended.

Daily reading text resolves the canonical `passageBooks` source book and previously
reviewed whole verse units through the installed Bible store. It accepts only units
matching the bundled source, including both scripts and source notes. An absent,
removed, corrupt or older download retains the reviewed bundled text. Neither the
native reader nor the download store parses a display citation or guesses numbering.
New archive revisions are generated locally; their catalog URLs become downloadable
only after the corresponding archives have been published to the release branch.

The Hebrew supplement is held until every requested book passes the source-review
gate in `content/HEBREW-DEUTEROCANON-REVIEW.markdown`. OCR and Wikisource comparison
reports are research evidence and cannot enable a book. Release generation must use
`build-bible-library.py --require-hebrew-supplement --sync`; this fails while any book
is missing, remains a draft, or has text that changed after its completed review.
