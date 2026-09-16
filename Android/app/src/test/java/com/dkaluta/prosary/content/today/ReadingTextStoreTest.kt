package com.dkaluta.prosary.content.today

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReadingTextStoreTest {
    private val editions = listOf(
        ReadingEdition("existing-he", "he", "Hebrew edition", "Credit", "https://example.org/he"),
        ReadingEdition("existing-tl", "tl", "Filipino edition", "Credit", "https://example.org/tl"),
    )

    @Test fun automaticEditionRequiresTheInterfaceLanguageAndHonorsAliases() {
        assertEquals("existing-he", ReadingTextStore.effectiveEditionId("", "iw-IL", editions))
        assertEquals("existing-tl", ReadingTextStore.effectiveEditionId("", "fil-PH", editions))
        assertNull(ReadingTextStore.effectiveEditionId("", "ar", editions))
        assertNull(ReadingTextStore.effectiveEditionId("removed-edition", "he", editions))
        assertEquals("existing-tl", ReadingTextStore.effectiveEditionId("existing-tl", "he", editions))
    }

    @Test fun metadataDoesNotLoadTextAndLookupUsesRawCitationPlusNamespace() {
        val opened = mutableListOf<String>()
        val store = ReadingTextStore { name ->
            opened += name
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[{"id":"edition","languageCode":"en","name":"Edition","attribution":"Credit","sourceURL":"https://example.org"}]}"""
                "readings-texts" -> """{"schemaVersion":1,"passages":{"daily|John 3:16–17":{"edition":[{"chapter":3,"verse":16,"text":"First fixture"},{"chapter":3,"verse":17,"text":"Second fixture"}]},"torah|John 3:16–17":{"edition":[{"chapter":3,"verse":16,"text":"Companion fixture"}]}}}"""
                else -> error("Unexpected dataset")
            }.byteInputStream()
        }
        assertEquals(1, store.editions.size)
        assertEquals(listOf("readings-editions"), opened)
        val citation = ReadingCitation("gospel", "Jn. 3", "John 3:16–17", fullByLanguage = mapOf("he" to "Localized caption"))
        assertEquals(listOf(16, 17), store.passage(citation, "edition")?.verses?.map { it.verse })
        assertFalse(requireNotNull(store.passage(citation, "edition")).includesWholeVerses)
        assertEquals("Companion fixture", store.passage(citation, "edition", isTorah = true)?.verses?.single()?.text)
        assertNull(store.passage(citation.copy(full = "John 3:16-17"), "edition"))
        assertNull(store.passage(citation, "another-edition"))
        assertEquals(listOf("readings-editions", "readings-texts"), opened)
    }

    @Test fun wholeVerseNoticeUsesExactCitationAndNamespaceWithoutMakingMissingEditionsAvailable() {
        val citation = ReadingCitation("reading", "1 Cor. 8", "1 Corinthians 8:1b–7; 8:11–13",
            fullByLanguage = mapOf("he" to "Localized caption"))
        val store = ReadingTextStore {
            """{"schemaVersion":1,"wholeVersePassages":["daily|${citation.full}"],"passages":{"daily|${citation.full}":{"edition":[{"chapter":8,"verse":1,"text":"Whole first verse"}]},"torah|${citation.full}":{"edition":[{"chapter":8,"verse":1,"text":"Companion fixture"}]}}}""".byteInputStream()
        }
        assertTrue(requireNotNull(store.passage(citation, "edition")).includesWholeVerses)
        assertEquals("Whole first verse", store.passage(citation, "edition")?.verses?.single()?.text)
        assertFalse(requireNotNull(store.passage(citation, "edition", isTorah = true)).includesWholeVerses)
        assertNull(store.passage(citation, "missing-edition"))
        assertNull(store.passage(citation.copy(full = "Localized caption"), "edition"))
    }

    @Test fun missingCorruptAndUnsupportedAssetsRemainUnavailable() {
        val citation = ReadingCitation("reading", "Gen. 1", "Genesis 1:1")
        for (contents in listOf(null, "not json", """{"schemaVersion":2,"editions":[],"passages":{}}""")) {
            val store = ReadingTextStore { contents?.byteInputStream() }
            assertEquals(emptyList<ReadingEdition>(), store.editions)
            assertNull(store.passage(citation, "edition"))
        }
    }

    @Test fun availableEditionsRequireACompletePassageInTheExactScope() {
        val store = ReadingTextStore { name ->
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[
                    {"id":"missing","languageCode":"en","name":"Missing","attribution":"Credit","sourceURL":"https://example.org"},
                    {"id":"complete","languageCode":"en","name":"Complete","attribution":"Credit","sourceURL":"https://example.org"},
                    {"id":"damaged","languageCode":"en","name":"Damaged","attribution":"Credit","sourceURL":"https://example.org"},
                    {"id":"empty","languageCode":"en","name":"Empty","attribution":"Credit","sourceURL":"https://example.org"},
                    {"id":"paired","languageCode":"arc","name":"Paired","attribution":"Credit","sourceURL":"https://example.org","textScript":"Hebr","transliteratedTextScript":"Syrc"}]}"""
                else -> """{"schemaVersion":1,"passages":{"daily|Fixture 1:1":{
                    "complete":[{"chapter":1,"verse":1,"text":"Complete text"}],
                    "damaged":[{"chapter":1,"verse":1,"text":" "}], "empty":[],
                    "paired":[{"chapter":1,"verse":1,"text":"בדיקה"}],
                    "unlisted":[{"chapter":1,"verse":1,"text":"Unknown edition"}]}}}"""
            }.byteInputStream()
        }
        val citation = ReadingCitation("reading", "Fixture", "Fixture 1:1")
        assertEquals(listOf("complete"), store.availableEditions(citation).map { it.id })
        assertTrue(store.availableEditions(citation, isTorah = true).isEmpty())
        assertTrue(store.availableEditions(citation.copy(full = "Fixture 1:1 ")).isEmpty())
        assertNull(store.passage(citation, "missing"))
    }

    @Test fun pairedAramaicEditionSelectsAuthoredScriptsAndRejectsIncompletePairs() {
        fun store(alternate: String?) = ReadingTextStore { name ->
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[{"id":"peshitta-1905","languageCode":"arc","name":"Fixture Peshitta","attribution":"Fixture credit","sourceURL":"https://example.org","textScript":"Hebr","transliteratedTextScript":"Syrc"}]}"""
                else -> """{"schemaVersion":1,"passages":{"daily|Fixture 1:1":{"peshitta-1905":[{"chapter":1,"verse":1,"text":"בדיקה"${alternate?.let { ",\"transliteratedText\":\"$it\"" }.orEmpty()}}]}}}"""
            }.byteInputStream()
        }
        val store = store("ܐܒܓ")
        val edition = store.editions.single()
        assertTrue(edition.hasAramaicScripts)
        assertEquals("peshitta-1905", ReadingTextStore.effectiveEditionId(edition.id, "en", store.editions))
        val citation = ReadingCitation("reading", "Fixture", "Fixture 1:1")
        val verse = requireNotNull(store.passage(citation, edition.id)).verses.single()
        assertEquals("בדיקה", verse.displayedText(edition, "Hebr"))
        assertEquals("ܐܒܓ", verse.displayedText(edition, "Syrc"))
        assertEquals("בדיקה", verse.text)
        for (alternate in listOf(null, "", " ")) {
            assertNull(store(alternate).passage(citation, edition.id))
        }
        assertFalse(editions.first().hasAramaicScripts)
    }

    @Test fun bundledCatalogPreservesAllLanguagesAndTheSevenFullBibleEditions() {
        val store = bundledStore()
        assertEquals(listOf("ar", "arc", "en", "fr", "he", "it", "ru", "tl", "uk"),
            store.editions.map { it.languageCode }.sorted())
        val citation = ReadingCitation("gospel", "Lk", "Luke 6:27–38")
        for (edition in store.editions) {
            assertTrue(edition.attribution.isNotBlank())
            assertTrue(edition.sourceURL.startsWith("https://"))
            // Arabic currently contains only the passages reviewed against the old print.
            if (edition.languageCode in listOf("ar", "arc")) continue
            val passage = requireNotNull(store.passage(citation, edition.id))
            assertFalse(passage.includesWholeVerses)
            val verses = passage.verses
            assertEquals((27..38).toList(), verses.map { it.verse })
            assertTrue(verses.all { it.chapter == 6 && it.text.isNotBlank() })
        }
    }

    @Test fun bundledSeptemberTenthPartialReadingsExposeCompleteVersesWithTheNotice() {
        val store = bundledStore()
        val editionId = requireNotNull(ReadingTextStore.effectiveEditionId("", "en", store.editions))
        val firstReading = ReadingCitation("reading", "1 Cor. 8", "1 Corinthians 8:1b–7; 8:11–13")
        val reading = requireNotNull(store.passage(firstReading, editionId))
        assertTrue(reading.includesWholeVerses)
        assertEquals((1..7).toList() + (11..13).toList(), reading.verses.map { it.verse })
        assertTrue(reading.verses.all { it.chapter == 8 && it.text.isNotBlank() })

        val psalmCitation = ReadingCitation("psalm", "Ps. 139", "Psalm 139:1–3; 139:13–14ab; 139:23–24")
        val psalm = requireNotNull(store.passage(psalmCitation, editionId))
        assertTrue(psalm.includesWholeVerses)
        // The Douay-Rheims edition retains Vulgate numbering, including its split at 138:4.
        assertEquals(listOf(1, 2, 3, 4, 13, 14, 23, 24), psalm.verses.map { it.verse })
        assertTrue(psalm.verses.all { it.chapter == 138 && it.text.isNotBlank() })
    }

    @Test fun bundledPeshittaCarriesBothScriptsForTheSameOrderedVerses() {
        val store = bundledStore()
        val edition = store.editions.single { it.id == "peshitta-1905" }
        assertEquals("arc", edition.languageCode)
        assertTrue(edition.hasAramaicScripts)
        val passage = requireNotNull(store.passage(ReadingCitation("gospel", "Lk", "Luke 6:27–38"), edition.id))
        assertEquals((27..38).toList(), passage.verses.map { it.verse })
        assertTrue(passage.verses.all { it.chapter == 6 })
        assertTrue(passage.verses.all { verse -> verse.displayedText(edition, "Hebr").any { it in '\u05D0'..'\u05EA' } })
        assertTrue(passage.verses.all { verse -> verse.displayedText(edition, "Syrc").any { it in '\u0710'..'\u072F' } })
        assertTrue(passage.verses.all { verse -> verse.displayedText(edition, "Syrc") == verse.transliteratedText })
    }

    @Test fun bundledSeptemberThirteenthReadingsUseTheSelectedEditionsNumbering() {
        val store = bundledStore()
        val cases = listOf(
            "Sirach 27:30; 28:1–7" to (listOf("27:33") + (1..9).map { "28:$it" }),
            "Psalm 103:1–2; 103:3–4; 103:9–10; 103:11–12" to listOf(1, 2, 3, 4, 9, 10, 11, 12).map { "102:$it" },
            "Romans 14:7–9" to (7..9).map { "14:$it" },
            "Matthew 18:21–35" to (21..35).map { "18:$it" },
        )
        for ((reference, expected) in cases) {
            val citation = ReadingCitation("reading", "Reading", reference)
            val passage = requireNotNull(store.passage(citation, "douay-rheims-1899")) { reference }
            assertEquals(reference, expected, passage.verses.map { "${it.chapter}:${it.verse}" })
            assertTrue(passage.verses.all { it.text.isNotBlank() })
        }
        val psalmCitation = ReadingCitation("psalm", "Psalm", cases[1].first)
        val psalmEditions = mapOf(
            "douay-rheims-1899" to 102, "synodal-1876" to 102,
            "masoretic-delitzsch" to 103, "ang-dating-biblia-1905" to 103,
            "crampon-1923" to 103, "kulish-1905" to 103,
        )
        for ((editionId, chapter) in psalmEditions) {
            val psalm = requireNotNull(store.passage(psalmCitation, editionId)) { editionId }
            assertEquals(editionId, listOf(1, 2, 3, 4, 9, 10, 11, 12), psalm.verses.map { it.verse })
            assertTrue(editionId, psalm.verses.all { it.chapter == chapter })
            assertTrue(editionId, psalm.includesWholeVerses)
        }
        for (editionId in listOf("martini", "jesuit-arabic-1897")) {
            assertNull(editionId, store.passage(psalmCitation, editionId))
        }
        val french = requireNotNull(store.passage(ReadingCitation("reading", "Sirach", cases[0].first), "crampon-1923"))
        assertEquals(listOf("27:30") + (1..7).map { "28:$it" }, french.verses.map { "${it.chapter}:${it.verse}" })
        assertTrue(french.verses.all { it.text.isNotBlank() })
        assertNull(store.passage(ReadingCitation("reading", "Sirach", cases[0].first), "masoretic-delitzsch"))
    }

    @Test fun bundledSeptemberSixteenthPsalmOpensWithTheSelectedEditionsNumbering() {
        val store = bundledStore()
        val citation = ReadingCitation("psalm", "Ps. 33", "Psalm 33:2–3; 33:4–5; 33:12; 33:22")
        val passage = requireNotNull(store.passage(citation, "douay-rheims-1899"))
        assertEquals(listOf(2, 3, 4, 5, 12, 22), passage.verses.map { it.verse })
        assertTrue(passage.verses.all { it.chapter == 32 && it.text.isNotBlank() })
        assertEquals(listOf("ang-dating-biblia-1905", "crampon-1923", "douay-rheims-1899",
            "kulish-1905", "masoretic-delitzsch", "synodal-1876"),
            store.availableEditions(citation).map { it.id }.sorted())
    }

    @Test fun bundledCorinthiansAppointmentsKeepTheClosingBlessingAcrossEditionNumbering() {
        val store = bundledStore()
        for (start in listOf(3, 5)) {
            val citation = ReadingCitation("reading", "2 Cor. 13", "2 Corinthians 13:$start–13")
            val tagalog = requireNotNull(store.passage(citation, "ang-dating-biblia-1905"))
            assertEquals((start..14).toList(), tagalog.verses.map { it.verse })
            assertTrue(tagalog.verses.all { it.chapter == 13 && it.text.isNotBlank() })
            assertTrue(tagalog.verses.last().text.contains("Espiritu Santo"))
            val douay = requireNotNull(store.passage(citation, "douay-rheims-1899"))
            assertEquals((start..13).toList(), douay.verses.map { it.verse })
            assertTrue(douay.verses.all { it.chapter == 13 && it.text.isNotBlank() })
            assertTrue(douay.verses.last().text.contains("Holy Ghost"))
        }
    }

    @Test fun bundledBoundaryAppointmentsRetainLeadingAndTrailingClausesWithWholeVerseNotice() {
        val store = bundledStore()
        val cases = listOf(
            Triple("Mark 3:20–30", "ang-dating-biblia-1905", 3 to (19..30)),
            Triple("Mark 3:20–30", "peshitta-1905", 3 to (19..30)),
            Triple("Luke 7:11–18", "douay-rheims-1899", 7 to (11..19)),
        )
        for ((reference, editionId, expected) in cases) {
            val passage = requireNotNull(store.passage(ReadingCitation("gospel", "Gospel", reference), editionId))
            assertTrue(reference, passage.includesWholeVerses)
            assertEquals(reference, expected.second.toList(), passage.verses.map { it.verse })
            assertTrue(passage.verses.all { it.chapter == expected.first && it.text.isNotBlank() })
        }
    }

    @Test fun bundledOldJesuitArabicOpensReviewedPassagesWithoutBorrowingMissingText() {
        val store = bundledStore()
        val editionId = requireNotNull(ReadingTextStore.effectiveEditionId("", "ar-LB", store.editions))
        assertEquals("jesuit-arabic-1897", editionId)
        val edition = store.editions.single { it.id == editionId }
        assertTrue(edition.name.contains("1897"))
        assertTrue(edition.attribution.isNotBlank())
        assertTrue(edition.sourceURL.startsWith("https://"))

        val citation = ReadingCitation("gospel", "Lk", "Luke 1:26–38")
        val verses = requireNotNull(store.passage(citation, editionId)).verses
        assertEquals((26..38).toList(), verses.map { it.verse })
        assertTrue(verses.all { it.chapter == 1 })
        assertEquals("فقالت مريم هاءنذا أمة الرب فليكن لي بحسب قولك. وانصرف الملاك من عندها.", verses.last().text)
        assertTrue(TodayTranslationLanguage.isRightToLeft(edition.languageCode))

        assertNull(store.passage(citation.copy(full = "Luke 6:27–38"), editionId))
        assertNull(store.passage(citation.copy(full = "Genesis 47:28–50:26"), editionId, isTorah = true))
    }

    @Test fun bundledHebrewNewTestamentKeepsSourceVowelsAndTheUnpointedDivineName() {
        val store = bundledStore()
        val editionId = requireNotNull(ReadingTextStore.effectiveEditionId("", "iw-IL", store.editions))
        assertEquals("masoretic-delitzsch", editionId)
        val edition = store.editions.single { it.id == editionId }
        assertFalse(edition.attribution.contains("ללא ניקוד"))
        assertTrue(edition.attribution.contains("1901"))
        assertTrue(edition.attribution.contains("delitz.fr"))
        assertEquals("https://delitz.fr/12/", edition.sourceURL)
        assertTrue(TodayTranslationLanguage.isRightToLeft(edition.languageCode))

        for (citation in listOf("Luke 6:27–38", "1 Corinthians 8:1b–7; 8:11–13")) {
            val verses = requireNotNull(store.passage(ReadingCitation("reading", "Reading", citation), editionId)).verses
            assertTrue("Every Hebrew NT verse keeps the source's vocalization: $citation",
                verses.all { verse -> verse.text.any { it in '\u05B0'..'\u05BC' || it == '\u05C7' } })
        }

        val annunciation = requireNotNull(store.passage(
            ReadingCitation("gospel", "Lk", "Luke 1:26–38"), editionId)).verses
        val marks = "[\\u0591-\\u05BD\\u05BF\\u05C1\\u05C2\\u05C4\\u05C5\\u05C7]*"
        val names = Regex("י${marks}ה${marks}ו${marks}ה${marks}")
            .findAll(annunciation.joinToString(" ") { it.text }).map { it.value }.toList()
        assertTrue("The tested NT passage contains the Divine Name", names.isNotEmpty())
        assertTrue("Only the Name's vowel points are removed; accents remain permitted",
            names.all { name -> name.none { it in '\u05B0'..'\u05BC' || it == '\u05C7' } })
    }

    @Test fun bundledHebrewTorahKeepsCantillationIncludingOnTheDivineName() {
        val store = bundledStore()
        val citation = ReadingCitation("reading", "Dt", "Deuteronomy 11:26–16:17")
        val verses = requireNotNull(store.passage(citation, "masoretic-delitzsch", isTorah = true)).verses
        val verse = verses.single { it.chapter == 11 && it.verse == 27 }
        assertEquals("אֶֽת־הַבְּרָכָ֑ה אֲשֶׁ֣ר תִּשְׁמְע֗וּ אֶל־מִצְוֹת֙ יהו֣ה אֱלֹֽהֵיכֶ֔ם אֲשֶׁ֧ר אָנֹכִ֛י מְצַוֶּ֥ה אֶתְכֶ֖ם הַיֹּֽום׃", verse.text)
    }

    private fun bundledStore() = ReadingTextStore { name ->
        File("src/main/assets/data/$name.json").takeIf { it.exists() }?.inputStream()
    }
}
