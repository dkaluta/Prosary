package com.dkaluta.prosary.content.today

import java.time.LocalDate
import java.time.ZoneId
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class TodayNavigationTest {
    @Test fun pickerRoundTripsCivilDateAcrossTimeZonesAndDst() {
        val original = TimeZone.getDefault()
        try {
            for (zone in listOf("Asia/Jerusalem", "America/Los_Angeles", "Pacific/Kiritimati")) {
                TimeZone.setDefault(TimeZone.getTimeZone(zone))
                for (raw in listOf("2026-03-27", "2026-11-01", "2027-01-01")) {
                    val day = LocalDate.parse(raw)
                    assertEquals(day, TodayDateSelection.fromPickerMillis(TodayDateSelection.pickerMillis(day)))
                    assertEquals(day, TodayDateSelection.lookupDate(day).toInstant().atZone(ZoneId.of(zone)).toLocalDate())
                }
            }
        } finally { TimeZone.setDefault(original) }
    }

    @Test fun onlyModernRomanWeekdaysUseLatinSeasonWeeks() {
        val date = TodayDateSelection.lookupDate(LocalDate.parse("2026-09-07"))
        for (calendar in listOf("lpj", "roman")) {
            assertTrue(TodayInfoStore.liturgicalDayInfo(date, calendar).english.contains("Ordinary Time"))
        }
        for (calendar in listOf("roman1962", "ugcc", "syriac", "future-eastern")) {
            val heading = TodayInfoStore.liturgicalDayInfo(date, calendar)
            assertEquals("Day 7 of September", heading.english)
            assertEquals(TodayTranslationLanguage.supportedCodes.toSet(), heading.byLanguage.keys)
            assertTrue(heading.byLanguage.values.none { it.contains("Ordinary Time") })
        }
        assertFalse(TodayInfoStore.shouldShowLiturgicalDay(TodayDateSelection.lookupDate(LocalDate.parse("2026-09-06"))))
        assertTrue(TodayInfoStore.shouldShowLiturgicalDay(date))
    }
}
