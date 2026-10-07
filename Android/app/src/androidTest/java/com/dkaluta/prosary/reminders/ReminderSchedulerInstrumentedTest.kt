package com.dkaluta.prosary.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.ParcelFileDescriptor
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.MultiDayRuns
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Calendar

/** Real AlarmManager checks: JVM fixtures cannot prove that Android accepts the idle policy. */
@RunWith(AndroidJUnit4::class)
class ReminderSchedulerInstrumentedTest {
    private val instrumentation get() = InstrumentationRegistry.getInstrumentation()
    private val context get() = instrumentation.targetContext

    private fun shell(command: String): String = ParcelFileDescriptor.AutoCloseInputStream(
        instrumentation.uiAutomation.executeShellCommand(command),
    ).bufferedReader().use { it.readText() }

    private fun pendingAlarmDump(): String = shell("dumpsys alarm")
        .substringAfter("pending alarms:").substringBefore("Pending user blocked background alarms:")
        .substringBefore("Past-due non-wakeup alarms:").substringBefore("Alarm Stats:")

    @Test fun reminderAlarmsRemainEligibleWhenThePhoneIsIdle() {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        fun operation(action: String, requestCode: Int) = PendingIntent.getBroadcast(context, requestCode,
            Intent(context, ReminderBroadcastReceiver::class.java).setAction(action),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val allowedAction = "com.dkaluta.prosary.TEST_IDLE_REMINDER"
        val ordinaryAction = "com.dkaluta.prosary.TEST_ORDINARY_ALARM"
        val allowed = operation(allowedAction, 85001)
        val ordinary = operation(ordinaryAction, 85002)
        try {
            val trigger = System.currentTimeMillis() + 3_600_000
            ReminderScheduler.arm(context, trigger, allowed)
            manager.set(AlarmManager.RTC_WAKEUP, trigger, ordinary)
            assertTrue(shell("cmd deviceidle force-idle").contains("idle", ignoreCase = true))
            val dump = pendingAlarmDump()
            fun policy(action: String): String = dump.substringAfter("tag=*walarm*:$action")
                .lineSequence().first { it.contains("policyWhenElapsed:") }
            fun isDeferred(action: String): Boolean = policy(action)
                .substringAfter("device_idle=").substringBefore(' ').startsWith("+")
            assertFalse("Reminder must remain eligible in Doze: ${policy(allowedAction)}", isDeferred(allowedAction))
            assertTrue("Control alarm must be deferred in Doze: ${policy(ordinaryAction)}", isDeferred(ordinaryAction))
        } finally {
            shell("cmd deviceidle unforce")
            manager.cancel(allowed)
            manager.cancel(ordinary)
            allowed.cancel()
            ordinary.cancel()
        }
    }

    @Test fun persistedSeriesRegainsItsAlarmsAfterTheKernelAlarmsAreLost() {
        AppSettings.init(context)
        PrayerPackStore.initialize(context.assets)
        val preferences = context.getSharedPreferences("multi_day_runs", Context.MODE_PRIVATE)
        val previous = preferences.getString("runs", null)
        val devotionId = "oAntiphons"
        val dayCount = PrayerPackStore.definition(devotionId)!!.days!!.size
        fun seriesAlarmCount(): Int = Regex("tag=\\*walarm\\*:com\\.dkaluta\\.prosary/\\.reminders\\.ReminderBroadcastReceiver")
            .findAll(pendingAlarmDump()).count()
        try {
            preferences.edit().remove("runs").commit()
            val baseline = seriesAlarmCount()
            val tomorrow = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
            MultiDayRuns.startFresh(context, devotionId, tomorrow)
            ReminderScheduler.refreshSeries(context, devotionId)
            assertEquals(baseline + dayCount, seriesAlarmCount())
            ReminderScheduler.removeSeries(context, devotionId, dayCount)
            assertEquals(baseline, seriesAlarmCount())
            ReminderScheduler.rescheduleAll(context, emptyList())
            assertEquals("Reboot/app-update restoration includes persisted series", baseline + dayCount, seriesAlarmCount())
        } finally {
            ReminderScheduler.removeSeries(context, devotionId, dayCount)
            if (previous == null) preferences.edit().remove("runs").commit()
            else preferences.edit().putString("runs", previous).commit()
        }
    }
}
