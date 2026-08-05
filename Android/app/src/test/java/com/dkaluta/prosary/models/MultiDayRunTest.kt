package com.dkaluta.prosary.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.concurrent.TimeUnit

/** The rules that make a multi-day devotion behave like a calendar rather than a counter. */
class MultiDayRunTest {
    private val nine = 9
    private val start = System.currentTimeMillis()
    private fun day(offset: Int) = start + TimeUnit.DAYS.toMillis(offset.toLong())

    @Test
    fun prayingTwiceInOneDayDoesNotAdvance() {
        val run = MultiDayRun("novena", start).recordingPrayed(0, start)
        assertTrue(run.hasPrayedToday(start))
        assertEquals(0, run.dueDay(nine, start))
        assertEquals(1, run.nextUnprayedDay(nine))
    }

    @Test
    fun theNextCalendarDayOffersTheNextDay() {
        val run = MultiDayRun("novena", start).recordingPrayed(0, start)
        assertFalse(run.hasPrayedToday(day(1)))
        assertEquals(MultiDayRun.Resumption.Resume(1), run.resumption(nine, day(1)))
        assertNull(run.missedDay(nine, day(1)))
    }

    @Test
    fun aMissedDayOffersBothItAndTheCalendarDay() {
        val run = MultiDayRun("novena", start).recordingPrayed(0, start)
        assertEquals(1, run.missedDay(nine, day(2)))
        assertEquals(2, run.dueDay(nine, day(2)))
        assertEquals(MultiDayRun.Resumption.Choose(1, 2), run.resumption(nine, day(2)))
    }

    @Test
    fun theDayCountComesFromTheDevotion() {
        val run = MultiDayRun("triduum", start)
            .recordingPrayed(0, start).recordingPrayed(1, day(1)).recordingPrayed(2, day(2))
        assertTrue(run.isComplete(3))
        assertEquals(MultiDayRun.Resumption.Complete, run.resumption(3, day(2)))
        assertFalse(run.isComplete(33))
    }

    @Test
    fun dueDayNeverRunsPastTheLastDay() {
        assertEquals(8, MultiDayRun("novena", start).dueDay(nine, day(400)))
    }
}
