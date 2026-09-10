# Offline Bible passages and daily readings

Prosary now has a Readings tab on iPhone, iPad and Android. It replaces the Categories
button; Search retains category browsing and combines the selected category with the text
query across local and community devotions. Mac and Windows show the reader in Today.
The date picker sits above the readings. Desktop references are always written out in full.
Expanding a reference loads selectable, numbered Bible text with the chosen edition and
source credit. The optional weekly Torah portion uses the same reader.

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
| Italian | Antonio Martini, 1769–1781 | [Parola Viva](https://parolaviva.art/opendata): public-domain Bible text; structured data by Giovanni Novelli under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). This source import covers the Pentateuch and New Testament, not its copyrighted meditations. |
| Ukrainian | Kulish, Nechui-Levytsky and Puluj, 1905 | [eBible `ukr1871`](https://ebible.org/ukr1871/copyright.htm), public-domain text. Uses the same pinned VPL payload as the existing Scripture importer. |
| Arabic | Old Jesuit translation, Beirut printing, 1897 | [Reviewed canonical transcription](content/arabic-jesuit-1897.json) relayed from the [historical scan](https://archive.org/details/AlKitabAlMoqadas). Only visually checked passages are included, with their printed verse boundaries and PDF page evidence. This is a limited public-domain selection, not a complete Arabic Bible or the modern Dar el-Machreq revision. |

The Hebrew reader uses **vocalized Scripture in both testaments**. The New Testament now
comes from the complete Delitzsch 1901 transcription at delitz.fr, replacing the previous
unpointed eBible `heb` text. Its published wording and vowel points move together; no points
are invented or transferred onto another transcription. All 260 chapters across 27 books
are hash-pinned. The importer extracts only numbered verse bodies, excluding headings,
navigation and verse-link labels. Prayer-pack excerpts retain their existing pointed source.

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

## Citation resolution and current limits

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

The helper [reading_versification.py](tools/reading_versification.py) resolves supported
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
Many Psalms and other numbering differences remain unavailable until their mappings are reviewed. Verse labels
in the rendered text follow the selected Bible edition.

Source checks found material limitations:

- The cached Crampon transcription has 124 empty entries across 58 chapters, including merged
  or shifted boundaries before the empty entry. The entire affected chapter is withheld;
  rejecting only the last empty verse would still display incorrect preceding text.
- Parola Viva's 1 Peter 5 currently contains only verses 11–14. The complete chapter is withheld.
- Some existing Syriac citations contain impossible or mixed-book references, such as
  `Galatians 6:21–31` and `Mark 14:32–42; 26:47–56`. They are not repaired by guessing.
- A Bible's inclusion of a book does not itself establish a valid mapping for its additions
  or alternative numbering. Unreviewed deuterocanonical mappings remain unavailable.

[readings-text-coverage.json](reports/readings-text-coverage.json) records available unique
citations per edition and every unavailable citation with its reason. Coverage counts are
not a claim of liturgical approval or an editorial proof of every source transcription.

The September 10 partial-verse update resolves 2,192 of 2,390 distinct references in at least
one edition, including 49 references newly available with full-verse notices.
Per-edition daily/Torah counts after the vocalized Hebrew update are: Douay–Rheims 2,104/63; Hebrew 2,121/71; Synodal 2,117/68;
Ang Dating Biblia 2,115/70; Crampon 2,063/69; Martini 1,863/58; Ukrainian 2,090/49.
The old Arabic Jesuit addition contains 220 transcribed verses in 64 reviewed passage units.
Its exact-unit policy supplies **9 distinct daily citations and no Torah passages** in the
current appointment tables. Other Arabic citations explicitly remain unavailable. Adding
more requires further source transcription and boundary review, not a wider runtime fallback.
The full-text JSON is about 36.8 MB before app-package compression; edition metadata is about 2.5 KB.

## Data and native contract

[reading-texts.json schema](schema/reading-texts.json) defines two files, copied byte-for-byte
from `Shared/data/` into each native app's data directory:

- `readings-editions.json`: version and edition metadata only; read to populate the picker.
- `readings-texts.json`: the same metadata and `passages["daily|<full>"][editionID]` or
  `passages["torah|<full>"][editionID]`, each an ordered list of `{chapter, verse, text}`.
  Its optional `wholeVersePassages` array contains exact passage keys needing the localized
  full-verse notice. Missing metadata means an empty array; the original citation is never
  changed to a normalized lookup key. Every platform exposes the flag on the loaded passage.

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
uv run --script Shared/tools/test-reading-versification.py
uv run --script Shared/tools/test-reading-appointment-reviews.py
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

## Release validation on September 10

The final vocalized Hebrew corpus passed all 26 shared validation checks, including 32
reading tests, schema validation, source provenance and byte-identical native data copies.
Apple passed 467 tests (465 XCTest and two Swift Testing tests). Android passed 364 unit
tests and three reader UI checks on an Android 16 tablet. Windows passed 17 portable checks;
native Windows CI remains pending. These results supersede the earlier snapshots below.
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
