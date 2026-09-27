# Supplied Peshitta Old Testament reader review

Reviewed 2026-09-27 after the user's request to expand the supplied Old Testament and
verify all material being offered. This governs Readings. The nine Isaiah verses used in
prayer packs and all 27 Digital Syriac Corpus NT source files remain unchanged.

## Source identity and import

The [supplied XML](https://archive.org/details/peshitta-complete-bible-otnt) has SHA-256
`4f71fe418a1d23f6b65d63d155f838a228dbdb6e4857834f4503afdcf009ea88`.
Its underlying OT edition and redistribution terms remain unresolved. Reused BFBS 1905
metadata does not identify the OT; the NT's CC BY 4.0 terms do not apply to it. See
[the earlier investigation](PESHITTA-ISAIAH-SOURCE-REVIEW.markdown).

The importer selects each book by exact reviewed name and guards its numeric ID. Damaged
and unnamed NT elements are never used. The named Susanna element also contains Bel and
is not imported under a guessed alias; Baruch is absent.

`peshitta-supplied-ot-review.json` records exact chapter labels and structural defects.
Changes fail closed. Entire damaged chapters are excluded, including both Exodus elements
labeled 32, Ezra 5's label 51, duplicate verses in 2 Chronicles 9, Sirach 42/44 and
1 Maccabees 7, gaps and unpointed placeholders. Labels are never repaired or overwritten.
Psalm 999 entries are prose introductions, never ordinary verse labels.

After those guards, the importer contains **45 OT books, 1,004 chapters and 25,095 entries**.
These source-inventory totals do not imply that every entry is available in the app.

## Complete independent witness collation

Every one of the 25,095 imported entries was compared with the corresponding explicit
book/chapter/verse label on [Peshitta.eu](https://www.peshitta.eu/ot.html). All 1,060 indexed
chapter pages for the selected books were fetched, including pages corresponding to source
chapters already excluded by the importer. Labels, duplicate/missing/extra entries,
normalized consonants and word divisions were checked separately.

`peshitta-supplied-ot-full-collation.json` retains every chapter URL and response hash,
label inventories, per-chapter result-manifest hashes, aggregate results and all 144 triaged
cases. It pins the full per-verse report by SHA-256. Website Scripture wording is not copied
into canonical data or native apps. The earlier 27-chapter file remains historical evidence;
it is no longer the scope of this review.

- 24,951 entries match both consonants and word divisions.
- 140 entries differ in consonants; four contain unsupported normalization characters.
- No imported verse is missing from the witness. No duplicate witness labels, unresolved
  page parsing errors or failed fetches remain.
- 33 differences are website copies of another chapter: Genesis 21:3 copies 20:3,
  1 Samuel 27:1–12 copies 26:1–12, and 2 Kings 16:1–20 copies 17:1–20. Exact alternate-coordinate
  hashes corroborate these findings; they do not authorize changing the supplied source.
- 83 differences are separate Lamentations acrostic-letter prefixes; five involve a beth
  missing inside the website's verse body. Remaining lexical/clause differences have
  individual dispositions in the collation file. Unresolved differences stay unresolved.

Among the 3,827 coordinates offered before this correction, only Genesis 21:3 and
Proverbs 23:29 differ from the website. The former is the website copy error above; the
latter is a parenthetical alternate in the supplied source, quarantined pending its review.

Normalization ignores points/punctuation, recognizes marked rish and final semkath, and
retains ambiguous unmarked U+0716 and superscript alaph U+0711 as explicit uncertainties.
This is **consonantal collation, not a review of every vowel or word meaning**. The website's
[source note](https://www.peshitta.eu/about.html) identifies a Syriac Orthodox Patriarchate
2020 publication; matching it does not identify the supplied XML's edition or grant rights.

## Complete review of the verses offered by the app

The team separately read **all 3,827 distinct OT coordinates** offered by the pre-correction
reader against the supplied Syriac, its established Hebrew-script projection, the complete
KJV reference verse and adjacent clauses. Scope: Genesis/Leviticus/Numbers/Deuteronomy 2,019;
Exodus 433; history/wisdom 681; Prophets 694. The semantic catalog pins the original reader
artifact and four review reports. This is the complete emitted scope; it is not a claim to
have semantically certified all 25,095 imported entries.

`peshitta-supplied-ot-semantic-review.json` records each reviewed coordinate, 41 compound
units, 23 exact editorial fragments and unresolved source queries. Mapping now requires
those explicit coordinates. **No other OT verse acquires an identity edge merely because
its chapter has matching counts or agrees with the website.** Future appointments outside
the catalog remain unavailable until reviewed. Existing structural, sparse-chapter,
Psalm/deuterocanonical and known STEP-risk exclusions still apply.

Compound units keep clauses together when source and Standard divide them differently.
For example, source Isaiah 1:17 starts the cease-from-evil clause of Standard 1:16;
source Genesis 13:4 contains the former tent-site clause of Standard 13:3; and the
Leviticus 11:13–19 bird list has different internal divisions. Selecting a member expands
to the complete reviewed envelope and supplies the existing whole-verse notice. Both
mapping directions use the same graph. Legacy and exact-appointment builder paths also
validate every coordinate, so chapter-level checks cannot bypass this restriction.

STEP has no Syriac source family. The retained English-family machinery supplies the
unchanged NT behavior and existing guards; OT availability comes from explicit local
review. Exodus 20:13–15 retains the reviewed murder/adultery/theft order independently of
STEP 4361–4363's predicate on unreviewed Exodus 37. Genesis 6 remains blocked: its equal
verse count concealed a moved clause, demonstrating why broad ordinary-numbering inference
was insufficient.

## Editorial material and unresolved wording

The reader removes only 23 individually identified caption prefixes/suffixes. Each records
the exact pointed fragment, its position and the SHA-256 of the complete original verse.
A changed hash or boundary fails import. Rejoining the removed fragment and retained text
reconstructs the original exactly; nothing outside the reviewed fragment changes. Examples
include “On the king of Tyre” before Ezekiel 28:1 and “Praise of Isaiah” after Isaiah 42:9.
Biblical introductions such as Isaiah 1:1 and 2:1 remain Scripture. The prayer importer is
unaffected. Reference audits can request the unmodified source with `exclude_editorial=False`.

Eight source queries are excluded from both mapping directions; a query inside a compound
withholds the whole compound. A requested passage containing an unresolved verse becomes
unavailable. The builder does not omit that verse and display the rest. Lee's independently
scanned 1823 edition confirms discrepancies at Exodus 12:15/48 and 15:21/22, Leviticus 24:8,
and Numbers 5:14 and 7:56. Proverbs 23:29 remains withheld pending adjudication of its
parenthetical gloss. These seven print discrepancies and one unresolved gloss are not
silently repaired or filled from another edition.

The printed review also distinguishes six retained source readings: Genesis 41:54's
Egypt/bread negation, Deuteronomy 20:19's wording without an additional local negative,
Isaiah 49:4's seed-of-Jacob opening, and Edom/Edomites at 2 Kings 5:1/2/5. Lee prints these
readings too; Mosul 1887 additionally corroborates Genesis 41:54. This establishes published
source variants rather than isolated digital copying errors. It does not resolve all
grammatical, historical or narrative questions. The catalog retains exact source URLs,
PDF hashes, page numbers, review-report hashes and image hashes for these decisions.

Within-verse wording differences remain unchanged. The catalog records 26 retained notes,
including the missing introductions in Daniel 7:11/13, dove in Isaiah 40:31, the day wording
in Ezekiel 43:27, guarding the strong in Ezekiel 34:16, treasury in Zechariah 11:13, and
14 Exodus observations. These are recorded source variants, not independent critical
certification of every reading. KJV serves as a boundary reference. It is never used to invent Syriac
wording, vocalize an uncertain correction or silently replace the supplied edition.

## Script safety and verification

Erez's established projection supplies Hebrew-square display. The Syriac reader body is
the supplied source after only documented caption exclusions. Final semkath maps to
semkath's Hebrew base letter. Ambiguous unmarked U+0716 and unsupported superscript alaph
U+0711 are never guessed or discarded. A conversion failure withholds the entire passage.

Run `uv run --script Shared/tools/test-peshitta-readings.py` after regenerating mapping
metadata and reading assets. Tests cover exact caption reconstruction/hash failure, every
compound in both directions, unknown-coordinate rejection, legacy/exact-appointment bypass,
unresolved queries, complete NT mapping preservation, unchanged prayer verses, source
fidelity and paired scripts. The [coverage report](../reports/readings-text-coverage.json)
is authoritative for resulting daily/Torah totals. The corpus digest is pinned in
`reading_edition_reviews_peshitta.py`; source, caption or review changes require regeneration.
