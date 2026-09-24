# Translation coverage and sources

This pass completes interface strings in the eight supported interface languages and
prayer headings, mystery names and fruits in all twelve public prayer languages.
It does not count the saved fallback language as a translation. Traditional prayer
bodies use published wording; newly translated display labels and authored reflections
are identified as editorial material in their canonical JSON files.

The generated [coverage report](../PRAYER-LANGUAGE-COVERAGE.markdown) and its
[key inventory](../PRAYER-LANGUAGE-COVERAGE.json) record every remaining gap.
Some pack overlays remain partial even though their headings are complete.

## Added published wording

| Content | Source and treatment |
| --- | --- |
| Hebrew O Antiphons | [St James Vicariate, antiphons before Christmas](https://www.catholic.co.il/?cat=faith&id=8770&m=PrayersandchosentextsfromtheChristiantradition&view=article). The seven prayer bodies retain the published pointing and refrain and carry `vicariate` tradition markers. Editorial headings and independently sourced Scripture do not carry that marker. |
| Russian O Antiphons | [RusCatholic, O Antiphons](https://ruscatholic.org/o-antifoni/). Published prayer wording with separate Scripture provenance. |
| Greek Angelus | [Institute of the Incarnate Word in Greece](https://www.ivegreece.gr/2016/03/i-prosefchi-angelos-tou-kyriou/). The Easter closing assembles existing sourced Greek Regina Caeli components, credited separately. |
| Greek Divine Mercy Chaplet | [iPray Greek prayers and recordings](https://rosary.ipray.eu/add_greek_audio.html). This devotional publication is credited without claiming episcopal approval. |
| Additional Spanish Stations and Via Lucis wording | Per-key publication links and composition notes in their canonical Spanish content files. Their unresolved optional closing prayers remain absent. |
| Ukrainian Via Lucis acclamation | Published CREDO prayerbook wording, pinned in the Ukrainian source fixtures. See [Ukrainian sources](UKRAINIAN-SOURCES.markdown). |
| Ukrainian Rosary collect, also used by the Crown and Loreto | Published by the [MIR Ukrainian information center](https://medjugorje.com.ua/media/video/molytvy/6220-6-den-novenna-do-bozhoyi-matery-fatymskoyi17-bereznya-25-bereznya-2022.html), whose footer permits publication with a source link. Exact wording and permission evidence are recorded with the Ukrainian sources. |
| Greek opening prayers and Stations response | The two Rosary opening variants follow the public-domain *Officium* (1823), printed page 7. The short Stations response follows the Greek Catholic bishops' published Stations. Per-key source links are in the canonical files. |
| Spanish Seven Sorrows closing | José Pulido y Espinosa, *Misal Romano* (Madrid, 1851), p. 333, independently checked against the printed page; its short introductory response has a separate published source. See [the prayer source record](SOURCED-PRAYER-ADDITIONS.markdown). |

Hebrew, Russian and Tagalog O Antiphon readings are generated with
`Shared/tools/import-o-antiphon-scripture.py` from the app's existing hash-pinned Bible
editions. Each content file records the source URLs, digests and edition terms.
The Hebrew Isaiah darkness-and-light passage is labeled 9:1 in its own edition;
Russian and Tagalog retain 9:2. Hebrew Divine Name vowel marks are removed without
removing adjacent punctuation.

All eight Arabic O Antiphon Scripture fields now follow the existing 1897 Jesuit
edition: nineteen additional verses were visually transcribed and independently
checked against its printed pages, then imported by `import-arabic-scripture.py`.
See [Arabic source evidence](ARABIC-SCRIPTURE-SOURCES.markdown).

All seven Spanish Isaiah readings now follow the same Torres Amat 1836 edition
as the app's existing Spanish New Testament. Nine verses were transcribed from
[volume IX](https://archive.org/details/lasagradabiblian10torr), printed pages
44, 50, 60–61, 93 and 114 (PDF pages 52, 58, 68–69, 101 and 122), then independently
checked. The local excerpt corpus records the PDF checksum, page map and historical
spelling policy. `import-scripture.py` verifies its checksum before importing.
The source is the public-domain print, without modern revisions or footnote commentary.
Spanish is now available for the complete O Antiphons and Seven Sorrows flows.

Seven additional Aramaic readings use the existing sourced Peshitta importer;
see [Peshitta sources](PESHITTA-SOURCES.markdown). Aramaic mystery names, fruits,
display headings and editorial reflections carry paired Syriac and Hebrew scripts.
These editorial additions are unpointed; they do not invent a vocalized liturgical text.
Each native port resolves the corresponding title, fruit and script together.

The two Syriac Rosary openings now assemble a visually checked five-word opening
from Walton's 1657 Psalter with the existing supplied doxology and the published
Peshitta Alleluia. Their component sources, script projection and limits are documented
in [Syriac prayer sources](SYRIAC-PRAYER-SOURCES.markdown); this is not presented as
a published complete Syriac Rosary formulary.

## Interface and safeguards

Shared option labels, reminders, devotion names and O Antiphon day dates are localized.
The Rosary's four group headings use the prayer language in full-Rosary sessions, and
the Apple shortcut phrases and spoken Today's Mysteries response use the interface language.
The native ports normalize Filipino `fil` to shared `tl`, including Windows devotion
metadata. The O Antiphon `periodByLanguage` map and paired mystery title/fruit fields
are documented in the schema and validated by native loaders and repository uploads.

`test-translation-completeness.py` checks interface catalogs, Apple shortcuts, widgets,
system Settings text and visible metadata;
`test-mystery-metadata.py` checks names, fruits and paired scripts;
`test-o-antiphon-scripture.py` checks passage selection, source numbering and provenance.
Existing source tests and the coverage report continue to expose unavailable traditional
prayer bodies. Content is rebuilt into `Shared/dist` and copied identically into all
three native ports.
