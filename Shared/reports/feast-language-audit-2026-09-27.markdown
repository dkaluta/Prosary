# Syriac feast-language audit — 27 September 2026

The display bug was in generated Syriac data: English names had been stored under
localized keys. Native Today, Readings and widget language selection was already
using the interface language, independently of prayer language. Hebrew `iw` and
Filipino `fil` normalize to the shared `he` and `tl` identifiers.

## Scope and findings

The original Syriac table contained 261 dates and 373 observance components,
covering 1 January through 8 December 2026. English and Arabic Evangelizo feeds
were compared by reviewed saint identities, never by position within a day.

- Hebrew, Russian, Filipino and Ukrainian each contained 181 English fallback
  components; French and Italian each contained 180. Arabic had 16.
- There were 184 uncovered identities across the languages, including 34
  observances supplemented by the Arabic feed. Eight missing liturgy labels were
  caused by repeated spaces in catalog lookup keys.
- Arabic catalog labels for some English-only saints existed but were skipped.
- The 10 February Arabic liturgy caption was the literal spreadsheet error
  `#REF!`; neither feed supplied a saint that day. The invalid row is removed.
- Two 22 January Timothy captions represented the same saint; an explicit
  reviewed alias now deduplicates them.
- Other calendars passed the audit for English copied into another language.
  Identical legitimate French names and Latin papal ordinals are not treated as
  missing translations merely because their characters match English.

## Corrected data

The regenerated table contains **260 dates, 371 observances and 368 identities**.
Every component has a reviewed label in all eight interface languages. English
keeps the provider's spelling; actual Arabic captions remain source metadata so
later editorial changes cannot overwrite them. Missing translations now stop
generation before the existing complete dataset is replaced.

The supplied Hebrew calendar is preserved verbatim at
`Shared/tools/sources/syriac-calendar-2026-he.ics`. A checksum and 357 reviewed
source UID mappings connect its labels and descriptions to the correct identities.
It is a **Syriac-only reference**. Its recurrence rules and dates do not change
Prosary's appointed dates, other rites, or ranks.

Already sourced Hebrew names and the user's chosen descriptors remain preferred;
the supplied reference fills remaining Syriac labels. This preserves
`תאמא השליח` and `שבועות`. The current table contains **246 Hebrew saint
descriptions**, matched to exact dates and identities. The distinct July and
October Thomas biographies stay attached to their respective dates.

Examples now covered in Hebrew:

- 30 September: Gregory the Illuminator and Jerome.
- 1 October: Ananias, Abbai, and Therese of Lisieux.

The native “About the saints” disclosure starts collapsed above readings, obeys
feast visibility, and resets on date/calendar/interface-language changes. It is
shown only for Syriac with an available biography in the exact interface language;
there is no foreign-language description fallback. Source links and attribution
identify the supplied Hebrew reference and underlying Evangelizo source.

## Source disagreements retained for review

English and Arabic can name different saints on the same day. Bartimaeus/Barses,
Custos/Sixtus, Vichai/Bishoy, Julian/Sabas, and the reused Matthew captions are not
automatically merged. Opaque English proper names receive conservative editorial
display transliterations, not invented biographies or claims of official liturgical
translation. Source captions also disagree over forty/forty-two martyrs and some
qualifications. Previously reviewed Hebrew names/roles are retained where available;
supplied biography wording remains unchanged apart from separating its attribution.

## Verification

`test-syriac-observances.py` checks component identities, all-language completeness,
actual Arabic preservation, refreshable editorial Arabic, rejection of blank or
partly translated compounds, invalid-source filtering, deduplication, atomic failure,
repeatable localization and native asset parity.

`test-syriac-hebrew-calendar.py` checks calendar unfolding/escaping, source checksum,
exact identity/date joins, separate Thomas biographies, stale-description removal
and Syriac-only scope. `test-today-data.py` covers all six calendars and their seven
feast tables. Native tests cover locale selection, disclosure/reset behavior and
missing-language handling. Published labels are metadata; these checks do not claim
ecclesiastical approval of editorial translations.
