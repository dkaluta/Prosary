package com.dkaluta.prosary.models

import android.content.SharedPreferences
import androidx.compose.runtime.derivedStateOf
import java.lang.reflect.Proxy
import org.junit.Assert.*
import org.junit.Test

class BasicPrayerPinsTest {
    @Test fun historicalSelectionsSurviveMigrationAndPinChangesSurviveReopening() {
        val storage = PinPreferences(mutableSetOf("aveMaria", "paterNoster"))
        val pins = BasicPrayerPins().apply { initialize(storage.preferences) }
        assertEquals(setOf("aveMaria", "paterNoster"), pins.ids)
        assertEquals(0, storage.writes)

        pins.setPinned("aveMaria", false)
        pins.setPinned("gloriaPatri", true)
        assertEquals(setOf("paterNoster", "gloriaPatri"), storage.stored)
        val reopened = BasicPrayerPins().apply { initialize(storage.preferences) }
        assertEquals(pins.ids, reopened.ids)
        // Removing the same card twice is harmless, never a toggle that restores it.
        reopened.setPinned("aveMaria", false)
        assertEquals(2, storage.writes)
    }

    @Test fun anAlreadyObservedPrayListRefreshesAndDoesNotShareMutableStorage() {
        val storage = PinPreferences(mutableSetOf("aveMaria"))
        val pins = BasicPrayerPins().apply { initialize(storage.preferences) }
        val observed = derivedStateOf { pins.ids.map { "basic:$it" } }
        val initial = pins.ids
        assertEquals(listOf("basic:aveMaria"), observed.value)
        storage.stored.add("external-mutation")
        assertEquals(setOf("aveMaria"), pins.ids)

        pins.toggle("aveMaria")
        assertTrue(observed.value.isEmpty())
        assertEquals(setOf("aveMaria"), initial)
        pins.toggle("aveMaria")
        assertEquals(listOf("basic:aveMaria"), observed.value)
        assertEquals(setOf("aveMaria"), storage.stored)
    }

    /** Only the actual SharedPreferences operations this store uses; no Android Context stub. */
    private class PinPreferences(initial: MutableSet<String>) {
        var stored = initial
        var writes = 0
        private val editor = Proxy.newProxyInstance(
            SharedPreferences.Editor::class.java.classLoader, arrayOf(SharedPreferences.Editor::class.java),
        ) { proxy, method, args ->
            when (method.name) {
                "putStringSet" -> {
                    assertEquals("favoriteBasicPrayerIds", args!![0])
                    @Suppress("UNCHECKED_CAST")
                    stored = (args[1] as Set<String>).toMutableSet()
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
                "getStringSet" -> {
                    assertEquals("favoriteBasicPrayerIds", args!![0])
                    stored
                }
                "edit" -> editor
                else -> error("Unexpected preference read: ${method.name}")
            }
        } as SharedPreferences
    }
}
