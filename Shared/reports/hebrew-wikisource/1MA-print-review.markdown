# 1 Maccabees print comparison in progress

The source is the supplied Kahana volume B, SHA-256
`656891d377d2e3d4a9216723d94205488423907bf01df424b9f0b9de1560051e`.
All page numbers below are PDF pages. The canonical book remains **draft** and no
page has been certified as fully reviewed. This report is not an import approval.

## Current extent

- Chapter 1, B97–105: first pointed draft, 59 printed units covering labels 1–64.
  Final vowel-mark comparison remains outstanding.
- Chapter 2, B105–110: consonants and printed unit boundaries compared throughout,
  57 units covering labels 1–69. The first 14 labels have a provisional pointed
  draft; labels 15–69 still require transcription of the printed niqqud.
- Chapter 3, B110–115: consonants and printed unit boundaries compared throughout,
  57 units covering labels 1–60. Printed niqqud remains untranscribed.
- Chapters 4–16: unreviewed online scaffold. Their empty `sourcePages` explicitly
  distinguish them from the passages compared with the scan.

Combined labels remain single source units. Chapter 1 combines 8–9, 14–15,
41–42, 46–47 and 50–51. Chapter 2 combines 4–5, 8–9, 16–17, 20–21, 30–31,
38–39, 46–47, 52–53, 55–56, 58–59, 60–61 and 68–69. Chapter 3 combines 22–23,
53–54 and 57–58. These are printed source
units, not an asserted crosswalk to another Bible edition.

## Material findings

| Source | Print finding retained in the draft |
| --- | --- |
| 1:26, B102 | A bracketed three-dash lacuna is absent from the online text. Chapter 1 is explicitly partial. |
| 1:39, B103 | The print has defective `הֻשַׁם`, without a consonantal ו. |
| 1:61, B105 | The print has feminine `צואריהן` and `ביתיהן`, unlike the online spellings. |
| 2:8–9, B107 | Printed bracket scope includes the maqaf: `כ[בית־]איש`. |
| 2:13, B107 | The printed lacuna is retained as `[ אם־ — — — ]`. Chapter 2 is explicitly partial. |
| 2:19, B108 | Wikisource omits `בקול גדול אם־כל־העמים אשר בבית־מלכות המלך שומעים לו`. The print also has `אבותיו`, not the online `אבותינו`. |
| 2:22, B108 | The print has `או`, not online `ואו`. |
| 2:26, B108 | The print spells the name `פינחס`. |
| 2:32–33, B109 | Printed 32 ends `רבים` without an ending sign. Printed 33 begins `וישיגום`; the online units divide this passage differently. |
| 2:34, B109 | The supplied word is bracketed: `[לעשות]`. |
| 2:51, B110 | The print brackets only `[ותחשב־לו]`, leaving `לצדקה` outside. |
| 2:54, B110 | The print brackets `[אדני]`. |
| 2:58–59, B110 | Printed name order is `חנניה עזריה מישאל`, unlike Wikisource. |
| 3:3, B110 | The supplied phrase remains bracketed: `[ויך אויב אחור]`. |
| 3:10, B111 | The print has `להלחם`, without the online extra ו. |
| 3:13, B111 | The source retains `ארם` and has `ויוצאים`. |
| 3:15, B111 | The print has `בבני־ישראל`. |
| 3:26, B112 | Printed `נגע` has no initial ו. |
| 3:29, B112 | Printed `[ובקשו]` and `למן־ימי` replace the online draft's corrupt wording. |
| 3:29, B112 | The enlarged omission-check crop confirms defective `האצרות`, without ו. |
| 3:32, B112 | The enlarged crop confirms the initial ו in `ומזרע`. |
| 3:38, B113 | The source spells the name `גרגיאס`, without the draft's inserted ו. |

Printed verse endings in the scan-compared rows use Hebrew sof pasuq `׃`
(U+05C3), not ASCII colon. Defective spellings and selectively unpointed names
are retained; no conventional vowels are supplied to fill unreadable marks.

Specific unresolved marks include chapter 1's worn pointing (including `כסלו`
at 1:54), and the printed pointing of `הרגו` at 2:8–9 and `חפשיה` at 2:11.
The latter two tokens deliberately remain unpointed in the provisional draft.
These findings prevent complete review status.

## Independent OCR omission check

The [B108 Kraken evidence](1MA-kraken-B108.json) records 17 complete printed
rows from 2:15–28, recognized without a lexicon or expected text after visual
inspection of their bounds. Against the previously typed consonantal draft,
156 of 170 reference words match exactly. The remaining differences are 13
substitutions and one token deletion caused by joining `בן־סלוא` as `בןסלוא`.
The scan supports the draft at these disagreements; no OCR words were substituted.
The long missing online clause in 2:19 was also recognized intact.

This is an omission check against a provisional draft, not an independently
certified accuracy benchmark. It does not verify or generate vowel marks.
The earlier [chapter-one comparison](1MA-ocr-baseline.markdown) freezes its own
reference snapshot; subsequent source corrections do not rewrite that experiment.

The [chapter-three check](1MA-kraken-chapter3.json) covers all 82 printed rows
on B110–115, with manually inspected line bounds. Its frozen pre-correction
reference has 739 words: 648 exact matches, 79 substitutions and 12 apparent
deletions. The latter come from joined poetic columns and other joined OCR
tokens, not absent printed clauses. Targeted enlarged crops resolved three
draft corrections listed above; the OCR's `ויגע` proposal at 3:26 was rejected
because the print reads `נגע`. The evidence retains both original inputs and
the source-backed dispositions; it does not silently revise the comparison.
