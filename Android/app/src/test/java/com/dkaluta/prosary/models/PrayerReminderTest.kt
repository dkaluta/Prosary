package com.dkaluta.prosary.models

import java.util.Calendar
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerReminderTest {

    // MARK: - Basic properties

    @Test
    fun defaultMinuteIsZero() {
        val r = PrayerReminder(hour = 9)
        assertEquals(9, r.hour)
        assertEquals(0, r.minute)
        assertTrue(r.isEnabled)
    }

    @Test
    fun displayTimeIsNonEmpty() {
        val r = PrayerReminder(hour = 6, minute = 0)
        assertTrue(r.displayTime.isNotEmpty())
    }

    @Test
    fun displayTimeReflectsHourAndMinute() {
        val r = PrayerReminder(hour = 14, minute = 30)
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 14)
            set(Calendar.MINUTE, 30)
        }
        val expected = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault()).format(cal.time)
        assertEquals(expected, r.displayTime)
    }

    // MARK: - Prayer.reminders integration

    @Test
    fun prayerRemindersDefaultEmpty() {
        val prayer = Prayer(kind = PrayerKind.Rosary)
        assertTrue(prayer.reminders.isEmpty())
    }

    @Test
    fun prayerCanHoldReminders() {
        val prayer = Prayer(kind = PrayerKind.Angelus).copy(
            reminders = listOf(PrayerReminder(hour = 6), PrayerReminder(hour = 12), PrayerReminder(hour = 18)),
        )
        assertEquals(3, prayer.reminders.size)
        assertEquals(listOf(6, 12, 18), prayer.reminders.map { it.hour })
    }

    @Test
    fun disabledReminderStaysDisabledAfterCopy() {
        val original = PrayerReminder(hour = 18, minute = 45, isEnabled = false)
        val copy = original.copy()
        assertEquals(original.id, copy.id)
        assertEquals(18, copy.hour)
        assertEquals(45, copy.minute)
        assertFalse(copy.isEnabled)
    }
}
