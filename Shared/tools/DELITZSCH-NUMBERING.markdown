# Delitzsch 1901 source numbering

Reviewed 2026-09-10 against the downloaded, pinned [12th-edition transcription](https://delitz.fr/12/index.html)
and the existing pinned [Douay–Rheims verse archive](https://ebible.org/Scriptures/engDRA_vpl.zip).
This is an edition-specific mapping, not a general Hebrew New Testament versification.
`delitzsch_numbering.py` accepts references already resolved unambiguously to SIL English
numbering and returns the vocalized source's published verse numbers. It never joins,
rewrites or drops Scripture text.

| English reference | Delitzsch 1901 reference | Inspected boundary |
| --- | --- | --- |
| John 1:38 | John 1:38–39 | Verse 38 introduces Jesus turning and speaking; verse 39 contains his question and the disciples' answer. English 1:39–51 therefore maps to source 1:40–52; 1:1–37 is unchanged. [Source chapter](https://delitz.fr/12/john.1.html). |
| Romans 7:25 | Romans 7:25–26 | The thanksgiving is source verse 25; the concluding contrast between service with the mind and flesh is verse 26. Verses 1–24 are unchanged. [Source chapter](https://delitz.fr/12/rom.7.html). |
| 1 Corinthians 13:12 | 1 Corinthians 13:12–13 | The mirror/face-to-face clause is source verse 12; the partial/full knowledge clause is verse 13. English 13:13, on faith, hope and love, is source 13:14. Verses 1–11 are unchanged. [Source chapter](https://delitz.fr/12/1cor.13.html), [Douay–Rheims comparison](https://ebible.org/engDRA/1CO13.htm). |
| 2 Corinthians 13:12–13 | 2 Corinthians 13:12 | The holy-kiss greeting and the saints' greeting share one complete source verse. English 13:14 is source 13:13. Verses 1–11 are unchanged. [Source chapter](https://delitz.fr/12/2cor.13.html). |
| 2 Thessalonians 3:16 | 2 Thessalonians 3:16–17 | The blessing of peace is source verse 16; the Lord's presence with everyone is verse 17. English 3:17 (Paul's signature) is source 3:18, and English 3:18 (grace) is source 3:19. Verses 1–15 are unchanged. [Source chapter](https://delitz.fr/12/2th.3.html). |
| Revelation 12:18; 13:1 | Revelation 13:1 | Standing on the seashore and seeing the beast share one complete source verse. Source chapter 12 ends at verse 17. Revelation 13:2–18 is unchanged. [Source chapter 12](https://delitz.fr/12/rev.12.html), [source chapter 13](https://delitz.fr/12/rev.13.html). |

The eBible unpointed Hebrew transcription is a useful textual comparison but must not be
assumed to have English verse boundaries merely because its chapter counts match English.
Its [Romans 7:25](https://ebible.org/heb/ROM07.htm) embeds a bracketed alternate verse 26.
Its [2 Thessalonians 3:17](https://ebible.org/heb/2TH03.htm) contains the final clause of
English verse 16; its verse 18 embeds a bracketed alternate verse 19. These annotations
are not imported into the vocalized reader.

For a source verse merging two English verses, both English references must appear
consecutively and in order. A request for only 2 Corinthians 13:12, only 13:13, only
Revelation 12:18, or only 13:1 is unavailable: it would require an unreviewed split of
the source verse. Requests for complete merged units emit that source verse exactly once.
All other omissions and requested order are preserved; duplicate references are rejected.

All 260 source chapter inventories were inspected. The six chapter maxima above differ
from SIL English; every other source chapter retains the English inventory. Validation
requires every numbered verse exactly once, not merely a matching maximum, and the
builder retains its separate nonempty-text and source-integrity checks.
