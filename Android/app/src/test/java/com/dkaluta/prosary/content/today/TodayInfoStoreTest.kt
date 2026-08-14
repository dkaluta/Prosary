package com.dkaluta.prosary.content.today

import com.dkaluta.prosary.models.AppSettings
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test

/** Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
 * movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
 * Roman Calendar), the switchable-calendar registry, the Pope's monthly intention, and the
 * graceful out-of-range null that hides the row. Mirrors iOS's TodayInfoStoreTests.swift. */
class TodayInfoStoreTest {
    companion object {
        @BeforeClass
        @JvmStatic
        fun loadData() {
            TodayInfoStore.initialize { name ->
                val file = File("src/main/assets/data/$name.json")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    /** The store resolves the selection live on every lookup, so pinning the setting back to
     * "follow the registry default" is the whole reset. */
    @Before
    fun resetCalendarSelection() {
        AppSettings.feastCalendarId = ""
    }

    private fun date(string: String): Date =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(string)!!

    @Test
    fun fixedSolemnityResolves() {
        val feast = TodayInfoStore.feast(date("2026-12-25"))
        assertEquals("Christmas", feast?.title)
        assertEquals("Solemnity", feast?.rank)
    }

    @Test
    fun movableFeastIsBakedInPerYear() {
        // Easter falls on April 5 in 2026; Good Friday 2027 is March 26 — both must resolve.
        assertEquals("Solemnity", TodayInfoStore.feast(date("2026-04-05"))?.rank)
        assertNotNull(TodayInfoStore.feast(date("2027-03-26")))
    }

    /** The Holy Land calendar's own principal feast overlays the General Roman Calendar — in
     * 2026 October 25 is a Sunday of Ordinary Time in the GRC, but the diocese's patronal
     * solemnity takes precedence. */
    @Test
    fun latinPatriarchatePropersOverlayTheGeneralCalendar() {
        val feast = TodayInfoStore.feast(date("2026-10-25"))
        assertEquals("Our Lady, Queen of Palestine and of the Holy Land", feast?.title)
        assertEquals("Solemnity", feast?.rank)

        assertEquals(
            "Dedication of the Basilica of the Holy Sepulchre",
            TodayInfoStore.feast(date("2026-07-15"))?.title,
        )
    }

    @Test
    fun ferialDayHasNoFeast() {
        assertNull(TodayInfoStore.feast(date("2026-07-27")))
    }

    @Test
    fun dateOutsideTheGeneratedYearsHasNoFeast() {
        assertNull(TodayInfoStore.feast(date("2031-12-25")))
    }

    // Switchable calendars

    @Test
    fun calendarRegistryListsTheShippedCalendarsInPickerOrder() {
        assertEquals(listOf("lpj", "roman", "roman1962"), TodayInfoStore.calendars.map { it.id })
        assertEquals("lpj", TodayInfoStore.selectedCalendarId)
    }

    /** October 25, 2026 wears three different faces: the LPJ's patronal solemnity, a plain
     * Sunday of Ordinary Time in the general calendar, and Christ the King in the 1962 books
     * (which place the feast on October's last Sunday). */
    @Test
    fun switchingCalendarsResolvesEachCalendarsOwnFeast() {
        assertEquals(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )

        AppSettings.feastCalendarId = "roman"
        assertEquals(
            "30th Sunday of Ordinary Time",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )

        AppSettings.feastCalendarId = "roman1962"
        val vetus = TodayInfoStore.feast(date("2026-10-25"))
        assertEquals("Christ the King", vetus?.title)
        assertEquals("1st Class", vetus?.rank)
    }

    @Test
    fun unknownCalendarIdFallsBackToTheDefault() {
        AppSettings.feastCalendarId = "narnia"
        assertEquals("lpj", TodayInfoStore.selectedCalendarId)
        assertEquals(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )
    }

    @Test
    fun vetusOrdoKeepsSeptuagesimaAndClassRanks() {
        AppSettings.feastCalendarId = "roman1962"
        val septuagesima = TodayInfoStore.feast(date("2026-02-01"))
        assertEquals("Septuagesima Sunday", septuagesima?.title)
        assertEquals("2nd Class", septuagesima?.rank)
        assertEquals("1st Class", TodayInfoStore.feast(date("2026-12-25"))?.rank)
    }

    @Test
    fun monthIntentionResolves() {
        val intention = TodayInfoStore.intention(date("2026-07-27"))
        assertEquals("For respect for human life", intention?.title)
        assertTrue(intention?.text?.contains("human life in all its stages") ?: false)
    }

    @Test
    fun monthOutsideThePublishedListHasNoIntention() {
        assertNull(TodayInfoStore.intention(date("2031-05-01")))
    }
}
