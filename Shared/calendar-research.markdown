# Calendar sources and behavior

Reviewed 6 September 2026 for Prosary 0.11.1. The selected calendar controls its own feast
names and appointed reading citations. A missing date hides that row; no rite borrows another
rite's readings. Browsing dates does not change the date used to build a prayer session.

| Calendar | Liturgical cycle and published source | App behavior |
| --- | --- | --- |
| Roman / Holy Land | Modern Roman year: Advent, Christmas, Lent, Easter and Ordinary Time. [LitCal](https://litcal.johnromanodorazio.com/) supplies the General Calendar; documented LPJ propers overlay it. [Evangelizo HE](https://publication.evangelizo.ws/HE/days/2026-09-06) supplies readings. | Modern Roman seasonal weekday heading; independent feast and readings rows. |
| Roman 1962 | Advent, Christmas, time after Epiphany, Septuagesima/pre-Lent, Lent/Passiontide, Easter and time after Pentecost. [Missale Meum](https://www.missalemeum.com/en/api/v5/proper/2026-09-06) supplies its calendar and Mass references. | Civil day/month on weekdays. Preserve all parts of a citation, including Galatians 5:25–26; 6:1–10 on 6 September 2026. |
| Byzantine — Ukrainian Greek Catholic | The [UGCC reform](https://direct.ugcc.ua/en/data/historical-decision-the-ugcc-in-ukraine-switches-to-a-new-calendar-232/) moved fixed feasts to the new style while retaining Julian Pascha. The [official 2026 calendar](https://ugcc.ua/data/tserkovnyy-kalendar-ugkts-na-2026-rik-8059/) supplies the default lectionary. The year begins 1 September; movable cycles use Triodion/Pentecostarion and Sundays after Pentecost. | Julian Pascha by default (12 April 2026). A Gregorian option uses the separate [Royal Doors calendar](https://calendar.google.com/calendar/ical/ugccliturgy%40gmail.com/public/basic.ics) and matching feast table (Pascha 5 April 2026). Fixed feasts remain Gregorian in both choices. |
| Syriac Catholic | The West Syriac/Syriac Catholic [Evangelizo SYE edition](https://syriac.dailygospel.org/) has its own Church-dedication, Nativity, Epiphany, fasting, Resurrection, Pentecost and Cross cycles. | Retain source observances and lectionary dates, with a civil day/month heading on weekdays. |
| Maronite | The [Maronite liturgical year](https://www.stmaron.org/qurbono) has proper Sunday/week cycles. It opens with the [Consecration and Dedication of the Church](https://eparchy.squarespace.com/feast-day/consecration-of-the-church), followed by the Announcement/Nativity cycle, Epiphany, commemorations, Lent, Resurrection, Pentecost and Cross. [Evangelizo MAE](https://maronite.dailygospel.org/) is a separate publication from SYE. | Keep MAE dates and references. Omit ordinary ferial season labels from the feast table, retaining named feasts and Holy Week days. |

The supplementary weekday heading is hidden on every Sunday; feast and reading rows remain.
“Ordinary Time” is used only for the two modern Roman calendars. Other weekdays show the
localized civil day and month. The native calendar opens from the selected date between the
previous/next arrows; its Today action returns to the current civil date.

The Byzantine Easter choice switches **both** feast and reading files, with a cache key that
includes the choice. It represents two verified usages, not an arbitrary date shift. Syriac
Catholic and Maronite retain their published calendar; an alternate Easter option for either
requires a separately verified lectionary. The choice does not implement an old-style Julian
fixed-feast calendar.

## Reading corrections and provenance

The Ukrainian 6 September 2026 reading is **2 Corinthians 1:21–2:4; Matthew 22:1–14**.
The fully Gregorian Royal Doors usage has **2 Corinthians 4:6–15; Matthew 22:35–46** that day.
The old app selected the latter without exposing that calendar distinction. This is a UGCC
calendar-usage difference; the source is not relabeled as a Ruthenian lectionary.

`tools/import-ugcc-calendar.py` preserves all 365 original source reference rows in a checked-in
snapshot, records the source HTML hash, and documents narrow punctuation/book corrections.
It selects appointed Liturgy readings separately from Matins and water-blessing readings.
On days whose published services are Hours/Vespers, their appointed references remain.
February 18 and 20 explicitly have no Liturgy and therefore no reading row. Holy Week days
with only an appointed Gospel are not filled with invented epistles. Regression fixtures
cover cross-chapter ranges, disjoint verses, Latin/Cyrillic Roman numerals, named services,
and each corrected source omission. No Scripture or prayer text is copied.

Missale Meum's appointed reference blocks are kept in full before their Scripture bodies.
This repairs truncated chapter continuations, historical book aliases, and dotted/comma
chapter separators. Rubrics before Gospel references are skipped. Grouped Good Friday and
Paschal Vigil lessons, Passion sections, Ember lessons, and the three Masses on All Souls
and Christmas are retained, while interspersed chant references are excluded. Maronite's feed assigns a
Roman-style “psalm” slot to some epistles; Eastern citation types are derived from their books,
so Romans 8 is a reading, not a psalm. All reference ranges and source ordering are retained.

## Translation policy

Every shipped feast, solemnity and Sunday has all seven interface languages. Existing church
wording takes precedence; the remaining exact identities use credited editorial display labels
in `tools/feast-titles-*.json`. Those labels are not represented as official liturgical prayer
translations. Reviewed aliases preserve identity and do not transfer dates, ranks or readings.
The English source title remains available for future unsupported identities.

Hebrew Pentecost is **שבועות**, including its associated Sundays. Hebrew church sources are
recorded in `hebrew-feast-titles.json`, `hebrew-saint-titles.json` and the Roman Hebrew catalog.
Citation book labels retain [Evangelizo](https://dailygospel.org/), [St James Vicariate](https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_SJVLiturgicalCalendar202526.pdf)
and [Mechon Mamre](https://www.mechon-mamre.org/i/t/tmp3.htm) provenance. Prayer wording is
independent of these display labels. Shared `tl` and `he` normalize platform `fil` and `iw`.

## Eretz Israel Torah portion

The optional Torah row uses the [Hebcal API](https://www.hebcal.com/home/195/jewish-calendar-rest-api)
with `i=on`, under CC BY 4.0. Each selected date maps to the next Saturday, including Saturday
itself. When a festival replaces the weekly portion, that Saturday's festival Torah reading is
shown. Haftarah and festival megillot are excluded; only the five Torah books remain.
No diaspora schedule or selector is present. Proper names use Hebcal Hebrew, French and Russian
where supplied; other locales retain source transliterations with localized captions and book
names. The shipped table covers 2026–2027, including the next Saturday beyond year end.

## Shipped coverage and refresh

Coverage reflects the sources available at generation time, not a promise that every date in
the native picker has data. Modern Roman and 1962 feasts, and both Byzantine feast variants,
cover 2026–2027. The Maronite source currently stops at 31 October 2026 (304 reading days);
its named observances end at the last Sunday in that range. Syriac readings currently reach
8 December 2026, with feast coverage ending 24 November. The official UGCC and Gregorian
Byzantine readings cover 2026; the 1962 table contains all 365 source days and 770 appointed citations. Modern Roman readings
currently span 31 July–5 December 2026. Missing entries are not synthesized.

Refresh `fetch-feasts.py` and `fetch-readings.py` periodically with `--sync`. Maronite's wrapper
`fetch-maronite.py` downloads each response once for both datasets and caches it outside the
repository. Refresh the official UGCC snapshot when a new year's calendar is published.
`fetch-torah-portions.py --sync` extends the Torah table. All native copies must remain
byte-identical to `Shared/data`; `test-today-data.py` checks the registered files and locales.
