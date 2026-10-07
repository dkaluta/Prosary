package com.dkaluta.prosary.reminders

import android.content.Context
import android.os.Build
import android.view.accessibility.AccessibilityNodeInfo
import androidx.activity.compose.setContent
import androidx.compose.material3.Text
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MultiDayRuns
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeFalse
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SeriesReminderPermissionInstrumentedTest {
    @Test fun finishingThePrayerKeepsTheSeriesPermissionResultAlive() {
        assumeTrue(Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        assumeFalse(ReminderScheduler.hasNotificationPermission(context))
        PrayerPackStore.initialize(context.assets)
        val preferences = context.getSharedPreferences("multi_day_runs", Context.MODE_PRIVATE)
        val previous = preferences.getString("runs", null)
        MultiDayRuns.startFresh(context, "oAntiphons")
        try {
            ActivityScenario.launch(MainActivity::class.java).use { scenario ->
                scenario.onActivity {
                    it.requestSeriesReminderPermission("oAntiphons")
                    // The flow that requested permission is already gone by the result.
                    it.setContent { Text("Prayer complete") }
                }
                fun allowButton(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
                    if (node == null) return null
                    if (node.viewIdResourceName?.endsWith(":id/permission_allow_button") == true) return node
                    for (index in 0 until node.childCount) allowButton(node.getChild(index))?.let { return it }
                    return null
                }
                val deadline = System.currentTimeMillis() + 10_000
                var allow: AccessibilityNodeInfo? = null
                while (allow == null && System.currentTimeMillis() < deadline) {
                    allow = allowButton(instrumentation.uiAutomation.rootInActiveWindow)
                    if (allow == null) Thread.sleep(50)
                }
                assertTrue("Series completion must request notification permission", allow != null)
                assertTrue(allow!!.performAction(AccessibilityNodeInfo.ACTION_CLICK))
                while (!ReminderScheduler.hasNotificationPermission(context) && System.currentTimeMillis() < deadline) Thread.sleep(50)
                assertTrue("Permission result survives removal of the prayer flow", ReminderScheduler.hasNotificationPermission(context))
            }
        } finally {
            ReminderScheduler.removeSeries(context, "oAntiphons", 7)
            if (previous == null) preferences.edit().remove("runs").commit()
            else preferences.edit().putString("runs", previous).commit()
        }
    }
}
