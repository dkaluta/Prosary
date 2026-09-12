package com.dkaluta.prosary.ui

import android.graphics.Bitmap
import android.os.SystemClock
import android.util.Log
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.readings.ReadingCard
import com.dkaluta.prosary.ui.readings.ReadingsScreen
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

/** A bounded integration check of the actual packaged, source-generated corpus. */
class RealReadingCorpusInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun packagedEditionsResolveLukeAndRenderTheMarkedHebrewTorah() {
        val context = compose.activity.applicationContext
        AppSettings.init(context)
        val previousEdition = AppSettings.readingsEditionId
        val previousCalendar = AppSettings.feastCalendarId
        val store = ReadingTextStore { name -> context.assets.open("data/$name.json") }
        try {
            val editions = store.editions
            assertEquals(8, editions.size)
            val luke = ReadingCitation("gospel", "Lk. 6", "Luke 6:27–38")
            for (edition in editions) {
                InstrumentationRegistry.getInstrumentation().runOnMainSync { AppSettings.readingsEditionId = edition.id }
                assertEquals(edition.id, context.getSharedPreferences("prosary_settings", 0).getString("readingsEditionId", null))
                val selected = ReadingTextStore.effectiveEditionId(AppSettings.readingsEditionId, "ar", editions)
                assertEquals("An explicit saved edition must survive a different interface language", edition.id, selected)
                val start = SystemClock.elapsedRealtime()
                val runtime = Runtime.getRuntime()
                val heapBefore = runtime.totalMemory() - runtime.freeMemory()
                val verses = store.passage(luke, selected!!)?.verses
                if (edition == editions.first()) Log.i("ProsaryReadingCorpus",
                    "firstDecodeMs=${SystemClock.elapsedRealtime() - start}; heapBefore=$heapBefore; " +
                        "heapAfter=${runtime.totalMemory() - runtime.freeMemory()}; heapLimit=${runtime.maxMemory()}")
                // The reviewed Arabic corpus does not contain this Gospel yet.
                if (edition.languageCode == "ar") {
                    org.junit.Assert.assertNull(edition.id, verses)
                    continue
                }
                assertNotNull(edition.id, verses)
                assertEquals(edition.id, (27..38).toList(), verses!!.map { it.verse })
                assertTrue(edition.id, verses.all { it.chapter == 6 && it.text.isNotBlank() })
            }
            val hebrew = editions.single { it.languageCode == "he" }
            val torah = ReadingCitation("reading", "Gen. 47", "Genesis 47:28–50:26")
            val verses = store.passage(torah, hebrew.id, isTorah = true)!!.verses
            assertEquals(85, verses.size)
            assertEquals(47 to 28, verses.first().let { it.chapter to it.verse })
            assertEquals(50 to 26, verses.last().let { it.chapter to it.verse })
            val text = verses.joinToString("") { it.text }
            assertTrue("Source cantillation survives JSON decoding", text.any { it in '\u0591'..'\u05AF' })
            assertTrue("Ordinary Scripture vowels survive JSON decoding", text.any { it in '\u05B0'..'\u05BB' })
            val nameVerse = verses.single { it.chapter == 49 && it.verse == 18 }.text
            assertTrue("The source accent on the Divine Name remains", nameVerse.contains("יהוֽה"))
            assertFalse("No vowel points are reintroduced on the Divine Name", nameVerse.contains("יְהוָה"))
            InstrumentationRegistry.getInstrumentation().runOnMainSync { AppSettings.readingsEditionId = hebrew.id }
            val showsReadingsScreen = mutableStateOf(false)
            compose.setContent {
                MaterialTheme {
                    if (showsReadingsScreen.value) ReadingsScreen(onOpenSettings = {})
                    else Column(Modifier.verticalScroll(rememberScrollState())) {
                        ReadingCard(torah, "en", hebrew, hebrew.id, store, true,
                            expanded = true, onToggleExpanded = {})
                    }
                }
            }
            compose.waitUntil(15_000) {
                compose.onAllNodes(hasText(verses.first().text, substring = true)).fetchSemanticsNodes().isNotEmpty()
            }
            compose.onNodeWithText(verses.first().text, substring = true).assertExists()
            compose.onNodeWithText(nameVerse, substring = true).performScrollTo().assertExists()
            compose.onNodeWithText(hebrew.attribution).performScrollTo().assertExists()
            compose.onNodeWithText(verses.first().text, substring = true).performScrollTo()
            screenshot("readings-hebrew-torah.png")

            val english = editions.single { it.languageCode == "en" }
            TodayInfoStore.initialize { name -> context.assets.open("data/$name.json") }
            compose.runOnIdle {
                AppSettings.feastCalendarId = "roman"
                AppSettings.readingsEditionId = english.id
                showsReadingsScreen.value = true
            }
            // Prefer the pinned Luke example when it is today's Gospel, but keep this
            // integration test valid on another civil date or outside the bundled horizon.
            val currentReadings = TodayInfoStore.readings()
            val screenshotReading = currentReadings.firstOrNull { it.full == luke.full }
                ?: currentReadings.firstOrNull { store.passage(it, english.id) != null }
            if (screenshotReading != null) {
                val englishVerse = store.passage(screenshotReading, english.id)!!.verses.first().text
                compose.waitUntil(15_000) {
                    // Earlier cards can grow while their default-open passages load.
                    compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag("readingExpand.daily.${screenshotReading.full}"))
                    compose.onAllNodes(hasText(englishVerse, substring = true)).fetchSemanticsNodes().isNotEmpty()
                }
                compose.onNodeWithText(englishVerse, substring = true).performScrollTo().assertExists()
            }
            screenshot("readings-english.png")
        } finally {
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                AppSettings.readingsEditionId = previousEdition
                AppSettings.feastCalendarId = previousCalendar
            }
        }
    }

    private fun screenshot(name: String) {
        compose.waitForIdle()
        val bitmap = InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot()
        compose.activity.cacheDir.resolve(name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }
}
