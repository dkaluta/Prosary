package com.dkaluta.prosary.widgets

import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.PrayerRunProgress
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date
import java.util.TimeZone
import org.junit.Assert.*
import org.junit.Test

class WidgetModelsTest {
    @Test fun linksAcceptOnlyKnownDestinationsAndSafeSavedIdentities() {
        assertEquals(WidgetDestination.Today, WidgetDestination.parse("prosary://widget/today"))
        assertEquals(WidgetDestination.Rosary, WidgetDestination.parse("prosary://widget/rosary"))
        assertEquals(WidgetDestination.SavedPrayer("abc-123"), WidgetDestination.parse("prosary://widget/prayer/abc-123"))
        listOf(null, "https://widget/today", "prosary://other/today", "prosary://widget/prayer/", "prosary://widget/prayer/../today",
            "prosary://widget/prayer/abc%2Fdef", "prosary://widget/today?prayer=other", "prosary://widget/today#other").forEach {
            assertNull(it, WidgetDestination.parse(it))
        }
    }

    @Test fun midnightUsesTheNextCivilDayAcrossDaylightSavingChanges() {
        val zone = ZoneId.of("America/New_York")
        assertEquals(Instant.parse("2026-03-09T04:00:00Z"), nextWidgetMidnight(Instant.parse("2026-03-08T05:00:00Z"), zone))
        assertEquals(Instant.parse("2026-11-02T05:00:00Z"), nextWidgetMidnight(Instant.parse("2026-11-01T04:00:00Z"), zone))
        assertEquals(Instant.parse("2026-09-10T10:00:00Z"), nextWidgetMidnight(Instant.parse("2026-09-10T09:59:59Z"), ZoneId.of("Pacific/Kiritimati")))
    }

    @Test fun progressRejectsChangedOptionsInvalidPositionsAndYesterdaysRosary() {
        val today = LocalDate.of(2026, 9, 10)
        val checkpoint = PrayerRunProgress(4, "fr", today.toString(), "same")
        assertEquals(WidgetProgress(5, 20), WidgetProgress.validated(checkpoint, 20, "same", true, today))
        assertNull(WidgetProgress.validated(checkpoint, 20, "changed", true, today))
        assertNull(WidgetProgress.validated(checkpoint.copy(stepIndex = 20), 20, "same", false, today))
        assertNull(WidgetProgress.validated(checkpoint.copy(stepIndex = 0), 20, "same", false, today))
        assertNull(WidgetProgress.validated(checkpoint, 20, "same", true, today.plusDays(1)))
        assertEquals(WidgetProgress(5, 20), WidgetProgress.validated(checkpoint, 20, "same", false, today.plusDays(1)))
        assertEquals(WidgetProgress(5, null), WidgetProgress.validated(checkpoint, Int.MAX_VALUE, "same", false, today, true))
    }

    @Test fun todayUsesSelectedRiteAndInterfaceLanguageAndHonorsHiddenRows() {
        val originalCalendar = AppSettings.feastCalendarId
        val originalFeast = AppSettings.showTodayFeast
        val originalIntention = AppSettings.showTodayIntention
        val originalTorah = AppSettings.showTodayTorahPortion
        try {
            TodayInfoStore.resetForTesting()
            TodayInfoStore.initialize { name -> File("src/main/assets/data/$name.json").takeIf(File::exists)?.inputStream() }
            AppSettings.feastCalendarId = "roman"
            AppSettings.showTodayFeast = true
            AppSettings.showTodayIntention = true
            AppSettings.showTodayTorahPortion = false
            val feast = TodayWidgetContent.load(LocalDate.of(2026, 9, 8), "fr")
            assertNotNull(feast.feast)
            assertNotNull(feast.readings)
            assertNull(feast.torah)
            assertNotEquals(feast.feast, TodayWidgetContent.load(LocalDate.of(2026, 9, 8), "en").feast)
            AppSettings.showTodayFeast = false
            AppSettings.showTodayIntention = false
            val hidden = TodayWidgetContent.load(LocalDate.of(2026, 9, 8), "fr")
            assertNull(hidden.feast)
            assertNull(hidden.intention)
            assertNotNull(hidden.readings)
            AppSettings.feastCalendarId = "ugcc"
            val byzantine = TodayWidgetContent.load(LocalDate.of(2026, 9, 10), "en")
            assertEquals("Day 10 of September", byzantine.day)
            assertNull(TodayWidgetContent.load(LocalDate.of(2099, 1, 1), "en").readings)
        } finally {
            AppSettings.feastCalendarId = originalCalendar
            AppSettings.showTodayFeast = originalFeast
            AppSettings.showTodayIntention = originalIntention
            AppSettings.showTodayTorahPortion = originalTorah
        }
    }

    @Test fun rosaryMysteriesAndSeasonsChangeAtLocalMidnight() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Jerusalem"))
            val calendar = MockLiturgicalCalendar()
            // Thursday has begun locally while UTC is still Wednesday.
            assertEquals(MysteryGroup.Luminous, calendar.mysteryGroup(Date.from(Instant.parse("2026-09-09T21:01:00Z"))))
            assertTrue(calendar.isEasterSeason(Date.from(Instant.parse("2026-04-04T21:01:00Z"))))
            TimeZone.setDefault(TimeZone.getTimeZone("America/Los_Angeles"))
            // A live provider follows a new zone; Wednesday still continues locally.
            assertEquals(MysteryGroup.Glorious, calendar.mysteryGroup(Date.from(Instant.parse("2026-09-10T01:00:00Z"))))
            assertFalse(calendar.isEasterSeason(Date.from(Instant.parse("2026-04-05T01:00:00Z"))))
        } finally {
            TimeZone.setDefault(original)
        }
    }
}
