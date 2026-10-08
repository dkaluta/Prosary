package com.dkaluta.prosary

import android.app.AlertDialog
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.SystemClock
import android.view.KeyEvent
import androidx.activity.compose.setContent
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** Exercises the actual Activity dispatch and shared reader without an alphabetic keyboard. */
@RunWith(AndroidJUnit4::class)
class PrayerVolumeInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()
    private var index by mutableIntStateOf(0)
    private var audioPlaying by mutableStateOf(false)
    private var finished by mutableStateOf(false)
    private var originalVolumeSetting = false
    private var originalAutoAdvance = 0

    @Before fun showReader() {
        compose.activityRule.scenario.onActivity { activity ->
            originalVolumeSetting = AppSettings.volumeButtonNavigationEnabled
            originalAutoAdvance = AppSettings.autoAdvanceSeconds
            AppSettings.volumeButtonNavigationEnabled = false
            AppSettings.setAutoAdvanceSeconds(0)
            activity.setContent {
                ProsaryTheme {
                    if (finished) Text("Prayer finished") else PrayerStepFlowScreen(
                        title = "Volume navigation test",
                        step = RosaryStep(title = "Test step", body = "A short test prayer."),
                        currentIndex = index,
                        totalSteps = 3,
                        seasonColor = Color.Transparent,
                        isRightToLeft = false,
                        languageCode = "en",
                        canGoBack = index > 0,
                        onBack = { index-- },
                        onNext = { if (index == 2) finished = true else index++ },
                        onNavigateUp = { finished = true },
                        audioIsPlaying = audioPlaying,
                        speechAvailable = false,
                    )
                }
            }
        }
        compose.waitForIdle()
    }

    @After fun restoreSettings() {
        compose.activityRule.scenario.onActivity {
            AppSettings.volumeButtonNavigationEnabled = originalVolumeSetting
            AppSettings.setAutoAdvanceSeconds(originalAutoAdvance)
        }
    }

    @Test fun settingIsOptionalAndEachHeldPressInvokesOneActionIncludingFinish() {
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(0)
        compose.runOnIdle { AppSettings.volumeButtonNavigationEnabled = true }
        key(KeyEvent.KEYCODE_VOLUME_DOWN)
        assertIndex(0)
        key(KeyEvent.KEYCODE_VOLUME_UP, repeats = 5)
        assertIndex(1)
        key(KeyEvent.KEYCODE_VOLUME_DOWN)
        assertIndex(0)
        key(KeyEvent.KEYCODE_VOLUME_UP)
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(2)
        key(KeyEvent.KEYCODE_VOLUME_UP, repeats = 4)
        compose.onNodeWithText("Prayer finished").assertExists()
        assertIndex(2)
    }

    @Test fun narrationAndDevicePlaybackLeaveVolumeToAndroid() {
        compose.runOnIdle { AppSettings.volumeButtonNavigationEnabled = true; audioPlaying = true }
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(0)
        compose.runOnIdle { audioPlaying = false }
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(1)

        // Active media with silent PCM avoids test noise while exercising AudioManager's
        // real device-wide playback state, independently of the reader's audio flag.
        val samples = ShortArray(8_000)
        val player = AudioTrack.Builder()
            .setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build())
            .setAudioFormat(AudioFormat.Builder().setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(8_000).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setBufferSizeInBytes(samples.size * 2).setTransferMode(AudioTrack.MODE_STATIC).build()
        try {
            assertEquals(samples.size, player.write(samples, 0, samples.size))
            player.setLoopPoints(0, samples.size, -1)
            player.play()
            val manager = compose.activity.getSystemService(AudioManager::class.java)
            compose.waitUntil(5_000) { manager.isMusicActive }
            key(KeyEvent.KEYCODE_VOLUME_UP)
            key(KeyEvent.KEYCODE_VOLUME_DOWN)
            assertIndex(1)
            player.stop()
            compose.waitUntil(5_000) { !manager.isMusicActive }
            key(KeyEvent.KEYCODE_VOLUME_UP)
            assertIndex(2)
        } finally {
            player.release()
        }
    }

    @Test fun aDialogKeepsVolumeKeysAwayFromTheReader() {
        compose.runOnIdle { AppSettings.volumeButtonNavigationEnabled = true }
        lateinit var dialog: AlertDialog
        compose.activityRule.scenario.onActivity {
            dialog = AlertDialog.Builder(it).setMessage("Volume test dialog").setPositiveButton("Close", null).show()
        }
        compose.waitUntil(5_000) { !compose.activity.hasWindowFocus() }
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(0)
        compose.activityRule.scenario.onActivity { dialog.dismiss() }
        compose.waitUntil(5_000) { compose.activity.hasWindowFocus() }
        key(KeyEvent.KEYCODE_VOLUME_UP)
        assertIndex(1)
    }

    private fun assertIndex(expected: Int) = compose.runOnIdle { assertEquals(expected, index) }

    private fun key(code: Int, repeats: Int = 0) {
        compose.waitForIdle()
        val downTime = SystemClock.uptimeMillis()
        fun dispatch(action: Int, repeat: Int) {
            compose.activityRule.scenario.onActivity {
                it.dispatchKeyEvent(KeyEvent(downTime, SystemClock.uptimeMillis(), action, code, repeat))
            }
        }
        dispatch(KeyEvent.ACTION_DOWN, 0)
        repeat(repeats) { dispatch(KeyEvent.ACTION_DOWN, it + 1) }
        dispatch(KeyEvent.ACTION_UP, 0)
        compose.waitForIdle()
    }
}
