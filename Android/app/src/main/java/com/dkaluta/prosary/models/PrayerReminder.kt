package com.dkaluta.prosary.models

import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.UUID

/** A single daily repeating reminder time attached to a [Prayer]. Scheduled via
 * [com.dkaluta.prosary.reminders.ReminderScheduler]. */
data class PrayerReminder(
    val id: String = UUID.randomUUID().toString(),
    var hour: Int, // 0-23
    var minute: Int = 0, // 0-59
    var isEnabled: Boolean = true,
) {
    /** Locale-formatted short time (e.g. "6:00 AM"), for display in the Favorites editor. */
    val displayTime: String
        get() {
            val cal = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
            }
            return SimpleDateFormat("h:mm a", Locale.getDefault()).format(cal.time)
        }
}
