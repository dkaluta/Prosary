package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.derivedStateOf
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class HomeWidgetPreferencesTest {
    @Test fun missingPreferenceUsesDefaultsButAnExplicitlyEmptyHomeSurvivesRestart() {
        val storage = Preferences()
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(HomeWidget.defaults, settings.widgets)
        settings.updateWidgets(emptyList())
        assertEquals("", storage.values["homeWidgetOrder"])
        assertTrue(HomeWidgetPreferences().apply { initialize(storage.instance) }.widgets.isEmpty())
    }

    @Test fun unknownAndRepeatedIdsCannotCreateDuplicateCardsAndAddingAppends() {
        val storage = Preferences(mutableMapOf("homeWidgetOrder" to "unknown\nphoto\nphoto\nreadings\ncalendar\nother"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        val observed = derivedStateOf { settings.widgets.map { it.id } }
        assertEquals(listOf("photo", "readings", "calendar"), observed.value)
        settings.add(HomeWidget.Reflection)
        settings.add(HomeWidget.Readings)
        assertEquals(listOf("photo", "readings", "calendar", "reflection"), observed.value)
        settings.move(HomeWidget.Reflection, -1)
        settings.move(HomeWidget.Photo, -1)
        settings.move(HomeWidget.Feast, 1)
        assertEquals(listOf("photo", "readings", "reflection", "calendar"), observed.value)
        val reopened = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(settings.widgets, reopened.widgets)
        reopened.updateWidgets(reopened.widgets - HomeWidget.Readings)
        assertEquals("photo\nreflection\ncalendar", storage.values["homeWidgetOrder"])
    }

    @Test fun deviceLocalPhotoCanBeReplacedAndRemovedWithoutChangingPrayerSettings() {
        val storage = Preferences(mutableMapOf("defaultLanguageCode" to "arc"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        settings.updatePhotoPath("/app/files/homePhotos/home-photo-first.jpg")
        assertEquals(settings.photoPath, HomeWidgetPreferences().apply { initialize(storage.instance) }.photoPath)
        settings.updatePhotoPath("/app/files/homePhotos/home-photo-second.jpg")
        settings.updatePhotoPath("")
        assertEquals("", HomeWidgetPreferences().apply { initialize(storage.instance) }.photoPath)
        assertEquals("arc", storage.values["defaultLanguageCode"])
    }

    private class Preferences(val values: MutableMap<String, String> = mutableMapOf()) {
        private val editor = Proxy.newProxyInstance(SharedPreferences.Editor::class.java.classLoader,
            arrayOf(SharedPreferences.Editor::class.java)) { proxy, method, args ->
            when (method.name) {
                "putString" -> { values[args!![0] as String] = args[1] as String; proxy }
                "apply" -> null
                else -> error("Unexpected preference edit: ${method.name}")
            }
        } as SharedPreferences.Editor
        val instance = Proxy.newProxyInstance(SharedPreferences::class.java.classLoader,
            arrayOf(SharedPreferences::class.java)) { _, method, args ->
            when (method.name) {
                "getString" -> values[args!![0] as String] ?: args[1]
                "edit" -> editor
                else -> error("Unexpected preference read: ${method.name}")
            }
        } as SharedPreferences
    }
}
