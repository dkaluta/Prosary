# Prayer language coverage

Generated from the current checkout with `uv run --script Shared/tools/audit-prayer-coverage.py --markdown`.

Exact selected-language coverage before user fallback. Native fixed prayers and shared bundle overrides merge; local keys resolve in their own pack. Shared mystery fields merge across packs. Hebrew traditions are one language, with he-x-gamliel inheriting he. Absent languages are expansion work, not broken manifest promises. Counts are key/language pairs, not unique prayers or editorial approval.

doxologiaMinor is reserved for future use and excluded from active body-gap counts.

Scope: 107 canonical language files, 10 packs, 11 public prayer languages.

## Common fixed prayers

| Language | Missing bodies | Missing headings |
|---|---:|---:|
| la | 0 | 0 |
| en | 0 | 0 |
| he | 0 | 0 |
| ar | 0 | 0 |
| ru | 0 | 0 |
| tl | 0 | 0 |
| fr | 0 | 0 |
| it | 0 | 0 |
| es | 0 | 0 |
| el | 1 | 0 |
| arc | 15 | 8 |

## Pack coverage gaps

Rows with no missing fields and an advertised language are omitted.

| Pack | Language | Status | Prayer bodies | Scripture | Meditations | Other bodies | Headings | Mystery title / fruit / body |
|---|---|---|---:|---:|---:|---:|---:|---|
| angelus | el | absent_language | 5 | 0 | 0 | 0 | 5 | 0 / 0 / 0 |
| angelus | arc | absent_language | 5 | 0 | 0 | 0 | 6 | 0 / 0 / 0 |
| divineMercyChaplet | el | absent_language | 3 | 0 | 0 | 0 | 8 | 0 / 0 / 0 |
| divineMercyChaplet | arc | absent_language | 3 | 0 | 0 | 0 | 9 | 0 / 0 / 0 |
| franciscanCrown | arc | absent_language | 10 | 0 | 0 | 0 | 11 | 7 / 7 / 1 |
| litanyOfLoreto | arc | absent_language | 17 | 0 | 0 | 0 | 16 | 0 / 0 / 0 |
| oAntiphons | he | absent_language | 7 | 8 | 0 | 0 | 10 | 0 / 0 / 0 |
| oAntiphons | ar | absent_language | 7 | 8 | 0 | 0 | 10 | 0 / 0 / 0 |
| oAntiphons | ru | absent_language | 7 | 8 | 0 | 0 | 10 | 0 / 0 / 0 |
| oAntiphons | tl | absent_language | 7 | 8 | 0 | 0 | 10 | 0 / 0 / 0 |
| oAntiphons | es | partial_overlay | 0 | 7 | 0 | 0 | 0 | 0 / 0 / 0 |
| oAntiphons | el | partial_overlay | 7 | 0 | 0 | 0 | 10 | 0 / 0 / 0 |
| oAntiphons | arc | partial_overlay | 7 | 0 | 0 | 0 | 10 | 0 / 0 / 0 |
| rosary | la | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | en | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | he | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | ar | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | ru | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | tl | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | fr | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | it | advertised | 0 | 0 | 0 | 0 | 1 | 0 / 0 / 0 |
| rosary | el | partial_overlay | 7 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| rosary | arc | advertised | 19 | 0 | 0 | 2 | 18 | 20 / 20 / 0 |
| sevenSorrows | es | partial_overlay | 1 | 0 | 0 | 0 | 6 | 7 / 7 / 1 |
| sevenSorrows | el | partial_overlay | 1 | 0 | 0 | 0 | 6 | 7 / 7 / 1 |
| sevenSorrows | arc | absent_language | 1 | 0 | 0 | 0 | 7 | 7 / 7 / 7 |
| stationsOfTheCross | ar | advertised | 0 | 1 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | tl | advertised | 0 | 1 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | fr | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | it | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | es | partial_overlay | 3 | 0 | 14 | 0 | 32 | 0 / 0 / 0 |
| stationsOfTheCross | el | partial_overlay | 3 | 0 | 14 | 0 | 32 | 0 / 0 / 0 |
| stationsOfTheCross | arc | partial_overlay | 4 | 0 | 14 | 0 | 32 | 0 / 0 / 0 |
| viaLucis | es | partial_overlay | 2 | 0 | 0 | 0 | 16 | 0 / 0 / 0 |
| viaLucis | el | partial_overlay | 2 | 0 | 0 | 0 | 16 | 0 / 0 / 0 |
| viaLucis | arc | partial_overlay | 2 | 0 | 0 | 0 | 16 | 0 / 0 / 0 |

## Exact common-prayer gaps

### el

Bodies: sanctusMichael

Headings:

### arc

Bodies: almaRedemptorisMater, animaChristi, aveReginaCaelorum, collectaPaschale, collectaStandard, oratioFatimae, oratioIesu, reginaCaeli, requiemAeternam, responsiumPaschale, responsiumStandard, salveRegina, sanctusMichael, versiculumPaschale, versiculumStandard

Headings: almaRedemptorisMaterTitle, aveMariaProCaritate, aveMariaProFide, aveMariaProSpe, aveReginaCaelorumTitle, decadeOrdinalFormat, reginaCaeliTitle, salveReginaTitle

## Exact pack gaps

The sibling `PRAYER-LANGUAGE-COVERAGE.json` records every missing key and its intended canonical file.
Regenerate it with `uv run --script Shared/tools/audit-prayer-coverage.py --json`.

Presence only establishes coverage. Source provenance, accurate wording, and liturgical suitability require separate review.
