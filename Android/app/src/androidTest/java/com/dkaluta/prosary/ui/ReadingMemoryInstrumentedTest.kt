package com.dkaluta.prosary.ui

import android.os.SystemClock
import android.util.Log
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.readings.ReadingsScreen
import org.junit.Assert.assertEquals
import org.junit.Assume.assumeTrue
import org.junit.Rule
import org.junit.Test

/** Opt-in diagnostic heap snapshots, with no device-dependent timing or memory assertions. */
class ReadingMemoryInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()
    // A field makes the retained-cache measurement's strong ownership explicit.
    private var retainedStore: ReadingTextStore? = null

    @Test fun retainsOneCorpusAcrossProductionDateNavigation() {
        assumeTrue(InstrumentationRegistry.getArguments().containsKey("memoryLabel"))
        val context = compose.activity.applicationContext
        AppSettings.init(context)
        val oldCalendar = AppSettings.feastCalendarId
        val oldEdition = AppSettings.readingsEditionId
        val label = InstrumentationRegistry.getArguments().getString("memoryLabel", "current")
        try {
            retainedStore = ReadingTextStore { name -> context.assets.open("data/$name.json") }
            val english = retainedStore!!.editions.single { it.languageCode == "en" }
            val luke = ReadingCitation("gospel", "Lk. 6", "Luke 6:27–38")
            val before = collectedHeap()
            val start = SystemClock.elapsedRealtime()
            val firstText = retainedStore!!.passage(luke, english.id)!!.verses.first().text
            val decodeMs = SystemClock.elapsedRealtime() - start
            val immediate = usedHeap()
            val retained = collectedHeap()
            assertEquals(12, retainedStore!!.passage(luke, english.id)!!.verses.size)
            Log.i("ProsaryReadingMemory", "$label direct decodeMs=$decodeMs before=$before immediate=$immediate retained=$retained")
            // The production measurement below owns its own single reader cache. Release
            // the diagnostic store so two independently decoded corpora cannot inflate it.
            retainedStore = null
            val released = collectedHeap()
            Log.i("ProsaryReadingMemory", "$label direct released=$released")
            TodayInfoStore.initialize { name -> context.assets.open("data/$name.json") }
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                AppSettings.feastCalendarId = "roman"
                AppSettings.readingsEditionId = english.id
            }
            // This optional diagnostic's fixed Gospel is appointed on the review date;
            // ordinary corpus tests remain independent of the current calendar date.
            assumeTrue(TodayInfoStore.readings().any { it.full == luke.full })
            compose.setContent { MaterialTheme { ReadingsScreen(onOpenSettings = {}) } }
            compose.waitUntil(15_000) {
                compose.onAllNodes(hasText(english.name, substring = true)).fetchSemanticsNodes().isNotEmpty()
            }
            val ready = collectedHeap()
            openLuke(luke, firstText)
            val expanded = collectedHeap()
            compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag("readingsPrevious"))
            compose.onNodeWithTag("readingsPrevious").performClick()
            compose.onNodeWithTag("readingsNext").performClick()
            openLuke(luke, firstText)
            val navigated = collectedHeap()
            Log.i("ProsaryReadingMemory", "$label production released=$released ready=$ready expanded=$expanded navigated=$navigated limit=${Runtime.getRuntime().maxMemory()}")
        } finally {
            retainedStore = null
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                AppSettings.feastCalendarId = oldCalendar
                AppSettings.readingsEditionId = oldEdition
            }
        }
    }

    private fun openLuke(citation: ReadingCitation, firstText: String) {
        val buttonTag = "readingExpand.daily.${citation.full}"
        compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag(buttonTag))
        // A lazy-list item restores its expansion when returning to its date.
        if (compose.onAllNodes(hasTestTag(buttonTag) and hasText(compose.activity.getString(R.string.readings_show_text)))
                .fetchSemanticsNodes().isNotEmpty()) {
            compose.onNodeWithTag(buttonTag).performClick()
        }
        compose.waitUntil(15_000) {
            compose.onAllNodes(hasText(firstText, substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun usedHeap(): Long = Runtime.getRuntime().let { it.totalMemory() - it.freeMemory() }

    private fun collectedHeap(): Long {
        repeat(3) {
            Runtime.getRuntime().gc()
            System.runFinalization()
            SystemClock.sleep(100)
        }
        return usedHeap()
    }
}
