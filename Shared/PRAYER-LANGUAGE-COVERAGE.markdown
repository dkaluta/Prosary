# Prayer language coverage

Generated from the current checkout with `uv run --script Shared/tools/audit-prayer-coverage.py --markdown`.

Exact selected-language coverage before user fallback. Native fixed prayers and shared bundle overrides merge; local keys resolve in their own pack. Shared mystery fields merge across packs. Hebrew traditions are one language, with he-x-gamliel inheriting he. Absent languages are expansion work, not broken manifest promises. Counts are key/language pairs, not unique prayers or editorial approval.

doxologiaMinor is reserved for future use and excluded from active body-gap counts.

Scope: 128 canonical language files, 10 packs, 12 public prayer languages.

## Common fixed prayers

| Language | Missing bodies | Missing headings |
|---|---:|---:|
| la | 0 | 0 |
| en | 0 | 0 |
| he | 0 | 0 |
| ar | 0 | 0 |
| ru | 0 | 0 |
| uk | 2 | 0 |
| tl | 0 | 0 |
| fr | 0 | 0 |
| it | 0 | 0 |
| es | 0 | 0 |
| el | 1 | 0 |
| arc | 15 | 0 |

## Pack coverage gaps

Rows with no missing fields and an advertised language are omitted.

| Pack | Language | Status | Prayer bodies | Scripture | Meditations | Other bodies | Headings | Mystery title / fruit / body |
|---|---|---|---:|---:|---:|---:|---:|---|
| angelus | arc | partial_overlay | 5 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| divineMercyChaplet | arc | partial_overlay | 3 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| franciscanCrown | uk | advertised | 2 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| franciscanCrown | arc | partial_overlay | 10 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| litanyOfLoreto | arc | partial_overlay | 17 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| oAntiphons | ar | partial_overlay | 7 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| oAntiphons | tl | partial_overlay | 7 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| oAntiphons | el | partial_overlay | 7 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| oAntiphons | arc | partial_overlay | 7 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| rosary | uk | advertised | 2 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| rosary | el | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| rosary | arc | advertised | 14 | 0 | 0 | 2 | 0 | 0 / 0 / 0 |
| sevenSorrows | el | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| sevenSorrows | arc | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | uk | advertised | 2 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | fr | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | it | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | es | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | el | partial_overlay | 2 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| stationsOfTheCross | arc | partial_overlay | 4 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| viaLucis | el | partial_overlay | 1 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |
| viaLucis | arc | partial_overlay | 2 | 0 | 0 | 0 | 0 | 0 / 0 / 0 |

## Exact common-prayer gaps

### uk

Bodies: almaRedemptorisMater, aveReginaCaelorum

Headings:

### el

Bodies: sanctusMichael

Headings:

### arc

Bodies: almaRedemptorisMater, animaChristi, aveReginaCaelorum, collectaPaschale, collectaStandard, oratioFatimae, oratioIesu, reginaCaeli, requiemAeternam, responsiumPaschale, responsiumStandard, salveRegina, sanctusMichael, versiculumPaschale, versiculumStandard

Headings:

## Exact pack gaps

The sibling `PRAYER-LANGUAGE-COVERAGE.json` records every missing key and its intended canonical file.
Regenerate it with `uv run --script Shared/tools/audit-prayer-coverage.py --json`.

Presence only establishes coverage. Source provenance, accurate wording, and liturgical suitability require separate review.
