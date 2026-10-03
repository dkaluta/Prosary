package com.dkaluta.prosary.content.today

import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class FeastObservanceTest {
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
