package com.dkaluta.prosary

import android.app.AlertDialog
import android.content.Intent
import android.os.SystemClock
import android.view.InputDevice
import android.view.KeyEvent
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.testing.PrayerSessionTestActivity
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/** Verifies real event dispatch to the shared reader and native focused controls. */
@RunWith(AndroidJUnit4::class)
class PrayerKeyboardInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private var scenario: ActivityScenario<PrayerSessionTestActivity>? = null

    @After fun close() { scenario?.close() }

    @Test fun rosaryRespondsOncePerPressAndHonorsIndependentSettings() {
        open("rosary")
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        assertEquals(1, index())
        key(KeyEvent.KEYCODE_SPACE, repeats = 5)
        assertEquals(2, index())
        key(KeyEvent.KEYCODE_DPAD_LEFT)
        assertEquals(1, index())
        scenario!!.onActivity { AppSettings.keyboardArrowNavigationEnabled = false }
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        assertEquals(1, index())
        // A disabled arrow can move native focus. Return focus to the reader via re-entry.
        scenario!!.recreate()
        compose.waitForIdle()
        key(KeyEvent.KEYCODE_SPACE)
        assertEquals(2, index())
        scenario!!.onActivity { AppSettings.keyboardArrowNavigationEnabled = true; AppSettings.keyboardSpaceAdvanceEnabled = false }
        key(KeyEvent.KEYCODE_SPACE)
        assertEquals(2, index())
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        assertEquals(3, index())
    }

    @Test fun jesusPrayerAndGenericDevotionsShareTheSameKeyboardPath() {
        for (mode in listOf("jesus", "custom")) {
            open(mode)
            key(KeyEvent.KEYCODE_SPACE)
            assertEquals(mode, 1, index())
            key(KeyEvent.KEYCODE_DPAD_RIGHT)
            assertEquals(mode, 2, index())
            key(KeyEvent.KEYCODE_DPAD_LEFT)
            assertEquals(mode, 1, index())
            scenario!!.close()
            scenario = null
        }
    }

    @Test fun basicPrayerSpaceInvokesItsFinishAction() {
        open("basic")
        key(KeyEvent.KEYCODE_SPACE)
        compose.onNodeWithText("Open test prayer").assertExists()
    }

    @Test fun modifiedKeysDialogsAndFocusedButtonsDoNotAdvanceTheReader() {
        open("rosary")
        key(KeyEvent.KEYCODE_SPACE, modifiers = KeyEvent.META_CTRL_ON)
        assertEquals(0, index())
        lateinit var dialog: AlertDialog
        scenario!!.onActivity {
            dialog = AlertDialog.Builder(it).setMessage("Keyboard test").setPositiveButton("Close", null).show()
        }
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        assertEquals(0, index())
        scenario!!.onActivity { dialog.dismiss() }
        compose.waitForIdle()
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        key(KeyEvent.KEYCODE_DPAD_RIGHT)
        assertEquals(2, index())
        compose.onNodeWithText(instrumentation.targetContext.getString(R.string.flow_back))
            .performSemanticsAction(SemanticsActions.RequestFocus) { it() }
        key(KeyEvent.KEYCODE_SPACE)
        assertEquals("Space activates the focused Back button", 1, index())
    }

    private fun open(mode: String) {
        assumeTrue("A physical alphabetic keyboard is required", keyboardId() != null)
        val intent = Intent(instrumentation.targetContext, PrayerSessionTestActivity::class.java)
            .putExtra("runId", UUID.randomUUID().toString()).putExtra("mode", mode)
        scenario = ActivityScenario.launch(intent)
        compose.onNodeWithText("Open test prayer").performClick()
        compose.waitForIdle()
    }

    private fun keyboardId(): Int? = InputDevice.getDeviceIds().firstOrNull { id ->
        InputDevice.getDevice(id)?.let { !it.isVirtual && it.keyboardType == InputDevice.KEYBOARD_TYPE_ALPHABETIC } == true
    }

    private fun index(): Int {
        compose.waitForIdle()
        var index = -1
        scenario!!.onActivity { index = it.sessionForTest().index }
        return index
    }

    private fun key(code: Int, modifiers: Int = 0, repeats: Int = 0) {
        val downTime = SystemClock.uptimeMillis()
        fun inject(action: Int, repeat: Int) {
            instrumentation.uiAutomation.injectInputEvent(KeyEvent(downTime, SystemClock.uptimeMillis(), action,
                code, repeat, modifiers, keyboardId() ?: -1, 0, 0, InputDevice.SOURCE_KEYBOARD), true)
        }
        inject(KeyEvent.ACTION_DOWN, 0)
        repeat(repeats) { inject(KeyEvent.ACTION_DOWN, it + 1) }
        inject(KeyEvent.ACTION_UP, 0)
        compose.waitForIdle()
    }
}
