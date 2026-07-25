package com.dkaluta.Prosary.reminders

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import java.util.Calendar

/**
 * Schedules/cancels daily repeating local notifications for a [Prayer]'s saved reminders, via
 * [AlarmManager]. Inexact `setRepeating` (not `setExactAndAllowWhileIdle`) is used deliberately —
 * a prayer reminder doesn't need to-the-second precision, and exact alarms require either a
 * hard-to-qualify special app category or a user trip to Settings on API 31+.
 */
object ReminderScheduler {
    const val NotificationChannelId = "prayer_reminders"
    const val ExtraPrayerId = "prayerId"
    const val ExtraPrayerName = "prayerName"
    const val ExtraPrayerKind = "prayerKind"

    fun createNotificationChannel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Idempotent: creating a channel that already exists with the same id is a no-op.
        val channel = NotificationChannel(NotificationChannelId, "Prayer Reminders", NotificationManager.IMPORTANCE_DEFAULT)
        manager.createNotificationChannel(channel)
    }

    fun hasNotificationPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /** Replaces all pending alarms for [prayer] with its current enabled reminders. */
    fun schedule(context: Context, prayer: Prayer) {
        cancelAll(context, prayer)
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        for (reminder in prayer.reminders) {
            if (!reminder.isEnabled) continue
            val triggerAt = nextTriggerTimeMillis(reminder.hour, reminder.minute)
            val pendingIntent = pendingIntentFor(context, prayer, reminder.id)
            alarmManager.setRepeating(AlarmManager.RTC_WAKEUP, triggerAt, AlarmManager.INTERVAL_DAY, pendingIntent)
        }
    }

    /** Removes all pending alarms for [prayer]. */
    fun cancelAll(context: Context, prayer: Prayer) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        for (reminder in prayer.reminders) {
            alarmManager.cancel(pendingIntentFor(context, prayer, reminder.id))
        }
    }

    /** Re-schedules every enabled reminder across every favorite — used after device reboot,
     * since AlarmManager alarms don't survive it (unlike iOS's UNUserNotificationCenter, which
     * persists at the OS level). */
    fun rescheduleAll(context: Context, prayers: List<Prayer>) {
        for (prayer in prayers) {
            if (prayer.reminders.any { it.isEnabled }) schedule(context, prayer)
        }
    }

    /** Notification body text per devotion — mirrors iOS's `ReminderScheduler.notificationBody(for:)`. */
    fun notificationBody(kind: PrayerKind): String = when (kind) {
        PrayerKind.Rosary -> "Time to pray the Rosary."
        PrayerKind.Angelus -> "The Angelus bell is ringing."
        PrayerKind.JesusPrayer -> "Time for the Jesus Prayer."
    }

    private fun pendingIntentFor(context: Context, prayer: Prayer, reminderId: String): PendingIntent {
        val intent = Intent(context, ReminderBroadcastReceiver::class.java).apply {
            putExtra(ExtraPrayerId, prayer.id)
            putExtra(ExtraPrayerName, prayer.name)
            putExtra(ExtraPrayerKind, prayer.kind.name)
        }
        val requestCode = (prayer.id + reminderId).hashCode()
        return PendingIntent.getBroadcast(
            context, requestCode, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun nextTriggerTimeMillis(hour: Int, minute: Int): Long {
        val cal = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (cal.timeInMillis <= System.currentTimeMillis()) {
            cal.add(Calendar.DAY_OF_YEAR, 1)
        }
        return cal.timeInMillis
    }
}
