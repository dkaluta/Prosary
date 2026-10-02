# Sirach Wikisource baseline assessment

This is a reference-only OCR/transcription aid. The supplied Abraham Kahana volume B scan remains the canonical source. No Wikisource wording was copied into the canonical Sirach draft in this audit.

## Inventory

- All 318 existing `בן סירא/` subpages were enumerated through the MediaWiki API on 2026-09-27. The saved API response and SHA are in `sirach-inventory.json`.
- The advertised Abraham Kahana edition root and chapter 1 are missing (saved `sirach-metadata-1.json` and `sirach-metadata-2.json`); there are zero existing Abraham Kahana subpages in the prefix inventory. A red link naming an edition is not a text witness.
- Existing chapter URLs, separated by edition/manuscript, are in `sirach-chapter-urls.json`. These are page-presence counts, not claims that each chapter body is complete.

- דוד כהנא: 42 chapter pages; labels 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 18, 19, 20, 21, 25, 26, 27, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 44, 45, 46, 47, 48, 49, 50, 51.
- בן זאב: 51 chapter pages; labels 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51.
- פרנקל: 51 chapter pages; labels 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51.
- פשיטתא: 51 chapter pages; labels 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51.
- רודלף סמנד: 14 chapter pages; labels 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15.
- כתב יד A: 14 chapter pages; labels 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16.
- כתב יד B: 24 chapter pages; labels 10, 11, 15, 30, 31, 32, 33, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51.
- כתב יד C: 14 chapter pages; labels 3, 4, 5, 6, 7, 18, 19, 20, 21, 22, 23, 25, 26, 37.
- כתב יד D: 5 chapter pages; labels 7, 8, 36, 37, 38.
- כתב יד E: 2 chapter pages; labels 32, 33.
- כתב יד F: 3 chapter pages; labels 31, 32, 33.
- כתב יד מצדה: 5 chapter pages; labels 40, 41, 42, 43, 44.
- מגילות ים המלח: 2 chapter pages; labels 6, 51.

## Edition and manuscript distinction

- Wikisource identifies David Kahana as the 1912 edition based on original Hebrew manuscript fragments. This is a different editor/edition from the supplied Abraham Kahana scan; the shared surname does not establish source identity. Its chapters 1–2 pages explicitly mark the Hebrew original missing, and their reconstructed Hebrew differs substantially from the supplied Greek-based Abraham Kahana wording.
- Manuscript A chapter 3 is unpointed and much closer in its preserved Hebrew section. Wikisource explicitly notes3:25 follows3:27 in manuscript A, confirming the unusual sequence visible in supplied PDF 453. It does not supply the scan’s vowel points.
- Fraenkel and Ben Ze’ev have all 51 chapter pages. They are other translations (Fraenkel via German; Ben Ze’ev based on Syriac), so they supply possible cognate vocabulary, not missing canonical wording.
- Smend supplies 14 chapters of manuscript-based comparison. It sometimes agrees more closely at a given unit but includes its own readings. Never choose the closest wording and thereby silently synthesize an edition.

Evidence URLs:

- https://he.wikisource.org/wiki/בן_סירא
- https://he.wikisource.org/wiki/ויקיטקסט:בן_סירא
- https://he.wikisource.org/wiki/בן_סירא/דוד_כהנא/א
- https://he.wikisource.org/wiki/בן_סירא/כתב_יד_A/ג
- https://he.wikisource.org/wiki/בן_סירא/רודלף_סמנד/ג

## Sample word comparison

The comparison uses the provisional manual draft of supplied PDF 449–452 (64 stored units). It strips vowel marks and punctuation for token comparison, preserving consonants and distinct divine-name spellings. It does not certify that draft, niqqud, source alignment outside these pages, or any full book. Repeated Wikisource section labels are concatenated in their own order; missing labels remain absent. `sirach-comparison.json` preserves per-unit texts and scores for inspection.

| Baseline | Chapter | Comparable units | Exact unpointed units | In-order matching draft tokens |
|---|---:|---:|---:|---:|
| david | 1 | 20 | 0 | 66/164 |
| david | 2 | 18 | 0 | 94/156 |
| david | 3 | 15 | 2 | 90/129 |
| manuscriptA | 3 | 11 | 3 | 78/95 |
| smend | 3 | 11 | 4 | 74/95 |
| fraenkel | 1 | 29 | 0 | 73/236 |
| fraenkel | 2 | 18 | 0 | 51/156 |
| fraenkel | 3 | 16 | 0 | 24/136 |
| benzeev | 1 | 26 | 0 | 59/213 |
| benzeev | 2 | 17 | 0 | 54/149 |
| benzeev | 3 | 15 | 0 | 40/129 |

