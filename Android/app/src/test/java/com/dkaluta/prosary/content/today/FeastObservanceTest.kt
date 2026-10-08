package com.dkaluta.prosary.content.today

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class FeastObservanceTest {
    @Test fun eachCalendarCanSupplyItsOwnSectionsInSourceOrder() {
        fun section(id: String, title: String, text: String) = CalendarTextSection(id,
            mapOf("en" to title), mapOf("en" to text))
        val eastern = FeastObservance("Feast", "eastern", sections = listOf(
            section("hymn", "Hymn", "Source hymn"),
            section("local-custom", "Local custom", "Source custom")))
        val western = FeastObservance("Feast", "western", sections = listOf(
            section("biography", "Life", "Source biography")))
        val easternDescription = requireNotNull(eastern.description("en-US"))
        assertEquals(listOf("hymn", "local-custom"), easternDescription.sections.map { it.id })
        assertEquals(listOf("biography"), western.description("en")!!.sections.map { it.id })
        assertNull(eastern.description("he"))
        assertNull(eastern.reflection("en"))
    }

    @Test fun completeSectionsUseExactLocalizedHeadingsWithoutLosingProse() {
        val first = CalendarTextSection("about", mapOf("he" to "על היום", "tl" to "Tungkol"),
            mapOf("he" to "פסקה ראשונה", "tl" to "Unang talata"))
        val second = CalendarTextSection("tradition", mapOf("he" to "מסורת"), mapOf("he" to "פסקה שנייה"))
        val source = FeastObservance("Feast", "identity", sections = listOf(first, second),
            descriptionByLanguage = mapOf("he" to "על היום:\nפסקה ראשונה\n\nמסורת:\nפסקה שנייה",
                "tl" to "Tungkol:\nUnang talata\n\nAdditional source paragraph"),
            reflectionByLanguage = mapOf("he" to "הרהור"))
        assertEquals(2, source.description("iw-IL")!!.sections.size)
        val partial = source.description("fil-PH")!!
        assertTrue(partial.sections.isEmpty())
        assertTrue(partial.text.contains("Additional source paragraph"))
        assertTrue(source.reflection("he")!!.sections.isEmpty())
        assertNull(source.description("fr"))
        assertNull(first.localized("fr"))
    }

    @Test fun expandedDescriptionsDoNotRepeatParentFeastTitles() {
        val saint = SaintDescription("saint", "  חַג\n הקדוש  ", "Sourced description")
        assertFalse(saint.shouldShowTitle("חג הקדוש"))
        assertTrue(saint.shouldShowTitle(null))
        assertTrue(saint.shouldShowTitle("חג אחר"))
        assertTrue(saint.shouldShowTitle("חג הקדוש / קדוש נוסף"))
    }

    @Test fun oldFeastFilesRemainReadableAndDescriptionsFollowTheSelectedDataset() {
        val old = Json.decodeFromString<FeastDay>("""{"title":"Feast","rank":"Feast"}""")
        assertTrue(old.saintDescriptions("syriac", "en").isEmpty())
        val feast = FeastDay("Feast", "Feast", observances = listOf(FeastObservance("Saint", "identity",
            descriptionByLanguage = mapOf("en" to "English biography"))))
        assertEquals("English biography", feast.saintDescriptions("syriac", "en").single().text)
        assertEquals("English biography", feast.saintDescriptions("roman", "en").single().text)
    }

    @Test fun descriptionsNeverBorrowAnotherLanguageAndNormalizePlatformAliases() {
        val saint = FeastObservance("Source saint", "identity", titleByLanguage = mapOf("he" to "קדוש", "tl" to "Santo"),
            descriptionByLanguage = mapOf("he" to "  סִימָן\n\nפסקה  ", "tl" to "Talambuhay", "en" to "English"),
            descriptionSourceByLanguage = mapOf("en" to "https://example.org/english", "tl" to "https://example.org/tl"),
            descriptionCreditByLanguage = mapOf("en" to "English credit", "he" to "מקור עברי"))
        val hebrew = requireNotNull(saint.description("iw-IL"))
        assertEquals("קדוש", hebrew.title)
        assertEquals("סִימָן\n\nפסקה", hebrew.text)
        assertEquals("מקור עברי", hebrew.credit)
        assertNull(hebrew.sourceURL)
        val filipino = requireNotNull(saint.description("fil-PH"))
        assertEquals("Santo", filipino.title)
        assertEquals("https://example.org/tl", filipino.sourceURL)
        assertNull(filipino.credit)
        assertNull(saint.description("fr"))
        assertNull(saint.description("unknown"))
    }

    @Test fun metadataMapsDecodeAndEmptyBodiesOrUnsafeSourcesDoNotCreateLinks() {
        val feast = Json.decodeFromString<FeastDay>("""{"title":"Feast","rank":"Feast","observances":[
            {"title":"Saint","identity":"saint","descriptionByLanguage":{"en":"Biography","he":"  "},
             "descriptionSourceByLanguage":{"en":"javascript:alert(1)"},"descriptionCreditByLanguage":{"en":"Source credit"}}
        ]}""")
        assertEquals("Source credit", feast.saintDescriptions("syriac", "en").single().credit)
        assertNull(feast.saintDescriptions("syriac", "en").single().sourceURL)
        assertTrue(feast.saintDescriptions("syriac", "he").isEmpty())
    }
}
