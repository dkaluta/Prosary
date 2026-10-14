# Vicariate Hail Mary wording

## Separate Nicene Creed and Filioque, October 2026

The user supplied the St. James Vicariate Nicene Creed on 11 October 2026, then supplied
a photograph of its **pointed printed text on page 6**, headed נוסח "של ניקאה".
`symbolumNicaenum` relays the print's spelling, niqqud, punctuation and maqaf. Two independent
visual transcriptions were compared against the original photograph. Physical print line wraps
are joined within their paragraphs, retaining the initial first-line break; NFC normalization
only changes equivalent Unicode mark ordering. This is source transcription, with no editorial
vocalization or inferred reading aid.

The source image was supplied as `IMG_5448.jpeg`, SHA-256
`0753c52ca77cad106feec019884775f064a1fbb75b814edfeaa8d87cb97eade7`.
The repository records its filename, printed page and hash without copying the personal photo
or its EXIF metadata. The initial unpointed transcription remains in the source fixture under
`initialUnpointedTranscription`. The photograph establishes **יִשְׁעֵנוּ** (`ישענו`) in place of
the initial `ישעינו`, and a comma after **הַמְחַיֶּה**. The unusual printed
**כְּלָאָב וְכַלְבֵּן** is retained without grammatical normalization, as are **מוּלָד**,
**עַצְמוֹ עֶצֶם הָאָב**, **אֲשֶׁר נוֹלַד**, and **וְלֹא יִהְיֶה קֵץ**.
The print naturally includes **וּמֵהַבֵּן** without the initial transcription's annotation
brackets. Its Hebrew body and heading retain the Vicariate provenance marker. It is a
separate Basic Prayer; the existing Vicariate Apostles' Creed remains available.

