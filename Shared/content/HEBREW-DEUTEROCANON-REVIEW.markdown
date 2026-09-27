# Hebrew deuterocanonical transcription

The user supplied the three scans of Abraham Kahana's edited collection and requested
complete books, verified against the scans, before release. Collection editorship does
not imply that Kahana translated every book. The parsed contributor catalog is
`hebrew-kahana-source-catalog.json`. No book is enabled merely because its title or an
OCR layer exists. The files below are transcriptions of user-supplied sources; no blanket
public-domain statement is inferred for all contributors or editions.

## Working and source contract

Each book has a separate canonical file in `hebrew-deuterocanon/<BOOK>.json`, with this
shape. The file is a draft until its full scan comparison has finished; production import
requires `review.status` to be `complete` and every verse's pages and text hash to agree.

```json
{
  "schemaVersion": 1,
  "book": "WIS",
  "title": "חכמת שלמה",
  "translator": "מנחם שטיין",
  "collectionEditor": "אברהם כהנא",
  "attribution": "Source-specific Hebrew credit, identifying translation and edition.",
  "sourceURL": "https://he.wikisource.org/wiki/...",
  "scan": {"volume": "A2", "sha256": "...", "pageCount": 325},
  "review": {
    "status": "draft",
    "method": "Direct visual comparison of every verse with the supplied printed source.",
    "reviewedPages": [],
    "notes": []
  },
  "chapters": [
    {"number": 1, "verses": [
      {"verse": 1, "text": "source text", "sourcePages": [145], "textSHA256": "..."}
    ]}
  ]
}
```

`sourcePages` are one-based PDF pages, not printed Hebrew page labels. Preserve source
spelling, niqqud, punctuation and translator-supplied brackets; do not insert commentary,
headers, footnote markers or conjectured repairs. A verse continuing onto the next page
records both pages. Text hashes cover the exact UTF-8 text alone. A missing or uncertain
word remains an unresolved finding and prevents a complete review status. OCR and online
transcriptions may provide a draft, but are not evidence of a completed print comparison.

Wikisource comparisons retain the source page revision, translator and relationship to
the printed edition. `Shared/tools/hebrew_ocr_baseline.py` aligns explicitly selected
excerpts and records equal, replaced, omitted and inserted words without changing either
input. Niqqud is removed only for that comparison. Different translations provide lexical
and passage-location hints, not replacement wording or a measured OCR accuracy standard.
Every automatic alignment remains subject to image review, including exact-edition text.

Each actual source verse receives its own positive integer label. A printed combined
label such as 10–11 must stay one unit and have explicit `endVerse: 11`, rather than
duplicating or splitting its wording. Notify the shared importer owner of such a unit;
the chapter/archive schema must be extended consistently before importing it.
Preserve the actual array order even when the print moves a numbered verse, as in
Sirach 3:26,27,25. Labels remain unique and ranges nonoverlapping; do not sort the text.

An unnumbered scriptural opening is preserved as `introduction`, with separate
`introductionSourcePages` and `introductionTextSHA256` evidence. It is not assigned an
invented verse number. Editorial introductions and commentary are excluded. A printed
lacuna remains visible exactly as printed; set the affected chapter's `isComplete` to
false and describe the gap in review notes. A completed transcription review means the
whole printed text was checked; it does not certify that a damaged source is gap-free.

Book IDs: `TOB`, `JDT`, `WIS`, `SIR`, `BAR`, `1MA`, `2MA`; additions are separate
`LJE` (Letter of Jeremiah), `ESG` (Esther additions), `S3Y` (Prayer of Azariah and Song),
`SUS` (Susanna), and `BEL` (Bel and the Dragon). Preserve the actual source chapter
numbering and document it. Do not overwrite Masoretic Daniel or silently assign Vulgate
chapter labels. Daily-reading crosswalks will be reviewed separately against these units.

Tobit uses the explicitly identified long Greek recension printed in Hiller's parallel
translation. The shorter recension is not interleaved with it. Credit Hiller, not Kahana,
as its translator. The two recensions' numbering is not interchangeable.

## Reference scans

- A1: 343 pages, SHA-256 `d187d4a7844b1d59cd462c5d5130b04c5f5554dff390d27841be8cf03043597a`.
- A2: 325 pages, SHA-256 `d59349185a03a9436f70ee41d01c5c34c04c454f1d426f5a0bf3b4953ecb89a5`.
- B: 530 pages, SHA-256 `656891d377d2e3d4a9216723d94205488423907bf01df424b9f0b9de1560051e`.

The reference scans remain in local research storage, rather than being copied into each
native app. Completed text imports and source evidence are canonical shared data.

## Import and release gates

`Shared/tools/hebrew_deuterocanon.py` validates source hashes, contributor credits,
text-unit hashes, page evidence and nonoverlapping labels. Drafts may contain missing
pages or chapters; they never enter a production archive. The Bible generator imports
the supplement only when all twelve requested books have completed review. Its
`--require-hebrew-supplement` flag makes unfinished work an explicit release failure.

A completed book also requires an entry in `hebrew-deuterocanon-review.json`, with
`schemaVersion: 1` and `books` keyed by book ID. Each entry contains `contentSHA256`
(the canonical book object excluding `review`, serialized with sorted keys),
`scanSHA256`, independently checked `textPages`, `method`, `hasIntroduction`, and
`chapters: [{number, units: [[start, end], ...]}]` in the print's exact order.
Record this inventory from the print; do not manufacture it from the draft or an OCR
alignment. The validator never writes approvals.

Every completed chapter declares `lastVerse`. A printed gap is documented in the
approval's `sourceGaps`, keyed by chapter number, with `omittedLabels` and `reason`;
the chapter remains `isComplete: false`. The complete review must have no
`unresolvedFindings`, and its reviewed pages must exactly match the independently
inventoried pages and the text's page evidence. The approved digest invalidates the
review if text, spelling, pointing, page evidence or credits subsequently change,
even if individual text hashes are recomputed.
