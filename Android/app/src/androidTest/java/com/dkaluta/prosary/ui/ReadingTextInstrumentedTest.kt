package com.dkaluta.prosary.ui

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateOf
import android.content.res.Configuration
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.text.font.FontStyle
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.readings.ReadingCard
import com.dkaluta.prosary.ui.readings.ReadingChapterHeading
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.util.Locale

class ReadingTextInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun supplementalPassageShowsItsOwnSourceAndUnnumberedTextInReviewedOrder() {
        val citation = ReadingCitation("reading", "Fixture", "Fixture 2:12–13; 1:1")
        val store = ReadingTextStore { name ->
            (if (name == "readings-editions") """{"schemaVersion":1,"editions":[
                {"id":"fixture","languageCode":"en","name":"Selected Bible","attribution":"Base credit",
                 "sourceURL":"https://example.org/base"}]}"""
            else """{"schemaVersion":1,"wholeVersePassages":["daily|${citation.full}"],
                "passages":{"daily|${citation.full}":{"fixture":[
                    {"chapter":2,"verse":12,"endVerse":13,"text":"First source unit"},
                    {"chapter":1,"verse":1,"text":"Next source unit"}]}},
                "passageSources":{"daily|${citation.full}":{"fixture":{
                    "book":"SIR","name":"Actual source book","attribution":"Actual translator credit",
                    "sourceURL":"https://example.org/supplement","isComplete":false,"contentBlocks":[
                        {"id":"first","kind":"verse","chapter":2,"verse":12,"printedLabel":"12–13"},
                        {"id":"extra","kind":"passage","text":"Unnumbered source wording"},
                        {"id":"next","kind":"verse","chapter":1,"verse":1}]}}}}""").byteInputStream()
        }
        val edition = store.editions.single()
        compose.setContent { MaterialTheme {
            ReadingCard(citation, "en", edition, edition.id, store, false, expanded = true, onToggleExpanded = {})
        } }
        compose.waitUntil(5_000) { compose.onAllNodes(androidx.compose.ui.test.hasTestTag("readingSourceName"))
            .fetchSemanticsNodes().isNotEmpty() }
        compose.onNodeWithText("Actual source book").assertExists()
        compose.onNodeWithText("Actual translator credit").assertExists()
        compose.onNodeWithText("Base credit").assertDoesNotExist()
        compose.onNodeWithText("Selected Bible").assertExists()
        compose.onNodeWithText(citation.full).assertExists()
        compose.onNodeWithTag("readingPartialSource").assertExists()
        compose.onNodeWithText(compose.activity.getString(R.string.readings_whole_verses_notice)).assertExists()
        compose.onNodeWithText("\u206612–13\u2069  First source unit").assertExists()
        compose.onNodeWithText("Unnumbered source wording").assertExists()
        compose.onNodeWithText("\u20661\u2069  Next source unit").assertExists()
        val positions = listOf("first", "extra", "next").map {
            compose.onNodeWithTag("readingBlock.$it").fetchSemanticsNode().boundsInRoot.top
        }
        assertTrue(positions.zipWithNext().all { (before, after) -> before < after })
    }

    @Test fun dailySourceNoteExpandsSeparatelyWithoutChangingScripture() {
        val text = "בַּקּבָּה"
        val store = ReadingTextStore {
            """{"schemaVersion":1,"passages":{"daily|Fixture 1:9":{"fixture":[{"chapter":1,"verse":9,"text":"$text",
                "sourceNotes":[{"id":"daily-note","kind":"unreadablePoint","anchor":"$text","occurrence":1,
                "letterIndex":2,"mark":"vowel","sourcePages":[16],"sourceURL":"https://example.org/scan.pdf#page=16"}]}]}}}""".byteInputStream()
        }
        val edition = ReadingEdition("fixture", "he", "Fixture", "Credit", "https://example.org")
        compose.setContent { MaterialTheme {
            ReadingCard(ReadingCitation("reading", "Fixture", "Fixture 1:9"), "en", edition,
                edition.id, store, false, expanded = true, onToggleExpanded = {})
        } }
        compose.waitUntil(5_000) { compose.onAllNodes(androidx.compose.ui.test.hasTestTag("scriptureSourceNote.daily-note"))
            .fetchSemanticsNodes().isNotEmpty() }
        val explanation = compose.activity.getString(R.string.scripture_source_note_vowel)
        compose.onNodeWithText(explanation).assertDoesNotExist()
        compose.onNodeWithTag("scriptureSourceNote.daily-note").performClick()
        compose.onNodeWithText(explanation).assertExists()
        compose.onNodeWithText(text).assertExists()
        compose.onNodeWithText("\u20669\u2069  $text").assertExists()
        compose.onNodeWithText(compose.activity.getString(R.string.scripture_source_note_scan)).assertExists()
        compose.onNodeWithTag("scriptureSourceNote.daily-note").performClick()
        compose.onNodeWithText(explanation).assertDoesNotExist()
        compose.onNodeWithText("\u20669\u2069  $text").assertExists()
    }

    @Test fun chapterWordsAndNumeralsFollowTheBibleInsteadOfTheInterface() {
        val context = compose.activity
        val hebrewInterface = context.createConfigurationContext(Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag("he"))
        })
        assertEquals("Chapter 15", ReadingChapterHeading.label(hebrewInterface, 15, "en"))
        assertEquals("פרק ט״ו", ReadingChapterHeading.label(context, 15, "he"))
        assertEquals("الفصل ١٥", ReadingChapterHeading.label(context, 15, "ar"))
        assertEquals("Κεφάλαιο 15", ReadingChapterHeading.label(context, 15, "el"))
        assertEquals("קפלאון ט״ו", ReadingChapterHeading.label(context, 15, "arc", "Hebr"))
        assertEquals("ܩܦܠܐܘܢ ܝܗ", ReadingChapterHeading.label(context, 15, "arc", "Syrc"))
    }

    @Test fun chapterHeadingsSeparateChapterTransitionsAndVersesUseOnlyTheirNumber() {
        val store = ReadingTextStore { name ->
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[{"id":"fixture","languageCode":"en","name":"Fixture edition","attribution":"Fixture credit","sourceURL":"https://example.org"}]}"""
                else -> """{"schemaVersion":1,"passages":{"daily|Fixture 1:9; 2:1":{"fixture":[{"chapter":1,"verse":9,"text":"First chapter text"},{"chapter":2,"verse":1,"text":"Second chapter text"}]}}}"""
            }.byteInputStream()
        }
        val edition = store.editions.single()
        compose.setContent {
            MaterialTheme {
                ReadingCard(ReadingCitation("reading", "Fixture", "Fixture 1:9; 2:1"), "en", edition,
                    edition.id, store, false, expanded = true, onToggleExpanded = {})
            }
        }
        compose.waitUntil(5_000) {
            compose.onAllNodes(androidx.compose.ui.test.hasText("First chapter text", substring = true))
                .fetchSemanticsNodes().isNotEmpty()
        }
        compose.onNodeWithText(compose.activity.getString(R.string.readings_chapter, 1)).assertExists()
        compose.onNodeWithText(compose.activity.getString(R.string.readings_chapter, 2)).assertExists()
        compose.onNodeWithText("\u20669\u2069  First chapter text").assertExists()
        compose.onNodeWithText("\u20661\u2069  Second chapter text").assertExists()
        compose.onNodeWithText("1:9\u2069  First chapter text", substring = true).assertDoesNotExist()
    }

    @Test fun unavailablePassageOffersOnlyAvailableEditionsAndChangesEditionAfterExplicitChoice() {
        val previousEdition = AppSettings.readingsEditionId
        val store = ReadingTextStore { name ->
            when (name) {
                "readings-editions" -> """{"schemaVersion":1,"editions":[
                    {"id":"missing","languageCode":"en","name":"Missing edition","attribution":"Missing credit","sourceURL":"https://example.org/missing"},
                    {"id":"available","languageCode":"he","name":"Available edition","attribution":"Available credit","sourceURL":"https://example.org/available"},
                    {"id":"damaged","languageCode":"en","name":"Damaged edition","attribution":"Damaged credit","sourceURL":"https://example.org/damaged"}]}"""
                else -> """{"schemaVersion":1,"passages":{"daily|Fixture 1:1":{
                    "available":[{"chapter":1,"verse":1,"text":"סִימָן לבדיקה"}],
                    "damaged":[{"chapter":1,"verse":1,"text":" "}]}}}"""
            }.byteInputStream()
        }
        try {
            AppSettings.readingsEditionId = "missing"
            compose.setContent {
                MaterialTheme {
                    val edition = store.editions.firstOrNull { it.id == AppSettings.readingsEditionId }
                    ReadingCard(ReadingCitation("reading", "Fixture", "Fixture 1:1"), "en", edition,
                        edition?.id, store, false, expanded = true, onToggleExpanded = {})
                }
            }
            compose.waitUntil(5_000) {
                compose.onAllNodes(androidx.compose.ui.test.hasTestTag("readingAvailableEditions.daily.Fixture 1:1"))
                    .fetchSemanticsNodes().isNotEmpty()
            }
            compose.runOnIdle { assertEquals("missing", AppSettings.readingsEditionId) }
            compose.onNodeWithText("סִימָן לבדיקה", substring = true).assertDoesNotExist()
            compose.onNodeWithTag("readingAvailableEditions.daily.Fixture 1:1").performClick()
            compose.onNodeWithText("Damaged edition").assertDoesNotExist()
            compose.onNodeWithText("Available edition").performClick()
            compose.waitUntil(5_000) {
                compose.onAllNodes(androidx.compose.ui.test.hasText("סִימָן לבדיקה", substring = true))
                    .fetchSemanticsNodes().isNotEmpty()
            }
            compose.onNodeWithText("Available credit").assertExists()
            compose.onNodeWithTag("readingAvailableEditions.daily.Fixture 1:1").assertDoesNotExist()
            compose.runOnIdle { assertEquals("available", AppSettings.readingsEditionId) }
        } finally { AppSettings.readingsEditionId = previousEdition }
    }

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
        compose.onNodeWithText("פרק א׳").assertExists()
        compose.onNodeWithText("Chapter 1").assertDoesNotExist()
        compose.onNodeWithText("פרק א׳").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { action ->
            val layouts = mutableListOf<androidx.compose.ui.text.TextLayoutResult>()
            assertTrue(action(layouts))
            assertEquals(FontStyle.Normal, layouts.single().layoutInput.style.fontStyle)
        }
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
