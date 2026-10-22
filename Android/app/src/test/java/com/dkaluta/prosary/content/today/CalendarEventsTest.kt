package com.dkaluta.prosary.content.today

import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class CalendarEventsTest {
    @Test fun observancesRemainSeparateAndDescriptionsNeverBorrowAnotherLanguage() {
        val date = LocalDate.of(2026, 10, 14)
        val day = FeastDay("Parent", "Memorial", observances = listOf(
            FeastObservance("First", "same-id", descriptionByLanguage = mapOf("he" to "Exact source prose")),
            FeastObservance("Second", "same-id", descriptionByLanguage = mapOf("en" to "Other source prose"))))
        val events = CalendarEvents.events(date, day)
        assertEquals(listOf("First", "Second"), events.map { it.title("en") })
        assertEquals(2, events.map { it.id }.distinct().size)
        assertNull(events.first().description("en"))
        assertEquals("Exact source prose", events.first().description("he")?.text)
        assertEquals("Parent", CalendarEvents.events(date, FeastDay("Parent", "Sunday")).single().title("en"))
        assertTrue(CalendarEvents.events(date, null).isEmpty())
    }

    @Test fun scriptureOfTheDayUsesTheFirstSourceGospelWithoutChangingSourceOrder() {
        val reading = ReadingCitation("reading", "First", "First source reading")
        val gospel = ReadingCitation("gospel", "Gospel", "First source Gospel")
        val later = ReadingCitation("gospel", "Later", "Later Gospel")
        val readings = listOf(reading, gospel, later)
        assertEquals(gospel, ScriptureOfDay.citation(readings))
        assertEquals(listOf(reading, gospel, later), readings)
        assertEquals(reading, ScriptureOfDay.citation(listOf(reading)))
        assertNull(ScriptureOfDay.citation(emptyList()))
    }
}
