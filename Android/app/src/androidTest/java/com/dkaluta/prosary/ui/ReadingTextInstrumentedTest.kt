package com.dkaluta.prosary.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.ui.readings.ReadingCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ReadingTextInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun expansionLoadsExactPassageAndPreservesHebrewMarksAndCredit() {
        val markedText = "סִימָן֑ לבדיקה"
        var opened = 0
        val store = ReadingTextStore { name ->
            assertEquals("readings-texts", name)
            opened++
            """{"schemaVersion":1,"passages":{"daily|Genesis 1:1":{"fixture-he":[{"chapter":1,"verse":1,"text":"$markedText"}]}}}""".byteInputStream()
        }
        val edition = ReadingEdition("fixture-he", "he", "Fixture edition", "Fixture source credit", "https://example.org")
        compose.setContent {
            MaterialTheme {
                ReadingCard(ReadingCitation("reading", "Gen. 1", "Genesis 1:1"), "en", edition, edition.id, store, false)
            }
        }
        compose.runOnIdle { assertEquals("Collapsed cards must not load the corpus", 0, opened) }
        compose.onNodeWithText(compose.activity.getString(R.string.readings_show_text)).performClick()
        compose.waitUntil(5_000) { compose.onAllNodes(androidx.compose.ui.test.hasText(markedText, substring = true)).fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText(markedText, substring = true).assertExists()
        compose.onNodeWithText("Fixture source credit").assertExists()
        compose.onNodeWithText("Genesis 1:1").assertExists()
        compose.onNodeWithText(compose.activity.getString(R.string.readings_whole_verses_notice)).assertDoesNotExist()
        compose.runOnIdle { assertEquals(1, opened) }
    }

    @Test fun partialVerseExpansionShowsTheNoticeAndPreservesTheAppointedCitation() {
        val citation = ReadingCitation("reading", "1 Cor. 8", "1 Corinthians 8:1b–7; 8:11–13")
        val store = ReadingTextStore {
            """{"schemaVersion":1,"wholeVersePassages":["daily|${citation.full}"],"passages":{"daily|${citation.full}":{"fixture-en":[{"chapter":8,"verse":1,"text":"The complete source verse"}]}}}""".byteInputStream()
        }
        val edition = ReadingEdition("fixture-en", "en", "Fixture edition", "Fixture source credit", "https://example.org")
        compose.setContent {
            MaterialTheme { ReadingCard(citation, "en", edition, edition.id, store, false) }
        }
        val notice = compose.activity.getString(R.string.readings_whole_verses_notice)
        compose.onNodeWithText(notice).assertDoesNotExist()
        compose.onNodeWithText(compose.activity.getString(R.string.readings_show_text)).performClick()
        compose.waitUntil(5_000) {
            compose.onAllNodes(androidx.compose.ui.test.hasText(notice)).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText(notice).assertExists()
        compose.onNodeWithText(citation.full).assertExists()
        compose.onNodeWithText("The complete source verse", substring = true).assertExists()
        compose.onNodeWithText(compose.activity.getString(R.string.readings_unavailable)).assertDoesNotExist()
    }

    @Test fun bundledHebrewGospelDisplaysTheSourceVowelsAndCredit() {
        val context = compose.activity.applicationContext
        val store = ReadingTextStore { name -> context.assets.open("data/$name.json") }
        val edition = store.editions.single { it.id == "masoretic-delitzsch" }
        val citation = ReadingCitation("gospel", "Lk", "Luke 6:27–38")
        val firstVerse = requireNotNull(store.passage(citation, edition.id)).verses.first().text
        assertTrue("The real Hebrew Gospel is vocalized", firstVerse.any { it in '\u05B0'..'\u05BC' })
        compose.setContent {
            MaterialTheme { ReadingCard(citation, "en", edition, edition.id, store, false) }
        }
        compose.onNodeWithText(compose.activity.getString(R.string.readings_show_text)).performClick()
        compose.waitUntil(5_000) {
            compose.onAllNodes(androidx.compose.ui.test.hasText(firstVerse, substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText(firstVerse, substring = true).assertExists()
        compose.onNodeWithText(edition.attribution).assertExists()
        compose.onNodeWithText(citation.full).assertExists()
    }
}
