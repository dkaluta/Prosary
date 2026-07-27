package com.dkaluta.prosary.content.today

import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/** Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
 * movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
 * Roman Calendar), the Pope's monthly intention, and the graceful out-of-range null that hides
 * the row. Mirrors iOS's TodayInfoStoreTests.swift. */
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
