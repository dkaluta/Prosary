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

The selected work's contributor record controls its translator and reference scan.
`collectionEditor` normally inherits the catalog's collection editor. A work may instead
declare its own nonempty editor credit, or explicitly set `collectionEditor: null` when
the selected edition has no collection-editor credit. The canonical book must include
the same field and exact value; omitting it does not silently erase or inherit a credit.
Replacing a source still requires its own catalogued scan, exact translator credit,
page evidence and independent completion approval. The changed metadata invalidates
the previous approved content digest; an old edition's review cannot approve a replacement.

`sourcePages` are one-based pages of the pinned PDF or DjVu scan, not printed Hebrew page labels. Preserve source
spelling, niqqud, punctuation and translator-supplied brackets; do not insert commentary,
headers, footnote markers or conjectured repairs. A verse continuing onto the next page
records both pages. Text hashes cover the exact UTF-8 text alone. A missing or uncertain
word remains an unresolved finding and prevents a complete review status. OCR and online
transcriptions may provide a draft, but are not evidence of a completed print comparison.
The user explicitly confirmed on 27 September 2026 that the reader must retain the
printed vowel points. Unpointed reference excerpts are useful for checking consonants,
but do not replace or approve the source's niqqud.

The user subsequently approved source notes for isolated unreadable points. Under
[`SCRIPTURE-SOURCE-NOTES.markdown`](../SCRIPTURE-SOURCE-NOTES.markdown), omit only the
unreadable vowel or dagesh, retain the word and all readable marks, and attach an exact
anchor and scan-page link. Accepted notes are part of the content digest and have a
separate review/approval inventory. They do not excuse uncertain consonants, missing
words or verses, unfinished comparison, or unreviewed numbering. A completed review
with such notes means the source limitation is explicitly disclosed, not resolved.

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

For **Letter of Jeremiah only**, the user selected Frenkel's *Ketuvim Aharonim*
(Warsaw, 1863) in place of Hartom, and explicitly selected Brenton's Greek-English
Septuagint as the authority for verse boundaries. The reader therefore uses Brenton's
73 verses, including the epistolary opening as verse 1. Frenkel's 79 original sections
remain in the source crosswalk; resegmentation must preserve every Hebrew word in order.
Brenton supplies boundaries, not replacement Hebrew wording, spelling or vowel points.
The modernized Wikisource text is only a working reference: the pointed print on scan
pages 113–116 controls the transcription. In particular, the print has the correct
section label לה where the web transcription duplicates לח. The former Hartom approval
has been withdrawn and cannot approve Frenkel. See the `LJE-brenton-boundary-source.json`
and `LJE-frenkel-*` evidence under `Shared/reports/hebrew-wikisource/`.

Tobit uses the explicitly identified **short Greek recension** printed in the upper
part of Hiller's parallel translation. Independent inventory found all 14 chapters,
228 printed units and 35 text pages without missing labels. The introduction explicitly
attributes gaps in the long recension's chapters 4 and 13 to lost manuscript leaves;
that incomplete draft is archived separately under `Shared/reports/hebrew-wikisource/`
and is not blended into the chosen text. `TOB-recension-decision.json` records the
source-backed change of selection. Credit Hiller, not Kahana, as translator. The two
recensions' numbering is not interchangeable.

## Reference scans

- A1: 343 pages, SHA-256 `d187d4a7844b1d59cd462c5d5130b04c5f5554dff390d27841be8cf03043597a`.
- A2: 325 pages, SHA-256 `d59349185a03a9436f70ee41d01c5c34c04c454f1d426f5a0bf3b4953ecb89a5`.
- B: 530 pages, SHA-256 `656891d377d2e3d4a9216723d94205488423907bf01df424b9f0b9de1560051e`.
- Frenkel 1863: 244 DjVu pages, SHA-256 `e67bcdad0d6d8e528f79bf8e5ed403c13c1cd220a19cc75038728a0572136345`; Letter of Jeremiah is on pages 113–116.

