package com.dkaluta.prosary.ui

import com.dkaluta.prosary.ui.readings.HomeReadingsMode
import com.dkaluta.prosary.ui.readings.ReadingsOpenRequest
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import java.time.LocalDate
import org.junit.Assert.*
import org.junit.Test

class HomeReadingsNavigationTest {
    @Test fun homeShortcutsSelectDailyCalendarAndBibleWithoutChangingTheSharedDate() {
        val selected = LocalDate.of(2026, 10, 3)
        val date = TodayBrowsingDate(selected.toEpochDay())
        for (mode in HomeReadingsMode.entries) {
            val request = ReadingsOpenRequest.latest(0, 0, 10, mode)!!
            assertEquals(mode.id, request.applyTo(date))
            assertEquals(selected.toEpochDay(), date.selectedEpochDay)
        }
    }

    @Test fun newerSystemWidgetOverridesAnOldHomeShortcutAndReturnsToTheCurrentDay() {
        val date = TodayBrowsingDate(LocalDate.of(2026, 10, 3).toEpochDay())
        val oldHome = ReadingsOpenRequest.latest(0, 0, 10, HomeReadingsMode.Bible)!!
        assertEquals("bible", oldHome.applyTo(date))
        val calendar = ReadingsOpenRequest.latest(20, 0, 10, HomeReadingsMode.Bible)!!
        assertEquals("calendar", calendar.applyTo(date))
        assertNull(date.selectedEpochDay)
        date.selectedEpochDay = LocalDate.of(2026, 10, 4).toEpochDay()
        val readings = ReadingsOpenRequest.latest(20, 30, 10, HomeReadingsMode.Bible)!!
        assertEquals("daily", readings.applyTo(date))
        assertNull(date.selectedEpochDay)
    }

    @Test fun aNewHomeShortcutAfterAWidgetPreservesTheReadersNewlyChosenDate() {
        val date = TodayBrowsingDate(LocalDate.of(2026, 10, 2).toEpochDay())
        val request = ReadingsOpenRequest.latest(20, 30, 40, HomeReadingsMode.Calendar)!!
        assertEquals("calendar", request.applyTo(date))
        assertEquals(LocalDate.of(2026, 10, 2).toEpochDay(), date.selectedEpochDay)
        assertNull(ReadingsOpenRequest.latest(0, 0, 0, HomeReadingsMode.Daily))
    }
}
