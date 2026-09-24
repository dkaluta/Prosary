# Arabic passage-boundary review, 19 September 2026

This review establishes eight whole-passage correspondences for the new excerpts
from the 1897 Jesuit Arabic printing. It supplements the independent
[transcription review](ARABIC-SCRIPTURE-SOURCES.markdown); matching verse numbers
alone do not establish a correspondence. It does not establish mappings for any
other Arabic verses or permit slicing the reviewed passages.

## Sources and reference system

- Arabic source: [1897 Beirut scan](https://archive.org/download/AlKitabAlMoqadas/AlKitabAlMoqadas.pdf),
  SHA-256 `2bca3535b75532044bdc2889b497b16b59e0337ee775f42de8aedc4e2809c09d`.
  Page references below are one-based PDF pages; printed pages are four lower.
- Reviewed transcription: `arabic-jesuit-1897.json`, SHA-256
  `9495719b3f1573e7a446dc22dbeb3014e913d69b5bfff71239dd9602c0efeda8`.
- The mapper's hub is **STEP English Standard (KJV)**, as recorded in the
  [pinned STEP documentation](../tools/versification/step/README.markdown),
  not Hebrew/Masoretic numbering, NABRE, or SIL Original. The actual KJV passage
  divisions linked below were compared with the Arabic printed clauses and their
  adjacent verse markers. The KJV supplies reference-boundary evidence only;
  its wording is not copied into the Arabic corpus.
- Pinned STEP TVTMS source commit:
  `1f342173b881ba5d1a5a4cae6e7c6c3fcc7cac51`; source SHA-256
  `63058e0f20201af4bdaa7d830da5be8f493455d947c5f147d84840b33db9ddf8`.

## Complete units

Every row below maps the entire Arabic source unit to the identically numbered
STEP Standard unit. The boundary descriptions are summaries of the independently
inspected clauses, not replacement translations.

| Arabic source and STEP Standard unit | Arabic PDF page | Clause envelope and adjacent printed boundaries | Standard boundary witness |
|---|---:|---|---|
| Luke 1:46–55 | 432 | Begins with Mary speaking and magnifying the Lord; includes her praise, reversals of fortune, and help for Israel; ends with the promise to Abraham and his descendants forever. Elizabeth's blessing ends at 45; Mary's three-month stay and return begin at 56. | [KJV Luke 1](https://ebible.org/eng-kjv/LUK01.htm) |
| Isaiah 11:2–3 | 295 | Begins with the Spirit resting on him, includes the listed gifts and fear of the Lord, and ends with judging neither by sight nor hearing. The Jesse branch is wholly in 1; judgment for the poor begins at 4. | [KJV Isaiah 11](https://ebible.org/eng-kjv/ISA11.htm) |
| Isaiah 11:4–5 | 295 | Begins with righteous judgment for the poor; includes the rod of the mouth and breath of the lips; ends with righteousness and faithfulness as a girdle. The preceding sight/hearing clause ends at 3; wolf and lamb begin at 6. | [KJV Isaiah 11](https://ebible.org/eng-kjv/ISA11.htm) |
| Isaiah 11:10 | 295 | Includes Jesse's root as a signal for peoples, the nations seeking him, and his glorious resting place. Waters covering the sea ends at 9; recovery of the remnant begins at 11. | [KJV Isaiah 11](https://ebible.org/eng-kjv/ISA11.htm) |
| Isaiah 22:22 | 297 | Includes the key of David's house on the shoulder and both opening/shutting clauses. Robe, authority, and fatherhood end at 21; the secure peg begins at 23. | [KJV Isaiah 22](https://ebible.org/eng-kjv/ISA22.htm) |
| Isaiah 9:2 | 294 | Contains both the people in darkness seeing light and light shining upon those in death's shadow. Zebulun and Naphtali belong to 9:1; multiplying the nation and joy begins at 9:3. | [KJV Isaiah 9](https://ebible.org/eng-kjv/ISA09.htm) |
| Isaiah 28:16 | 299 | Begins with the Lord's declaration of the tested cornerstone in Zion and includes the concluding assurance for the believer. The covenant with death ends at 15; judgment as a measuring line begins at 17. The translations differ in the assurance's wording, not its placement. | [KJV Isaiah 28](https://ebible.org/eng-kjv/ISA28.htm) |
| Isaiah 7:14 | 293 | Contains the Lord giving a sign, the virgin conceiving and bearing a son, and naming him Emmanuel. The rebuke to David's house ends at 13; the child's food begins at 15. | [KJV Isaiah 7](https://ebible.org/eng-kjv/ISA07.htm) |

## Isaiah numbering safeguards

The source's Isaiah 9:2 is **Standard 9:2**, not Standard 9:3. This is established
by the scanned clause boundaries and the KJV witness above. Pinned STEP row
18202 independently records `Eng-KJV+Latin Isa.9:2 → Isa.9:2`; row 18223 records
`Hebrew+Greek Isa.9:1 → Isa.9:2`. Applying the Hebrew offset to this Arabic printing
would therefore assign the light passage to the following verse incorrectly.
The STEP rows have chapter-`Last` predicates. The sparse Arabic inventory cannot
evaluate those predicates and does not activate either broad tradition; the
bounded manual comparison is the mapping authority.

Isaiah 11:2–3 is deliberately retained as one complete unit. Its spirit/gifts/fear
clauses remain together, including the sight/hearing clauses at the end of 3;
the mapper does not infer separate verse or subverse equivalence from another
edition's division of those clauses. The separately reviewed 11:4–5 unit begins
with judgment for the poor and ends before the animals in 6.

All eight correspondences can remain in the bounded Arabic adapter. This review
does not authorize a general Old Testament identity mapping. Existing exact-unit
tests reject partial requests within the Magnificat and Isaiah 11, and reject
using Standard 9:1 for the reviewed light passage. No additional Isaiah daily
appointment becomes available in the current tables; Luke 1:46–55 is the only
new emitted Arabic daily citation.
