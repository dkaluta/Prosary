package com.dkaluta.prosary

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppAppearanceInstrumentedTest {
    @Test fun colorsPersistAndLauncherSwitchingKeepsExistingActivityLinksUsable() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        val preferences = context.getSharedPreferences("prosary_settings", Context.MODE_PRIVATE)
        val originalColor = preferences.getString("appColor", null)
        val originalSystemColors = if (preferences.contains("useSystemColors")) preferences.getBoolean("useSystemColors", true) else null
        try {
            preferences.edit().remove("appColor").remove("useSystemColors").commit()
            ActivityScenario.launch(MainActivity::class.java).use { scenario ->
                scenario.onActivity {
                    assertEquals("blue", AppSettings.appColor)
                    assertTrue(AppSettings.useSystemColors)
                    AppSettings.useSystemColors = false
                }
                for (color in AppColor.entries) {
                    scenario.onActivity { activity ->
                        assertTrue(LauncherIconController.select(activity, color.id))
                        assertEquals(color.id, preferences.getString("appColor", null))
                        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER).setPackage(context.packageName)
                        val matches = activity.packageManager.queryIntentActivities(launcher, 0)
                        assertEquals(listOf(color.launcherClass), matches.map { it.activityInfo.name })
                        assertNotEquals(PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                            activity.packageManager.getComponentEnabledSetting(ComponentName(activity, MainActivity::class.java)))
                    }
                    scenario.recreate()
                    scenario.onActivity {
                        assertEquals(color.id, AppSettings.appColor)
                        assertFalse(AppSettings.useSystemColors)
                    }
                }
            }
            // Launch through an alias, then change that alias while its target is still open.
            val launch = requireNotNull(context.packageManager.getLaunchIntentForPackage(context.packageName))
            ActivityScenario.launch<MainActivity>(launch).use { scenario ->
                scenario.onActivity { activity -> assertTrue(LauncherIconController.select(activity, "blue")) }
                scenario.onActivity { assertFalse(it.isFinishing) }
            }
            // Explicit intents persisted by earlier app versions keep their original target.
            ActivityScenario.launch(MainActivity::class.java).use { scenario ->
                scenario.onActivity { assertFalse(it.isFinishing) }
            }
        } finally {
            preferences.edit().apply {
                if (originalColor == null) remove("appColor") else putString("appColor", originalColor)
                if (originalSystemColors == null) remove("useSystemColors") else putBoolean("useSystemColors", originalSystemColors)
            }.commit()
            instrumentation.runOnMainSync {
                AppSettings.init(context)
                LauncherIconController.synchronize(context)
            }
        }
    }
}
