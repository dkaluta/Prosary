package com.dkaluta.prosary.ui

import android.view.KeyEvent
import com.dkaluta.prosary.ui.shared.PrayerKeyboardAction
import com.dkaluta.prosary.ui.shared.prayerKeyboardAction
import org.junit.Assert.assertEquals
import org.junit.Test

class PrayerKeyboardNavigationTest {
    private fun action(
        key: Int,
        keyDown: Boolean = true,
        repeats: Int = 0,
        modified: Boolean = false,
        active: Boolean = true,
        arrows: Boolean = true,
        space: Boolean = true,
        rtl: Boolean = false,
        canGoBack: Boolean = true,
    ) = prayerKeyboardAction(key, keyDown, repeats, modified, active, arrows, space, rtl, canGoBack)

    @Test fun arrowsFollowInterfaceDirectionWhileSpaceAlwaysAdvances() {
        assertEquals(PrayerKeyboardAction.Previous, action(KeyEvent.KEYCODE_DPAD_LEFT))
        assertEquals(PrayerKeyboardAction.Next, action(KeyEvent.KEYCODE_DPAD_RIGHT))
        assertEquals(PrayerKeyboardAction.Next, action(KeyEvent.KEYCODE_DPAD_LEFT, rtl = true))
        assertEquals(PrayerKeyboardAction.Previous, action(KeyEvent.KEYCODE_DPAD_RIGHT, rtl = true))
        for (rtl in listOf(false, true)) {
            assertEquals(PrayerKeyboardAction.Next, action(KeyEvent.KEYCODE_SPACE, rtl = rtl))
        }
    }

    @Test fun settingsAreIndependentAndOtherKeysRemainAvailable() {
        assertEquals(PrayerKeyboardAction.Ignore, action(KeyEvent.KEYCODE_DPAD_RIGHT, arrows = false))
        assertEquals(PrayerKeyboardAction.Next, action(KeyEvent.KEYCODE_SPACE, arrows = false))
        assertEquals(PrayerKeyboardAction.Ignore, action(KeyEvent.KEYCODE_SPACE, space = false))
        assertEquals(PrayerKeyboardAction.Next, action(KeyEvent.KEYCODE_DPAD_RIGHT, space = false))
        for (key in listOf(KeyEvent.KEYCODE_DPAD_UP, KeyEvent.KEYCODE_DPAD_DOWN, KeyEvent.KEYCODE_PAGE_UP,
            KeyEvent.KEYCODE_PAGE_DOWN, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_TAB, KeyEvent.KEYCODE_A)) {
            assertEquals(PrayerKeyboardAction.Ignore, action(key))
        }
    }

    @Test fun eachPressNavigatesOnceAndPreviousStopsAtTheFirstStep() {
        for (key in listOf(KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_SPACE)) {
            assertEquals(PrayerKeyboardAction.Consume, action(key, repeats = 1))
            assertEquals(PrayerKeyboardAction.Consume, action(key, repeats = 12))
            assertEquals(PrayerKeyboardAction.Consume, action(key, keyDown = false))
        }
        assertEquals(PrayerKeyboardAction.Consume, action(KeyEvent.KEYCODE_DPAD_LEFT, canGoBack = false))
        assertEquals(PrayerKeyboardAction.Consume, action(KeyEvent.KEYCODE_DPAD_RIGHT, canGoBack = false, rtl = true))
    }

    @Test fun modifiersAndInactiveReadersLeaveKeysToTheirFocusedControl() {
        for (key in listOf(KeyEvent.KEYCODE_DPAD_LEFT, KeyEvent.KEYCODE_DPAD_RIGHT, KeyEvent.KEYCODE_SPACE)) {
            assertEquals(PrayerKeyboardAction.Ignore, action(key, modified = true))
            assertEquals(PrayerKeyboardAction.Ignore, action(key, active = false))
        }
    }
}
