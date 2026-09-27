# Jesuit Arabic Gospel expansion, 27 September 2026

`arabic-jesuit-1897-gospel-readings.json` adds **204 previously untranscribed
verses** from four complete chapters: Luke 6, 10, 11, and 12. It supplements
`arabic-jesuit-1897.json`; none of the original 239 verses is replaced or copied
into this extension. The existing edition ID remains `jesuit-arabic-1897`.

## Printed source and transcription

- Source: [1897 Beirut Jesuit Bible](https://archive.org/details/AlKitabAlMoqadas),
  [PDF](https://archive.org/download/AlKitabAlMoqadas/AlKitabAlMoqadas.pdf).
- PDF SHA-256: `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.
- Publisher: مطبعة المرسلين اليسوعيين ببيروت; printing year 1897. The edition's
  title and approval pages remain documented in
  [ARABIC-SCRIPTURE-SOURCES.markdown](ARABIC-SCRIPTURE-SOURCES.markdown).
- Independent transcription of public-domain nineteenth-century biblical text;
  the scanned images are not redistributed with the application.
- Text was transcribed by reading rendered pages, then read independently against
  the same pages. Enlarged crops were used for small or crowded letters. No OCR
  output or wording from a modern Arabic Bible supplies the transcription.
- The existing transcription convention is retained: omit vowel signs, shadda,
  ornaments, and note markers; normalize whitespace, punctuation, and ordinary
  Unicode hamza typography. Retain printed wording, names, and verse divisions.

All page numbers below are **one-based PDF pages**, four greater than the printed
page numbers. Each verse has explicit page evidence in the JSON; a verse crossing
a page retains both pages.

| Complete chapter | Verse count | PDF pages | Printed pages | Page transition |
|---|---:|---|---|---|
| Luke 6:1-49 | 49 | 434-435 | 430-431 | Verse 38 continues onto PDF 435. |
| Luke 10:1-42 | 42 | 437 | 433 | Verse 12 crosses from the right to the left column. |
| Luke 11:1-54 | 54 | 437-438 | 433-434 | Verse 8 continues onto PDF 438. |
| Luke 12:1-59 | 59 | 438-439 | 434-435 | Verse 33 continues onto PDF 439. |

The chapter openings and endings were inspected in context: Luke 6 begins after
the wine saying and ends before the centurion narrative; Luke 10 begins after
the plough saying and ends with Mary's chosen portion; Luke 11 begins with the
disciples' request for instruction in prayer and ends with the attempt to catch
Jesus in his words; Luke 12 begins with the gathering crowd and ends with the
last coin paid before the report about the Galileans.

## STEP Standard correspondences

The reference hub is **STEP English Standard (KJV)**, as in the existing
[Arabic boundary review](ARABIC-REFERENCE-REVIEW.markdown). The comparison uses
the actual KJV chapter text: [Luke 6](https://ebible.org/eng-kjv/LUK06.htm),
[Luke 10](https://ebible.org/eng-kjv/LUK10.htm),
[Luke 11](https://ebible.org/eng-kjv/LUK11.htm), and
[Luke 12](https://ebible.org/eng-kjv/LUK12.htm). KJV wording is comparison evidence,
not a source for the Arabic wording.

Each printed verse marker was compared with the beginning and ending clauses of
its Standard counterpart. The JSON lists **203 explicit, complete mapping
units**. All are single printed verses except Luke 6:17-18, which is indivisible.
This is bounded review of the four chapters, not a generic Arabic identity rule.

| Arabic source unit(s) | STEP Standard unit(s) | Boundary evidence |
|---|---|---|
| Luke 6:1-16, each verse separately | Same individual labels | Sabbath grain, David's bread, the withered hand, night prayer, and each part of the apostle list retain the corresponding marked beginnings and endings. |
| Luke 6:17-18, together | Luke 6:17-18, together | Arabic 17 ends at Tyre and Sidon. Arabic 18 starts with the people coming to hear and be healed, then includes those afflicted by unclean spirits. Standard 17 already includes the hearing/healing clause. Neither Arabic nor Standard 17 or 18 may be mapped alone. |
| Luke 6:19-49, each verse separately | Same individual labels | The touch/healing verse, beatitudes and woes, love of enemies, lending, judgment, blind guides, eye/beam, tree/fruit, and two house foundations preserve the inspected individual envelopes. |
| Luke 10:1-42, each verse separately | Same individual labels | Sending, hospitality, warnings, return, thanksgiving, the lawyer's questions, each Samaritan narrative verse, and Martha/Mary retain the corresponding clause boundaries. |
| Luke 11:1-54, each verse separately | Same individual labels | Prayer, the midnight friend, asking, exorcism, the returning spirit, the sign of Jonah, light, and the rebukes retain the corresponding printed envelopes, including the end of 53 before the waiting/catching clause in 54. |
| Luke 12:1-59, each verse separately | Same individual labels | Disclosure, fear/confession, inheritance, the rich man, providence, readiness, the steward, division, weather, and the debt/judge sayings retain the corresponding individual envelopes. |

Textual variants are preserved rather than repaired from KJV. For example,
Luke 10:1 and 17 print seventy-two; Luke 11:2 and 4 have the shorter prayer text.
These are differences within the corresponding verse envelopes, not permission
to add the longer KJV clauses or splice another Arabic edition into the source.
The complete printed chapters also establish their actual final labels (49, 42,
54, and 59), but do not establish anything about an untranscribed chapter.

Luke 11:53 required enlarged inspection of PDF 438: the printed word is
`ويبتزونه`, retained after two independent readings of the larger letterforms.
The teeth and separated zay were checked; the initial tentative reading with a
medial ghayn was rejected. This decision comes from the scan, not another Bible.
The sentence-meaning check also returned to PDF 439 for Luke 12:52 and confirmed
the printed verb `يشاق` (three opposing two), correcting a mistaken noun reading.

The final word-level review reread all 204 verses in enlarged page columns, with
another reader separately checking Luke 6/12 and Luke 10/11. Differences were
resolved from targeted larger crops, including small conjunctions and verb forms;
neither familiar modern phrasing nor smoother synonyms replace the print. Among
the confirmed readings are `المدنفين` (6:18), `مثل خراف` (10:3), `وقال مجربا له`
(10:25), `هم يحكمون عليكم` (11:19), `مع ذلك فتصدقوا` (11:41), `أغلت له أرضه`
(12:16), and `ولماذا لا تحكمون بالعدل من تلقاء أنفسكم` (12:57). Targeted crops also
confirmed the original readings `يعطى` (11:10), `على نفسه` (11:17), and
`اقترب منكم` (11:20), rejecting alternative readings proposed during the review.

## Validation and integration limits

Structural checks require exactly 204 unique new references, complete sequential
verse labels for all four chapters, nonempty Arabic text, page evidence for every
verse, no overlap with the original transcription, and exhaustive, nonoverlapping
mapping-unit coverage. The Luke 6:17-18 pair must remain a whole mapping unit.
Generated daily-reading coverage is measured by the corpus builder after the
extension is integrated; a newly transcribed verse does not independently prove
that every calendar appointment containing it can be mapped.
