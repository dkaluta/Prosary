# Pointed Peshitta Isaiah source review

Reviewed 2026-09-07. This records source research and the subsequent integration of nine user-supplied pointed verses into the seven Isaiah passages in `oAntiphons/content/arc.json`. The user reported that Erez appeared to approve these verses and requested their use. Their underlying edition and redistribution terms remain unidentified; this is not an independent verification of those claims. No vowels are inferred or composed.

## Scope and current source

The Latin source citations in `oAntiphons/content/la.json` identify seven passages comprising nine verses. The accepted XML numbers the darkness/light verse 9:2, matching the Latin input. The former ETCBC source numbered it 9:1; that old offset has been removed for the replacement source. All other imported references retain their chapter and verse numbers.

The superseded Old Testament text came from ETCBC/peshitta. Its [About document](https://github.com/ETCBC/peshitta/blob/master/docs/about.md) distinguishes the text's **CC BY-NC 4.0** terms from the converter's MIT license; the repository's root MIT file must not be used to describe the Scripture text as MIT. Neither license applies to the replacement XML. See [PESHITTA-SOURCES.markdown](PESHITTA-SOURCES.markdown) for the separate, pointed New Testament source.

## Public-domain print candidate: Walton

Brian Walton, *Biblia sacra polyglotta* (London: Thomas Roycroft, 1657), has the required Isaiah passages with actual Western Syriac vowel signs. This was checked visually in the Syriac column of all five relevant scan pages, including enlarged renders. The [syri.ac bibliography](https://syri.ac/bibliography/33759301) identifies the edition; its [Bible resource list](https://syri.ac/syriacbible) includes Walton among the public-domain editions. The [Internet Archive scan item](https://archive.org/details/WaltPoly1PrologVariantReadings) is marked **CC0 1.0 Universal**.

The required file is `WaltPoly6_Psalms-Jeremiah)_text.pdf`, a 300-page PDF of facing-page scans. Its filename is an archive segment label; it is not the printed Isaiah pagination. A second [image PDF](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29.pdf) and [JP2 scan images](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_jp2.zip) are available from the same item.

Each link below opens the exact PDF page. PDF page numbers are one-based; the printed page is the right-hand page headed *ESAIAS*, in the upper *Versio Syriaca* column. Walton prints the darkness/light verse as 9:2, corresponding to the former ETCBC source's 9:1.

| Content key | Latin input | Previous ETCBC reference | Walton reference | Printed page | PDF page |
| --- | --- | --- | --- | --- | --- |
| `oEmmanuelLectio` | Isaiah 7:14 | Isaiah 7:14 | Isaiah 7:14 | 21 | [147](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=147) |
| `oOriensLectio` | Isaiah 9:2 | Isaiah 9:1 | Isaiah 9:2 | 25 | [149](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=149) |
| `oSapientiaLectio` | Isaiah 11:2 | Isaiah 11:2 | Isaiah 11:2 | 33 | [153](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=153) |
| `oSapientiaLectio` | Isaiah 11:3 | Isaiah 11:3 | Isaiah 11:3 | 33 | [153](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=153) |
| `oAdonaiLectio` | Isaiah 11:4 | Isaiah 11:4 | Isaiah 11:4 | 33 | [153](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=153) |
| `oAdonaiLectio` | Isaiah 11:5 | Isaiah 11:5 | Isaiah 11:5 | 33 | [153](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=153) |
| `oRadixIesseLectio` | Isaiah 11:10 | Isaiah 11:10 | Isaiah 11:10 | 33 | [153](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=153) |
| `oClavisDavidLectio` | Isaiah 22:22 | Isaiah 22:22 | Isaiah 22:22 | 57 | [165](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=165) |
| `oRexGentiumLectio` | Isaiah 28:16 | Isaiah 28:16 | Isaiah 28:16 | 71 | [172](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=172) |

## Wording differences and transcription status

Walton is a distinct historical edition. It must not be used as a vowel dictionary to point the current ETCBC consonants. The initial visual comparison found:

- Isaiah 7:14: Walton has `ܡܪܝܐ` followed by `ܐܬܐ`; the current text has `ܡܪܝܐ ܐܠܗܐ ܐܬܐ`.
- Isaiah 11:2: Walton places `ܥܠܘܗܝ` between `ܘܬܬܢܝܚ` and `ܘܬܫܪܐ`; the current text places it after both verbs.
- Isaiah 28:16: the opening and foundation wording differ visibly. This verse needs a complete consonantal collation before a replacement is considered.
- Isaiah 9 has the versification difference documented above.

These are preliminary observations, not an exhaustive collation. The scan is sufficient to establish the presence of Western vocalization, but several small vowel shapes and their exact attachment could not be verified confidently during this review. No complete nine-verse Unicode transcription or converter-ready fixture was verified. Automated OCR from the scan does not supply trustworthy Syriac text.

A future Walton transcription needs the actual printed wording, all vowels and other marks, a full consonantal difference record, explicit edition-specific verse mapping, and a second comparison against the cited pages. Walton has not been used to produce the accepted XML text or to establish its provenance.

## User-supplied vocalized Zefania XML

The user supplied this [complete Peshitta XML](https://dn760101.eu.archive.org/0/items/peshitta-complete-bible-otnt/Peshitta%20Complete%20Bible%20OTNT%20with%20vocalization%20-%20Zefania%20XML%20%28---Original---%20With%20most%20Apocrypha%29.xml.txt), held in [this Internet Archive item](https://archive.org/details/peshitta-complete-bible-otnt). The inspected download has SHA-256 `4f71fe418a1d23f6b65d63d155f838a228dbdb6e4857834f4503afdcf009ea88`.

It is valid Zefania XML with 73 books. Isaiah is `BIBLEBOOK` number 23, named `Isaiah`, with 66 chapters. All nine requested verses are present as plain text with Western Syriac vowel signs; together they contain 260 signs supported by Erez's vowel mapping. No vowels need to be inferred from unpointed words.

The full consonantal comparison against the current ETCBC passages found seven matching verses and two wording differences, after ignoring punctuation and combining marks and resolving the marked rish described below:

- Isaiah 11:2: current `ܕܐܝܕܥܬܐ`, supplied XML `ܕܝܕܥܬܐ`.
- Isaiah 28:16: the supplied XML omits the current text's `ܗܟܢܐ`.
- The darkness/light passage is numbered **9:2** in this XML. Its 9:1 is the preceding Zebulun/Naphtali passage. An importer for this edition must not apply the current ETCBC 9:2-to-9:1 offset.

Isaiah 11:4 encodes a rish bearing seyame as `ܖ̈` (U+0716 plus U+0308). The Hebrew converter now recognizes this attached combination before removing seyame, including when another combining mark intervenes. It leaves the source Syriac untouched and rejects an ambiguous U+0716 without attached seyame. This follows the distinction described in [Unicode section 9.3.1](https://www.unicode.org/versions/Unicode17.0.0/core-spec/chapter-9/). A nine-verse conversion check confirms that this form no longer leaks a Syriac letter into the Hebrew projection.

The underlying OT edition is still unidentified. The header names BFBS 1905, but its description, identifier `SYP`, contributor `OSIS`, publisher, coverage, and format match the earlier [Zefania Syriac Peshitta NT module](https://sourceforge.net/projects/zefania-sharp/files/Bibles/SYR/Syriac%20Peshitta%20NT/). That original module identifies itself as NT version 2.0.1.18 and supplies an OSIS source URL and date. This combined file changes NT to OT and removes that source URL and date. This is evidence of reused metadata, not evidence that the pointed Isaiah came from BFBS 1905. Both the XML's creator and rights fields are empty, and the Archive metadata supplies no license declaration.

Following the user's reported Erez review, these nine verses now replace the seven formerly unpointed passages. `import-scripture.py` verifies the full download's hash on fetch and cache read, restricts extraction to these nine verses, and rejects missing passages, missing vowel signs, duplicate reviewed verses, wrong book identity, and inline annotations. The regression fixture contains only these verses and explicitly retains the unresolved attribution status. Tests compare all seven generated passages and both scripts with this fixture, including the 9:2 citation and the accepted 11:2 and 28:16 readings. Attribution must not label its OT edition or redistribution terms as verified.

## Other sources checked

- **Peshitta.eu:** the live chapters [7](https://www.peshitta.eu/ot/isaiah/7.html), [9](https://www.peshitta.eu/ot/isaiah/9.html), [11](https://www.peshitta.eu/ot/isaiah/11.html), [22](https://www.peshitta.eu/ot/isaiah/22.html), and [28](https://www.peshitta.eu/ot/isaiah/28.html) contain Western-vocalized Unicode text covering the target passages. The [site's source note](https://peshitta.eu/about.html) identifies its Old Testament as the Syriac Orthodox Patriarchate's 2020 publication. No redistribution grant for that pointed electronic text was found. Its availability for reading is not an open-content license.
- **Antioch Bible / Gorgias Press:** [the 2012 Isaiah volume](https://gorgiaspress.com/the-book-of-isaiah-according-to-the-syriac-peshitta-version-with-english-translation), Syriac prepared by George Kiraz and Joseph Bali, explicitly offers fully vocalized and pointed Western Syriac. It covers Isaiah, but no open redistribution license was found for this modern edition.
- **Digital Syriac Corpus:** the pinned corpus used for the licensed New Testament was searched for a corresponding Isaiah Bible volume. None was found; works about Isaiah or quotations in commentaries do not establish a complete, checked source for these nine verses.

Walton provides an identified public-domain print route, with transcription still needed. The supplied XML provides the selected pointed text now used, with its underlying edition and redistribution terms unresolved.
