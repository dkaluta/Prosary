# Arabic Psalm appointments, 6 October 2026

The new `arabic-jesuit-1897-psalm-readings-2026.json` extends the existing reader-only
Psalm transcription from the same 1897 Beirut Jesuit printing. It preserves the printed
words and native chapter/verse labels. It does not change the prayer Scripture corpus,
translate another Bible, or claim a complete Arabic Bible.

## Printed witnesses

The original [Archive scan](https://archive.org/details/AlKitabAlMoqadas) has 570 PDF pages and
SHA-256 `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.
Every new source row records its inspected one-based PDF page or pages. The scanned
Psalm leaves have printed page number equal to PDF page minus four.

An independent [Princeton color copy, hosted by NYU](https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/)
confirms difficult letters, column continuations and the same printed line layout.
Its [approval leaf](https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/9) dates the
printing to 3 November 1897. The edition, pagination and text match the original
grayscale witness. The color images were inspected directly; no OCR or generative
image repair supplied Scripture words. Scan images are not redistributed.

Independent readers checked the draft against the page images, then returned to
enlarged crops for disputed words. As in the existing transcription, short vowels,
shadda and ornaments are omitted, while whitespace, punctuation and hamza typography
are normalized. Historical wording is preserved.

## Clause boundaries

The exact original Roman Psalm appointments retain their already verified Hebrew
source numbering. The new review maps their Standard clauses to complete printed
Arabic units. It neither assumes a uniform chapter offset nor slices a source verse.

| Printed source unit | Standard unit | Material retained |
| --- | --- | --- |
| 8:7 | 8:6 | Both works of the hands and all things under his feet. |
| 12:6 | 13:5-6 | Trust, rejoicing and the final song in one printed unit. |
| 18:5-6 | 19:4-5 | The words throughout the earth, the sun's tent and the bridegroom/race clause. |
| 94:7-9 | 95:7-9 | The existing shared Today/hear, hardening and testing envelope. |
| 106:2-3 | 107:2-3 | Redemption and gathering, followed by all the named directions. |
| 115:3,4,8,9 | 116:12,13,17,18 | Benefits, cup, thanksgiving and the later vow-payment occurrence. |
| 117:16 | 118:15-16 | All three printed right-hand clauses. |
| 138:2-3 | 139:2-3 | Sitting/rising, distant thoughts and all the searched paths/ways. |

When a requested clause crosses a printed boundary, the reader includes complete
source units and carries the existing localized whole-verse notice. Selecting one
of two identical vow-payment sentences still selects its actual appointed occurrence.

The source-unit facts may also serve a different calendar only after that calendar's
own published numbering has independently been established. A verified profile supplies
Standard coordinates; the adapter requires every requested clause to have reviewed
source text. An unreviewed calendar, missing source words or an unsupported chapter
remain unavailable. The optional Bible remains a separately declared partial corpus.

## Independent rereading corrections

The peer review caught literal differences from familiar contemporary wording, including
printed 36:4 `فتمتلك`, 36:5 `يفعل`, 41:2 `يشتاق`, 70:6 `منعم علي`, 138:15
`ذاتي عنك`, 138:23 `امحني`, and 143:10 `المولي`. These are source readings,
not editorial paraphrases. Printed 30:20 has `للمتقين لك وجبلتها` and
`تجاه بني البشر`, confirmed in the [color page](https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/232).
Printed 17:47 retains `حي الرب وتبارك صخري وتعال خلاصي`; an unprinted `إله`
is not supplied from another translation.

### One unresolved printed mark

Printed 89:12 reads `فعلمنا أن نعد أيامنا هكذا فاتي بقلب ذي حكمة` in the
unpointed transcription. The letters of `فاتي` are visible, but the small mark on
its alif cannot securely be distinguished as hamza or maddah in either witness.
The transcription retains the visible base alif without inventing either mark.
A specific editorial note and the [Princeton page](https://sites.dlib.nyu.edu/viewer/books/princeton_aco001445/243)
are carried in that passage's source credit. Text from the neighboring right column,
Psalm 88:10, is not part of this verse.

## Reproducibility

`../tools/arabic-daily-psalm-reviews.json` pins the original and new canonical
transcriptions, explicit source/Standard unit relationships, and all 103 original
Roman Psalm appointments. `arabic_daily_psalms.py` rejects changed source words,
incomplete coverage, unknown calendar contexts and unreviewed coordinates. The native
apps receive only the resolved passage rows and source credit, not a runtime reference parser.

`test-arabic-daily-psalms.py` checks source clauses, overlapping envelopes, the
correct vow occurrence, the historical words and alif note, source revisions and
calendar isolation. Regeneration and independent full source audits remain necessary
after changing any word or boundary.
