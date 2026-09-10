package com.dkaluta.prosary

import android.content.Intent
import android.graphics.Bitmap
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.util.Log
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.runtime.State
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.swipeDown
import androidx.compose.ui.test.swipeUp
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.testing.PrayerSessionTestActivity
import org.junit.After
import org.junit.Before
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/** Real Activity replacement, with navigation-entry ownership and isolated test prayer data. */
@RunWith(AndroidJUnit4::class)
class PrayerSessionContinuityInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()
    private var scenario: ActivityScenario<PrayerSessionTestActivity>? = null
    private var audioFixture: File? = null
    private val instrumentation = InstrumentationRegistry.getInstrumentation()

    @Before fun wakeScreen() = wakeAndUnlock()

    @After fun close() {
        scenario?.close()
        audioFixture?.delete()
    }

    @Test fun rosaryKeepsItsStepAndReentryStillOffersContinue() {
        open("rosary")
        repeat(3) { next() }
        val progress = readProgress()
        val body = readBody()
        recreate()
        recreate()
        assertEquals(progress, readProgress())
        assertEquals(body, readBody())
        assertNoResumePrompt()

        // A genuine new navigation entry retains the normal bookmark decision.
        pressBack()
        compose.onNodeWithText("Open test prayer").performClick()
        recreate()
        compose.onNodeWithText(label(R.string.flow_continue)).performClick()
        assertEquals(progress, readProgress())
        recreate()
        assertNoResumePrompt()
        next()
        assertNotEquals(progress, readProgress())
    }

    @Test fun foldingClosedAndOpenKeepsTheActiveRosary() {
        val states = Regex("identifier=(\\d+), name='?([A-Z_]+)'?")
            .findAll(shell("cmd device_state print-states"))
            .associate { it.groupValues[2] to it.groupValues[1].toInt() }
        assumeTrue("This test requires a foldable device", states["CLOSED"] != null && states["OPENED"] != null)
        try {
            shell("cmd device_state state ${states.getValue("OPENED")}")
            wakeAndUnlock()
            open("rosary")
            repeat(3) { next() }
            val progress = readProgress()
            val openSize = activitySize()
            val firstCreation = activityCreation()
            shell("cmd device_state state ${states.getValue("CLOSED")}")
            compose.waitUntil(15_000) {
                wakeAndUnlock()
                runCatching { activitySize() != openSize }.getOrDefault(false)
            }
            compose.waitForIdle()
            assertEquals(progress, readProgress())
            assertNoResumePrompt()

            shell("cmd device_state state ${states.getValue("OPENED")}")
            compose.waitUntil(15_000) {
                wakeAndUnlock()
                runCatching { activitySize() == openSize }.getOrDefault(false)
            }
            compose.waitForIdle()
            assertEquals(progress, readProgress())
            assertNoResumePrompt()
            Log.i("ProsaryFoldTest", "Activity creations during open/closed/open: ${activityCreation() - firstCreation}")
            next()
            assertNotEquals(progress, readProgress())
        } finally {
            shell("cmd device_state state reset")
            wakeAndUnlock()
        }
    }

    @Test fun autoAdvanceWaitsWhileBackgroundedAndRestartsOnReturn() {
        open("rosary")
        lateinit var index: State<Int>
        requireNotNull(scenario).onActivity { index = it.rosaryIndexForTest() }
        compose.onNodeWithContentDescription(label(R.string.settings_auto_advance)).performClick()
        compose.onNodeWithText(instrumentation.targetContext.getString(R.string.auto_advance_every, 3)).performClick()
        val before = index.value
        requireNotNull(scenario).moveToState(Lifecycle.State.CREATED)
        // This interval must actually elapse while the Activity has no foreground UI.
        SystemClock.sleep(3_500)
        assertEquals("Background time must not advance the prayer", before, index.value)
        requireNotNull(scenario).moveToState(Lifecycle.State.RESUMED)
        compose.waitForIdle()
        assertEquals("Returning starts a fresh countdown", before, index.value)
        compose.waitUntil(5_000) { index.value == before + 1 }
    }

    @Test fun aScrolledRosaryPrayerKeepsItsReadingPlaceAfterRecreation() {
        open("rosary", largeText = true)
        next() // The Creed is long enough to scroll at an accessibility text size.
        compose.onNodeWithTag("prayerBody").performTouchInput { swipeUp() }
        val anchor = readingAnchor()
        requireNotNull(scenario).onActivity { Log.i("ProsaryReadingTest", "before ${it.readingMetricsForTest()}") }
        captureReading("reading-before")
        assertNotEquals("The test must move away from the reading start", 0 to 0, anchor)
        val progress = readProgress()
        recreate()
        requireNotNull(scenario).onActivity { Log.i("ProsaryReadingTest", "after ${it.readingMetricsForTest()}") }
        captureReading("reading-after")
        assertEquals(progress, readProgress())
        assertEquals("The same live step must keep its paragraph and offset", anchor, readingAnchor())
        assertNoResumePrompt()

        // A fresh gesture releases restoration: the next recreation keeps the new place.
        compose.onNodeWithTag("prayerBody").performTouchInput { swipeDown() }
        val newAnchor = readingAnchor()
        assertNotEquals("The reader must accept a new scroll after restoring", anchor, newAnchor)
        recreate()
        assertEquals("A second recreation must keep the newly chosen reading place", newAnchor, readingAnchor())
        assertEquals(progress, readProgress())
        assertNoResumePrompt()
    }

    @Test fun customDevotionKeepsItsLanguageAndCurrentStep() {
        open("custom")
        repeat(2) { next() }
        val english = readBody()
        compose.onNodeWithContentDescription(label(R.string.flow_prayer_language)).performClick()
        compose.onNodeWithText(LanguageCatalog.pickerLanguageName("it")).performScrollTo().performClick()
        val progress = readProgress()
        val italian = readBody()
        assertNotEquals(english, italian)
        recreate()
        assertEquals(progress, readProgress())
        assertEquals(italian, readBody())
        assertNoResumePrompt()
    }

    @Test fun jesusPrayerKeepsItsLiveRepetition() {
        open("jesus")
        repeat(4) {
            compose.onNodeWithText(label(R.string.common_pray)).performScrollTo().performClick()
        }
        val progress = readProgress()
        assertEquals(instrumentation.targetContext.getString(R.string.flow_step_of, 5, 33), progress)
        recreate()
        assertEquals(progress, readProgress())
        assertNoResumePrompt()
        compose.onNodeWithText(label(R.string.common_pray)).performScrollTo().performClick()
        assertEquals(instrumentation.targetContext.getString(R.string.flow_step_of, 6, 33), readProgress())
    }

    @Test fun selectedDaySurvivesRecreation() {
        open("days")
        val day = requireNotNull(PrayerPackStore.definition("oAntiphons")?.days?.get(1))
        val title = day.period?.let { "$it — ${day.localizedName}" } ?: day.localizedName
        compose.onNodeWithContentDescription(label(R.string.flow_day)).performClick()
        compose.onNodeWithText(title).performScrollTo().performClick()
        val body = readBody()
        recreate()
        assertEquals(body, readBody())
        assertNoResumePrompt()
    }

    @Test fun selectedFormSurvivesRecreation() {
        open("variant")
        val variant = requireNotNull(PrayerPackStore.definition("stationsOfTheCross")?.variants?.get(1))
        compose.onNodeWithContentDescription(label(R.string.flow_choose_form)).performClick()
        compose.onNodeWithText(variant.localizedName).performScrollTo().performClick()
        next()
        val progress = readProgress()
        val body = readBody()
        recreate()
        assertEquals(progress, readProgress())
        assertEquals(body, readBody())
        assertNoResumePrompt()
    }

    @Test fun narrationSurvivesRecreationPausesInBackgroundAndReleasesOnExit() {
        open("audio")
        compose.onNodeWithContentDescription(label(R.string.audio_play)).performClick()
        lateinit var audio: AudioPlaybackController
        requireNotNull(scenario).onActivity { audio = it.audioForTest() }
        compose.waitUntil(5_000) { audio.isPlaying && audio.currentTime > 0.5 }
        val before = audio.currentTime
        recreate()
        requireNotNull(scenario).onActivity { assertSame(audio, it.audioForTest()) }
        assertTrue("Recreation must not pause a playing track", audio.isPlaying)
        assertTrue("Recreation must not rewind narration", audio.currentTime >= before)
        assertNoResumePrompt()

        requireNotNull(scenario).moveToState(Lifecycle.State.CREATED)
        assertFalse("Backgrounding pauses narration", audio.isPlaying)
        assertTrue("Backgrounding retains the loaded track", audio.isLoaded)
        requireNotNull(scenario).moveToState(Lifecycle.State.RESUMED)
        assertFalse("Foregrounding does not unexpectedly start narration", audio.isPlaying)
        pressBack()
        compose.waitUntil(5_000) { !audio.isLoaded }
    }

    private fun open(mode: String, largeText: Boolean = false) {
        val intent = Intent(instrumentation.targetContext, PrayerSessionTestActivity::class.java)
            .putExtra("runId", UUID.randomUUID().toString())
            .putExtra("mode", mode)
            .putExtra("largeText", largeText)
        if (mode == "audio") {
            audioFixture = File.createTempFile("prayer-audio-test-", ".prosaryprayer", instrumentation.targetContext.cacheDir)
            instrumentation.context.assets.open("kyrieaudiodemo.prosaryprayer").use { input ->
                requireNotNull(audioFixture).outputStream().use { input.copyTo(it) }
            }
            intent.putExtra("audioFixture", requireNotNull(audioFixture).absolutePath)
        }
        scenario = ActivityScenario.launch(intent)
        compose.onNodeWithText("Open test prayer").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodes(hasTestTag("prayerProgress")).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun recreate() {
        requireNotNull(scenario).recreate()
        compose.waitForIdle()
        compose.onNodeWithTag("prayerProgress").fetchSemanticsNode()
    }

    private fun next() = compose.onNodeWithText(label(R.string.common_next)).performClick()

    private fun readProgress(): String = compose.onNodeWithTag("prayerProgress").fetchSemanticsNode()
        .config[SemanticsProperties.Text].joinToString { it.text }

    private fun readBody(): List<String> = compose.onAllNodes(
        hasAnyAncestor(hasTestTag("prayerBody")), useUnmergedTree = true,
    ).fetchSemanticsNodes().flatMap { node ->
        node.config.getOrNull(SemanticsProperties.Text).orEmpty().map { it.text }
    }.also { assertTrue("The prayer reader should expose its text", it.isNotEmpty()) }

    private fun assertNoResumePrompt() = compose.onNodeWithText(label(R.string.flow_resume_title)).assertDoesNotExist()
    private fun label(resource: Int) = instrumentation.targetContext.getString(resource)

    private fun activitySize(): Pair<Int, Int> {
        var size = 0 to 0
        requireNotNull(scenario).onActivity {
            size = it.resources.configuration.run { screenWidthDp to screenHeightDp }
        }
        return size
    }

    private fun activityCreation(): Int {
        var creation = 0
        requireNotNull(scenario).onActivity { creation = it.creationNumberForTest }
        return creation
    }

    private fun readingAnchor(): Pair<Int, Int> {
        compose.waitForIdle()
        var anchor = 0 to 0
        requireNotNull(scenario).onActivity { anchor = it.readingAnchorForTest() }
        return anchor
    }

    private fun shell(command: String): String = ParcelFileDescriptor.AutoCloseInputStream(
        instrumentation.uiAutomation.executeShellCommand(command),
    ).bufferedReader().use { it.readText() }

    private fun wakeAndUnlock() {
        shell("input keyevent KEYCODE_WAKEUP")
        shell("wm dismiss-keyguard")
    }

    private fun captureReading(name: String) {
        val bitmap = instrumentation.uiAutomation.takeScreenshot() ?: return
        File(instrumentation.targetContext.getExternalFilesDir(null), "$name.png").outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        bitmap.recycle()
    }
}
