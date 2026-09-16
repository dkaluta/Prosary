package com.dkaluta.prosary.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.readings.ReadingCard
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ReadingTextInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun aramaicDefaultAndLocalToggleChangeTheRenderedVersesAndSurviveCollapse() {
        val previousScript = AppSettings.aramaicDefaultScript
        val store = ReadingTextStore { name ->
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[{"id":"paired","languageCode":"arc","name":"Fixture Peshitta","attribution":"Fixture credit","sourceURL":"https://example.org","textScript":"Hebr","transliteratedTextScript":"Syrc"}]}"""
                else -> """{"schemaVersion":1,"passages":{"daily|Fixture 1:1":{"paired":[{"chapter":1,"verse":1,"text":"בדיקה","transliteratedText":"ܐܒܓ"}]},"daily|Fixture 1:2":{"paired":[{"chapter":1,"verse":2,"text":"בדיקה","transliteratedText":"ܐܒܓ"}]}}}"""
            }.byteInputStream()
        }
        val edition = store.editions.single()
        val expanded = mutableStateOf(true)
        val citation = mutableStateOf(ReadingCitation("reading", "Fixture", "Fixture 1:1"))
        fun waitFor(text: String) {
            compose.waitUntil(5_000) {
                compose.onAllNodes(androidx.compose.ui.test.hasText(text, substring = true)).fetchSemanticsNodes().isNotEmpty()
            }
        }
        try {
            AppSettings.setAramaicDefaultScript("Syrc")
            compose.setContent {
                MaterialTheme {
                    ReadingCard(citation.value, "en", edition, edition.id, store, false,
                        expanded = expanded.value, onToggleExpanded = { expanded.value = !expanded.value })
                }
            }
            waitFor("ܐܒܓ")
            compose.runOnIdle { AppSettings.setAramaicDefaultScript("Hebr") }
            waitFor("בדיקה")
            compose.runOnIdle { AppSettings.setAramaicDefaultScript("Syrc") }
            waitFor("ܐܒܓ")
            compose.onNodeWithTag("readingScript.daily.Fixture 1:1").performClick()
            waitFor("בדיקה")
            compose.onNodeWithText("ܐܒܓ", substring = true).assertDoesNotExist()
            compose.runOnIdle { assertEquals("Syrc", AppSettings.aramaicDefaultScript) }
            compose.onNodeWithText(compose.activity.getString(R.string.readings_hide_text)).performClick()
            compose.onNodeWithText(compose.activity.getString(R.string.readings_show_text)).performClick()
            waitFor("בדיקה")
            compose.runOnIdle { citation.value = citation.value.copy(full = "Fixture 1:2") }
            waitFor("ܐܒܓ")
        } finally { AppSettings.setAramaicDefaultScript(previousScript) }
    }

    @Test fun expansionLoadsExactPassageAndPreservesHebrewMarksAndCredit() {
        val markedText = "סִימָן֑ לבדיקה"
        var opened = 0
        val store = ReadingTextStore { name ->
            if (name == "readings-texts") {
                opened++
                """{"schemaVersion":1,"passages":{"daily|Genesis 1:1":{"fixture-he":[{"chapter":1,"verse":1,"text":"$markedText"}]}}}""".byteInputStream()
            } else """{"schemaVersion":1,"editions":[]}""".byteInputStream()
        }
        val edition = ReadingEdition("fixture-he", "he", "Fixture edition", "Fixture source credit", "https://example.org")
        val expanded = mutableStateOf(false)
        compose.setContent {
            MaterialTheme {
                ReadingCard(ReadingCitation("reading", "Gen. 1", "Genesis 1:1"), "en", edition, edition.id, store, false,
                    expanded = expanded.value, onToggleExpanded = { expanded.value = !expanded.value })
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
        val expanded = mutableStateOf(false)
        compose.setContent {
            MaterialTheme {
                ReadingCard(citation, "en", edition, edition.id, store, false,
                    expanded = expanded.value, onToggleExpanded = { expanded.value = !expanded.value })
            }
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
            MaterialTheme { ReadingCard(citation, "en", edition, edition.id, store, false,
                expanded = true, onToggleExpanded = {}) }
        }
        compose.waitUntil(5_000) {
            compose.onAllNodes(androidx.compose.ui.test.hasText(firstVerse, substring = true)).fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText(firstVerse, substring = true).assertExists()
        compose.onNodeWithText(edition.attribution).assertExists()
        compose.onNodeWithText(citation.full).assertExists()
    }
}