Concrete print-checked counterexamples:

-1:8: supplied Abraham print has the one wise and greatly fearsome figure seated on his throne; David’s version instead describes the fearsome one alone, ruling the treasures. It cannot fill this verse.
-3:15: **correction from the clearer-scan second pass:** both source scans end `להשבית עוניך`, agreeing with these baselines at this phrase. The earlier `שרך` report was a mistaken image reading, not a source variant. `SIR-page452-second-pass.json` retains the before/after evidence. The historical comparison scores above still describe the old provisional draft and must not be interpreted as current source differences.
-3:13: supplied scan reads `וגם אם יחסר`; David’s page reads `וגם איש יחסר`. Manuscript A/Smend have `אם`. The name of the edition is not enough to decide an OCR correction.
-3:26,27,25: manuscript A preserves the same displaced source order as supplied PDF 453; David’s edited page lists25 before26. The reader should preserve the scan’s order.

## Bounded local OCR lexicon experiment

- Portable engine: local Tesseract.js Hebrew best_int, PSM6. Input: `/private/tmp/prosary-sirach-review/B-449-body.png`. No page was uploaded.
- Unassisted output: `/private/tmp/prosary-hebrew-ocr/B-449.txt`, reported confidence 36.
- Baseline lexicon: 856 pointed/unpointed word candidates collected from chapter 1 of David Kahana, Fraenkel and Ben Ze’ev (`sirach-chapter1-user-words.txt`). Loaded using `user_words_file` during Tesseract reinitialization.
- Assisted output: `sirach-ocr-lexicon.txt`, reported confidence 37. The change corrects a handful of isolated words but leaves extensive merged spacing, letter substitutions, missing letters and false vowel marks. This is too small an improvement to justify automatic correction or unattended corpus transcription.
- Full-float official tessdata_best Hebrew model could not run in this WASM build (missing DotProductSSE function); no system changes or paid API were used.
- Better use: a side-by-side, verse-labeled candidate panel with edition attribution and difference highlights. Human source checking must approve each actual scan word and point. A baseline disagreement must remain visible, not be converted into a forced correction.

## Niqqud-removal experiment and disposition

A second bounded test removed detached black connected components from the same source crop, using 8-neighbour connectivity and maximum component areas of 20, 35 and 55 pixels. The original remained unchanged. Against the 13-unit provisional consonant transcription (400 Hebrew consonants including printed verse labels; heading omitted), raw OCR had 64 edits (16% character error), lexicon-assisted OCR 62 (15.5%), and filtered images 72, 70 and 92 (18%, 17.5% and 23%). These are sample-only, provisional figures, not a full-book or vowel-accuracy claim. Filtering is rejected because it also damages consonants. No further OCR tuning or batch transformation is approved by this experiment.

`sirach-ocr-experiments.json` records the model, original image hash, settings and results. Raw scan-derived images, API snapshots, OCR outputs and scratch scripts remain under `/private/tmp/prosary-hebrew-wikisource-baselines/` and `/private/tmp/prosary-hebrew-ocr/`; durable revision URLs and SHA-256 fingerprints allow source identification. This report does not mark any Sirach page proofread.

## Bounded Kraken alternative trial (2026-09-27)

