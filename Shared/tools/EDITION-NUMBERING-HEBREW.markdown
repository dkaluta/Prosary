# Numbering reviews for Hebrew, Tagalog, and Kulish sources

Reviewed 2026-09-12. `reading_edition_reviews_hebrew.py` describes numeric
correspondences for three exact source assemblies already used by the passage
builder. It contains references, selected upstream rule numbers, source pins,
and limitations. It contains no Scripture text. The source bytes and rendered
verse bodies were read from the existing verified cache; no new Bible edition
was acquired and no wording was copied into the review or tests.

The review combines the published [STEP versification rules](https://github.com/STEPBible/STEPBible-Data/tree/master/Versification),
the pinned [SIL tables](versification/README.markdown), the actual imported source
inventories, and inspection of the changed verse boundaries. STEP and SIL pins
and licenses remain in their respective `versification/*/sources.json` files.
An edition's language, tradition, or chapter maximum alone does not establish
its verse correspondence. Generic STEP families are restricted; local rules
from other families are selected only for the reviewed source pattern.

## Source identity and coverage

| Edition | Exact source assembly | Books / chapters / imported labels | Labels admitted by this profile |
| --- | --- | --- | --- |
| `masoretic-delitzsch` | `hbo` Old Testament plus 260 pinned Delitzsch 1901 New Testament chapter sources | 66 / 1,189 / 31,174 | 31,174 |
| `ang-dating-biblia-1905` | `TagAngBiblia` | 66 / 1,189 / 31,102 | 31,102 |
| `kulish-1905` | `ukr1871` | 66 / 1,189 / 31,082 | 31,046; 36 labels in two incomplete chapters are excluded |

All imported chapters have contiguous, nonempty, positive integer verse labels.
None of these assemblies contains the seven deuterocanonical books. A reference
in a missing book remains unavailable. An admitted label means that a reviewed
whole-verse correspondence exists; it does not assert identical wording or an
exact subdivision of the source verse.

The lock's VPL SHA-256 identifies the archive member imported by the builder,
rather than the containing ZIP. JSON and HTML source hashes identify their
complete imported bytes.

| Source | Primary publisher URL | Imported SHA-256 |
| --- | --- | --- |
| `hbo` | [eBible Hebrew archive](https://ebible.org/Scriptures/hbo_vpl.zip) | `2cea0bd9a61b446e704e61c49dac9cbf4747fa52a9ccd682c4f40d9889503aa8` |
| `TagAngBiblia` | [scrollmapper TagAngBiblia JSON](https://raw.githubusercontent.com/scrollmapper/bible_databases/master/formats/json/TagAngBiblia.json) | `d171f5d70731e21343d005af77596a1f876cfa39d2ce7517224c0d005e7f69d4` |
| `ukr1871` | [eBible Kulish archive](https://ebible.org/Scriptures/ukr1871_vpl.zip) | `1d2230822492a230c04fbea34f1b5ede7073a9d19c23a461d9738c87b85c2ec1` |
| Delitzsch 1901 | [12th-edition chapter index](https://delitz.fr/12/index.html) | All 260 separate hashes in `reading-text-sources.json` |

Each profile additionally pins its complete assembly. Its `source_pin_digest`
is SHA-256 over UTF-8 JSON of the exact `{sourceId: sourceSHA256}` map, with sorted
keys and separators `(',', ':')`. The shared registry must verify this digest
against the actual assembled corpus before applying these relations.

| Edition | Assembly digest |
| --- | --- |
| `masoretic-delitzsch` | `25c8eb7b72ca449b0b4ea64251c560789eeaf234555a31b8b4ec91a2ee0a2a95` |
| `ang-dating-biblia-1905` | `a841574697b680101934da5ac4f768a5dc0d3f08d8a231d8c770d77d978fe370` |
| `kulish-1905` | `f2a938ae98dbc3c4e562c57d6f2e5b63bb9d2b7adec2770d796fec1efb7d3239` |

## Whole-verse and title behavior

Mappings are a graph of whole published source verses and STEP Standard
references. A source verse can include more than one Standard verse or a
Standard verse can span more than one source verse. Converting part of an
indivisible group returns the enclosing whole verses and sets the envelope
flag. Converting the complete group clears that flag. No code estimates where
to cut a verse. Shared STEP clause-boundary groups continue to use this same
conservative rule.

STEP Standard differs from SIL English at 3 John 1:14 and Revelation 13:1.
Standard 3 John 1:14 encloses SIL English 1:14–15. Standard Revelation 13:1
encloses SIL English 12:18 and 13:1. The separate shared bridge handles those
relations; this profile maps directly to Standard.

| Source | Canonical Psalm headings represented | Boundary behavior |
| --- | --- | --- |
| Hebrew | 116 | 63 headings use separate numbered source verses; the other 53 are joined to the first body verse. SIL numeric title relations supply the separately numbered units. All 150 actual Hebrew Psalm inventories match SIL Original. |
| Tagalog | 0 | Every one of the 116 canonical heading locations was inspected. The first imported verse begins with Psalm body material, and no separately imported heading exists. Title requests remain unavailable. |
| Kulish | 114 | Psalm 60 uses source verses 1–2 for the heading, then 3–14 for Standard body verses 1–12. Other retained headings are joined to source verse 1. Psalms 98 and 123 omit their headings. All 116 candidate opening locations were inspected. |

Standard verse zero names a Psalm heading only. It is never manufactured as a
source verse. A request for body verse 1 of a source that joins its heading to
that verse sets the envelope flag because the complete source includes the
heading. The Hebrew graph is built from SIL Original correspondences, not the
NABRE Psalm graph, which has different local exceptions.

## Hebrew and Delitzsch review

The 929 Hebrew Old Testament chapter inventories agree with SIL Original.
The base families are `Hebrew` and `Eng-KJV`. Nehemiah 7 has 72 source verses;
source 7:68 corresponds to Standard 7:69, continuing through source 7:72 to
Standard 7:73. Standard 7:68 has no source counterpart. Inspection of source
7:67–72 confirmed this absence; the STEP `IfEmpty` entry creates no text.

Hebrew 1 Samuel 20:42 and 21:1 jointly correspond to Standard 20:42. The shared
engine expands the source's complete chapter inventories to read STEP's
cross-chapter summary without losing the second source verse.

Hebrew Malachi 3:19–24 corresponds, in order, to Standard 4:1–6. Source
3:22–24 was inspected because its whitespace word counts make STEP's language
dependent length discriminator choose an incorrect alternate order. The
explicit relation pins the observed source order, rather than treating that
length comparison as portable evidence.

The six already reviewed Delitzsch chapter differences retain the exact units
documented in [DELITZSCH-NUMBERING.markdown](DELITZSCH-NUMBERING.markdown):

| Source | STEP Standard |
| --- | --- |
| John 1:38–39 | 1:38 |
| John 1:40–52 | 1:39–51 |
| Romans 7:25–26 | 7:25 |
| 1 Corinthians 13:12–13; 13:14 | 13:12; 13:13 |
| 2 Corinthians 13:12; 13:13 | 13:12–13; 13:14 |
| 2 Thessalonians 3:16–17; 3:18–19 | 3:16; 3:17–18 |
| Revelation 13:1, following chapter 12's final verse 17 | 13:1 |

Delitzsch 3 John 1:14–15 jointly corresponds to Standard 1:14. Philippians
1:16–17 retains Standard order. These boundary checks prevent treating the
combined Hebrew edition as a universal Hebrew New Testament numbering scheme.

## Tagalog review

The source's complete chapter inventories match SIL English except for
3 John 1, which ends at 14, and Revelation 12, which ends at 17. Their closing
and adjacent source verse bodies were inspected: 3 John 1:14 and Revelation
13:1 each contain their complete Standard unit.

Philippians 1:16 and 1:17 reverse Standard order even though the chapter maximum
is unchanged. Only STEP lines 27455–27456 are selected for that reviewed swap.
Second Corinthians 13 has 14 source verses and retains the separate Standard
12, 13, and 14 units. Psalm headings are absent as described above.

## Kulish review

Fifty-five chapter inventories differ from SIL English. Fifty-three are
positively reviewed complete source units and appear in
`reviewed_inventory_exceptions`; the remaining two are excluded. The review
also handles internal differences that retain a chapter's original maximum,
including Deuteronomy 29 and Philippians 1.

The following local published rule groups were checked against the pinned
source at both sides of their changed boundaries. Their family names are
upstream categories, not blanket claims about this Ukrainian edition.

| Source range | Standard relation | Selected STEP lines |
| --- | --- | --- |
| 1 Samuel 20:42–43 | Jointly 20:42 | 6142–6144 |
| 1 Samuel 24:1; 24:2–23 | 23:29; 24:1–22 | 6184–6206 |
| 1 Kings 22:43–44; 22:45–54 | Jointly 22:43; 22:44–53 | 7175–7187 |
| Job 39:31–35; 40:1–19; 40:20–27; 41:1–26 | 40:1–5; 40:6–24; 41:1–8; 41:9–34 | 10156–10213 |
| Ecclesiastes 4:17; 5:1–19 | 5:1; 5:2–20 | 18002–18021 |
| Song 1:1–16 | 1:2–17; Standard 1:1 title is absent | 18101–18117; no `IfEmpty` text |
| Song 7:1; 7:2–14 | 6:13; 7:1–13 | 18157–18170 |
| Daniel 3:31–33; 4:1–34 | 4:1–3; 4:4–37 | 20264–20266, 20540–20573 |
| Hosea 14:1; 14:2–10 | 13:16; 14:1–9 | 21082–21091 |
| Jonah 2:1; 2:2–11 | 1:17; 2:1–10 | 21170–21180 |
| 2 Corinthians 13:12; 13:13 | 13:12–13; 13:14 | 27448–27451 |
| 3 John 1:14–15 | Jointly 1:14 | 27463–27465 |

Additional source merges and subdivisions were inspected directly. They are
explicit numeric overrides, not offsets guessed from the shorter chapter.
Unlisted verses in these ranges retain their ordinary labels unless another
published local rule applies.

| Source | Standard |
| --- | --- |
| Genesis 3:1; 3:2–23 | 3:1–2; 3:3–24 |
| Genesis 6:20; 6:21; 48:21 | 6:20–21; 6:22; 48:21–22 |
| Leviticus 5:20–23; 5:24–25; 5:26–27 | 6:1–4; jointly 6:5; 6:6–7 |
| Leviticus 6:1–21; 6:22 | 6:8–28; 6:29–30 |
| Leviticus 14:55; 17:15 | 14:55–57; 17:15–16 |
| Numbers 8:25; 14:44; 15:40; 20:28; 25:17; 27:22 | Each joins its Standard same-number verse and the following verse |
| Numbers 23:17–18; 23:19; 23:20 | Jointly 23:17; 23:18; 23:19 |
| Numbers 23:21; 23:22; 23:23–28 | 23:20–21; 23:21; 23:22–27 |
| Numbers 23:29; 23:30; 23:31 | 23:28–29; 23:29; 23:30 |
| Deuteronomy 16:21; 24:21; 32:51; 34:11 | Each joins its Standard same-number verse and the following verse |
| Deuteronomy 28:69; 29:1–2 | 29:1; jointly 29:2 |
| 2 Samuel 2:4–5; 2:6–33 | Jointly 2:4; 2:5–32 |
| Job 21:32; 21:33 | 21:32–33; 21:34 |
| Psalm 13:5; 24:9; 89:51; 106:47 | Each joins its Standard same-number verse and the following verse |
| Psalm 29:7; 29:8–10 | 29:7–8; 29:9–11 |
| Psalm 54:4; 54:5–6 | 54:4–5; 54:6–7 |
| Psalm 127:5–6 | Jointly 127:5 |
| Proverbs 30:30; 30:31–32 | 30:30–31; 30:32–33 |
| Isaiah 9:21–22 | Jointly 9:21 |
| Philippians 3:20 | 3:20–21 |
| Philemon 1:23; 1:24 | 1:23–24; 1:25 |

Numbers 23 includes overlapping clauses across the numbered divisions. Those
relations intentionally return whole verse envelopes for partial requests.
Kulish Philippians 1:16–17 retains Standard order: the actual source bodies
were inspected. Its word lengths would select the opposite Greek-family swap,
so that family is not enabled for this boundary.

Leviticus 21 has only 23 source rows, and the final row does not include the
material of Standard 21:24. Psalm 148 has 13 source rows; the last retains a
closing acclamation but lacks most of Standard 148:14. Their complete chapters
remain excluded, including structural predicates: an excluded source does not
prove either `Last` or `NotExist`. The missing passages are not filled from a
different edition. Song 1:1 and Psalm 98/123 headings are separately recorded
as absent; the surrounding admitted body verses are preserved.

## Repeating the validation

Run `uv run --script Shared/tools/test-reading-edition-reviews-hebrew.py`.
The tests use `build-reading-texts.py` to import only the existing cached
sources and verify their exact hashes. They skip the integration suite when
the caches are absent and never initiate a fetch. The tests check assembly
digests, every chapter inventory, all admitted source labels, target bounds,
round-trip whole-verse containment, complete Standard coverage, all canonical
Psalm heading locations, same-count exceptions, and missing-source behavior.

Changing a source pin requires a new source review. Updating counts alone is
insufficient: inspect changed chapter boundaries and known unchanged-count
exceptions, update the numeric relations and documented limitations, then
regenerate the shared source inventory through the registry's normal tool.
Scripture words remain confined to the already licensed source cache and the
normal passage assets; no review or mapping artifact needs their contents.
