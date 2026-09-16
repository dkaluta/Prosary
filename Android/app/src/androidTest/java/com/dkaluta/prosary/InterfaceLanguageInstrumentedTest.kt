package com.dkaluta.prosary

import android.content.Context
import android.view.View
import androidx.appcompat.app.AppCompatDelegate
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.InterfaceLanguage
import com.dkaluta.prosary.models.Prayer
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class InterfaceLanguageInstrumentedTest {
    @Test fun nativeLocaleChangesRecreateWithTranslatedResourcesRtlAndIndependentSavedPrayers() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val preferences = instrumentation.targetContext.getSharedPreferences("prosary_settings", Context.MODE_PRIVATE)
        val oldDefault = preferences.getString("defaultLanguageCode", null)
        preferences.edit().putString("defaultLanguageCode", "arc").commit()
        var original = ""
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            try {
                scenario.onActivity { original = AppCompatDelegate.getApplicationLocales().toLanguageTags() }
                val explicit = Prayer(languageCode = "he-x-gamliel")
                for (code in InterfaceLanguage.codes + "") {
                    // Use the same action as the Settings picker; the framework recreates the activity.
                    scenario.onActivity { InterfaceLanguageController.select(code) }
                    instrumentation.waitForIdleSync()
                    var ready = false
                    repeat(100) {
                        if (!ready) {
                            scenario.onActivity { activity ->
                                val configured = InterfaceLanguage.effective((0 until activity.resources.configuration.locales.size()).map {
                                    activity.resources.configuration.locales[it].toLanguageTag()
                                })
                                ready = AppSettings.interfaceLanguageCode == code && (code.isEmpty() || configured == code)
                            }
                            if (!ready) Thread.sleep(50)
                        }
                    }
                    assertTrue("Locale recreation completed for $code", ready)
                    scenario.onActivity { activity ->
                        val current = AppSettings.effectiveInterfaceLanguageCode
                        assertEquals(code, preferences.getString(InterfaceLanguage.preferenceKey, null))
                        assertEquals("arc", Prayer().resolvedLanguageCode)
                        assertEquals("he-x-gamliel", explicit.resolvedLanguageCode)
                        assertEquals("arc", preferences.getString("defaultLanguageCode", null))
                        assertEquals(if (current in listOf("he", "ar")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
                            activity.resources.configuration.layoutDirection)
                        if (code == "he") assertEquals("שפת היישומון", activity.getString(R.string.settings_app_language))
                    }
                    // An ordinary recreation must keep the selection and its resources.
                    scenario.recreate()
                    scenario.onActivity { assertEquals(code, AppSettings.interfaceLanguageCode) }
                }
            } finally {
                scenario.onActivity { AppCompatDelegate.setApplicationLocales(androidx.core.os.LocaleListCompat.forLanguageTags(original)) }
                instrumentation.waitForIdleSync()
                preferences.edit().apply {
                    if (oldDefault == null) remove("defaultLanguageCode") else putString("defaultLanguageCode", oldDefault)
                }.commit()
            }
        }
    }
}
