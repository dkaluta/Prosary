# Peshitta Psalm appointment boundaries

The 2026-10-06 review in `Shared/tools/peshitta-eu-2020-psalm-review.json` adds
source-specific correspondences for the Roman calendar's Psalm appointments. Its
numeric evidence identifies actual verse bodies in the existing hash-pinned
[Patriarchate 2020 website source](https://peshitta.eu/ot/psalms.html). Pointed Syriac
wording and its existing Hebrew-script projection remain unchanged.

The independent comparison witness is the
[ETCBC Electronic Peshitta Text, Psalms](https://github.com/ETCBC/peshitta/blob/9850f5addade26f681334aa475570bef9b0b440a/plain/0.2/Psalms.txt),
pinned at revision `9850f5addade26f681334aa475570bef9b0b440a`. Its Hebrew-labelled
body coordinates bridge through Prosary's already pinned Original-to-STEP Standard
correspondence. The witness omits superscriptions; an absent title is never
manufactured or copied into the website edition. ETCBC's text has separate
[CC BY-NC terms](https://github.com/ETCBC/peshitta/blob/9850f5addade26f681334aa475570bef9b0b440a/docs/about.md).
It is comparison evidence only: the committed review contains coordinates,
response/verse hashes, method and notes, with no witness wording.

The review records 427 source units in 59 source chapters. Of its 406 evidence
records, 307 independently match the complete segmented consonantal body; 78
retain inspected conjunction, spelling, segmentation or lexical variants; and 21
preserve whole source envelopes where clauses cross verse boundaries or source
verses merge or split. Chapter totals, a generic Greek offset, and a similarity
threshold do not establish an enabled edge. Two repeated refrains are selected
at their inspected local labels and surrounding passage, rather than an identical
line in another Psalm or another part of the same Psalm.

Examples show why this source needs its own graph:

- Standard Psalm 23:1 remains source Psalm 23:1, with its shepherd opening.
- Source Psalm 1:2 opens with the mockers-seat clause from Standard 1:1. Requesting
  only Standard 1:1 therefore retains complete source 1:1–2 and shows the existing
  whole-verse notice.
- Source Psalm 113:5 contains the high dwelling and looking-down clauses, which
  occupy Standard 113:5–6.
- Source Psalm 144:10 merges Standard 145:10–11. Source 144:12–13 splits the
  kingdom and faithful-Lord clauses in the witness's complete 145:13 unit.
- Similar judgement text in Psalms 96 and 98 remains attached to its actual
  Psalm. The latter has a separate crossed-clause envelope at source 98:8–9.

The ETCBC witness omits two clauses in Psalm 111:7–8. The website's complete
source 111:7–8 was independently inspected against the
[USCCB's published Psalm 111](https://bible.usccb.org/bible/psalms/111): works and
justice, reliable commands, enduring establishment, and truth/equity. Their
crossed order remains one complete source envelope. No missing witness text is
inserted into the app.

This graph makes 95 of the 103 current Roman Psalm appointments available in the
paired Aramaic edition. A separate bounded daily supplement adds seven exact
Psalm 119 appointments using the other actual source Psalm 118 units. Its parser
recognizes only the pinned verse-91 omission marker and validates the other 175
pointed units and their paired projection; its manifest approves only seven exact
Roman keys and retains source-unit hashes. The moved lifting-hands clause stays
in the two complete source 118:47–48 units. The chapter remains excluded from the
Bible catalogue and general reference mapper.

Thus 102 of the 103 current Roman Psalm appointments are available in Aramaic.
The appointment explicitly requesting Psalm 119:91 remains unavailable because
source Psalm 118:91 contains an omission marker. Source Psalm 89's omission also
remains excluded. All unreviewed Psalm coordinates retain empty edges and cannot
acquire a fallback identity mapping. No wording is borrowed from the comparison
witness, another edition, or another script.

The website publication's existing rights/attribution record is unchanged. This
review does not assign the NT's BFBS/Digital Syriac Corpus license or the
comparison witness's license to the 2020 OT source.
