package com.dkaluta.prosary.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.services.AppServices
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Re-schedules every enabled reminder after a device reboot — AlarmManager alarms don't survive
 * it, unlike iOS's UNUserNotificationCenter, which persists at the OS level (no iOS equivalent to
 * mirror; a necessary Android-side addition for real parity). Reads directly from Room since
 * there's no live AppServices/Activity at boot time. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIMEZONE_CHANGED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) return
        if (intent.action == Intent.ACTION_TIMEZONE_CHANGED) java.util.TimeZone.setDefault(null)

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AppSettings.init(context)
                val services = AppServices.create(context)
                ReminderScheduler.rescheduleAll(context, services.presetStore.all())
            } finally {
                pendingResult.finish()
            }
        }
    }
}
