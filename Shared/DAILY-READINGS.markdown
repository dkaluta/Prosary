# Offline Bible passages and daily readings

Prosary now has a Readings tab on iPhone, iPad and Android. It replaces the Categories
button; Search retains category browsing and combines the selected category with the text
query across local and community devotions. Mac and Windows show the reader in Today.
The date picker sits above the readings. Desktop references are always written out in full.
Home, Pray and Readings share one browsed civil date within each window. Choosing Today restores
local-day following in both; browsing never changes a prayer session or widget date.
Readings start collapsed on entry and date/calendar changes. The shared
`expandReadingsByDefault` setting (off by default) opens them automatically when enabled;
manual disclosure choices survive ordinary refreshes and edition changes.
`showTodayReadings` (on by default) controls readings in Pray and the native desktop Today
surface; the dedicated reader stays available independently. The customizable Home readings
card has its own visibility in `homeWidgetOrder`.
Each available passage shows selectable Bible text under a **Chapter** n
heading at each chapter transition. The word and number style follow the selected Bible,
independently of the interface: Hebrew gematria, Arabic digits, or the Aramaic reader's
selected Hebrew/Syriac script. The number is upright. Each passage also shows verse-only numbers,
the chosen edition and source credit. The optional weekly Torah portion uses the same reader.
Passages use the installed app Bible's reviewed source units when available. The
canonical `passageBooks` table supplies the actual source book; the already resolved
rows supply whole unit boundaries and exact source content. A download must agree
with those reviewed rows, including both scripts and source notes. Otherwise the
same reviewed bundled passage remains available; no runtime citation parser or
automatic edition switch is involved.
When a passage is unavailable in the selected edition, its Bible-edition menu lists editions
with complete text for that passage. Choosing one explicitly updates `readingsEditionId`;
there is no automatic language or edition substitution, and the chosen source credit remains visible.

This first corpus reuses Bible translations represented in Prosary's prayer packs. Arabic
uses the old Jesuit translation, replacing the previously unverified Dar el-Machreq excerpts.
It is an **incomplete collection of offline Bible passages**, not a licensed lectionary or
an assertion that every daily appointment has full text. Unavailable passages retain their
citation and show an explicit unavailable state. No text is translated, reconstructed,
substituted from another rite, or silently replaced with an English edition.

## Editions and provenance

The reproducible source inventory is [reading-text-sources.json](tools/reading-text-sources.json).
It pins each actual text payload with SHA-256, its source URL and its source rights statement.
For eBible ZIPs the hash covers the VPL text, since archive timestamps can change independently
of Scripture. The generated corpus is separate from existing `.prosaryprayer` packs.

