package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.derivedStateOf
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class FilioquePreferenceTest {
    @Test fun absenceSurvivesLoadingUntilTheFirstRiteSuppliesADefault() {
        val storage = Preferences()
        val preference = FilioquePreference().apply { initialize(storage.preferences) }
        assertNull(preference.choice)
        assertEquals(0, storage.writes)
        preference.initializeOnce(false)
        preference.initializeOnce(true)
        assertEquals(false, preference.choice)
        assertEquals(false, storage.stored)
        assertEquals(1, storage.writes)
        assertEquals(false, FilioquePreference().apply { initialize(storage.preferences) }.choice)
    }

    @Test fun explicitTogglePersistsAndLaterRitesCannotResetIt() {
        val storage = Preferences(true)
        val preference = FilioquePreference().apply { initialize(storage.preferences) }
        val display = derivedStateOf { preference.choice }
        assertEquals(true, display.value)
        preference.set(false)
        assertEquals(false, display.value)
        preference.initializeOnce(true)
        val reopened = FilioquePreference().apply { initialize(storage.preferences) }
        assertEquals(false, reopened.choice)
        assertEquals(1, storage.writes)
    }

    @Test fun firstExplicitGreekChoiceWinsOverLaterHebrewAndLatinSelections() {
        val saved = AppSettings.includeFilioqueChoice
        try {
            AppSettings.restoreFilioqueForTesting(null)
            AppSettings.initializeFilioqueFromSelection("")
            assertNull(AppSettings.includeFilioqueChoice)
            AppSettings.initializeFilioqueFromSelection("el")
            AppSettings.initializeFilioqueFromSelection("he-x-gamliel")
            AppSettings.initializeFilioqueFromSource(true)
            assertEquals(false, AppSettings.includeFilioqueChoice)
            AppSettings.includeFilioque = true
            AppSettings.initializeFilioqueFromSelection("el")
            assertTrue(AppSettings.includeFilioque)
        } finally {
            AppSettings.restoreFilioqueForTesting(saved)
        }
    }

    private class Preferences(initial: Boolean? = null) {
        var stored = initial
        var writes = 0
        private val editor = Proxy.newProxyInstance(
            SharedPreferences.Editor::class.java.classLoader, arrayOf(SharedPreferences.Editor::class.java),
        ) { proxy, method, args ->
            when (method.name) {
                "putBoolean" -> {
                    assertEquals("includeFilioque", args!![0])
                    stored = args[1] as Boolean
                    writes++
                    proxy
                }
                "apply" -> null
                else -> error("Unexpected preference edit: ${method.name}")
            }
        } as SharedPreferences.Editor
        val preferences = Proxy.newProxyInstance(
            SharedPreferences::class.java.classLoader, arrayOf(SharedPreferences::class.java),
        ) { _, method, args ->
            when (method.name) {
                "contains" -> {
                    assertEquals("includeFilioque", args!![0])
                    stored != null
                }
                "getBoolean" -> {
                    assertEquals("includeFilioque", args!![0])
                    stored ?: args[1]
                }
                "edit" -> editor
                else -> error("Unexpected preference read: ${method.name}")
            }
        } as SharedPreferences
    }
}
