package com.dkaluta.prosary.ui

import android.view.KeyEvent
import com.dkaluta.prosary.ui.shared.PrayerVolumeAction
import com.dkaluta.prosary.ui.shared.PrayerVolumeNavigation
import org.junit.Assert.assertEquals
import org.junit.Test

class PrayerVolumeNavigationTest {
    private val navigation = PrayerVolumeNavigation()

    private fun action(
        key: Int = KeyEvent.KEYCODE_VOLUME_UP,
        keyAction: Int = KeyEvent.ACTION_DOWN,
        repeats: Int = 0,
        downTime: Long = 100L,
        enabled: Boolean = true,
        active: Boolean = true,
        audio: Boolean = false,
        canGoBack: Boolean = true,
        modified: Boolean = false,
        canceled: Boolean = false,
    ) = navigation.action(key, keyAction, repeats, downTime, enabled, active, audio, canGoBack, modified, canceled)

    @Test fun upAdvancesAndDownGoesBack() {
        assertEquals(PrayerVolumeAction.Next, action())
        assertEquals(PrayerVolumeAction.Previous, action(KeyEvent.KEYCODE_VOLUME_DOWN))
        assertEquals(PrayerVolumeAction.Consume, action(KeyEvent.KEYCODE_VOLUME_DOWN, downTime = 200L, canGoBack = false))
    }

    @Test fun disabledInactiveAndAudioReadersLeaveVolumeToAndroid() {
        for (key in listOf(KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN)) {
            assertEquals(PrayerVolumeAction.Ignore, action(key, enabled = false))
            assertEquals(PrayerVolumeAction.Ignore, action(key, active = false))
            assertEquals(PrayerVolumeAction.Ignore, action(key, audio = true))
            assertEquals(PrayerVolumeAction.Ignore, action(key, modified = true))
            assertEquals(PrayerVolumeAction.Ignore, action(key, canceled = true))
        }
        assertEquals(PrayerVolumeAction.Ignore, action(KeyEvent.KEYCODE_VOLUME_MUTE))
        assertEquals(PrayerVolumeAction.Ignore, action(KeyEvent.KEYCODE_SPACE))
    }

    @Test fun heldNavigationPressAdvancesOnceAndKeepsItsReleaseAfterFinishing() {
        assertEquals(PrayerVolumeAction.Next, action())
        assertEquals(PrayerVolumeAction.Consume, action(repeats = 1))
        assertEquals(PrayerVolumeAction.Consume, action(repeats = 12, active = false, audio = true))
        assertEquals(PrayerVolumeAction.Consume, action(keyAction = KeyEvent.ACTION_UP, active = false, enabled = false))
        assertEquals(PrayerVolumeAction.Ignore, action(keyAction = KeyEvent.ACTION_UP))
        assertEquals(PrayerVolumeAction.Next, action(downTime = 200L))
    }

    @Test fun nativeVolumePressDoesNotBecomeNavigationWhenAudioStops() {
        assertEquals(PrayerVolumeAction.Ignore, action(audio = true))
        assertEquals(PrayerVolumeAction.Ignore, action(repeats = 1))
        assertEquals(PrayerVolumeAction.Ignore, action(keyAction = KeyEvent.ACTION_UP))
        assertEquals(PrayerVolumeAction.Next, action(downTime = 200L))
    }

    @Test fun upAndDownHaveIndependentPressLifetimes() {
        assertEquals(PrayerVolumeAction.Next, action())
        assertEquals(PrayerVolumeAction.Previous, action(KeyEvent.KEYCODE_VOLUME_DOWN, downTime = 110L))
        assertEquals(PrayerVolumeAction.Consume, action(keyAction = KeyEvent.ACTION_UP))
        assertEquals(PrayerVolumeAction.Consume, action(KeyEvent.KEYCODE_VOLUME_DOWN, repeats = 1, downTime = 110L))
        assertEquals(PrayerVolumeAction.Consume, action(KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.ACTION_UP, downTime = 110L))
    }

    @Test fun unmatchedReleaseDoesNotConsumeNativeVolume() {
        assertEquals(PrayerVolumeAction.Next, action())
        assertEquals(PrayerVolumeAction.Ignore, action(keyAction = KeyEvent.ACTION_UP, downTime = 200L))
        assertEquals(PrayerVolumeAction.Consume, action(keyAction = KeyEvent.ACTION_UP))
        assertEquals(PrayerVolumeAction.Ignore, action(keyAction = KeyEvent.ACTION_MULTIPLE, downTime = 200L))
    }
}