| Interface language | Existing edition used for the reader | Source and boundary |
| --- | --- | --- |
| English | Douay–Rheims American Edition, 1899 | [eBible](https://ebible.org/engDRA/copyright.htm), public-domain text; Vulgate numbering. |
| Hebrew | Masoretic Tanakh and vocalized Franz Delitzsch New Testament, 12th edition (1901) | [Masoretic source](https://ebible.org/hbo/copyright.htm) and the [vocalized 1901 Delitzsch transcription](https://delitz.fr/12/), with the historical edition identified by its title page and [printed source](https://archive.org/details/hebrewnewtestam00deli). Public-domain Bible text. One selectable edition covers both testaments. |
| Russian | Synodal, 1876 | [eBible](https://ebible.org/russyn/copyright.htm), public-domain text; Synodal numbering. The inspected source has 66 books. |
| Filipino/Tagalog | Ang Dating Biblia / Ang Biblia, 1905 | Existing edition transcribed in scrollmapper `TagAngBiblia`; [CrossWire's source statement](https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=TagAngBiblia) identifies the Philippine Bible Society 1905 text as public domain. |
| French | Augustin Crampon, 1923 | Existing cached scrollmapper `FreCrampon` source; [CrossWire](https://www.crosswire.org/sword/modules/ModInfo.jsp?modName=FreCrampon) identifies the edition as public domain. Chapters with missing/merged source entries are withheld. |
| Italian | Antonio Martini, 1769–1781 | [Parola Viva](https://parolaviva.art/opendata): public-domain Bible text; structured data by Giovanni Novelli under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This source import covers the Pentateuch, all 150 published Psalms, and New Testament. The copyrighted meditations are excluded. |
| Ukrainian | Kulish, Nechui-Levytsky and Puluj, 1905 | [eBible `ukr1871`](https://ebible.org/ukr1871/copyright.htm), public-domain text. Uses the same pinned VPL payload as the existing Scripture importer. |
| Arabic | Old Jesuit translation, Beirut printing, 1897 | [Reviewed canonical transcription](content/arabic-jesuit-1897.json), [Psalm extension](content/arabic-jesuit-1897-readings.json), and [Gospel extension](content/arabic-jesuit-1897-gospel-readings.json), relayed from the [historical scan](https://archive.org/details/AlKitabAlMoqadas). Only visually checked passages are included, with their printed verse boundaries and PDF page evidence. This is a limited public-domain selection, not a complete Arabic Bible or the modern Dar el-Machreq revision. |
| Aramaic (selectable) | Peshitta, BFBS 1905 New Testament; Syriac Orthodox Patriarchate 2020 Old Testament | [peshitta.eu](https://peshitta.eu/about.html), credited as **Old Testament - publication of the Syriac Orthodox Patriarchate 2020**. Actual pointed website chapters are hash-pinned separately from the prior XML; its unchanged NT is Digital Syriac Corpus, CC BY 4.0. Both use Erez's established Hebrew-script projection. Native OT browsing and daily verse correspondences have separate gates; see the [2020 source review](content/PESHITTA-EU-2020-REVIEW.markdown). |
| Greek (selectable) | Brenton Septuagint, Old Testament only | [eBible `grcbrent`](https://ebible.org/Scriptures/details.php?id=grcbrent), public-domain Greek text. The exact VPL payload and its own Greek verse mapping are pinned. No Greek New Testament or replacement edition is supplied. |

The Greek option (`brenton-lxx`, language `el`) uses the same Brenton source already used
for Greek Old Testament excerpts. It preserves the source words, accents and integer verse
labels. Its source is not a generic Latin or English numbering system: for example,
Standard Psalm 103 maps to Greek Psalm 102, and Isaiah 9:2 maps to Greek 9:1.
[The Greek source adapter](tools/brenton_reading_source.py) withholds whole chapters containing
lettered labels or gaps because the native verse contract cannot represent those labels
without dropping or relabeling text. Combined Ezra/Nehemiah chapters, separate Greek additions,
Sirach 33, and uncertain reference boundaries also remain unavailable. The inspected import
provides 908 complete integer-label chapters from 43 source books. Current passage coverage
is reported separately for every registered source calendar in
[psalm-coverage.json](reports/psalm-coverage.json). These are coverage limits,
not permission to fill missing passages from the Greek New Testament or another Bible.

Nine Roman Psalm appointments additionally have exact reviewed Brenton excerpts in
[greek-daily-psalm-reviews.json](tools/greek-daily-psalm-reviews.json). The bounded
[resolver](tools/greek_daily_psalms.py) reads the unchanged pinned VPL and preserves its
original source units. Roman Psalm 13:6 requires both Greek 12:5 and 12:6. Roman 116:12–13,
17–18 uses Greek 115:3–4,8–9 without importing the unappointed repeated 4a. Roman 145:13cd
retains Greek 144:13a as a separate printed source witness; a 13ab-only appointment omits it.
The complete-chapter parser and general reference crosswalk keep their exclusions. These
daily excerpts certify only their exact citation, Roman context and source payload, and retain
whole-verse and partial-source notices where applicable. Every emitted primary and lettered
unit is independently compared with the pinned source by the full reader audit.

Four complete published Greek Psalm bodies also have independent whole-body reviews:
native 12 covers Standard 13:1–6; native 114 covers 116:1–9; native 115 covers 116:10–19;
and native 144 covers 145:1–21. New source calendars may select exact unions of those fully
requested bodies after their own numbering is established. The native 115 selection keeps
printed 4a and never invents a verse 5; native 144 retains 13a. Partial unreviewed cuts remain
unavailable through this route. The whole-body review preserves original row order and
published labels, pins both source payloads and published page witnesses, and requires
the wider-source notice for native 12's extra closing praise and native 144's 13a witness.
The ordinary Bible chapter importer and general partial-reference exclusions remain in place.

The Hebrew reader uses **vocalized Scripture in both testaments**. The New Testament now
comes from the complete Delitzsch 1901 transcription at delitz.fr, replacing the previous
unpointed eBible `heb` text. Its published wording and vowel points move together; no points
are invented or transferred onto another transcription. All 260 chapters across 27 books
are hash-pinned. The importer extracts only numbered verse bodies, excluding headings,
navigation and verse-link labels. Prayer-pack excerpts retain their existing pointed source.

The Hebrew edition also includes twelve fully transcribed and reviewed source works:
Tobit, Judith, Wisdom, Sirach, Baruch, 1–2 Maccabees, Letter of Jeremiah, Esther's additions,
the Song of the Three, Susanna, and Bel and the Dragon. Each book retains its actual
translator credit; the Kahana collection is not treated as a single translator's work.
Letter of Jeremiah uses Frenkel with reviewed public-domain Brenton boundaries.
[The source review](content/HEBREW-DEUTEROCANON-REVIEW.markdown) records the complete-book
gate, printed lacunae, separate witnesses, and explicitly approved editorial restorations.
Completed transcription does not remove gaps in the original print.

Daily excerpts use [separate endpoint reviews](tools/hebrew-daily-reading-reviews.json)
for each exact citation and calendar. They select indivisible source units, including
combined labels and any reviewed witnesses, with the selected edition's text unchanged.
Documented translation or recension variants do not become invented replacement wording;
unresolved boundaries or missing appointed source material remain unavailable.
The optional `passageSources` table in the [dataset contract](schema/reading-texts.json)
carries the actual book title, attribution, source link, partial-source notice and ordered
source blocks to all three native readers. This also preserves the distinction between a
calendar's Daniel/Esther citation and the separate source work supplying the Hebrew text.
An enlarged whole-unit envelope displays the existing full-verse notice.

[Delitzsch numbering](tools/DELITZSCH-NUMBERING.markdown) records six chapter differences
from SIL English. All 7,961 source verses are accounted for without omission or duplication;
split source verses retain their published labels, and merged verses require the complete
requested unit. [Source reviews](tools/delitzsch-source-reviews.json) record two precisely
scoped transcription corrections checked visually against the 1901 print: the corrupted
final word of Mark 14:72 and the duplicated vowel in 1 Corinthians 8:4. The original downloaded
pages stay unchanged. This review does not claim an editorial proof of the entire transcription.

For Tanakh, source vowels and cantillation are retained. On the four letters of יהוה only,
the builder removes U+05B0–U+05BC and U+05C7; it preserves the source cantillation, meteg and
surrounding word/prefix marks. For example, the source token `יְהוָ֥ה` becomes `יהו֥ה`.
No accents are invented. Native readers pass the generated verse text through unchanged.
This follows the user's explicit September 10 instruction to retain cantillation on the
Divine Name while removing its vocalization.

The app's first-party [LICENSE](../LICENSE) does not replace third-party rights. Edition
credits are shown in the reader; the canonical source manifest carries source and license
URLs. SIL versification data retains its [MIT license](tools/versification/LICENSE) and
[pinned provenance](tools/versification/sources.json).
The [STEP reference-only adaptation](tools/versification/step/README.markdown) credits STEP
Bible / Tyndale House Cambridge and retains its CC BY 4.0 source, license and checksums.
All three About screens carry that credit. The NABRE import retains only published book,
chapter and verse labels plus provenance; NABRE wording is neither stored nor shipped.

## Citation resolution and current limits

The October 6, 2026 update discovers every reading table through `calendars.json`,
including Pascha variants. Additional calendars use their own opaque dataset-scoped
passage keys, captured with the reading before an asynchronous lookup; they cannot
borrow the original six calendars' interpretation. St James and order-calendar
Psalm conventions have separate print-pinned evidence. Impossible printed spans and
unreviewed cross-edition endings retain explicit unavailable reasons.

The original Roman Psalm set now has all 103 appointments in nine editions and
102 in Peshitta; the latter source explicitly omits one appointed verse. English
and Greek clause overlaps are reviewed against the actual source words, not merely
chapter counts. Italian retains its published native row labels, and Arabic includes
the [independently checked 1897 expansion](content/ARABIC-PSALM-APPOINTMENTS-REVIEW.markdown).
The source note for one uncertain Arabic alif mark remains visible. This is not a
claim of complete Bible/translation coverage in the additional calendars; current
per-table counts and every gap are in [psalm-coverage.json](reports/psalm-coverage.json)
and [readings-text-coverage.json](reports/readings-text-coverage.json).

The older dated counts and limitations below describe their historical expansions.

[build-reading-texts.py](tools/build-reading-texts.py) parses the **original canonical English
full citation**, before localization, at build time. It preserves ordered ranges, omissions
and cross-chapter spans. Native apps do not parse Bible references or fetch Scripture at runtime.

Whole-verse source text cannot identify a lectionary's `a`/`b` cuts. These appointments now
open their enclosing **whole Bible verses**, retaining the original citation and showing
a localized note that full verses are displayed. Adjacent disjoint cuts such as `16a,16b`
display verse 16 once; ordered omissions and cross-chapter ranges are retained. Reviewed
Arabic passage units remain indivisible even when a citation asks for part of a verse.
Alternative readings in one unstructured reference, reversed or malformed spans, and
unreviewed split/merge mappings remain unavailable. A valid-looking chapter/verse
number is not enough: the seven imported Bible editions' source chapters must also match the
expected numbered inventory and contain no empty verse entries. Actual overlapping ranges
are rejected rather than repeating text; only adjacent disjoint subverse cuts are combined.

The old Arabic Jesuit selection uses a separate, explicitly reviewed source type. Its
canonical JSON is hash-pinned and each verse records the inspected PDF page(s). A reading
must consist of complete reviewed passage units, in order, with every word available;
the builder may concatenate whole units but never slice one. Numeric mappings alone do not
establish the old printing's textual boundaries: Luke 1:32–33, for example, divides the
promise of the kingdom differently. A citation asking only for part of a reviewed unit
therefore stays unavailable even when some requested verse numbers exist. This bounded
policy does not relax whole-chapter checks for the other editions and never fills missing
Arabic verses from another translation or unreviewed OCR.

The existing helper [reading_versification.py](tools/reading_versification.py) resolves supported
one-to-one references through the pinned SIL Original, English, Vulgate and Russian Orthodox
tables. It rejects ambiguous mapping endpoints. Torah references use Hebcal's Hebrew numbering.
New Testament appointments exclusive to the 1962 calendar use Vulgate numbering. The other
daily tables lack an explicit versification field: English book labels do not establish
English verse numbering, including for the New Testament. Their text is emitted only where
all four numbering traditions agree on the resulting passage, unless an exact appointment
has a source review in [reading-appointment-reviews.json](tools/reading-appointment-reviews.json).
That manifest binds each reviewed citation and calendar context to inspected source hashes
and explicit edition verse sequences. The September 10 Roman Psalm 139 review includes
Douay–Rheims Psalm 138:1–4, 13–14, 23–24: its verse 4 contains the end of the appointed
Hebrew-numbered verse 3, so a simple chapter-number conversion would lose text. The other
five reviewed editions retain their own numbering and seven complete source verses.
The review does not establish general numbering rules for other Psalm appointments.

The reusable [NABRE mapper](tools/reading_nabre_mapping.py) adds a separate path for
appointments whose **source numbering has been established**. Its input inventory must
cover all 73 books, including the lettered Esther additions and numbered Psalm titles.
It converts published source markers into the STEP Standard correspondence graph, preserving
split/merged units, order changes and documented variable clause boundaries. Ambiguous
relationships and predicates lacking evidence remain unavailable. The complete snapshot also
pins 61 numeric word counts for STEP's comparative-length predicates; all 35,519 published
labels have a supported whole-verse correspondence. The [metadata documentation](tools/versification/nabre/README.markdown)
records the numeric provenance, exceptional boundary reviews, and reproducible browser extraction.
The target mapper returns complete source verses and flags any larger verse envelope.
It never transfers the NABRE words or infers text from a verse count.

[reading-source-numbering-reviews.json](tools/reading-source-numbering-reviews.json) records
exact citation/calendar reviews with original publication references and source hashes.
Unlike the older edition-boundary review, it supplies no hand-written target verse list:
the general mapper performs the conversion. Every calendar sharing a raw citation key must
be covered by the review. A Roman review cannot reinterpret a Syriac or Byzantine occurrence
of that same key. In particular, Evangelizo's Hebrew publication or an English display label
does not establish NABRE numbering for the entire dataset.

The September 13, 2026 original Evangelizo HE references were checked against the same-date
USCCB appointment. The resulting bounded reviews resolve Sirach 27:30; 28:1–7 to the pinned
Douay–Rheims 27:33; 28:1–9, and the specified Psalm 103 ranges to Douay–Rheims Psalm 102.
The existing September 10 Psalm 139 edition-boundary review retains precedence unchanged.
Other appointments continue using the existing agreement policy until their source numbering
is established; a complete Bible mapping inventory does not itself prove a calendar's convention.

The September 16 Psalm review establishes **all 103 distinct currently bundled Psalm appointments**,
each confined to its exact Roman citation. Their original Evangelizo HE publications contain
642 embedded chapter/verse markers. Comparing those excerpts to the pinned eBible Masoretic
source at the same labels gives 639 exact consonantal matches, two nonempty partial-verse
substrings, and one documented spelling variant in Psalm 117:1. The manifest retains source
URLs, payload checksums and reference evidence; it imports none of Evangelizo's wording.
These reviews use `hebrew-psalms`, separately from NABRE's local boundaries in Psalms 2, 66,
72, 109 and 146. The pinned SIL Hebrew-to-Standard relations feed the existing per-edition
mapper, including numbered titles, merged verses and the selected edition's chapter numbers.
Titles joined to a body verse remain in that edition's existing full verse when present.
The previous September 10 and 13 reviews retain their precedence.

All 103 appointments are available in Douay–Rheims, Masoretic Hebrew, Synodal, Ang Dating Biblia,
Crampon and Kulish. Arabic now supplies a reviewed selection of Psalm appointments. Peshitta
Psalms remain outside its reviewed numbering profile, and the current Martini import omits
them. Parola Viva publishes Martini Psalms, but its chapter payloads use internal
splits/merges that require a separate source-boundary review: Psalm 50:1–2 splits traditional
verse 3, and Psalm 3:6 crosses traditional verses 7–8. Even matching chapter totals do not
prove identical boundaries. Those texts are not relabeled by a guessed offset or substituted
from another edition; the reader offers an explicit available-edition choice.

The complete mapping audit also identified two exact 2 Corinthians appointments whose
closing verse uses the 13-verse chapter ending: UGCC and Gregorian UGCC `13:3–13`, and
Maronite `13:5–13`. The original calendars, Byzantine lection 197 published by the Greek
Catholic Eparchy of Mukachevo, and the original Evangelizo MAE verse markers establish the
final Trinitarian blessing. Pinned STEP rows 27448–27451 map that closing unit to Standard
verse 14. Bounded edition reviews therefore retain the blessing at verse 13 in six editions
and at verse 14 in Ang Dating Biblia and Peshitta. They also restore the complete passages
in Crampon and Kulish. Exact target labels are validated against their reviewed inventories
and are never converted a second time as if they were English reference labels.

The June 28, 2026 Missale Meum Latin and English Epistle confirms that the 1962 appointment
`1 Peter 3:8–15` ends within verse 15 after sanctifying Christ in the heart. Its existing
full Bible verses 8–15 remain unchanged, with the full-verse notice now shown. Verse 16 is
not appended merely because a conservative alignment graph groups the neighboring verses.
The remaining flagged endpoints were checked against their original calendar publications.
Three Mark 3 appointments now retain the house-arrival clause in the selected edition's
complete verses, and the Syriac-calendar Luke 7:11–18 includes full verse 19 to preserve
John's summons of two disciples. Shared Mark keys use a reviewed envelope covering both
verified calendar cuts, with a notice. Acts 3, Ephesians 5 and Mark 16 retain their verse
sequences with notices for the verified partial boundaries. Ephesians 1, John 7 and
Revelation 12 retain their existing selections. The [13-key boundary review](reports/readings-boundary-review-2026-09-16.markdown)
records each disposition and its primary-source checksums; none of those flags is unresolved.

Exact per-edition envelopes may declare `sourceSystem: reviewed` without assigning a generic
tradition to their calendar. All reviews retain their citation/calendar/source-pin scope.
If a known reviewed citation acquires an unreviewed calendar context, generation refuses it
before any generic fallback. See the dated [mapping verification](reports/readings-mapping-verification.markdown)
and reusable source and numerical audits.

The [edition mapper](tools/reading_edition_mapping.py) now supplies independently reviewed
profiles for all ten bundled editions, using the same STEP Standard hub. Its
[numeric inventories](tools/versification/editions/README.markdown) contain source pins,
chapter/verse identifiers, measured word counts and hashes, with no Scripture wording.
The reusable mapper opens only this metadata; the passage builder separately verifies the
actual imported corpus against its digest before selecting any existing source rows.
Profiles account for Psalm headings, moved verses, split/merged endings, Delitzsch's own
numbering and local exceptions where word-count comparisons across languages select the
wrong rule. Generic SIL maxima remain completeness guards unless a chapter has an explicit
review. Arabic retains its 488 indivisible reviewed units rather than using chapter predicates
on sparse data. One verified converter is cached per assembled edition during generation.

The September 13 Sirach reading is now also available in Crampon at 27:30; 28:1–7. The day's
Psalm carries the existing whole-verse notice because some editions retain a heading joined
to verse 1. Other previously emitted verse rows are unchanged by this extension. Additional
verse envelopes use that same notice; missing books, omitted titles and unreviewed mappings
remain unavailable. Rendered verse labels continue to follow the selected edition.

Source checks found material limitations:

- The cached Crampon transcription has 124 empty entries across 58 chapters, including merged
  or shifted boundaries before the empty entry. The entire affected chapter is withheld;
  rejecting only the last empty verse would still display incorrect preceding text.
- Parola Viva's 1 Peter 5 contains only verses 11–14; John 11 and 1 Thessalonians 4 omit
  their final sentences. The edition mapper withholds all three chapters. Its pinned source
  includes the Pentateuch and New Testament only.
- Kulish's Leviticus 21 and Psalm 148 omit material at the end. Those chapters are withheld
  by the edition mapper. Synodal's five supplementary Joshua/Proverbs verses have no ordinary
  Standard counterpart and are not relabeled as another verse.
- Some existing Syriac citations contain impossible or mixed-book references, such as
  `Galatians 6:21–31` and `Mark 14:32–42; 26:47–56`. They are not repaired by guessing.
- A Bible's inclusion of a book does not itself establish a valid mapping for its additions
  or alternative numbering. Unreviewed deuterocanonical mappings remain unavailable.

[readings-text-coverage.json](reports/readings-text-coverage.json) records available unique
citations per edition and every unavailable citation with its reason. Coverage counts are
not a claim of liturgical approval or an editorial proof of every source transcription.

The September 10 partial-verse update resolves 2,192 of 2,390 distinct references in at least
one edition, including 49 references newly available with full-verse notices.
After the September 16 Psalm review, 2,291 of 2,390 references have text in at least one edition.
Current per-edition daily/Torah counts are: Douay–Rheims 2,203/63; Hebrew 2,219/71; Synodal 2,215/68;
Ang Dating Biblia 2,213/70; Crampon 2,164/69; Martini 1,863/58; Ukrainian 2,190/49.
The old Arabic Jesuit selection contains 665 transcribed verses in 488 reviewed passage units.
Its exact-unit policy supplies **133 distinct daily citations and no Torah passages** in the
current appointment tables. Other Arabic citations explicitly remain unavailable. Adding
more requires further source transcription and boundary review, not a wider runtime fallback.
The 19 September extension adds the complete Magnificat, Luke 1:46–55, and seven bounded
Isaiah reading units checked against PDF pages 293–299 and 432. Their exact correspondence
to STEP English Standard is documented in the
[Arabic passage-boundary review](content/ARABIC-REFERENCE-REVIEW.markdown), including
Isaiah 9:2's distinction from Masoretic numbering and the whole Isaiah 11:2–3 envelope.
The Magnificat is the one newly available daily citation; all previously emitted reading rows remain unchanged.
The subsequent complete visual audit corrected ten verses in that prayer transcription;
its current SHA-256 is
`dbb7c4736218f730506d5eedb05708983420712c02076e008b16839665d9f39c`.
The September 27 reader extension adds 222 Psalm verses and the 204 verses of Luke 6, 10,
11 and 12, bringing 123 more daily citations into Arabic. The
[Psalm review](content/ARABIC-JESUIT-1897-PSALMS-REVIEW.markdown) and
[Gospel review](content/ARABIC-GOSPEL-READINGS-REVIEW.markdown) record printed numbering
and indivisible boundaries. Their separate source pins
and word hashes live in [reference-only extension metadata](tools/arabic-reading-extensions.json).
The [complete Arabic visual audit](content/ARABIC-FULL-AUDIT.markdown) subsequently checked
all 665 verses against the 1897 scan and corrected 26 transcribed verses: ten in the
original prayer corpus, two in Psalms and fourteen in the Gospel extension. Scripture in
affected prayer packs, native fallbacks, Terminal content and reader assets is regenerated
from those corrected sources. Its per-verse ledger pins the exact reviewed wording;
the earlier extension's unchanged-wording claim does not apply to these corrections.

The Peshitta addition now supplies 1,994 daily citations and 23 Torah passages.
Its pinned inventory contains 7,912 NT verse labels and 25,095 structurally valid supplied
OT entries. Every one of the 3,827 previously emitted OT coordinates received a semantic
review. The reader now uses an explicit coordinate gate, 41 indivisible compound units,
and 23 exact source-pinned editorial exclusions instead of inferring matching boundaries
from chapter lengths. Eight unresolved or print-confirmed defective coordinates are
withheld; six initially suspicious coordinates are retained as print-supported variants.
An automated consonantal collation covers all 25,095 imported OT entries, with every
reported disagreement triaged. This is not a claim of printed verification of every verse.
See the [completed OT review](content/PESHITTA-OT-READER-REVIEW.markdown) for scope,
primary witnesses and individual dispositions. Luke 10/11, Philippians 1, 3 John and
Revelation 12/13 retain the existing structural/boundary exclusions.

## Downloadable Bible library

Readings also contains a Bible mode with source-native book, chapter and verse navigation.
It shares the selected edition with Daily Readings, while keeping its position independent
of the prayer date. Only the small catalog is bundled; each edition is an explicit,
individually removable offline download. Book titles follow the edition language and
paired script. Partial chapters retain their exact verse labels and show a visible notice.

The separate [Bible library contract](BIBLE-VIEWER.markdown) and
[schema](schema/bible-library.json) define immutable ZIP archives, source credits,
content hashes, bounds and atomic installation. Generate them with
`uv run --script Shared/tools/build-bible-library.py --sync`; verify with
`uv run --script Shared/tools/test-bible-library.py` and the generator's `--check` mode.
Archives live once in `Shared/dist/bibles`, and only `bible-catalog.json` is copied into
native resources. [Coverage](reports/bible-library-coverage.json) reports actual inventory;
a Bible viewer does not imply that every offered edition supplies the complete Catholic
canon. Known damaged chapters and unreviewed Syriac material are withheld, and the
reviewed Arabic collection remains partial. No missing Scripture is filled by inference.

## Data and native contract

[reading-texts.json schema](schema/reading-texts.json) defines two files, copied byte-for-byte
from `Shared/data/` into each native app's data directory:

- `readings-editions.json`: version and edition metadata only; read to populate the picker.
- `readings-texts.json`: the same metadata and `passages["daily|<full>"][editionID]` or
  `passages["torah|<full>"][editionID]`, each an ordered list of `{chapter, verse, text}`.
  Its optional `wholeVersePassages` array contains exact passage keys needing the localized
  full-verse notice, including wider envelopes from reviewed numbering correspondences.
  If any edition needs the notice, its raw key is listed for all editions. Missing metadata
  means an empty array; the original citation is never
  changed to a normalized lookup key. Every platform exposes the flag on the loaded passage.

Paired-script editions additionally declare `textScript` and `transliteratedTextScript`;
every verse then requires nonempty `transliteratedText`. Peshitta uses primary Hebrew-square
`Hebr` and alternate source Syriac `Syrc`, matching the existing Aramaic prayer contract.
An incomplete pair makes the entire passage unavailable. Native readers initialize from
`aramaicDefaultScript` and offer the same Hebrew/Syriac choice, rendering the selected
verse field with its actual script, typeface and RTL direction. They never convert Scripture
or substitute the other field when the selected script is missing.

The shared setting is `readingsEditionId`. Empty follows the interface language, normalizing
`iw` to `he` and `fil` to `tl`. An explicit unknown/removed edition or an interface language
with no edition resolves to unavailable. No automatic edition/language fallback occurs.
Text direction follows the selected edition. Dates, selected calendar and edition are part
of the reader state; changing them invalidates the expanded text. The corpus loads lazily
on the first expansion, away from the UI thread. Widgets keep their small Today citation
resources and do not embed the full-text corpus.

Regeneration and verification:

```sh
uv run --script Shared/tools/build-reading-texts.py --fetch --sync
uv run --script Shared/tools/build-reading-texts.py --check --sync
uv run --script Shared/tools/test-reading-texts.py
uv run --script Shared/tools/test-peshitta-readings.py
uv run --script Shared/tools/test-greek-readings.py
uv run --script Shared/tools/test-greek-daily-psalms.py
uv run --script Shared/tools/test-reading-versification.py
uv run --script Shared/tools/test-reading-appointment-reviews.py
uv run --script Shared/tools/test-reading-source-numbering.py
uv run --script Shared/tools/test-reading-nabre-mapping.py
uv run --script Shared/tools/test-reading-step-mapping.py
uv run --script Shared/tools/test-reading-psalm-mapping.py
uv run --script Shared/tools/test-reading-standard-bridge.py
uv run --script Shared/tools/build-edition-mappings.py --check
uv run --script Shared/tools/test-reading-edition-mapping.py
uv run --script Shared/tools/test-reading-edition-reviews-hebrew.py
uv run --script Shared/tools/test-reading-edition-reviews-western.py
uv run --script Shared/tools/test-reading-edition-reviews-arabic.py
uv run --script Shared/tools/test-nabre-versification.py
uv run --script Shared/tools/test-nabre-versification-fetch.py
uv run --script Shared/tools/test-delitzsch-source.py
uv run --script Shared/tools/test-delitzsch-numbering.py
```

`--fetch` only downloads missing pinned remote source payloads. The Arabic transcription is
read directly from canonical `Shared/content/` and is never downloaded or created by this
option. A changed source hash stops the build
for review. It never silently accepts new upstream text. The coverage report remains canonical
build documentation and is not copied into native apps.
After refreshing feast/reading or Torah appointment tables, rerun the passage builder and
its coverage checks so newly added dates receive available text from the pinned editions.
The citation localizer selects tables from the calendar registry, so its `readings-*` naming
does not accidentally treat edition metadata or Bible text as a calendar dataset.

Reference inventories are regenerated separately from Scripture. Use
`fetch-nabre-versification.py` for the official NABRE chapter markers and
`fetch-step-mapping.py --check` to verify the pinned STEP rule extraction. The passage build
fails if the NABRE inventory is incomplete; it cannot publish an unfinished scrape as a
complete numbering source. Adding an appointment review requires evidence for the exact
source citation and every affected calendar context, without copying lectionary wording.
Run `build-edition-mappings.py` before rebuilding passages whenever a pinned edition source,
importer or reviewed mapping changes. Its `--check` mode reconstructs the numeric inventory
from existing checked source caches and verifies deterministic output. Mapping metadata stays
in the shared tools directory; only pre-resolved passages are copied to native applications.

## Release validation on September 10

The final vocalized Hebrew corpus passed all 26 shared validation checks, including 32
reading tests, schema validation, source provenance and byte-identical native data copies.
Apple passed 467 tests (465 XCTest and two Swift Testing tests). Android passed 364 unit
tests and three reader UI checks on an Android 16 tablet. Windows passed 17 portable checks
and all 455 native CI tests. All six GitHub CI jobs passed for release code commit `24cc973`.
These results supersede the earlier snapshots below.
The signed Mac 0.12.0 app was also verified live: all three September 10 readings open in
the Hebrew 1901 edition, with readable pointed first-reading and Gospel text and retained
Masoretic accents in the Psalm. The generic iOS Simulator compatibility build also passed.

## Earlier partial-verse verification on September 10

This snapshot precedes the complete vocalized Delitzsch corpus and the release validation above.

All 29 passage-builder/corpus tests, 11 versification tests and five bounded appointment-review
tests pass. Regeneration is byte-identical across all three native data directories, and the
localized content/provenance checks pass. Eight focused Mac reader tests pass; the iOS
Simulator compatibility build and the local signed Mac build succeed. The rebuilt Mac app
was reopened and all three September 10 Roman readings were expanded: the first reading and
Psalm show complete numbered text and the full-verse notice, while the Gospel has no notice.
The original citations and source credits remain visible; the final Mac layout was inspected.
Android passes all 362 unit tests plus two reader UI checks on an Android 16 fold emulator.
Windows passes C# semantic compilation and 16 portable fixture/bundled reader checks;
native WinUI execution was not performed on this Mac.

## Earlier Arabic conversion verification on September 10

This snapshot precedes the partial-verse and vocalized Delitzsch updates.

The reviewed Arabic source is pinned to SHA-256
`2c9bdbfb9a132fc2f79b5a7482f5e89958f4b37c02aa1a7df785b0b8d1f118c4`.
All 23 passage-builder/corpus tests pass, including reviewed-unit boundaries, unavailable
subsets, missing source words, altered source hashes, and the complete Arabic Annunciation.
Regeneration with `--check --sync` is byte-for-byte reproducible across iOS/Mac, Android and
Windows. The new edition follows the existing metadata-driven native reader contract.
All 13 Arabic import/source/pack tests pass, including preservation of non-Scripture fields
and all four copies of each affected pack. The shared localization, content, coverage,
line-break and asset-deduplication checks also pass; Arabic source checks are included in CI.
Six focused Mac reader tests pass against the rebuilt app's bundled data using the local
unsigned test configuration. Android's full `testDebugUnitTest` suite passes, including
the new bundled Arabic reader checks. All eight localized Scripture credits agree across
the native ports. Windows tests were updated for the eighth edition, but native Windows
execution was not performed on this Mac.

## Earlier seven-edition verification on September 10

The native build and emulator results below precede the old Arabic edition conversion;
they do not claim a rebuilt or interactively tested eight-edition app package.

- Shared: 14 passage-builder/corpus tests and 11 versification tests pass. Regeneration is
  byte-for-byte reproducible; native copies match. The existing citation, Today, localization
  and artwork-deduplication checks also pass. The two new offline test scripts are included
  in CI.
- Apple: iOS and Mac builds package the final corpus; nine focused Mac tests cover actual
  bundled readings, category filtering and saved-prayer App Intents. Both widget extensions
  contain only their 16 Today JSON resources. Physical Siri/Shortcuts invocation and widget
  gallery installation remain unverified.
- Android: 358 unit tests and app/test builds pass. Emulator checks cover navigation/date
  restoration, categories combined with queries, lazy loading, all seven real editions,
  Hebrew source marks and attribution. The packaged corpus matches the canonical checksum.
  Screenshots were inspected for the English Readings screen and the production Hebrew
  Torah passage component; the latter was rendered in an isolated test host.
  Direct stream decoding avoids a temporary full-file string. In one emulator comparison,
  immediate post-decode Java heap fell from 104.75 to 57.49 MiB; the production reader retained
  about 50 MiB after garbage collection and after date navigation. These are sampled Java
  heap measurements, not peak process memory or a physical-device performance guarantee.
- Windows: application/test C# semantically compiles against the cached WinUI references;
  18 earlier portable model/reader/search tests and three real-corpus checks pass. Native
  WinUI XAML compilation, UI interaction and the Windows date integration test require
  Windows and were not executed on this Mac.

## Lessons from Erez's MikraVeParasha implementation

The supplied repository was inspected read-only as reference code. Useful patterns carried
into the native implementation are independent passage disclosures, lazy loading, selectable
numbered text, and one renderer shared by daily and Torah readings. In particular, it keeps
an original citation separately from its localized display label; Prosary's pre-resolved
keys preserve that boundary too.

The reference's eager 66-book imports, runtime WebView extraction, hardcoded RTL and permissive
citation handling were not adopted. Its lookup normalizes `Psalms` to `Psalm` while its data
map uses `Psalms`; its subverse digit extraction can expand `16a` into an entire verse or
repeat a verse for `16a,16b`. These findings informed strict parsing and source validation.
Its Salkinson/Ginsburg NT is a different translation from the user-selected Delitzsch source.
Neither another app's first-party license nor a successful numeric lookup establishes Bible
rights or correct versification.

## Exact Mass readings remain separate

Bible verses do not reproduce every authorized lectionary opening, omitted phrase, alternative,
psalm response or liturgical adaptation. Exact Mass text needs records for the rite, territory,
language, edition, day and authorized options, with the publisher's display/offline rights.
The [USCCB Bible questions](https://www.usccb.org/faq) and
[permissions policy](https://www.usccb.org/offices/new-american-bible/permissions) explain the
separate lectionary treatment for United States English use. No publisher permission request
has been sent or license obtained in this work. Existing Bible passage availability does not
claim that exact-text work is complete.
