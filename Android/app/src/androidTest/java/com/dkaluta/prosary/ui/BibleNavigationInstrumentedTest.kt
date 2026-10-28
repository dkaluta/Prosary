package com.dkaluta.prosary.ui

import android.graphics.Bitmap
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.click
import androidx.compose.ui.test.performScrollToNode
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleBook
import com.dkaluta.prosary.content.bible.BibleCatalog
import com.dkaluta.prosary.content.bible.BibleChapter
import com.dkaluta.prosary.content.bible.BibleChapterInfo
import com.dkaluta.prosary.content.bible.BibleEdition
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.bible.BibleStore
import com.dkaluta.prosary.content.bible.BibleContentBlock
import com.dkaluta.prosary.content.bible.BibleAddress
import com.dkaluta.prosary.content.today.ReadingVerse
import com.dkaluta.prosary.content.today.ReadingSourceNote
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.readings.BibleScreen
import com.dkaluta.prosary.ui.readings.ReadingsScreen
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import java.io.File
import java.security.MessageDigest
import java.time.LocalDate
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class BibleNavigationInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()
    private val json = Json { encodeDefaults = true }

    private fun web(): android.webkit.WebView? {
        fun find(view: android.view.View): android.webkit.WebView? {
            if (view is android.webkit.WebView) return view
            if (view is android.view.ViewGroup) for (index in 0 until view.childCount) find(view.getChildAt(index))?.let { return it }
            return null
        }
        return find(compose.activity.window.decorView)
    }
    private fun script(code: String): String {
        val latch = java.util.concurrent.CountDownLatch(1)
        var result = "null"
        compose.activity.runOnUiThread {
            val view = web()
            if (view == null) latch.countDown() else view.evaluateJavascript(code) { result = it; latch.countDown() }
        }
        check(latch.await(10, java.util.concurrent.TimeUnit.SECONDS))
        return result
    }
    private fun ready() {
        compose.waitUntil(30_000) { runCatching {
            org.json.JSONObject(script("window.ProsaryReader?.position() ?? null")).getInt("total") > 0
        }.getOrDefault(false) }
    }

    @Test fun canonicalLabelsAndPhysicalWitnessesRemainInTheContinuousEdition() {
        val directory = File(compose.activity.cacheDir, "bible-reference-test-${UUID.randomUUID()}").apply { mkdirs() }
        val previous = AppSettings.readingsEditionId
        val (edition, archive) = fixture(directory, withRichSource = true, withCanonicalReference = true)
        val library = BibleLibrary(BibleStore(File(directory, "installed")), File(directory, "download"))
        library.store.install(edition, archive)
        val catalog = json.encodeToString(BibleCatalog(1, listOf(edition)))
        try {
            AppSettings.readingsEditionId = edition.id
            compose.setContent { MaterialTheme { BibleScreen(library) { catalog.byteInputStream() } } }
            ready()
            compose.onNodeWithTag("bibleChapter").assertTextContains("ברוך ו׳")
            val body = script("document.getElementById('flow').textContent")
            org.junit.Assert.assertTrue(body.contains("Source verse one"))
            org.junit.Assert.assertTrue(body.contains("Second printed witness"))
            org.junit.Assert.assertTrue(body.contains("Unnumbered thanksgiving hymn"))
            org.junit.Assert.assertTrue(body.indexOf("Source verse one") < body.indexOf("Second printed witness"))
            compose.onNodeWithTag("bibleVerse").performClick()
            compose.onNodeWithTag("bibleChoice.heading").assertDoesNotExist()
            compose.onNodeWithTag("bibleChoice.hymn").assertDoesNotExist()
            compose.onNodeWithTag("bibleChoice.primary-four").performClick()
            compose.waitUntil { script("window.ProsaryReader.position().anchor").contains("GEN/1/primary-four") }
            assertEquals(listOf(1, 4), library.store.chapter(edition, "GEN", 1)!!.verses.map { it.verse })
            val total = org.json.JSONObject(script("window.ProsaryReader.position()")).getInt("total")
            compose.onNodeWithTag("bibleNextChapter").performClick()
            compose.onNodeWithTag("bibleChapter").assertTextContains("Chapter 3")
            assertEquals(total, org.json.JSONObject(script("window.ProsaryReader.position()")).getInt("total"))
            org.junit.Assert.assertFalse(script("document.getElementById('flow').textContent").contains("Unreadable vowel"))
            compose.onNodeWithTag("bibleEditionText").performTouchInput { click(center) }
            compose.waitUntil(5_000) { compose.onAllNodesWithTag("biblePageCount").fetchSemanticsNodes().isEmpty() }
            compose.onNodeWithTag("biblePageCount").assertDoesNotExist()
            compose.onNodeWithTag("bibleChapter").assertDoesNotExist()
            compose.onNodeWithTag("bibleEditionText").performTouchInput { click(center) }
            compose.waitUntil(5_000) { compose.onAllNodesWithTag("bibleChapter").fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("bibleChapter").assertTextContains("Chapter 3")
        } finally { AppSettings.readingsEditionId = previous; directory.deleteRecursively() }
    }

    @Test fun sourceNotesUseTheirNativeDisclosureOutsideSelectableScripture() {
        val directory = File(compose.activity.cacheDir, "bible-notes-test-${UUID.randomUUID()}").apply { mkdirs() }
        val previous = AppSettings.readingsEditionId
        val (edition, archive) = fixture(directory, withSourceNote = true)
        val library = BibleLibrary(BibleStore(File(directory, "installed")), File(directory, "download"))
        library.store.install(edition, archive)
        val catalog = json.encodeToString(BibleCatalog(1, listOf(edition)))
        try {
            AppSettings.readingsEditionId = edition.id
            compose.setContent { MaterialTheme { BibleScreen(library) { catalog.byteInputStream() } } }
            ready()
            script("document.querySelector('[data-note]').click()")
            waitFor("scriptureSourceNote.bible-note")
            compose.onNodeWithTag("scriptureSourceNote.bible-note").performClick()
            compose.onNodeWithText(compose.activity.getString(R.string.scripture_source_note_vowel)).assertExists()
            org.junit.Assert.assertFalse(script("document.getElementById('flow').textContent").contains("Unreadable vowel"))
        } finally { AppSettings.readingsEditionId = previous; directory.deleteRecursively() }
    }

    @Test fun dailyReadingsHasNoFullBibleOrCalendarModeAndKeepsDateBrowsing() {
        val previous = AppSettings.readingsEditionId
        val date = TodayBrowsingDate(LocalDate.of(2026, 10, 1).toEpochDay())
        try {
            AppSettings.readingsEditionId = "douay-rheims-1899"
            compose.setContent { MaterialTheme { ReadingsScreen(browsingDate = date) } }
            compose.onNodeWithTag("readingsMode.bible").assertDoesNotExist()
            compose.onNodeWithTag("readingsMode.daily").assertDoesNotExist()
            compose.onNodeWithTag("readingsMode.feasts").assertDoesNotExist()
            compose.onNodeWithTag("bibleScreen").assertDoesNotExist()
            assertEquals(LocalDate.of(2026, 10, 1).toEpochDay(), date.selectedEpochDay)
            compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag("readingsPrevious"))
            compose.onNodeWithTag("readingsPrevious").performClick()
            assertEquals(LocalDate.of(2026, 9, 30).toEpochDay(), date.selectedEpochDay)
            assertEquals(LocalDate.of(2026, 9, 30).toEpochDay(), date.selectedEpochDay)
        } finally { AppSettings.readingsEditionId = previous }
    }

    private fun captureScreenshot(name: String) {
        if (InstrumentationRegistry.getArguments().getString("captureBibleScreenshots") != "true") return
        compose.waitForIdle()
        val bitmap = requireNotNull(InstrumentationRegistry.getInstrumentation().uiAutomation.takeScreenshot())
        File(compose.activity.filesDir, name).outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
    private fun waitFor(tag: String) {
        compose.waitUntil(10_000) { compose.onAllNodes(hasTestTag(tag)).fetchSemanticsNodes().isNotEmpty() }
    }
    private fun fixture(directory: File, withSourceNote: Boolean = false, withRichSource: Boolean = false,
        withCanonicalReference: Boolean = false): Pair<BibleEdition, File> {
        val books = listOf(BibleBook("GEN", "Genesis", listOf(BibleChapterInfo(1, 2, false,
            canonicalReference = if (withCanonicalReference) "ברוך ו׳" else null), BibleChapterInfo(3, 1, true)),
            introduction = "Unnumbered opening", canonicalReference = if (withCanonicalReference) "ברוך ו׳" else null),
            BibleBook("EXO", "Exodus", listOf(BibleChapterInfo(2, 1, false))))
        val revision = "a".repeat(64)
        val version = if (withRichSource) 3 else if (withSourceNote) 2 else 1
        val files = linkedMapOf("manifest.json" to """{"schemaVersion":$version,"editionId":"fixture","revision":"$revision","books":${json.encodeToString(books)}}""")
        books.forEach { book -> book.chapters.forEach { info ->
            var verses = if (info.verseCount == 2) listOf(ReadingVerse(info.number, 1, "Source verse one"), ReadingVerse(info.number, 4, "Source verse four", endVerse = 5))
                else listOf(ReadingVerse(info.number, 1, "Source chapter ${info.number}"))
            if (withSourceNote && book.id == "GEN" && info.number == 1) verses = verses.map { verse ->
                if (verse.verse == 1) verse.copy(text = "בַּקּבָּה", sourceNotes = listOf(ReadingSourceNote("bible-note",
                    "unreadablePoint", "בַּקּבָּה", 1, 2, "vowel", listOf(16), "https://example.org/scan.pdf#page=16"))) else verse
            }
            val blocks = if (withRichSource && book.id == "GEN" && info.number == 1) listOf(
                BibleContentBlock("heading", "heading", text = "Source heading"),
                BibleContentBlock("primary-one", "verse", 1, 1, printedLabel = "כ–כא"),
                BibleContentBlock("witness-one", "witness", printedLabel = "א", text = "Second printed witness", addresses = listOf(BibleAddress(1, 1))),
                BibleContentBlock("primary-four", "verse", 1, 4),
                BibleContentBlock("hymn", "passage", text = "Unnumbered thanksgiving hymn"),
                BibleContentBlock("colophon", "colophon", text = "ו", sourceNotes = listOf(ReadingSourceNote(
                    "colophon-shuruq", "unreadablePoint", "ו", 1, 1, "shuruq", listOf(225),
                    "https://example.org/scan.pdf#page=225"))),
            ) else null
            files[BibleStore.chapterPath(book.id, info.number)] = json.encodeToString(BibleChapter(version, "fixture", book.id, info.number, verses, blocks))
        } }
        val archive = File(directory, "fixture.zip")
        ZipOutputStream(archive.outputStream()).use { zip -> files.forEach { (name, text) ->
            zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry()
        } }
        val hash = MessageDigest.getInstance("SHA-256").digest(archive.readBytes()).joinToString("") { "%02x".format(it) }
        return BibleEdition("fixture", "en", "Fixture Bible", "Fixture credit", "https://example.org",
            revision, "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip", hash,
            archive.length(), files.values.sumOf { it.toByteArray().size.toLong() }, books, archiveSchemaVersion = version) to archive
    }
}
