# Arabic Jesuit 1897 Psalm expansion

This review supports the independent transcription in
`arabic-jesuit-1897-readings.json`: **222 printed numbered verses in 22 printed
Psalm chapters**, corresponding to **21 complete Psalms in STEP Standard**.
It supplements the earlier 239-verse corpus without replacing or modernizing it.
This is a bounded expansion, not a claim to a complete Arabic Bible.

## Printed witness and method

- Edition: *الكتاب المقدس*, Jesuit Press, Beirut, 1897.
- Scan: [Internet Archive, AlKitabAlMoqadas](https://archive.org/details/AlKitabAlMoqadas).
- [Original PDF](https://archive.org/download/AlKitabAlMoqadas/AlKitabAlMoqadas.pdf),
  SHA-256 `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.
- Edition evidence: PDF page 7 (title), page 9 (approval dated 3 November 1897).
- Page references below and in the JSON are one-based PDF pages, not the printed
  page numbers. These Psalm leaves have printed page number equal to PDF page
  minus four.
- Wording was read from rendered page images and enlarged column/verse crops.
  A second independent visual reading checked every transcribed verse. A further
  meaning and context pass returned to the scan for unusual or apparently broken
  phrases. OCR text was not used to supply or repair any Scripture wording.
- The nineteenth-century biblical text is independently transcribed; the scan
  images and their separately advertised license are not redistributed.
- The transcription follows the established main corpus policy: omit vowel
  marks, shadda, ornaments and footnote markers; normalize whitespace and
  punctuation; use ordinary Unicode hamza typography. Preserve printed wording,
  numbered superscriptions, meaningful final *Hallelujah*, and verse boundaries.
  Do not substitute wording from Van Dyck or a modern Jesuit edition.

## Reviewed coverage

| Printed Psalm | STEP Standard Psalm | Printed verse labels | PDF pages |
| --- | --- | --- | --- |
| 22 | 23 | 1–6 | 230 |
| 23 | 24 | 1–10 | 230–231 |
| 94 | 95 | 1–11 | 244 |
| 95 | 96 | 1–13 | 244 |
| 96 | 97 | 1–12 | 244 |
| 97 | 98 | 1–9 | 244–245 |
| 99 | 100 | 1–5 | 245 |
| 102 | 103 | 1–22 | 245 |
| 110 | 111 | 1–10 | 247–248 |
| 111 | 112 | 1–10 | 248 |
| 112 | 113 | 1–9 | 248 |
| 116 | 117 | 1–2 | 248 |
| 121 | 122 | 1–9 | 250–251 |
| 127 | 128 | 1–6 | 251 |
| 137 | 138 | 1–8 | 252 |
| 144 | 145 | 1–21 | 253 |
| 145 | 146 | 1–10 | 254 |
| 146 | 147:1–11 | 1–11 | 254 |
| 147 | 147:12–20 | **12–20** | 254 |
| 148 | 148 | 1–14 | 254 |
| 149 | 149 | 1–9 | 254 |
| 150 | 150 | 1–6 | 254 |

The printed heading *Psalm 147* continues with verse **12**, not verse 1.
The JSON retains those actual labels. Psalm 146:1–11 and Psalm 147:12–20
jointly supply Standard Psalm 147, with no inferred renumbering or missing rows.

## Clause boundaries and reference evidence

The reference witness is the public-domain KJV in
[eBible's verse-per-line download](https://ebible.org/Scriptures/eng-kjv_vpl.zip)
([edition and rights](https://ebible.org/eng-kjv/copyright.htm)). It is used only
for STEP Standard clause boundaries, never to generate Arabic wording.
The reference download retrieved on 27 September 2026 has ZIP SHA-256
`c0526ded109f413faf90091d63352fd8426147e138686b16ce94a640fdef197f`;
its `eng-kjv_vpl.txt` member has SHA-256
`fb7b8c10feb607c22b3461e837bfd267c09814f39ce23756a1928f7739a52b3c`.
Every source verse was compared with its Standard counterpart, including the
start/end clauses and the neighboring verse. A mere chapter-number offset was
not used as proof of an individual verse match.

The JSON contains **213 explicit review units**: 206 single source-verse units
and the following seven indivisible envelopes. No resolver may silently select
only part of an envelope or widen an appointment to include it.

| Printed source envelope | Standard envelope | Boundary difference |
| --- | --- | --- |
| 94:7–9 | 95:7–9 | Printed 7 ends at the sheep of his hand. Printed 8 begins “Today” and includes “harden not”; printed 9 then begins the provocation/testing clause and includes the fathers' testing. Standard 7 includes “Today,” and Standard 8 includes the provocation/testing clause. |
| 99:1–2 | 100:1–2 | Printed 1 is the superscription alone. Printed 2 contains both the joyful shout and the command to serve and enter singing. |
| 110:7–8 | 111:7–8 | Printed 7 ends with the works of his hands as truth and judgment. Printed 8 contains both the reliable commandments and their everlasting establishment. |
| 111:6–7 | 112:6–7 | Printed 6 ends at never being moved. Printed 7 begins the righteous person's eternal remembrance and continues through fearlessness and the trusting heart. |
| 145:1–3 | 146:1–3 | Printed 1 is “Hallelujah”; printed 2 contains the praise addressed to the soul, lifelong praise and the warning against trusting princes; printed 3 continues the warning against a son of Adam. |
| 145:6–7 | 146:6–7 | Printed 6 ends after creation of heaven, earth, sea and their contents. Printed 7 includes preserving truth forever, justice, food and release of prisoners. |
| 148:13–14 | 148:13–14 | Printed 13 ends with the exalted name. Printed 14 begins his glory above earth and heaven before the exalted horn and praise of his people. |

All remaining numbered verses have individually reviewed equivalent clause
boundaries. Translation differences and genuine additional text remain part of
this edition; they are not trimmed to imitate the reference witness.

In particular, printed **144:13** retains the additional clause that the Lord
is faithful in all his words and righteous in all his works. It occurs inside
that printed verse before the numbered start of 14. The surrounding kingdom,
dominion and upholding-the-fallen clauses establish the 13/14 boundary; the
additional wording is not discarded or moved into 14. This is an edition-text
variation, not evidence for an extra numbered verse.

## Context checks and corrected draft readings

The first draft was corrected against the same printed witness in two places:

- 97:4 has `أنغموا بمجده`, following the opening `اهتفوا للرب`.
- 137:7 has `تمد يدك`, retaining the initial ت.

The enlarged witness also confirms 94:6 `هلموا اسجدوا واركعوا نجثو`;
102:5 `شيبتك`; and 137:6 `ونظر إلى المتواضع` (without an added alif).
Historical expressions such as 110:2 `مدبرة طبقا لكل مراديها`, 145:9
`ويهبط طرق المنافقين`, and 150:1 `جلد عزه` were retained after the context
check; they were not rewritten into a contemporary Bible's wording.

## Structural checks

The transcription's verse keys, nonempty bodies and per-verse page evidence
must agree exactly. The 213 review units cover every one of the 222 source
verses once, with no duplicate or uncovered source/Standard coordinate. The
mapped Standard coverage consists of all verses in the 21 complete Psalms listed
above. No existing main-corpus coordinate is replaced.
