# Peshitta.eu 2020 Old Testament reader source

The user requested this source on 2026-10-03. Its [About page](https://peshitta.eu/about.html)
identifies **Old Testament - publication of the Syriac Orthodox Patriarchate 2020**.
Prosary uses that exact credit and imports the website's actual pointed Syriac HTML
verse bodies, paired with the existing Hebrew-script projection. It retains the
BFBS 1905 / Digital Syriac Corpus New Testament; the website's St Gabriel Monastery
2013 NT is not substituted. Existing prayer packs keep their original pinned sources.

The source lock in `Shared/tools/reading-text-sources.json` pins 1,060 downloaded
chapter responses from the 45 OT source books already represented by the app.
The extra separately titled works on the website are not automatically appended
or mapped to Catholic books. The adapter validates the book/chapter/verse labels,
contiguous printed labels, nonempty vocalized Scripture, and paired-script projection.
Exact source-body copies published under different chapter labels remain withheld.

`Shared/tools/peshitta-eu-2020-review.json` records each exclusion and the actual
generated scope. The 2026-10-07 recovery retains 1,053 OT chapters containing
26,729 unchanged source verses: 1,012 complete chapters and 41 explicitly partial
chapters. The partial chapters recover 1,325 valid verses previously withheld with
their chapter; 111 individually defective verse bodies remain absent. Their original
source numbers stay intact, and every omission has its source-body hash and reason.
The source chapter hash and retained verse count are checked too. A chapter remains
partial even when its only omitted verse is at the end. No omitted word is filled,
no chapter is relabeled, and no point is borrowed from the former XML.

Seven chapters remain entirely unavailable: 1 Samuel 26–27 and 2 Kings 16–17 have
unresolved copied bodies; 2 Chronicles 12 and 28 and Sirach 1 have invalid numbering.
The strict complete-chapter parser still
rejects defective material. A separately reviewed partial import permits only unchanged,
vocalized verses that support the existing paired-script projection. It cannot relax
book/chapter labels, duplicate or missing verse numbers, or unsupported markup.

The native Bible may browse a valid source-native chapter without asserting a daily
calendar correspondence. Daily passages have a separate conservative graph:
previously inspected semantic units transfer only when the website retains the
same segmented Syriac consonants at their exact reviewed coordinates after the
old review's documented caption exclusions. Vocalization always comes exclusively
from the new website response. Every compound unit remains whole, and a differing
or missing member withholds the group. The manifest retains the former mismatches.
The original graph still admits the same 3,804 OT units, including the independently
read Job 42 appointment below. Separate reviewed Psalm boundaries and bounded daily
Psalm excerpts retain their existing evidence. Recovering a browseable verse adds
no calendar correspondence: a regression checks that all 1,325 recovered units
remain unavailable through the general daily mapper. Matching verse counts alone
never establishes a mapping.

For 2026-10-03, the Roman/Latin Patriarchate appointment `Job 42:1–3; 42:5–6;
42:12–16` uses [Job 42](https://peshitta.eu/ot/job/42.html) units 1,2,3,5,6,12,13,14,15,16.
The endpoints describe Job's answer, capacity and knowledge; hearing, seeing and
repentance; then blessing, children, names, inheritance, 140 years and four
generations. The source's verse 17 death remains outside the appointment. The
app's native daily readers use that exact reviewed sequence and both source scripts.

The same date's appointed Psalm 119 uses the website's source Psalm 118 numbering.
[Source Psalm 118:91](https://peshitta.eu/ot/psalms/118.html) is explicitly marked
`(ܠܝܬ)` (absent). The partial Bible chapter omits that marker and retains the other
175 valid source verses. An appointment requesting verse 91 still remains unavailable
instead of being silently shortened or filled from a different edition. The independently
reviewed bounded daily excerpts avoid verse 91 and retain their own exact-source tests.
Other unknown Psalm mappings remain unavailable.

The website identifies its publication and carries a copyright footer but states
no redistribution license. That absence is recorded here and in the source lock;
the BFBS/Digital Syriac Corpus NT's CC BY 4.0 terms do not apply to this OT.
Bible archives are committed alongside their synchronized catalogs. Their immutable
catalog URLs become downloadable after an authorized push to `main`; app-store
distribution is a separate step. Bundled daily excerpts remain usable independently
of that download publication.
