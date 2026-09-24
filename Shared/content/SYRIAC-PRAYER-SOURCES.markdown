# Syriac prayer source review

Reviewed 2026-09-19. This supplements the earlier research in
[`PRAYER-SOURCE-RESEARCH-2026-09-06.json`](../PRAYER-SOURCE-RESEARCH-2026-09-06.json).
It distinguishes attested Syriac text from editorial captions and from related prayers
that do not supply the missing counterpart. The supplied Erez basic prayers retain their
wording and paired scripts.

## Rosary opening

The two Rosary invitatory forms now assemble three separately identified components:

1. The opening is **Psalm 70:2 in Brian Walton's 1657 Polyglot**. Walton numbers the
   superscription as verse 1; this is Psalm 70:1 in editions that leave the superscription
   unnumbered, and Psalm 69:2 in the Vulgate. The five words were manually transcribed from
   the Syriac column on printed page 194, lower left, third line, and independently checked
   against an enlarged render of the same print:
   `ܐܰܠܳܗܳܐ ܦܰܨܳܢܝ ܡܳܪܝܳܐ ܠܥܽܘܕܪܳܢܝ ܟܰܬܰܪ`.
   The [exact scan is PDF page 9](https://archive.org/download/WaltPoly1PrologVariantReadings/WaltPoly6_Psalms-Jeremiah%29_text.pdf#page=9).
   The 1657 print is public domain; its [Archive item](https://archive.org/details/WaltPoly1PrologVariantReadings)
   declares CC0 1.0 Universal. The inspected PDF has SHA-256
   `f54132b1d7e5fd6340f8bba5a8bad9f1205ad71ab9d8e8ade63b87fd2b50a0f9`.
2. The doxology is the **unchanged supplied `gloriaPatri`**, separately in each script.
   Its Hebrew-letter form is not regenerated from the Syriac because the supplied pair
   is authoritative for these existing basic prayers.
3. The ordinary form adds `ܗܰܠܶܠܽܘܝܰܐ` from **Revelation 19:1**, in the already credited
   Digital Syriac Corpus edition of the BFBS 1905 New Testament. The Lenten form omits it.
   George A. Kiraz transcribed the Syriac; the TEI edition is © James E. Walters,
   [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
   [Pinned source](https://github.com/srophe/syriac-corpus/blob/833adc148cc356a6c70c16f81b22df9188df717a/data/tei/145.xml).

Prosary adds full stops, a response line break and bold response formatting to the Psalm
opening, replacing its printed terminal colon. The letters and vowel signs are unchanged.
Erez's deterministic converter supplies the Hebrew-script projection of the new Psalm
opening and Alleluia only. This assembly follows the app's existing invitatory structure;
it does **not** claim that Walton prints a complete Syriac Rosary formulary.

The narrow [source fixture](../tools/fixtures/syriac-invitatory-source.json) records both
editions, their locators and hashes, the inspected wording, and the presentation changes.
[`test-syriac-invitatory.py`](../tools/test-syriac-invitatory.py) checks the exact source
words, both displayed scripts, unchanged Gloria, and the Lenten Alleluia boundary.
This addition does not broaden the approval of the separate user-supplied Isaiah XML
or add Walton to the automated Scripture importer.

## Remaining gaps revisited

- **Jesus Prayer:** the [Scetis page](https://scetis.com/en/scripta/oratio) prints a Syriac
  form, but gives no named Syriac translator or source edition. The same unresolved source
  was found in the previous audit. A [note by Maronite priest Joseph Azize](https://www.josephazize.com/wp-content/uploads/2017/11/The-Prayer-of-the-Heart-and-the-Jesus-Prayer.pdf)
  discusses the Jesus Prayer but proposes a different Syriac invocation, “Holy God, have
  mercy on us”; it is not the app's “Lord Jesus Christ, Son of God, have mercy on me, a
  sinner.” Neither establishes a checked source for `oratioIesu`.
- **Rosary endings, Fatima, Saint Michael, Angelus and Loreto:** Samir Georges's 2019
  *A Brief Catechism of Saint Robert Bellarmine and Catholic Devotions* is an identified
  Syriac publication. Its [publisher catalog](https://www.beith-morounoye.org/Publication/index1.html)
  and [preview](https://www.beith-morounoye.org/Publication/preview/CatechismAndDevotions%20preview.pdf)
  still do not expose the relevant full pages: Fatima 72, Salve 81, Michael 83, Loreto 86,
  Angelus 93 and prayers for souls 225. The free Rosary *Madrosho* PDFs use their own hymn
  forms and do not supply these missing Roman prayer texts. No unseen text is reconstructed.
- **Salve Regina:** [Hudra's Qambel Maran page](https://hudra.day/articles/qambel-maran-cd)
  still marks this chant's text as pending. An audio item and a hymn title do not provide
  a checked Syriac transcription.
- **Loreto:** the [CMS India chant entry](https://www.thecmsindia.org/encyclopedia-of-syriac-chants/k/kuriyelaison-litany)
  explicitly provides selected portions, not a complete litany, and requests permission
  for reuse. It cannot complete the app's full sequence.
- **Stations:** the [syri.ac manuscript inventory](https://syri.ac/digimss/faceted/field_content_key_words_other_ge/stations-cross-1043?items_per_page=25)
  identifies Saint Mark, Jerusalem, SMMJ 00058, fols. 3v–23r (1729), with Garshuni and
  Syriac material. A manuscript catalog record is a research lead, not a verified
  transcription of the app's specific opening, closing and acclamation.

The unfilled Aramaic liturgical bodies remain visible in the generated language-coverage
report. No different prayer is inserted merely because its translated title is similar,
and no dialectal or newly composed wording is presented as an attested Classical Syriac
version. Their ordinary headings and mystery/fruit captions are already translated.
