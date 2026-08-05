package com.dkaluta.prosary.reminders

import com.dkaluta.prosary.models.MultiDayRun
import java.util.Calendar
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Test

/** One prompt per remaining day, never for a day already prayed or already past. Mirrors iOS's
 * MultiDaySeriesReminderTests. */
class SeriesReminderTest {
    private fun at(year: Int, month: Int, day: Int, hour: Int = 9): Long =
        Calendar.getInstance().apply {
            clear()
            set(year, month - 1, day, hour, 0, 0)
        }.timeInMillis

    @Test
    fun everyUnprayedDayGetsOnePromptOnItsOwnDate() {
        val run = MultiDayRun("oAntiphons", at(2026, 12, 17))
        val pending = ReminderScheduler.pendingSeriesDays(run, 7, 18, 0, now = at(2026, 12, 17, 8))

        assertEquals(listOf(0, 1, 2, 3, 4, 5, 6), pending.map { it.first })
        assertEquals(at(2026, 12, 17, 18), pending.first().second)
        assertEquals(at(2026, 12, 23, 18), pending.last().second)
    }

    @Test
    fun prayedAndPastDaysAreSkipped() {
        val start = at(2026, 12, 17)
        val run = MultiDayRun("oAntiphons", start).recordingPrayed(0, start + TimeUnit.HOURS.toMillis(19))
        // Two evenings in: day 0 was prayed, day 1's prompt has already fired.
        val pending = ReminderScheduler.pendingSeriesDays(run, 7, 18, 0, now = at(2026, 12, 18, 20))

        assertEquals(listOf(2, 3, 4, 5, 6), pending.map { it.first })
    }

    @Test
    fun theBundlesSuggestedTimeWinsAndNonsenseFallsBack() {
        assertEquals(7 to 30, ReminderScheduler.reminderTime("07:30"))
        assertEquals(18 to 0, ReminderScheduler.reminderTime(null))
        assertEquals(18 to 0, ReminderScheduler.reminderTime("25:00"))
    }
}
