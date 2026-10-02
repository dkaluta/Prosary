# Complete Arabic Scripture audit — 27 September 2026

All **665 transcribed verses** were visually reread against the [1897 Jesuit printing](https://archive.org/download/AlKitabAlMoqadas/AlKitabAlMoqadas.pdf): the original 239 prayer verses, 222 Psalm verses, and 204 Gospel verses. Printed verse markers, complete clause envelopes, and contextual meaning were checked. Every changed reading received a second independent visual confirmation. No OCR or modern revision supplied words.

The review found **26 transcription errors**: ten in the original prayer corpus, two in Psalms, and fourteen in the new Gospel chapters. This report supersedes earlier claims that these transcriptions were fully checked without those errors. Corrections retain the historical edition’s wording; spelling, vowel-mark and punctuation normalization follows the existing source policy.

The [machine-readable ledger](../tools/arabic-scripture-audit.json) records all 665 references, exact current verse hashes, page evidence, complete corpus hashes and correction history. The regression check rejects a changed or unaudited verse. It verifies the audit’s coverage and pins; it is not itself a linguistic reviewer.

No printed verse is missing inside the transcribed complete chapters. This remains an excerpt corpus, not a complete Arabic Bible. Unsupported appointments remain unavailable. Verse divisions that differ from Standard remain indivisible reviewed units, including Luke 1:26–38, 22:41–44 and 6:17–18.

PDF SHA-256: `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.

## Confirmed corrections

|Reference|PDF page|Previous transcription|Printed wording|
|---|---|---|---|
|Matthew 2:13|410|ولما انصرفوا|فلما انصرفوا|
|Mark 14:62|430|فقال له يسوع|قال له يسوع|
|Mark 15:20|430|وخرجوا به ليصلبوه|وأتوا به ليصلبوه|
|Luke 1:46|432|وقالت مريم|فقالت مريم|
|Luke 1:51|432|بفكر قلوبهم|بأفكار قلوبهم|
|Luke 24:32|445|قال أحدهما للآخر|فقال أحدهما للآخر|
|John 2:10|446|فبعد ذلك|فمن بعد ذلك|
|John 21:3|456|فقال لهم سمعان بطرس|قال لهم سمعان بطرس|
|John 21:5|456|فقال لهم يسوع|قال لهم يسوع|
|John 21:6|456|فقال لهم ألقوا|قال لهم ألقوا|
|Luke 6:2|434|فقال لهم|قال لهم|
|Luke 6:9|434|فقال لهم|قال لهم|
|Luke 6:45|435|من كنزه الشرير|من كنز قلبه الشرير|
|Luke 10:13|437|يا بيت صيدا إذ لو صنع|يا بيت صيدا لأنه لو صنع|
|Luke 11:11|438|فمن منكم|من منكم|
|Luke 11:36|438|ليس فيه شيء مظلم|ليس فيه جزء مظلم|
|Luke 11:38|438|لم يغتسل|لم يغسل|
|Luke 11:41|438|مع ذلك فتصدقوا|مع ذلك قد بقي لكم أن تصدقوا|
|Luke 12:1|438|وفيما اجتمع جموع ربوات من الشعب|وفيما اجتمع حوله ربوات من الجمع|
|Luke 12:27|438|في كل مجده ليس كواحدة منها|في كل مجده لم يلبس كواحدة منها|
|Luke 12:35|439|ومصابيحكم|وسرجكم|
|Luke 12:41|439|أم لجميع الناس أيضا|أم للجميع أيضا|
|Luke 12:54|439|سحابة تطلع|غيمة تطلع|
|Luke 12:56|439|فكيف لا تميزون|كيف لا تميزون|
|Psalm 95:13|[244]|لأنه آت ليدين الأرض|لأنه آت آت ليدين الأرض|
|Psalm 150:6|[254]|كل نسمة فلتسبح الرب|كل نسمة تسبح الرب|

## Rejected proposed corrections

Luke 1:34 retains `قالت مريم` without an added conjunction. Mark 15:34 retains the printed `سبقتني` spelling. Luke 6:29 retains `فقدم الآخر` without inserting `له`. Luke 11:53 retains `ويبتزونه`. Psalm 22:4 retains `هما يعزياني`, and Psalm 127:2 retains `من تعب يديك`. Familiar wording from other editions did not override the scan.

## Final corpus checksums

- `arabic-jesuit-1897.json`: `dbb7c4736218f730506d5eedb05708983420712c02076e008b16839665d9f39c` (239 verses, 72 units).
- `arabic-jesuit-1897-gospel-readings.json`: `27cfb56e8d5ba75995e6634db631dccc0a17a63a66173dcd26bf65eec252d608` (204 verses, 203 units).
- `arabic-jesuit-1897-readings.json`: `f68ada5fa1de23b37df8dc04b36b29ef4d8ca480454030ec4eb9c164e5c78ec5` (222 verses, 213 units).
