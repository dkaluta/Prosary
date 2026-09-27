# Bible viewer

Readings contains two native modes, Daily Readings and Bible. They share the existing
`readingsEditionId` preference. Mode, book, chapter and verse position belong to the
current window; they do not change the selected prayer date. Terminal has no reader.

The Bible mode offers book, chapter and verse navigation in the selected edition's
language and numbering, previous/next available chapter, selectable text, source
credit, and the existing paired-script control. Hebrew chapter numbers use gematria.
Missing content never falls back to another edition. Partial chapters carry a visible
“Only part of this chapter is available” notice; gaps retain their source verse labels.

## Distribution contract (version 1)

Only `Shared/data/bible-catalog.json` is bundled and copied into the three native
data directories. Bibles are independent, optional downloads with explicit Download
and Remove Download actions, progress and retry. Downloading is an explicit user
action. Daily passages continue to work without Bible downloads.

The catalog root is `{schemaVersion: 1, editions: [...]}`. Each edition repeats the
existing reading-edition metadata (`id`, `languageCode`, `name`, `attribution`,
`sourceURL`, and optional paired `textScript`/`transliteratedTextScript`) and adds:

- `revision`: 64 lowercase hexadecimal characters identifying the uncompressed content.
- `downloadURL`: HTTPS URL of an immutable archive under
  `https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/`.
- `archiveSHA256`, `archiveByteCount`, `unpackedByteCount`: pinned archive identity and sizes.
- `books`: ordered `{id, name, transliteratedName?, attribution?, sourceURL?, introduction?, chapters}` records. Book IDs match
  the source adapters (uppercase letters/digits). Each chapter record is
  `{number, verseCount, isComplete}`. A chapter can exist even when only excerpts
  are available; `isComplete` must then be false. `name` and optional paired
  `transliteratedName` follow the edition's script, never the interface language.
  When supplied, book attribution and source URL are displayed alongside the edition
  credit; they identify the actual translator of a separately sourced supplement.
  Optional `introduction` preserves a source's unnumbered scriptural opening. Display
  it as scripture above the first available chapter only, in the edition's direction
  and typeface; it has no verse-picker entry. Do not include editorial introductions.

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
contains the complete Catholic canon. Sparse reviewed Arabic and Syriac material
remains explicitly partial. Per-book credits identify the translator when a
supplement requires a different translator; no uncredited supplement is appended.

The Hebrew supplement is held until every requested book passes the source-review
gate in `content/HEBREW-DEUTEROCANON-REVIEW.markdown`. OCR and Wikisource comparison
reports are research evidence and cannot enable a book. Release generation must use
`build-bible-library.py --require-hebrew-supplement --sync`; this fails while any book
is missing, remains a draft, or has text that changed after its completed review.
