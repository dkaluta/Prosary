# Wikisource as a Hebrew OCR baseline

Reviewed 27 September 2026. This inventory and the sampled comparisons support
transcription of the user-supplied Kahana collection. They do not certify complete
books, supply missing wording, or authorize a release. The source review contract
remains [HEBREW-DEUTEROCANON-REVIEW.markdown](HEBREW-DEUTEROCANON-REVIEW.markdown).

## Available witnesses

| Printed book | Wikisource baseline | Use |
| --- | --- | --- |
| 1 Maccabees, Abraham Kahana | Complete Kahana transcription, 16 chapters | Closest baseline; retain every online-versus-print difference for review |
| Sirach, Abraham Kahana | Hebrew manuscripts, David Kahana, Smend, Fraenkel, Ben Ze'ev | Select the identified manuscript or edition for comparison; no Abraham Kahana text pages were found in the complete prefix inventory |
| Tobit, Dov Hiller, long Greek recension | Neubauer's medieval Hebrew witness, 13 divisions | Passage and vocabulary clues; recension and divisions differ from the 14-chapter print |
| Judith, Moses Simon | Fraenkel text; Simon landing page and introduction | Passage and vocabulary clues; Simon's Scripture body is absent |
| Wisdom, Menachem Stein | Adapted Fraenkel translation, 19 chapters | Related vocabulary; not the same wording or verse divisions |
| Letter of Jeremiah, Eliyahu S. Hartom | Fraenkel translation | Related vocabulary; online 79 labels differ from print 72 plus an unnumbered opening |
| Esther additions, Menachem Stein | Other translations and retellings on the generic page | Context only; the Stein-specific page has an introduction and placeholder body links |
| Daniel additions, Dov Hiller | Fraenkel prayer, song, Susanna, Bel and Dragon | Edition-labeled context and vocabulary; not Hiller's text |
| Baruch and 2 Maccabees, Abraham Kahana | No matching body text found in the checked targets and searches | No usable exact-text baseline yet |

The collection's [translator table](https://he.wikisource.org/wiki/הספרים_החיצונים_(כהנא))
identifies the contributors. A link from that table is not proof that its destination
contains that translation: the [Wisdom page](https://he.wikisource.org/wiki/חכמת_שלמה)
explicitly presents an adaptation of Fraenkel, while its Stein edition is a scan link.
The [Stein Esther page](https://he.wikisource.org/wiki/תוספות_למגלת_אסתר) and
[generic Esther page](https://he.wikisource.org/wiki/תוספות_למגילת_אסתר) are distinct.

## Comparison workflow

1. Save the reference URL, revision, response hash, translator and available extent.
2. Select corresponding passages by wording and context. Do not join different
   editions on verse numbers alone. Retain original page images and raw OCR.
3. Compare unpointed tokens while retaining the exact original texts. Preserve
   consonants, defective/full spelling, final letters and non-Hebrew OCR noise.
4. Inspect matches and differences beside the image. A matching online word is a
   candidate, not an automatic correction. Verify vowel points separately.
5. Record reviewed source text only after image comparison. The comparison tools
   never modify the canonical transcriptions or their review status.

`Shared/tools/hebrew_ocr_baseline.py` produces a minimum word-edit alignment with
equal, replacement, deletion and insertion spans and offsets. Related translations
are labeled explicitly; their difference rate is never reported as OCR accuracy.
`Shared/tools/compare-1maccabees-ocr.py` provides the bounded exact-edition prototype
for chapter 1, using scripture-only crops of PDF B97–105 and Kahana's online text.

## What the samples establish

- The Letter and Wisdom comparisons show extensive wording differences from
  Fraenkel. Roughly one fifth of reference tokens match in order in these samples;
  those figures describe translation overlap with a provisional draft, not OCR
  quality or a verified verse crosswalk.
- Sirach manuscript A is substantially closer in its surviving chapter 3 sample
  than the other translations. It also independently preserves 26, 27, 25 order,
  matching the supplied print. Differences remain, including the printed reading
  at 3:15, so the manuscript still cannot replace the edited print automatically.
- A Wikisource-derived word list did not reliably improve OCR. After correcting
  the 1 Maccabees crops to preserve overhanging lines and separating marginal
  labels by word boxes, the held-out page had 52 exact aligned words without the
  list and 51 with it. This supersedes the apparent improvement from the earlier
  narrow crop. Removing small image components to suppress niqqud also worsened
  the tested Sirach sample. Neither experiment justifies automatic correction.
- A later local Kraken trial, using manually bounded lines, performed much better
  on the small tested excerpts. The separate Letter of Jeremiah test uses the
  user's transcription checked against their attached PDF15 crop: 48 of 52 words
  match, with four single-letter substitutions and no inserted or omitted words.
  This measures consonants only. The crop excludes marginal labels and does not
  establish whole-page segmentation, vowel-point fidelity or whole-book accuracy.
  Exact inputs, the corrected user typing omission, raw OCR, model hash and errors
  are preserved in `LJE-user-ocr-baseline.json` beside the provisional Sirach
  experiment. Neither comparison changes a book's review status.

Revision-pinned inventories, comparisons and bounded experiments are recorded in
`Shared/reports/hebrew-wikisource/`. Raw downloaded pages and trial images stay in
local research storage. Draft text and measured overlap remain separate from the
completed source-review evidence required for import.