The reference scans remain in local research storage, rather than being copied into each
native app. Completed text imports and source evidence are canonical shared data.

An additional scan of volume B from Wikisource provides clearer letter and vowel detail:
[`Apocrypha_Kahana_B_extra_scan.pdf`](https://he.wikisource.org/wiki/קובץ:Apocrypha_Kahana_B_extra_scan.pdf),
272 spreads, SHA-256 `b72eaf5d2d858fabb7c3438ac0436ccd64c394a7dd2fad609efabe628d5534c7`.
Match each spread side to the original scan by wording, layout and printed page number;
there is no reliable single page offset throughout the volume. Book-specific evidence
records those pairings and crop hashes. The original scan remains the canonical page
reference. Clearer images can supersede earlier tentative letter or vowel readings;
retain the correction history and never treat the old draft as ground truth.

Source structure also needs independent checking. Baruch's separately audited margin
inventory is `Shared/reports/hebrew-wikisource/BAR-print-inventory.json`: 123 printed
units across five chapters. Its last chapter 3 label is 37, followed by an unnumbered
continuation before chapter 4. That continuation is preserved; a printed label 38 or
a crosswalk to another edition is not invented. Margin labels may begin a new unit
partway through a physical line, so page crossings cannot be inferred from line starts.

Sirach's draft records internal headings, repeated main-body manuscript witnesses,
subverse labels, and cross-chapter physical-order exceptions separately in review
evidence. These require a shared representation before import. Do not discard them,
merge distinct witnesses into one verse, or silently relabel them to satisfy the current
numeric unit contract. Their presence in review evidence is not production support.
The implemented source contract is specified in
[`BIBLE-SOURCE-STRUCTURE.markdown`](../BIBLE-SOURCE-STRUCTURE.markdown): ordered
`contentBlocks`, exact source hashes/pages on self-contained blocks, and explicit
`addressRoutes` for cross-chapter primary presentations. The approval separately
pins ordered block IDs and routes in addition to the full content digest. Migration
does not approve draft words or source identities.

Susanna uses the separately titled lower Theodotion text in A2 pages 237–242. The
upper old Greek text and the following Bel and the Dragon are separate works/versions.
Its independent margin inventory finds 59 units ending at printed label 64, including
an apparent repeated `כ–כא` margin label after 39 and before 42. The separately reviewed
disposition in `SUS-label-disposition.json` retains positional 40–41 for navigation
and the literal-looking `כ–כא` as a visible `printedLabel` annotation on its version 3
presentation reference. The original margin inventory remains unchanged. This does
not certify the misprint as an ordinary printed 40–41 label.

## Import and release gates

The completed source reviews are Judith (16 chapters, 332 source units, all
23 text pages), Baruch (five chapters, 123 source units, all seven text pages),
Frenkel's Letter of Jeremiah (73 Brenton verses preserving 79 source sections,
all four text pages, one disclosed unreadable dagesh),
the Prayer of Azariah and Song of the Three (69 units plus the unnumbered closing
narrative, all four pages, 65 disclosed unreadable points), and
Susanna (59 units, all six pages, 25 disclosed isolated unreadable points and an
explicit printed-label disposition).
Their exact content is pinned in `hebrew-deuterocanon-review.json` against separately
recorded source inventories. The other seven selected works remain unfinished; these
five completed books do not open the production gate by themselves. Completion here
means the chosen Hebrew edition has been transcribed and checked, not that its
numbering has already been reconciled with every daily-reading citation.

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
`unresolvedFindings`; accepted, displayed point notes must instead match the separate
`acceptedSourceNoteIds` and approval `sourceNoteIds` inventories. Its reviewed pages must exactly match the independently
inventoried pages and the text's page evidence. The approved digest invalidates the
review if text, spelling, pointing, page evidence or credits subsequently change,
even if individual text hashes are recomputed.
