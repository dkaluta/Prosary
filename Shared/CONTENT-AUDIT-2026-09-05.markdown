# Prayer content and language audit — 5 September 2026

Updated 6 September 2026. The automated audit covers every canonical content JSON file and all
10 shipped prayer packs; the regenerated [coverage report](PRAYER-LANGUAGE-COVERAGE.markdown)
records current file counts and exact missing keys for all eleven public prayer languages.
It is **not an exhaustive, word-for-word comparison of every prayer with an authoritative
printed edition**, and it is not a theological or native-speaker certification. Counts of JSON
prayer values include headings, responses, and repeated texts; they are not counts of unique
prayers.

## Scripture editions currently used

| Language | Edition / textual source |
| --- | --- |
| Latin | Clementine Vulgate |
| English | Douay–Rheims, Challoner revision (1899) |
| Hebrew | Franz Delitzsch's New Testament, transcribed at [Kirjasilta](https://www.kirjasilta.net/ha-berit/); Old Testament passages follow the Masoretic text. A specific critical edition of the Hebrew Old Testament has not been established by this pass. |
| Arabic | Jesuit Arabic Bible, Dar el-Machreq; not Smith–Van Dyke |
| Russian | Synodal Bible (1876) |
| Tagalog | Ang Dating Biblia (1905) |
| French | Augustin Crampon (1923), imported from the scrollmapper Bible dataset |
| Italian | Antonio Martini (1769–1781), imported from ParolaViva; its structured data is credited separately under CC BY 4.0 |
| Aramaic / Syriac | Peshitta: ETCBC `syrnt` for the New Testament and ETCBC `peshitta` for the Old Testament. The Hebrew-square-script rendering is a deterministic transcription using Erez's converter, not a new Bible translation. |
| Greek | Robinson–Pierpont Byzantine Majority New Testament; Brenton Greek Septuagint for Old Testament passages. The app does not use the Patriarchal 1904 New Testament. |
| Spanish | Félix Torres Amat (1836), from the transcribed Wikisource edition; coverage remains partial. |

The two Hebrew prayer traditions are authored prayer-text overlays, not different Bible
translations. They share a single public language label, **עברית**, with a separate prayer
tradition choice. Existing `he-x-gamliel` data remains readable.

Today displays lectionary **citations**, not full Bible passages. Its calendar/readings sources
include Evangelizo, Missale Meum and Royal Doors, depending on the selected calendar; choosing
an interface language does not select a Bible edition. Today now follows that interface
language, independent of the prayer language.

## Checks and corrections in this pass

- Every canonical prayer/mystery value is checked for blank text, suspicious truncation,
  website contamination, and applicable drift from the native common-prayer tables.
- Bundle validation verifies every declared language and its resolved step keys. Generated
  packs are copied to all three ports and checked for byte identity and duplicate artwork.
- The scripture importer tests verify supported source conversions and verse-number mappings;
  these do not establish that every upstream transcription is error-free.
- Four Hebrew Scripture values contained a website's “next chapter” footer: Stations of the
  Cross, traditional station 14 and scriptural stations 4 and 14; Seven Sorrows, the burial
  meditation. Only the navigation text was removed. The audit now catches the pointed and
  unpointed form of that footer.
- Aramaic Rosary and Basic Prayer title regressions verify all five main Aramaic headings with
  English-first fallback preferences. The canonical headings were already present; current
  engine and interface tests verify they remain Aramaic. This does not establish which older
  installed build first showed English titles.
- Erez's supplied departed response is preserved exactly in the Rosary. The Pope, bishop and
  departed intentions have independent controls, each with its own introduction followed by
  Our Father, Hail Mary and Glory Be. The departed group also has the concluding V/R.
- The new Litany of Loreto uses exactly one context-specific final collect: `Concede nos
  famulos` when opened directly, `Deus cuius Unigenitus` after the Rosary. Its separate
  [source record](content/litanyOfLoreto/SOURCES.markdown) distinguishes published wording,
  faithful source omissions and the explicitly credited Greek and Tagalog standalone translations.

## Remaining editorial work

The 6 September follow-up distinguishes real selected-language text from a successful fallback.
The format validator's acceptance of a known `PrayerKey` never proved that the requested
language supplied its wording. The new `audit-prayer-coverage.py` inventories native tables,
shared overrides, each devotion's optional variants, and each mystery field separately. CI
also checks that newly completed language/devotion pairs have no prayer or Scripture fallback.

The follow-up adds sourced Spanish common prayers, Angelus and Divine Mercy texts, French and
Italian O Antiphons, and French/Italian/Spanish/Greek Trisagion texts. Eight Greek common prayers
come from published modern Catholic texts and an 1823 Greek–Latin Little Office; their exact
sources and the remaining Greek St Michael lead are recorded in
[the source research](PRAYER-SOURCE-RESEARCH-2026-09-06.json). Greek and Spanish mystery names
and fruits are credited as Prosary metadata translations, separate from their imported Bible text.
Spanish and Greek Franciscan Crown flows are complete. French and Italian Stations now have
the opening and all fourteen traditional Liguori meditations, with sources and transcription
details in [their source record](STATIONS-SOURCE-RESEARCH-2026-09-06.json). Their optional
independent closing prayer still needs a published counterpart.

The Aramaic additions include a published medieval Melkite Syriac *Sub tuum praesidium* in both
scripts. This is an attested historical counterpart, not a claim that it is the contemporary
Maronite form. The “of” counter and mystery-fruit label are separately credited interface text.
A published Syriac Catholic prayerbook lists the Fatima prayer, but the public preview omits
the actual page. Its presence in a table of contents is not sufficient to reconstruct the text.

The Spanish Bible importer previously split nested footnote numbers into false verses,
truncating sentences, and missed John 21 because its chapter heading is misspelled upstream.
The importer now preserves inline words, removes annotations as whole elements, and includes
the two previously missing Via Lucis passages. The Italian Isaiah 28:16 split word
`fonda mento` is corrected to `fondamento` only at that verse, verified against a
[printed Martini edition](https://www.e-rara.ch/download/pdf/14913584.pdf), printed page 673.
Authored prayer credits now survive Scripture regeneration in every language.

A qualified reader should still compare every prayer and Scripture passage to the intended
edition, especially legacy Hebrew/Arabic content and partially populated languages. For
example, the malformed final word in the current [Kirjasilta Mark 14:72 transcription](https://www.kirjasilta.net/ha-berit/Mar.14.html)
is also present upstream (and in another online copy); it needs comparison with a printed
Delitzsch edition. This pass has not silently reconstructed its pointing or claimed the
upstream transcription is correct.

Sources and availability vary by devotion. A selectable app language does not mean that every
historical prayer variant has a complete published translation in it. Fallback remains explicit
in the existing content model; missing liturgical Hebrew and Syriac must not be invented.
