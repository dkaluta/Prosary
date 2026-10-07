# Calendar sources and behavior

Reviewed 3 October 2026. The selected calendar controls its own feast
names and appointed reading citations. A missing date hides that row; no rite borrows another
rite's readings. Browsing dates does not change the date used to build a prayer session.

| Calendar | Liturgical cycle and published source | App behavior |
| --- | --- | --- |
| Roman / Holy Land | Modern Roman year: Advent, Christmas, Lent, Easter and Ordinary Time. [LitCal](https://litcal.johnromanodorazio.com/) supplies the General Calendar; documented LPJ propers overlay it. [Evangelizo HE](https://publication.evangelizo.ws/HE/days/2026-09-06) supplies readings. | Modern Roman seasonal weekday heading; independent feast and readings rows. |
| Roman 1962 | Advent, Christmas, time after Epiphany, Septuagesima/pre-Lent, Lent/Passiontide, Easter and time after Pentecost. [Missale Meum](https://www.missalemeum.com/en/api/v5/proper/2026-09-06) supplies its calendar and Mass references. | Civil day/month on weekdays. Preserve all parts of a citation, including Galatians 5:25–26; 6:1–10 on 6 September 2026. |
| Roman — St James Vicariate (2026–2027) | The supplied [bilingual calendar](https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_HebrewandEnglish20262027SA2.pdf) includes Great Advent from October. | Its own 4 October 2026–24 October 2027 appointments, source English/Hebrew titles and printed Year B/C labels. Keep additional readings, Mass groups and alternatives; community-only alternatives remain in the reviewed snapshot. |
| Franciscan Conventual — St Anthony Province, Italy (2025–2026) | The province's [dated annual Ordo](https://www.francescaninorditalia.net/aggiornamenti/news/1075-calendario-liturgico-pisap-ofm-conv-2025-2026.html). | Provincial precedence, including the solemnity of Francis on Sunday 4 October. Covers 29 November 2025–28 November 2026; not a universal calendar for all Franciscan branches. |
| Discalced Augustinian — General Ordo (2026) | The Order of Discalced Augustinians' [English annual Ordo](https://oadnet.org/calendario_liturgico/). | Its general calendar, including Augustine as a solemnity; fixed January 6 Epiphany and first printed general/day Mass. National variants and alternative Masses remain in the snapshot. |
| Byzantine — Ukrainian Greek Catholic | The [UGCC reform](https://direct.ugcc.ua/en/data/historical-decision-the-ugcc-in-ukraine-switches-to-a-new-calendar-232/) moved fixed feasts to the new style while retaining Julian Pascha. The [official 2026 calendar](https://ugcc.ua/data/tserkovnyy-kalendar-ugkts-na-2026-rik-8059/) supplies the default lectionary. The year begins 1 September; movable cycles use Triodion/Pentecostarion and Sundays after Pentecost. | Julian Pascha by default (12 April 2026). A Gregorian option uses the separate [Royal Doors calendar](https://calendar.google.com/calendar/ical/ugccliturgy%40gmail.com/public/basic.ics) and matching feast table (Pascha 5 April 2026). Fixed feasts remain Gregorian in both choices. |
| Byzantine — Old-style Julian (feasts) | The same curated fixed menologion and seasonal Sunday ranges use Julian dates converted to civil Gregorian dates; Pascha is computed independently. The [UGCC's earlier Christmas schedule](https://synod.ugcc.ua/data/opublikovano-rozklad-translyatsiy-rizdvyanyh-bogosluzhin-z-patriarshogo-soboru-voskresinnya-hrystovogo-7702/) explicitly identifies Julian Christmas on 7 January, before the fixed-feast reform. | Separate `ugcc-julian` choice: Christmas 7 January, Theophany 19 January, Cross 27 September in 2026–2027. Its 187 feast/Sunday dates are curated scope; old-style daily readings remain absent pending a verified lectionary. |
| Syriac Catholic | The West Syriac/Syriac Catholic [Evangelizo SYE edition](https://syriac.dailygospel.org/) has its own Church-dedication, Nativity, Epiphany, fasting, Resurrection, Pentecost and Cross cycles. | Retain source observances and lectionary dates, with a civil day/month heading on weekdays. |
| Maronite | The [Maronite liturgical year](https://www.stmaron.org/qurbono) has proper Sunday/week cycles. It opens with the [Consecration and Dedication of the Church](https://eparchy.squarespace.com/feast-day/consecration-of-the-church), followed by the Announcement/Nativity cycle, Epiphany, commemorations, Lent, Resurrection, Pentecost and Cross. [Evangelizo MAE](https://maronite.dailygospel.org/) is a separate publication from SYE. | Keep MAE dates and references. Omit ordinary ferial season labels from the feast table, retaining named feasts and Holy Week days. |

The supplementary weekday heading is hidden on every Sunday; feast and reading rows remain.
“Ordinary Time” is used only for the two modern Roman calendars. Other weekdays show the
localized civil day and month. The native calendar opens from the selected date between the
previous/next arrows; its Today action returns to the current civil date.

The Byzantine Easter choice switches **both** feast and reading files, with a cache key that
includes the choice. It represents two verified usages, not an arbitrary date shift. Syriac
Catholic and Maronite retain their published calendar; an alternate Easter option for either
requires a separately verified lectionary. The Easter choice remains independent of the
separate old-style `ugcc-julian` feast calendar. Old-style fixed holidays cross civil-year
boundaries, so January's Christmas is generated from the previous Julian year's December 25;
the conversion handles Julian-only leap days and changing century offsets. Seasonal Sundays
are resolved around the converted feast dates, rather than shifting the whole calendar by
thirteen days. A fixed Great Feast coinciding with a movable Great Feast retains both titles
(Annunciation with Pascha); this is covered by 1991 Julian and 2035 Gregorian regression cases.
Ordinary fixed commemorations can still be displaced by the curated movable precedence;
the dataset does not claim a verified old-style typikon's transfer rubrics.
The [source investigation and conversion audit](tools/sources/old-style-julian-research.json)
records the Catholic calendar evidence, the exact generator fingerprint and the
absence of a verified complete old-style daily lectionary.

The [3 October follow-up](tools/sources/old-style-readings-followup-research.json) verifies
current Catholic practice through [Our Lady of Fatima Russian Catholic parish](https://byzantinecatholicsf.org/)
and its published calendar feed: Christmas on 7 January, Theophany on 19 January and Pascha
on 12 April 2026, plus eight other fixed or movable feast dates. Its entries supply no
Scripture appointments or explicit 2027 feast records. Several apparent Julian leads instead
publish new-style fixed feasts. No complete annual Catholic old-style lectionary or usable
dated reading citations were found in this bounded search; the existing choice remains
feast-only pending an authorized Catholic ordo or parish reading table.

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

The Vetus Ordo investigation confirms that the existing importer uses the 1962 calendar's
actual lesson/Epistle/Gospel sections, not the modern Roman lectionary. A fresh primary-API
refresh now supplies every day of 2026 and 2027 (730 days). Its grouped Holy Week, Ember Day,
All Souls and Christmas appointments are retained. Missale Meum's
[source repository](https://github.com/mmolenda/missalemeum) documents the free v5 API and its
Divinum Officium inputs. This is the selected source's 1962 usage, not every older missal or
religious-order variation; citation data does not claim to provide the entire Mass proper.

`tools/import-stjames-calendar.py` preserves 386 consecutive bilingual rows with source PDF
pages and SHA-256, excluding personal anniversaries and contacts. It generates 196 feast
dates, including 60 source-aligned optional memorials, and 1,290 appointed citations. Exact
`sourceText` spans remain available alongside normalized punctuation. Single-chapter books
expand to chapter 1; whole Psalms retain their printed chapter without invented verse bounds.
Compact numbered books, source-specific abbreviations (including English Sg = Song of Songs),
cross-chapter references and inherited alternatives are checked before writing. Unknown or
unconsumed reference numbers fail regeneration. `sourceGroup` retains printed Mass/additional
reading/alternative wording; native readers show a heading when the group changes.

`tools/import-order-calendars.py` preserves hash-pinned annual source snapshots. The Conventual
edition has 365 calendar dates but only 75 dates with explicitly printed passages (299
citations). A bare ferial lectionary or Seraphic Missal reference supplies no passage numbers,
so these dates remain unavailable. Three unresolved printed references are quarantined:
31 May (`Dm`), 2 October (`Ez 23` on Guardian Angels) and 9 November (`1Cor 3,9c11`). The
Discalced Augustinian edition has 365 calendar dates and 364 reading dates (1,176 citations);
30 May's printed `Jgs 17.20–25` needs publisher clarification. Each missing appointment has
`readingSourceReview` on its feast row; the original remains in the source snapshot. Duplicate
punctuation, dotted chapter separators and reviewed typographical book aliases are normalized
without dropping source spans. No missing appointment borrows another calendar's readings.

## Translation policy

Existing calendars and St James have all seven translated feast display languages. Existing church
wording takes precedence; the remaining exact identities use credited editorial display labels
in `tools/feast-titles-*.json`. Those labels are not represented as official liturgical prayer
translations. Reviewed aliases preserve identity and do not transfer dates, ranks or readings.
The English source title remains available for future unsupported identities.

The order editions add six non-Hebrew editorial display languages. Hebrew titles are included
only for exact identities already present in credited church sources; otherwise
`sourceOnlyLanguages: ["he"]` records the gap and the reader uses its English heading.
The full printed heading is retained in `observances.sourceTitleByLanguage`. These are display
captions, not translated liturgical prayer texts. No Hebrew title is fabricated to fill a gap.

Hebrew Pentecost is **שבועות**, including its associated Sundays. Hebrew church sources are
recorded in `hebrew-feast-titles.json`, `hebrew-saint-titles.json` and the Roman Hebrew catalog.
Citation book labels retain [Evangelizo](https://dailygospel.org/), [St James Vicariate](https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_SJVLiturgicalCalendar202526.pdf)
and [Mechon Mamre](https://www.mechon-mamre.org/i/t/tmp3.htm) provenance. Prayer wording is
independent of these display labels. Shared `tl` and `he` normalize platform `fil` and `iw`.

## Hebrew saint and feast descriptions

Palm Sunday's Hebrew display name is **יום ראשון של הלולבים** (literally, “lulav Sunday”),
as supplied by the user on 3 October 2026. Shared title catalogs apply this wording to the
same named observance across calendars. Saint James retains its printed year suffix and
stores the original Hebrew caption in `sourceTitleByLanguage`; source snapshots and
liturgical prose remain literal.

The Saint James Vicariate's [Hebrew Feasts index](https://www.catholic.co.il/?cat=faith&m=Feasts&view=category&id=35&lang=he)
contains saint biographies, biblical figures, feast explanations and prayers. They are source
articles, not a calendar with precedence rules. `tools/scrape-catholic-hebrew-saints.py` follows
the index's published article and pagination links and saves a review catalogue at
`tools/sources/catholic-hebrew-saints.json`. Run it with:

```sh
uv run --script Shared/tools/scrape-catholic-hebrew-saints.py
uv run --script Shared/tools/test-catholic-hebrew-scraper.py
```

The source uses separate article IDs for some translations. A Hebrew query parameter or flag
does not always yield a Hebrew body, and the HTML language attribute is unreliable. The scraper
validates the actual article prose, excluding menus and sidebars, and follows a published Hebrew
flag link when necessary. Wrong-language, mixed-language or empty articles are quarantined
with diagnostic evidence. Genuine Hebrew articles with a short body or all their prose in the introduction
are retained with an explicit `contentShape`; a long Hebrew introduction cannot disguise
a present English body. Accepted text preserves the source's Unicode characters and paragraph order with
HTML whitespace normalized; source titles, date labels, credit candidates and HTML/text SHA-256
digests remain available. The exact page URL and initial request URL are recorded, including
published flag-link journeys.

Requests obey robots rules, use one connection with a minimum two-second delay, retry temporary
errors within bounds, and reuse successful HTML for one day in the system temporary directory.
The page, article, request and byte limits are explicit; hitting one marks the snapshot incomplete
and returns a failing exit status. The site keeps advertising a next arrow after its last
populated page; a recognized empty page reached from a proven populated parent ends the crawl.
An empty first page or unrecognized article cards still fail. `--limit 5 --output /tmp/hebrew-saints-sample.json` is a small
diagnostic crawl, not a complete catalogue. No native asset is changed by this scraper.

The 3 October 2026 crawl follows 276 unique article links across 14 populated index pages,
plus the verified empty terminal page. It retains 273 Hebrew articles: 265 with ordinary
bodies, seven introduction-only articles and one short body. Six attempts are quarantined:
three mixed-language source articles and three foreign-language flag targets. The mixed records
preserve their full original prose in `fullSourceProse`, including the Latin Stabat Mater in
article 4707 and French martyr names in article 17282, alongside separately retained Hebrew
passages. Article 19264 is a bilingual event announcement. These are source evidence rather
than approved Hebrew saint descriptions. The final run completed without errors or exhausted
budgets; all 296 responses came from the cache. All 21 offline extraction/completion checks pass.

Calendar/date/identity joins and the genre labels require review. Source credit candidates may
refer to a book translation rather than the article's author. The site retains its Saint James
Vicariate copyright notice; collecting source evidence does not approve full-prose redistribution.
Keep this catalogue separate from the reviewed Evangelizo excerpts until the Catholic.co.il
source contract, attribution, identity mapping and proposed excerpts have been reviewed.

### Description sources in the other interface languages

On 3 October 2026, actual Catholic saint/feast prose was verified in all seven non-Hebrew
interface languages. This is a source survey with bounded samples, not a complete multilingual
calendar import. Published language flags, metadata and dates alone are not evidence of prose
language, saint identity or the selected calendar's appointment.

| Language | Verified source examples | Collection and extraction notes |
| --- | --- | --- |
| English | [Thérèse — Saint James Vicariate](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=2494&lang=en); [Francis — Evangelizo AM](https://publication.evangelizo.ws/AM/saints/5e2fffae-2c62-47fd-b0c0-a335588ca2ec) | Catholic.co.il uses the same Feasts HTML structure; published pagination uses `en-GB`. Evangelizo returns structured `bio` HTML and `bio_source` credit; its Francis source credits Alban Butler's 1894 *Lives of the Saints*. |
| Arabic | [Francis — Evangelizo AR](https://publication.evangelizo.ws/AR/saints/1f2909c0-1e32-4b11-8a5d-049091add431) | Actual Arabic biography in `data.bio`. The existing reviewed catalogue already supplies three Arabic excerpts, with exact source identities. No Arabic flag was observed in the Catholic.co.il catalogue. |
| French | [Thérèse — Saint James Vicariate](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=3887&lang=fr); [Francis — Evangelizo FR](https://publication.evangelizo.ws/FR/saints/430eb289-6726-4c10-a883-98cc111fa2d1) | Actual French prose; Catholic.co.il heading `Fêtes`, pagination `fr-FR`. Evangelizo's Francis biography credits ©Evangelizo.org. |
| Italian | [Thérèse — Saint James Vicariate](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=11782&lang=it); [Francis — Evangelizo IT](https://publication.evangelizo.ws/IT/saints/759ac43b-bc06-4a8f-904d-ac84214628bc) | Actual Italian prose; Catholic.co.il heading `Feste`, pagination `it-IT`. Evangelizo preserves its underlying source references in `bio_source`. |
| Russian | [Vincent](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=7039&lang=ru), [Mother Teresa](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=3828&lang=ru), [Hildegard](https://www.catholic.co.il/?cat=faith&m=Feasts&view=article&id=7030&lang=ru) — Saint James Vicariate | All three have actual Russian introductions and body prose in the same article container. Vincent/Hildegard credit Sister Gabriela and Mother Teresa credits Lucia. Evangelizo publishes a Russian edition, but the sampled saint-date/name queries returned empty saint arrays; Russian readings do not establish biography availability. |
| Ukrainian | [Francis](https://rkc.org.ua/events/svyatyj-franczysk-assizkyj-obovyazkovyj-spomyn/), [Thérèse](https://rkc.org.ua/events/svyata-tereza-vid-dytyaty-isus-obovyazkovyj-spomyn/), [Vincent](https://rkc.org.ua/events/svyatyj-vikentij-de-pol-obovyazkovyj-spomyn/) — Roman Catholic Church in Ukraine | Official Latin-rite Catholic site with actual Ukrainian biographies and a liturgical calendar collection. Calendar event dates/ranks remain source usage, not overrides for the app's selected calendar. The sampled articles retain the site's copyright; no individual author was shown. |
| Filipino / Tagalog (`tl`) | [Lorenzo Ruiz](https://www.ourparishpriest.com/2026/09/saints-of-september-san-lorenzo-ruiz-at-mga-kasama-mga-martir/), [Thérèse](https://www.ourparishpriest.com/2026/09/saints-of-october-santa-teresita-ng-batang-si-hesus-st-therese-of-the-child-jesus/) — Our Parish Priest; [Guadalupe — Daughters of Saint Paul](https://paulines.ph/onlineradio/disyembre-12-2024-huwebes-paggunita-sa-mahal-na-birhen-ng-guadalupe/) | Our Parish Priest is a priest's publishing ministry with monthly saint indexes and explicit credit to Fr. RMarcos / *Isang Sulyap sa mga Santo* where stated. Extract the biography under `A. KUWENTO NG BUHAY`, preserving other quoted material separately. Paulines is an institutional supplementary source, but many saint-titled radio pages contain only Gospel reflections. |

The Hebrew catalogue already records published English, French, Italian and Russian flags
for all 273 accepted articles. Those links are discovery seeds; every destination still needs
its own identity and language verification. A multilingual Catholic.co.il collector can reuse
the article/category boundaries and the observed empty-page terminator, while adding explicit
regional language aliases, per-language index headings and language detection beyond script
counting for English/French/Italian. Preserve article credits and the Saint James Vicariate
copyright. The existing Hebrew collector remains Hebrew-only.

Editorial review matters before enriching app data: Russian Thérèse article 3889 prints the
malformed death year `19897`; Our Parish Priest's Padre Pio article gives both 1968 and 1969.
Retain these as source evidence and flag the affected passages rather than silently correcting
or approving an entire site's biographies. Tagalog publication dates differ from feast dates,
and the page metadata can incorrectly say `en-US`. Annual reposts require identity/content
deduplication. Lorenzo Ruiz's page also includes a song after the biography; do not treat its
lyrics as biography prose.

For provenance, the TV Maria archive provides [Thérèse](https://tvmaria.wordpress.com/2011/10/01/santa-teresita-ng-nino-jesus/),
[Raphael](https://tvmaria.wordpress.com/2011/09/29/san-rafael/) and
[Jean-François Régis](https://tvmaria.wordpress.com/2011/06/18/san-francisco-regis/) biographies
credited to J. C. Abriol, *Talambuhay ng mga Santo*, volume 2, third edition, Paulines Publishing
House, 2010. They are book reproductions rather than an independent open-text source.
Keep the original book credit and consult the publisher's
[rights information](https://paulines.ph/multimedia-publishing/press/rights-and-permissions/)
when selecting material for redistribution. Our Parish Priest's
[About page](https://www.ourparishpriest.com/about/) asks for attribution to its original material,
and its footer retains All Rights Reserved. Source discovery does not mark any of these
texts as approved app content.

### Collected descriptions and source review

The 3 October 2026 collection is saved under `Shared/tools/sources/`, separate from
native Today assets. `saint-source-review.json` reconciles each catalogue's published
scope, recomputes prose fingerprints, checks preserved HTML against extracted text,
and records source issues and representative editorial findings. Its snapshot hashes
prevent a review from silently referring to different catalogue bytes.
`saint-source-independent-audits.json` records the separate cache/prose audits;
`saint-source-retry-independent-audits.json` binds the two historical Tagalog
archive audits to their exact final snapshots. `evangelizo-language-availability.json`
preserves the live language registry and dated Russian biography probes;
`saint-source-editorial-review.json` retains representative manual checks with exact
source-text fingerprints. These are source-selection records, not certification of
every biographical assertion or approval to redistribute every collected article.

| Language/source | Captured scope | Result |
| --- | --- | --- |
| Hebrew — Saint James Vicariate | 276 published Feasts article IDs | 273 Hebrew candidates; six quarantined attempts, including three extra flag targets. The earlier Hebrew catalogue is preserved. |
| English — Saint James Vicariate | 274 published Feasts article IDs | 273 language-checked articles; one English-heading/Hebrew-body homily held. |
| French — Saint James Vicariate | 137 published Feasts article IDs | 134 language-checked articles; six quarantined attempts, including three extra flag targets. |
| Italian — Saint James Vicariate | 134 published Feasts article IDs | 131 language-checked articles; six quarantined attempts, including three extra flag targets. |
| Russian — Saint James Vicariate | 137 published Feasts article IDs | 134 language-checked articles; six quarantined attempts, including three extra flag targets. |
| Arabic — Evangelizo AR | All 366 valid month/day collections, including leap day | 221 source subjects captured; 219 actual Arabic bodies. Guardian Angels and Mar Charbel have no biography in this source. This is the union of dated AR collections, not a claim about undated subjects elsewhere in the provider's library. |
| Ukrainian — Roman Catholic Church in Ukraine | Published Saint of the Day archive and its actual Load More termination | 15 complete Ukrainian descriptions. The site's future-date cursor jumps and then returns an empty page; this proves only that reachable collection, not annual coverage. Its published sitemap returns a development-page soft error rather than an XML event index. |
| Ukrainian — CREDO supplement | All 18 published Saints/Feasts category pages | 515 literal publisher-truncated excerpts: 356 saint/feast candidates and 159 retained exclusions. Three representative full pages were also captured and audited. This is complete category-excerpt coverage, not a full-biography collection. |
| Filipino/Tagalog — Our Parish Priest | Published Saints & Sinners category advertises 402 posts over five API pages | Incomplete: the live robots request returned HTTP 403 with a browser challenge, and collection stopped. Previously collected first-page metadata covers 100 posts; two complete cached article bodies were extracted and reviewed, with one Thérèse candidate and one Padre Pio quarantine. The other 98 records are explicitly metadata-only. |
| Filipino/Tagalog — Our Parish Priest historical Blogger archive | All 1,982 entries across 80 pages of the homepage-published Atom feed; all 158 entries carrying its SAINT label | 96 complete source-marked biography candidates, six explicit introductory excerpts and 56 other or quarantined records. Three published full-page samples match the feed prose. This is an older archive with migration stubs and repeated editions, not a replacement for the blocked current website or an annual calendar. |
| Filipino/Tagalog — TV Maria historical archive | All 205 posts across 72 pages in the 11 monthly archives published on its homepage | 147 Tagalog saint/feast biography candidates; 57 retained exclusions and one genuinely untitled post held. Biography, reflection and printed book credits are separated while preserving full original prose. These dated posts are not 147 unique saints or a complete annual calendar. |

The Evangelizo retry used the official client's published
[`/languages` registry](https://publication.evangelizo.ws/languages), which returned
19 languages and 34 editions on 3 October 2026. It lists no Filipino/Tagalog or
Ukrainian edition. The published Russian edition does not advertise saint biography
features; actual saint queries for 1 and 4 October returned empty collections.
Russian reading availability therefore does not fill the biography gap. No guessed
Filipino or Ukrainian edition URLs were requested, and `/editions` was not treated as
a registry. Ukrainian coverage remains the 15 full RKC descriptions and CREDO's
category excerpts above. The two successful Tagalog archives preserve their own
historical scope and source credits; overlapping subjects remain separate.

The Vicariate's Feasts collection also contains homilies, biblical figures, prayers
and event announcements. Language-checked article counts are not counts of distinct
saints or ready-to-ship notification descriptions. Full mixed/foreign source text
remains in the new multilingual quarantines. The French Bonaventure page has an
Italian body, while some Marian and Angela Merici pages serve English fallback
prose. A published flag is evidence of a link, not proof of its target language.

The reviewed source errors remain literal: Russian Thérèse prints `19897` and a
malformed pontiff suffix; the checked [Holy See letter](https://www.vatican.va/content/john-paul-ii/en/apost_letters/1997/documents/hf_jp-ii_apl_19101997_divini-amoris.html)
gives her death on 30 September 1897 and is issued by John Paul II. Arabic John
Fisher prints an August execution date where [Vatican News](https://www.vaticannews.va/it/santo-del-giorno/06/22/santi-giovanni-fisher--vescovo-di-rochester--e-tommaso-more--mar.html)
gives 22 June 1535. The Tagalog Padre Pio biography mixes 1968 and 1969; the
[Holy See biography](https://www.vatican.va/news_services/liturgy/saints/ns_lit_doc_20020616_padre-pio_en.html)
gives 23 September 1968. These passages are held for editorial selection without
silently correcting the source. Literal credit candidates are reviewed as author,
translator or book-reference evidence; regex matches alone do not assign a role.
The CREDO Thérèse full-page sample also prints 1944 for mission patronage and 1999
for Doctor of the Church, conflicting with the Holy See's 1927 and 1997 dates;
the original sentences and primary links remain in its `sourceFactReview`.
Sixteen CREDO duplicate-title groups remain separate, and Latin/Byzantine rite
labels remain literal source evidence. CREDO's thirty-second robots delay was
honoured throughout the index and representative-page crawl; its written-consent
reuse notice is retained alongside its copyright and credit evidence.

The TV Maria Guadalupe article prints 8 December as its feast, conflicting with
[Vatican News' 12 December](https://www.vaticannews.va/en/church/news/2018-12/our-lady-of-guadaloupe-feast-day-mexico-americas.html).
Its Thérèse biography says her parents had ten children, while
[Benedict XVI gives nine](https://www.vatican.va/content/benedict-xvi/en/audiences/2011/documents/hf_ben-xvi_aud_20110406.html).
These statements stay literal and are held in the separate editorial review. The
Blogger retry also preserves the Padre Pio death-year conflict and a Lawrence of
Brindisi paragraph which incorrectly places all Franciscan branches in Francis'
lifetime: the [Capuchins' own history](https://www.ofmcap.org/en/the-history-of-the-capuchins/)
dates their origins to around 1525 and papal approval to 1528. Reflection sections,
migration links and book reproductions do not become
approved biography text merely because they carry a saint's name.

Collectors are self-contained uv scripts: `scrape-catholic-saints.py` for the four
additional Vicariate editions, `scrape-evangelizo-arabic-saints.py`,
`scrape-rkc-saints.py`, `scrape-credo-saints.py`, `scrape-tagalog-saints.py`,
`scrape-opp-blogger-saints.py` and `scrape-tvmaria-saints.py`.
Each keeps request/byte limits and source provenance. They obey verified robots
policies, pace requests, cache outside the repository, and do not bypass browser
challenges. The Arabic collector rejects HTML masquerading as robots, honours any
published longer crawl delay, and reconciles returned pagination totals and source
UUIDs. The Tagalog collector follows the site's advertised read-only WordPress API;
the historical Blogger collector follows the homepage-published feed and its actual
next links, avoiding the disallowed label-search route. The TV Maria collector follows
the homepage's monthly archives and their published pagination. Posting dates and
URL years never become feast dates.

Run `uv run --script Shared/tools/review-saint-source-catalogues.py` after refreshing
the source catalogues. It intentionally returns a failing status while any requested
collection remains incomplete, even when the captured-record integrity checks pass.
The current Tagalog blocker is preserved rather than hidden by a successful sample
review. The accompanying `test-*-saints.py`, Arabic scraper, Hebrew scraper and source
review checks exercise source boundaries, literal wording, language mismatches,
pagination completeness, metadata-only records and preserved error evidence.

The [first integration batch research](tools/sources/saint-integration-followup-research.json)
pins six small source-language passages in Hebrew, Russian, Ukrainian and Tagalog, with
31 inspected calendar/date/title/identity binding candidates. These remain proposed text
and bindings. The shared importer currently validates only Evangelizo URLs and UUIDs;
provider-aware reviewed provenance is needed, while the native description, link and credit
maps already support the intended output. Suppressed memorials and the 1962 calendar's
different dates must not receive a description through a guessed name/date join.

[RKC's publisher notice](https://rkc.org.ua/events/svyatyj-franczysk-assizkyj-obovyazkovyj-spomyn/)
permits complete or partial site-material use with a link to its homepage, giving a practical
route for its finite Ukrainian batch. [CREDO's reuse rules](https://credo.pro/rules) require
written consent and prohibit full reprints. Catholic.co.il and historical Tagalog candidates
still need selected-passage credit and distribution review. A short-excerpt editorial limit,
public feed access or future release approval does not itself supply a reuse license.

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
cover 2026–2027. The separate old-style Julian table supplies curated feast dates for the same
years, with no imported daily lectionary. The Maronite source currently stops at 31 October 2026 (304 reading days);
its named observances end at the last Sunday in that range. Syriac readings currently reach
8 December 2026. The Syriac feast refresh on 26 September 2026 now covers the same
1 January–8 December range: 261 dates with named observances. It combines the main liturgy
and every saint from both [English SYE](https://publication.evangelizo.ws/SYE/days/2026-10-01)
and [Arabic SYA](https://publication.evangelizo.ws/SYA/days/2026-10-01). The former importer
discarded saint arrays entirely. September 30 now includes Gregory the Illuminator and
Jerome of Stridon; October 1 includes St. Ananias, St. Abi, and Arabic-only Thérèse.
English saint names retain SYE's published spelling, taking precedence over alternate
main-liturgy headings and reviewed matching metadata. Arabic supplements the English list.
The generated `observances` components separate display names from reviewed identities,
preserving safe offline localization when the English source reuses a name for different saints.
Reviewed identities deduplicate equivalent names; differing identities, including the
English Simeon Stylites and Arabic Simeon Salos on July 21, remain separate in every
language. Arabic captions retain source class suffixes without assigning Roman ranks.
Untranslated saint names retain their published source name; locale-map presence does not
claim a reviewed translation. Source evidence and disputed identities are recorded in
`tools/syriac-observance-identities-first.json` and `tools/syriac-observance-identities-second.json`.
`test-syriac-observances.py` checks the reported examples, both editions, deduplication,
safe source failures and platform parity.

The official UGCC and Gregorian
Byzantine readings cover 2026; the 1962 table covers every day of 2026 and 2027. Modern Roman readings
currently span 31 July–5 December 2026. Missing entries are not synthesized.

Refresh `fetch-feasts.py` and `fetch-readings.py` periodically with `--sync`. Maronite's wrapper
`fetch-maronite.py` downloads each response once for both datasets and caches it outside the
repository. Refresh the official UGCC snapshot when a new year's calendar is published.
`fetch-torah-portions.py --sync` extends the Torah table. All native copies must remain
byte-identical to `Shared/data`; `test-today-data.py` checks the registered files and locales.