The [PP-OCRv6 small multilingual recognition model](https://zenodo.org/records/21788405)
was published by Benjamin Kiessling on 2026-08-04 (v1, Apache-2.0). Its publication
explicitly includes Hebrew and Syriac and requires Kraken 7.1.0 or later. This is a
recognition aid, not a new textual witness. The source scan was processed locally;
no document was uploaded. The 13.1 MB `small.safetensors` file matched the published
MD5 `07279cd68cd4402807542799f12d0f4a`; its SHA-256 is
`3108259779f5abfed3908a1c9eafba64d17e4a2a169368c539ecfeff04c018f3`.

Kraken 7.1.1 ran on Python 3.13.13. Its declared SciPy 1.15.3 dependency failed to
load on this Mac with a malformed `__thread_bss` Mach-O section. A temporary local
SciPy 1.16.3 override ran successfully, **outside Kraken's declared dependency
range**. This compatibility workaround is recorded, not presented as a supported
installation recipe. All model files and environment changes remain under
`/private/tmp`; no application dependency changed.

The same B449 source rectangle used by the earlier Tesseract comparison was used.
Automatic neural segmentation fragmented its thirteen poetic rows into 67 regions,
so that output was unsuitable. The bounded follow-up supplied thirteen full-width
line rectangles in printed order and enabled logical RTL recognition. It performed
no image filtering, resizing, dictionary correction, or text substitution. Each
rectangle retains both poetic half-lines and its verse label. The clipped chapter
heading above the body is excluded from the comparison; a marginal chapter letter
inside the first body rectangle was not erased. Footnotes outside the body crop
were never part of this experiment.

**The reference remains a provisional manually transcribed sample of thirteen
units, not an independently proofread benchmark.** Comparing only Hebrew consonants
and printed verse labels (400 reference letters), with spaces, punctuation and
vowel points excluded, gave:

| Engine | Layout supplied | Consonant edit distance | Provisional sample rate |
| --- | --- | ---: | ---: |
| Kraken PP-OCRv6 small | Same 13 manual line rectangles | 13 / 400 | 3.25% |
| Tesseract Hebrew | Same 13 manual line rectangles | 68 / 400 | 17% |
| Tesseract Hebrew plus chapter-1 Wikisource candidate lexicon | Same 13 manual line rectangles | 64 / 400 | 16% |

This is evidence that Kraken may help locate missing or mistaken consonants on
this sample. It is not a full-book accuracy claim, a held-out evaluation, or a
license to copy its output. The model generally omits niqqud, and its publication
warns of mixed transcription conventions. All pointing, words, boundaries and
source sigla still require visual source review. No canonical Sirach text was
changed by this trial.

The full settings, per-unit raw outputs, source/model hashes and rectangle list are
in [`sirach-kraken-trial.json`](sirach-kraken-trial.json). The temporary reusable
runner is `/private/tmp/prosary-kraken-lines.py`; it accepts a source image and an
ordered JSON list of `{ "rect": [left, top, right, bottom], "unit": "reference" }`
objects. It refuses to overwrite a nonempty output directory and preserves cropped
images, uncorrected text, logs, hashes and the exact command. The successful trial
used `ocr -s -n --base-dir R`. This separate layout assistance must remain explicit
when comparing it to whole-page OCR.

## Further transcription observations (working, not approval)

During the main-print draft through B472, the manuscript-A chapter-14 snapshot
(revision 2914682) has malformed/truncated material around its apparent verses7–8.
Those labels are absent from the continuous main text of Kahana B472. Their mere
presence in a Wikisource page inventory is therefore not evidence of usable verse
text or a reason to fill the printed source. The original limited sample metrics
above remain limited to their stated sample; they do not certify these later pages.

The print also interleaves Sirach12:1 before an explicitly labelled11:34 on B468,
then returns to12:2–3. A structured `review.sourceOrderExceptions` entry in the
Sirach draft records that physical sequence while each chapter/verse identity is
stored exactly once. This is source evidence, not a claim that ordinary grouped
chapter navigation reproduces the interleaving. The complete source inventory and
subsequent visual review remain unfinished.

## Complete first draft and source-structure inventory

The first pointed draft now reaches supplied B PDF530, covering all82 main-text pages
449–530 and51 chapter containers, with1,333 primary numbered units. This is **not** a
completed proofreading: zero pages are approved and the production importer still
excludes the book. The draft preserves five separately recorded repeated main-text
witnesses, three internal headings, one subverse/range unit, one unnumbered lacuna,
an unnumbered thanksgiving hymn, a closing blessing and the closing colophons.

The machine-readable `sirach-print-inventory.json` records all current chapter
sequences and the separately retained texts with source pages/hashes. It derives
counts from the draft, not from an independent margin-label approval. A proposed
minimal reader extension is in `sirach-structure-proposal.markdown`; it is not yet an
adopted contract. Word/point review and final identity decisions remain mandatory.

Structural checks currently pass: all51 chapter numbers occur once; all82 drafted
pages occur once; primary verse ranges remain globally nonoverlapping; all current
text hashes match; no Hebrew combining mark is stranded after a bracket. These checks
say nothing about whether an individual letter or vowel matches the printed source.
