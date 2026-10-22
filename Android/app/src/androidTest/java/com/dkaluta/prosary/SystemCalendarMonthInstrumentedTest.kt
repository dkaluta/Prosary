package com.dkaluta.prosary

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dkaluta.prosary.ui.readings.SystemCalendarMonth
import java.time.LocalDate
import java.util.Locale
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SystemCalendarMonthInstrumentedTest {
    @Test fun regionalWeekStartChangesPaddingWithoutChangingCivilDates() {
        val date = LocalDate.of(2024, 2, 15)
        val sunday = SystemCalendarMonth(date, Locale.US, Locale.UK)
        val monday = SystemCalendarMonth(date, Locale.UK, Locale.US)
        assertEquals(4, sunday.days.indexOfFirst { it != null })
        assertEquals(3, monday.days.indexOfFirst { it != null })
        assertEquals("Sunday", sunday.weekdays.first().second)
        assertEquals("Monday", monday.weekdays.first().second)
        assertEquals(sunday.days.filterNotNull(), monday.days.filterNotNull())
        assertEquals(29, sunday.days.filterNotNull().size)
    }

    @Test fun hebrewLeapMonthsKeepCivilDatesAndNativeMonthBoundaries() {
        val locale = Locale.forLanguageTag("he-IL-u-ca-hebrew")
        val first = SystemCalendarMonth(LocalDate.of(2024, 2, 20), locale, locale)
        val second = SystemCalendarMonth(LocalDate.of(2024, 3, 20), locale, locale)
        assertEquals(LocalDate.of(2024, 2, 10), first.start)
        assertEquals(LocalDate.of(2024, 3, 11), first.adjacentMonth(1))
        assertEquals(first.adjacentMonth(1), second.start)
        assertEquals(30, first.days.filterNotNull().size)
        assertEquals(29, second.days.filterNotNull().size)
        assertEquals(1, first.dayOfMonth(first.start))
        assertEquals(1, second.dayOfMonth(second.start))
        assertEquals(first.start, second.adjacentMonth(-1))
        assertTrue(second.title.contains("5784") || second.title.contains("תשפ"))
    }
}
