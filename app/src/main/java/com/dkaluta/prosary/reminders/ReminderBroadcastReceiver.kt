package com.dkaluta.prosary.reminders

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.PrayerKind

/** Fired by the alarm [ReminderScheduler.schedule] sets up; builds and posts the notification
 * directly from Intent extras — no live app process or database read needed, mirroring iOS's
 * `ReminderScheduler` using `content.userInfo`. */
class ReminderBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Defensive: the channel is also created at app startup, but a device that rebooted
        // straight into this receiver (before MainActivity ever ran) needs it created here too.
        ReminderScheduler.createNotificationChannel(context)

        val prayerId = intent.getStringExtra(ReminderScheduler.ExtraPrayerId) ?: return
        val prayerName = intent.getStringExtra(ReminderScheduler.ExtraPrayerName) ?: return
        val kind = runCatching {
            PrayerKind.valueOf(intent.getStringExtra(ReminderScheduler.ExtraPrayerKind) ?: "")
        }.getOrDefault(PrayerKind.Rosary)

        if (!ReminderScheduler.hasNotificationPermission(context)) return

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentIntent = PendingIntent.getActivity(
            context, prayerId.hashCode(), openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, ReminderScheduler.NotificationChannelId)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(prayerName)
            .setContentText(ReminderScheduler.notificationBody(kind))
            .setAutoCancel(true)
            .setContentIntent(contentIntent)
            .build()

        NotificationManagerCompat.from(context).notify(prayerId.hashCode(), notification)
    }
}
