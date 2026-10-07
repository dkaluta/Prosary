package com.dkaluta.prosary.content.today

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.*
import org.junit.Test

class MissionCalendarTest {
    @Test fun bundledProvisionalCalendarHasExactLanguageReflectionsAndRawSource() {
        val json = Json { ignoreUnknownKeys = true }
        val data = json.parseToJsonElement(File("src/main/assets/data/feasts-mission-provisional.json").readText()).jsonObject
        val days = data.getValue("days").jsonObject
        assertEquals(365, days.size)
        assertFalse(days.keys.any { it.startsWith("2027-") })
        val feast = json.decodeFromJsonElement(FeastDay.serializer(), days.getValue("2026-01-01"))
        assertEquals(3, feast.reflections("iw-IL").size)
        assertTrue(feast.reflections("en").isEmpty())
        assertTrue(feast.reflections("fr").isEmpty())
        val observance = feast.observances.first()
        assertTrue(observance.sourceDescriptionByLanguage!!.getValue("he").contains("נקודה לערעור:"))
        assertTrue(observance.descriptionByLanguage!!.getValue("he").contains("נקודה להרהור:"))
        assertFalse(observance.reflection("he")!!.text.contains("על החג והיום"))
        assertTrue(observance.reflection("he")!!.credit!!.contains("תקופת ניסיון"))
        assertTrue(observance.categories.isEmpty())
        assertEquals("FREQ=YEARLY", observance.sourceRecurrence)
        assertEquals(observance.reflectionByLanguage!!.getValue("he"),
            observance.sections.single { it.id == "reflection" }.textByLanguage.getValue("he"))
    }

    @Test fun reflectionDoesNotRequireBiographyOrBorrowSourceCredit() {
        val observance = FeastObservance("Source", "identity", reflectionByLanguage = mapOf("he" to "מחשבה"),
            descriptionCreditByLanguage = mapOf("en" to "English credit"))
        assertEquals("מחשבה", observance.reflection("he")?.text)
        assertNull(observance.reflection("he")?.credit)
        assertNull(observance.reflection("en"))
        assertNull(observance.description("he"))
    }
}