The Latin fallback is the ancient Creed printed in the
[Vatican papal Mass booklet of 29 June 2012](https://www.vatican.va/news_services/liturgy/libretti/2012/20120629.pdf),
printed pages 36–37. The existing Mission, Greek and Aramaic Nicene texts are reused
unchanged under the separate key, including the Aramaic source/reading-aid pair.
The source fixture is [`nicene-creed.json`](../../tools/fixtures/nicene-creed.json).
Missing prayer translations retain the configured language fallback; editorial headings
do not establish translated prayer-body coverage.

The separate Nicene body is supplied in Latin, Vicariate Hebrew, Mission Hebrew, Aramaic,
Greek and Ukrainian. English, Arabic, Russian, Tagalog, French, Italian and Spanish have
translated display headings and retain the configured body fallback. In particular, the
Spanish Rosary's existing devotion flow remains complete; its separately available Nicene
Basic Prayer does not acquire a Spanish liturgical translation from that coverage. The
Spanish `$coverage.fallbackPrayerKeys` records only `symbolumNicaenum`, and the selected-language
coverage test permits that exact supplemental omission while continuing to require every
Spanish devotion body, mystery and heading.

The former user Filioque switch is retired. Internal `$creedPolicy` tags choose absent,
square-bracketed or unbracketed presentation for the actual authored source; old saved toggle
values are ignored. Syriac and Mission preserve their supplied clause in square brackets.
Latin and Vicariate render it unbracketed. Greek has no supplied procession insertion and
retains its sourced wording.

The [St. George Melkite parish explanation](https://stgeorgemelkite.org/resources/frequently-asked-questions/)
also describes retaining the Creed without the Filioque. The request for an unbracketed
Melkite recension therefore remains a source-selection question; the app does not add a
Greek clause to the supplied text without an identified preferred source.

The Ukrainian Nicene body is independently transcribed from the [UGCC catechism,
Христос – наша Пасха](https://catechismugcc.org/doc/Catechism-UGCC.pdf), 2012 edition,
printed page 10. Its square-bracketed `[і Сина]` is already in the source. Physical
line wraps and split words are joined; no wording, spelling or punctuation is modernized.
The PDF hash and exact text are pinned in `tools/fixtures/ukrainian-nicene-creed.json`.
This is credited third-party wording, not a Prosary translation or CC0 dedication. Raw
older Ukrainian Apostles text is retained with its Latin source credit for provenance;
the selected Eastern policy hides that separate entry and resolves legacy devotion Creed
steps to the authored Nicene body/title instead.

A [published Saint Maron parish Creed](https://www.saintmaron.ca/prayers/) includes the
Filioque unbracketed. A Maronite source can therefore declare `unbracketed` explicitly;
this evidence does not supply an otherwise missing Syriac or Hebrew Maronite recension.
The renderer never manufactures a clause merely from a language, calendar or Church name.

The contributor supplied five prayer corrections on 6 October 2026: Syriac Fatima and
Sub tuum praesidium; Ukrainian Our Father, Fatima and Hail Mary. Their exact supplied
wording is pinned in `Shared/tools/fixtures/contributor-prayer-corrections.json` and
credited separately in each native About screen. No published-source claim is made for
these corrections. The new Fatima body stays in Syriac letters; no Hebrew-letter
version is inferred. For Sub tuum, the existing separately credited Hebrew-letter
body is retained while the supplied Syriac recension replaces its alternate body.

The Hebrew fixed Hail Mary retains the St. James Vicariate prayer book's
**מְלֵאַת הַחֶסֶד** and its original reading aid. The alternative wording option was removed
at the user's request on 26 September 2026; old saved preferences no longer substitute any
text. Source selection and the distinction between Vicariate, Mission, generic Hebrew and
Scripture remain unchanged.

## Separate Rosary collect, September 2026

`rosaryCollect` reuses the existing, sourced `collectaStandard` body unchanged in each
language that supplies it. Spanish and Mission Hebrew reuse their existing credited
`collectAfterRosary` from the Litany of Loreto. Vicariate Hebrew retains its per-key
tradition marker; Mission Hebrew retains Erez's supplied wording. No Aramaic collect is
invented. Existing fallback behavior is not a claim of Aramaic coverage.

The Rosary removes the embedded collect from every Marian antiphon choice and displays
its own collect separately. Enabling the optional Litany of Loreto includes its body
before that one Rosary collect. The standalone Litany keeps its existing standard collect;
standalone basic Marian antiphons keep their existing complete bodies and collects.
The Hebrew heading **נתפללה** is the user's explicit wording for Oremus, supplied on
27 September 2026 and also applied to the corresponding headings in other prayer bundles.

## Mystery and navigation metadata, September 2026

Missing mystery names, spiritual-fruit labels, intention captions and navigation headings
are editorial app vocabulary. The Spanish, Greek and Aramaic Seven Sorrows overlays also translate
the canonical English fourth-Sorrow narrative; it remains explicitly a meditation, never
Scripture. These additions do not claim to be published liturgical translations.

The Aramaic metadata uses unpointed **Classical Syriac**, with a separate deterministic
Hebrew-square projection from `Shared/tools/aramaic_script_converter.py`. No vowels are
reconstructed. It must not be identified as Hebrew or as a modern Assyrian/Chaldean dialect.
The spelling and vocabulary are informed by the already credited Peshitta passages and
Syriac lexicography, including:

- [Beth Mardutho's SEDRA lexical reference](https://sedra.bethmardutho.org/), which identifies
  its Classical Syriac dictionaries and editions;
- [Syriac Dictionary's humility entry](https://syriacdictionary.net/mobile/index.cgi?hidden=Search&word=%DC%A1%DC%B0%DC%9F),
  confirming `ܡܟܝܟܘܬܐ`;
- [Syriaca's *On Humility* work record](https://syriaca.org/work/8579), attesting the same noun;
- [Comprehensive Aramaic Lexicon's cited Syriac text](https://cal.huc.edu/oneentry.php?cits=all&lemma=k%29mt+c),
  attesting `ܡܫܬܡܥܢܘܬܐ` for obedience.

These references support vocabulary, not an assertion that the complete newly assembled
metadata phrases appear in a Syriac prayerbook. Existing prayer bodies remain separately
sourced, and the unresolved Marian antiphons, collects and other traditional Syriac prayers
remain absent. Native readers retain the title, fruit and description with their own paired
alternate-script fields; switching the Scripture script also switches the supplied metadata.

The new Franciscan Crown and Seven Sorrows Scripture overlays were generated from the same
pinned BFBS 1905 Digital Syriac Corpus source as the Rosary: Matthew 2:9–11; Luke 2:34–35;
Matthew 2:13–14; Luke 2:43–45; John 19:25–27, 38–40 and 41–42. See
[the Peshitta attribution](../PESHITTA-SOURCES.markdown). The Crown's optional Marian endings,
the Seven Sorrows closing prayer remains unavailable in
Aramaic pending a suitable source.
