package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.derivedStateOf
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class HomeWidgetPreferencesTest {
    @Test fun sourceCardUpgradePreservesEarlierRemovalsAndDoesNotRepeatAfterRestart() {
        val storage = Preferences(mutableMapOf("homeWidgetOrder" to "photo\nfeast", "homeWidgetLayoutVersion" to "1"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(listOf(HomeWidget.Photo, HomeWidget.Feast, HomeWidget.Hymn, HomeWidget.Tradition), settings.widgets)
        settings.updateWidgets(listOf(HomeWidget.Photo))
        assertEquals(listOf(HomeWidget.Photo), HomeWidgetPreferences().apply { initialize(storage.instance) }.widgets)
    }

    @Test fun missingPreferenceUsesDefaultsButAnExplicitlyEmptyHomeSurvivesRestart() {
        val storage = Preferences()
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(HomeWidget.defaults, settings.widgets)
        settings.updateWidgets(emptyList())
        assertEquals("", storage.values["homeWidgetOrder"])
        assertTrue(HomeWidgetPreferences().apply { initialize(storage.instance) }.widgets.isEmpty())
    }

    @Test fun unknownAndRepeatedIdsCannotCreateDuplicateCardsAndAddingAppends() {
        val storage = Preferences(mutableMapOf("homeWidgetOrder" to "unknown\nphoto\nphoto\nreadings\ncalendar\nother", "homeWidgetLayoutVersion" to "2"))
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

    @Test fun dailyCardsMigrateOnceAndLaterRemovalStaysRemoved() {
        val storage = Preferences(mutableMapOf("homeWidgetOrder" to "photo\nreadings\nfeast"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(listOf(HomeWidget.Photo, HomeWidget.Readings, HomeWidget.Torah, HomeWidget.Feast, HomeWidget.Reflection, HomeWidget.Hymn, HomeWidget.Tradition), settings.widgets)
        assertEquals("2", storage.values["homeWidgetLayoutVersion"])
        settings.updateWidgets(settings.widgets - HomeWidget.Torah - HomeWidget.Reflection - HomeWidget.Hymn - HomeWidget.Tradition)
        assertEquals(listOf(HomeWidget.Photo, HomeWidget.Readings, HomeWidget.Feast),
            HomeWidgetPreferences().apply { initialize(storage.instance) }.widgets)
        assertTrue(HomeWidget.addingDailyCards(emptyList()).isEmpty())
        assertEquals(HomeWidget.defaults, HomeWidget.addingDailyCards(HomeWidget.defaults))
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

    @Test fun sizeChoicesAndIndependentImagesSurviveRestartWithoutRemovingWidgetContent() {
        val storage = Preferences()
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertTrue(settings.collapsed.isEmpty())
        settings.setCollapsed(HomeWidget.Readings, true)
        settings.setGraphicPath(HomeWidget.Readings, "/app/files/homePhotos/home-photo-readings.jpg")
        settings.setGraphicPath(HomeWidget.Calendar, "/app/files/homePhotos/home-photo-calendar.jpg")
        val reopened = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(setOf(HomeWidget.Readings), reopened.collapsed)
        assertEquals(settings.widgets, reopened.widgets)
        assertEquals(settings.graphicPaths, reopened.graphicPaths)
        reopened.setCollapsed(HomeWidget.Readings, false)
        reopened.setGraphicPath(HomeWidget.Readings, "")
        val again = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertTrue(again.collapsed.isEmpty())
        assertEquals(mapOf("calendar" to "/app/files/homePhotos/home-photo-calendar.jpg"), again.graphicPaths)
    }

    @Test fun corruptOrUnknownGraphicAndSizePreferencesCannotAddUnrecognizedCards() {
        val storage = Preferences(mutableMapOf("homeWidgetCollapsedIds" to "unknown\nreadings\nreadings",
            "homeWidgetGraphicPaths" to "{\"unknown\":\"x\",\"readings\":\"\",\"calendar\":\"local\"}"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(setOf(HomeWidget.Readings), settings.collapsed)
        assertEquals(mapOf("calendar" to "local"), settings.graphicPaths)
        storage.values["homeWidgetGraphicPaths"] = "corrupted JSON"
        assertTrue(HomeWidgetPreferences().apply { initialize(storage.instance) }.graphicPaths.isEmpty())
    }

    @Test fun cardColorsPersistIndependentlyAndDefaultResetDoesNotChangeOtherCards() {
        val storage = Preferences(mutableMapOf("homeWidgetColors" to
            "{\"readings\":\"blue\",\"feast\":\"rose\",\"photo\":\"default\",\"torah\":\"purple\",\"unknown\":\"green\"}"))
        val settings = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(mapOf("readings" to "blue", "feast" to "rose"), settings.colors)
        val originalOrder = settings.widgets
        settings.setColor(HomeWidget.Readings, "gold")
        settings.setColor(HomeWidget.Feast, "default")
        val reopened = HomeWidgetPreferences().apply { initialize(storage.instance) }
        assertEquals(mapOf("readings" to "gold"), reopened.colors)
        assertEquals(originalOrder, reopened.widgets)
        reopened.setColor(HomeWidget.Readings, "unknown")
        assertEquals("{}", storage.values["homeWidgetColors"])
        assertTrue(HomeWidgetPreferences.parseColors("bad json").isEmpty())
        assertTrue(HomeWidgetPreferences.parseColors("null").isEmpty())
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
