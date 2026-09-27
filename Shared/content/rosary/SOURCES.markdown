# Vicariate Hail Mary wording

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
