# Supplied Peshitta Old Testament reader review

Reviewed 2026-09-27 following the user's explicit request to expand the previously supplied
Old Testament in Readings. This expands the reader, not prayer-pack Scripture. The original
nine Isaiah prayer verses and all 27 Digital Syriac Corpus NT source files remain unchanged.

## Source and boundaries of the claim

The [supplied Archive XML](https://archive.org/details/peshitta-complete-bible-otnt) has SHA-256
`4f71fe418a1d23f6b65d63d155f838a228dbdb6e4857834f4503afdcf009ea88`. Its 73 book elements contain
1,322 chapter elements and 35,029 verse elements. The 46 named OT/apocryphal elements account
for 1,062 chapter elements and 27,127 verse elements. Those totals include prose headings
and damaged labels; they are not a certification of a complete Bible.

The underlying OT edition and redistribution terms remain unresolved. Reused BFBS 1905
metadata does not identify the OT. The NT's CC BY 4.0 terms do not apply to it. See the
[earlier metadata investigation](PESHITTA-ISAIAH-SOURCE-REVIEW.markdown).

The reader selects each book by its reviewed exact name and then guards its numeric ID.
This matters because the XML's NT entries reuse IDs 7 and 50 and omit their book names.
Those entries are never used: the NT continues to come from its existing TEI files.
The named “Susanna” element contains chapters 13 and 14 (including Bel); it is not imported
under a guessed book/chapter alias. Baruch is absent from the supplied book inventory.

## Source-preserving import

`peshitta_supplied_ot.py` verifies the complete source hash before parsing. Every emitted
Syriac string is the original verse element's text. It never supplies words from a witness,
renumbers a verse to fill a hole, discards an inconvenient word, or overwrites duplicate keys.

`peshitta-supplied-ot-review.json` records the exact chapter-label sequence and every observed
source defect. Import fails if those observations change. Entire affected chapters are
omitted, including both Exodus elements labeled 32 (the second appears to contain 33,
but this import does not repair it), Ezra 5's label 51, duplicate verses in 2 Chronicles 9,
Sirach 42/44 and 1 Maccabees 7, nonconsecutive ordinary labels, and unpointed placeholders.
Nine entries in the whole XML have no Syriac vowel signs; none is silently vocalized.
Psalm entries numbered 999 are prose introductions, not ordinary verses or a verse-zero
alias; the entire Psalm book remains unavailable pending its own numbering review.

The source adapter yields 45 OT books, 1,004 chapters and 25,095 verse entries. The reference
profile currently permits 37 OT books, 552 chapters and 14,290 entries before appointment
resolution. These are structural/profile totals, not a claim that every appointment resolves.
The [generated coverage report](../reports/readings-text-coverage.json) is authoritative for
the actual daily and Torah passages delivered to native apps.

## Ordinary-numbering inference and reference witnesses

The pinned [STEP TVTMS rules](../tools/versification/step/sources.json) contain no Syriac or
Peshitta source family. Therefore this review does not select a fictional Syriac profile.
It uses ordinary English body labels as an **inference**, outside every OT chapter touched
by a known nonidentity STEP alternative, with the existing complete-chapter inventory guard.
An equal verse count is necessary in that profile but never independently proves boundaries.
Psalm and deuterocanonical numbering stays blocked rather than being assigned English labels.

As independent corroboration, 27 chapters were compared verse by verse with the published
[Peshitta.eu text](https://www.peshitta.eu/ot/genesis/1.html). That site's
[source note](https://www.peshitta.eu/about.html) identifies its OT publication separately;
the comparison does not identify the supplied XML's edition or grant rights to its words.
Only URLs, response hashes, verse labels, and comparison results are stored in
`peshitta-supplied-ot-witnesses.json`; no website wording enters the app.

The comparison removes points and punctuation and resolves marked rish/final semkath only
for comparing consonant sequences. Twenty-five chapters match every verse's consonants
and label; Genesis 2 and 5 have differences. Representative complete matches include
Genesis 1/12/22, Exodus 3/12, Leviticus 19, Deuteronomy 6, Ruth 1, 1 Samuel 16, 1 Kings 19,
Isaiah 40, Jeremiah 31, Ezekiel 36, Daniel 7 and Amos 5. This is corroboration of the ordinary
profile, not independent certification of every verse in every enabled chapter.

The textual spot review also checked high-use passage endpoints: Genesis 1:26–31 (image,
creation, blessing and the sixth day), Genesis 12:1/4/9 (call/departure/journey),
Genesis 22:1–2/13–14/18–19 (trial/ram/blessing/return), Exodus 3:1/6–8/13–15
(bush, patriarchs, deliverance and the divine name), Exodus 12:1/8/11/14 (Passover),
Leviticus 19:1–2/11/18 (holiness and love of neighbour), Deuteronomy 6:4–9 (Shema),
and Isaiah 40:1–5/9/11 (comfort, the way, herald and shepherd). Their supplied clauses
occur at the ordinary reference endpoints. This review does not rewrite source wording.

Eight exceptional chapters were separately admitted after textual boundary checks and full
per-verse consonantal agreement with the independent witness:

| Chapters | Explicit boundary evidence |
| --- | --- |
| Genesis 31–32 | 31:55 contains Laban's departure; 32:1 starts Jacob meeting angels. |
| Genesis 36–37 | 36:43 ends the Edomite chiefs; 37:1 starts Jacob dwelling in Canaan. |
| Genesis 49–50 | 49:33 contains Jacob's death; 50:1 starts Joseph falling on him and weeping. |
| Exodus 20 | 12 honouring parents, 13–16 the individual prohibitions, 17 coveting, 18 thunder and 26 altar steps retain the ordinary labels. |
| Numbers 6 | 21 ends the Nazirite law; 22–23 introduce the blessing; 24–26 contain its three clauses; 27 places the name upon Israel. |

Exodus 20:13–15 additionally has explicit identity edges in the Peshitta profile:
the supplied verses prohibit murder, adultery and theft, respectively. STEP rules
4361–4363 determine this order indirectly from the last verse of Exodus 37, whose
numbering remains unreviewed here. Those three conditional rules alone are excluded
for this edition and replaced with the locally reviewed whole-verse identities.
Exodus 37 stays blocked. Both emitted Exodus 20 appointments must project and
round-trip through the same graph; no words, labels or passage coverage change.

Genesis 2, 5 and 6 remain blocked. The supplied 2:4 lacks the second clause present in the
independent witness. Genesis 5:6/28 differs in wording. Most decisively, source Genesis 6:1
already includes the opening clause of English 6:2 even though both sources count 22 verses.
Matching source/site labels and totals would therefore be an unsafe justification for
enabling that chapter. Isaiah 9 retains only the previously reviewed 9:2; the chapter is not
broadly enabled. All other known STEP-risk chapters remain blocked unless recorded above.

## Script safety and regression checks

The Hebrew-square projection uses Erez's converter; original Syriac is always retained.
Final semkath has the same base-letter projection as semkath. Ambiguous unmarked U+0716
(Sirach 3:19, Tobit 8:6, 2 Maccabees 10:19) and unsupported superscript alaph U+0711
(Wisdom 10:5, Sirach 38:12) are not guessed or dropped. A conversion error or residual
Syriac letter makes the entire requested passage unavailable. Syriac punctuation is distinct
from an unconverted letter. U+0711 is checked explicitly because its Unicode category is Mn.

Run `uv run --script Shared/tools/test-peshitta-readings.py` after regenerating the mapping
inventory and reader assets. Tests cover pin/name guards, exact defect matching, duplicate
and invalid labels, source fidelity, unchanged nine Isaiah prayer verses, conservative
Genesis 6 exclusions, and complete paired-script output. Numeric mapping provenance includes
the parser, review, witness metadata and converter so changed source assumptions require
explicit regeneration. The whole imported Peshitta corpus digest is
`996e84718322cfd7bfd966e369f3f610e4881fc58ba693db683b94c52c561171`.
