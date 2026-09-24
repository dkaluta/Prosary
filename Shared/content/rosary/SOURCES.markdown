# Vicariate Hail Mary wording

The default Hebrew fixed Hail Mary retains the St. James Vicariate prayer book's
**מְלֵאַת הַחֶסֶד**. The optional Jaffa wording is **בְּרוּכַת הַחֶסֶד**.

On 6 September 2026, the user supplied the Jaffa wording and reported that the congregation's
pastor, **Fr. Apolinary Tadeusz Szwed, OFM**, had verified it and personally prays this way.
The user subsequently confirmed the rendering with vowel points. This attribution records
user-supplied pastoral testimony; it is not a claim of independent verification or a published
edition. The exact source pair and attribution are recorded in
[`vicariate-wording.json`](../../tools/vicariate-wording.json).

The app-wide `useJaffaHailMaryWording` preference is off by default. When enabled, it substitutes
the phrase only after a Vicariate prayer has won text resolution, including explicitly marked
Vicariate repository content. Pointed prayer text uses the pointed replacement; an exact
unpointed phrase in a marked prayer stays unpointed. Mission wording, unmarked shared Hebrew,
and Scripture retain their own texts. The setting also applies when Vicariate is reached
through the user's fallback order, without changing that order.

The source prayer text is never rewritten by the preference. No corresponding reading aid
was supplied for the Jaffa wording, so an affected prayer's original aid is omitted while
the substitution is enabled. Unaffected prayers retain their aids.

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
