# Pinned edition reference inventories

`inventories.json` records the exact numbered inventories imported by Prosary's nine
existing Bible editions. It contains book/chapter/verse identifiers, word counts and SHA-256
digests only. No Bible wording is copied into this directory. Arabic additionally records
the numeric source/Standard ranges of its existing reviewed units and their page evidence.

`sources.json` binds the inventory to the source lock, importer, mapping profiles and pinned
SIL/STEP rules. Each profile separately checks a digest of its source IDs and hashes. Runtime
reference conversion needs no Scripture cache or network access; the passage builder also
checks the actual assembled text digest before selecting existing source rows.

| Edition | Books in pinned source | Chapters | Verse labels | Labels with an ordinary Standard correspondence |
| --- | ---: | ---: | ---: | ---: |
| Douay–Rheims | 73 | 1,334 | 35,811 | 35,811 |
| Masoretic / Delitzsch 1901 | 66 | 1,189 | 31,174 | 31,174 |
| Synodal | 66 | 1,189 | 31,169 | 31,164 |
| Ang Dating Biblia | 66 | 1,189 | 31,102 | 31,102 |
| Crampon | 73 | 1,334 | 35,610 | 33,869 |
| Martini | 32 | 447 | 13,785 | 13,708 |
| Kulish | 66 | 1,189 | 31,082 | 31,046 |
| Old Jesuit Arabic | 7 | 24 sparse | 220 | 220 within 64 reviewed units |
| Peshitta | 28 | 264 (including five sparse Isaiah chapters) | 7,912 | 7,791 |

These counts describe the existing pinned imports, not a claim that every printed edition
or every daily appointment is fully available. Whole source verses can overlap more than one
Standard verse; partial selections return the enclosing whole verses and an expansion flag.
Arabic requires exact ordered concatenations of reviewed units and refuses partial units.

The reviewed profiles are [Hebrew, Tagalog and Ukrainian](../../reading_edition_reviews_hebrew.py),
[Russian, French and Italian](../../reading_edition_reviews_western.py), and
[Arabic](../../reading_edition_reviews_arabic.py), and
[Peshitta](../../reading_edition_reviews_peshitta.py). The DRA profile retains its earlier
[STEP](../step/README.markdown) and [Psalm](../../reading_psalm_mapping.py) boundary reviews.
They use the existing sources in [reading-text-sources.json](../../reading-text-sources.json).
Source numbering is edition-specific: matching chapter lengths or word counts across
languages do not establish matching boundaries. Local reviews override those predicates only
for their pinned sources.

Crampon's 58 chapters with empty or shifted entries remain excluded, as do mappings whose
predicates depend on those chapters. Martini excludes incomplete John 11, 1 Thessalonians 4
and 1 Peter 5. Kulish excludes incomplete Leviticus 21 and Psalm 148. Synodal's five additional
Joshua/Proverbs labels have no ordinary Standard counterpart. Missing books and omitted
Psalm superscriptions are never supplied from another edition.
Peshitta excludes Luke 10/11, Philippians 1, 3 John and Revelation 12/13 pending their
source/boundary reviews; only its exact nine already approved Isaiah verses bypass ordinary
complete-chapter validation, with their full sparse inventory checked against the profile.
No other Old Testament source is exposed. See the [Peshitta source review](../../../content/PESHITTA-SOURCES.markdown).

From the repository root:

```sh
uv run --script Shared/tools/build-edition-mappings.py
uv run --script Shared/tools/build-edition-mappings.py --check
uv run --script Shared/tools/build-reading-texts.py --sync
uv run --script Shared/tools/test-reading-edition-mapping.py
```

Regeneration uses existing hash-checked imports, without downloading new editions. `--fetch`
can populate missing files from those same already-pinned source URLs. Metadata never removes
the separate requirement to establish a calendar appointment's source numbering. The builder
keeps exact appointment reviews and the existing agreement policy for unreviewed citations.

The build-time API is `reading_edition_mapping.mapper(edition_id)` with `to_standard` and
`from_standard` methods, or `convert_references(source_id, target_id, references)`. References
are `(book, chapter, verse)` tuples; `NABRE` is also accepted as a source ID. Results contain
the ordered target references and a Boolean whole-verse expansion flag. Unavailable mappings
raise `reading_step_mapping.Unavailable`.
