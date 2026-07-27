package com.dkaluta.prosary.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.room.Room
import com.dkaluta.prosary.persistence.AppDatabase
import com.dkaluta.prosary.persistence.MIGRATION_1_2
import com.dkaluta.prosary.persistence.RoomPresetStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** Re-schedules every enabled reminder after a device reboot — AlarmManager alarms don't survive
 * it, unlike iOS's UNUserNotificationCenter, which persists at the OS level (no iOS equivalent to
 * mirror; a necessary Android-side addition for real parity). Reads directly from Room since
 * there's no live AppServices/Activity at boot time. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return

        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val db = Room.databaseBuilder(context.applicationContext, AppDatabase::class.java, "prosary.db")
                    .addMigrations(MIGRATION_1_2)
                    .build()
                val store = RoomPresetStore(db.presetDao())
                ReminderScheduler.rescheduleAll(context, store.all())
            } finally {
                pendingResult.finish()
            }
        }
    }
}
