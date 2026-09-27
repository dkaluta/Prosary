package com.dkaluta.prosary.ui

import android.graphics.Bitmap
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.test.junit4.StateRestorationTester
import androidx.test.platform.app.InstrumentationRegistry
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleBook
import com.dkaluta.prosary.content.bible.BibleCatalog
import com.dkaluta.prosary.content.bible.BibleChapter
import com.dkaluta.prosary.content.bible.BibleChapterInfo
import com.dkaluta.prosary.content.bible.BibleEdition
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.bible.BibleStore
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

    @Test fun downloadedBibleShowsSourceNoteAndKeepsItOutOfVerseNavigation() {
        val directory = File(compose.activity.cacheDir, "bible-note-test-${UUID.randomUUID()}").apply { mkdirs() }
        val previous = AppSettings.readingsEditionId
        val (edition, archive) = fixture(directory, withSourceNote = true)
        val library = BibleLibrary(BibleStore(File(directory, "installed")), File(directory, "download"))
        library.store.install(edition, archive)
        val catalog = json.encodeToString(BibleCatalog(1, listOf(edition)))
        try {
            AppSettings.readingsEditionId = edition.id
            compose.setContent { MaterialTheme { BibleScreen(library) { catalog.byteInputStream() } } }
            waitFor("scriptureSourceNote.bible-note")
            val explanation = compose.activity.getString(R.string.scripture_source_note_vowel)
            compose.onNodeWithText(explanation).assertDoesNotExist()
            compose.onNodeWithTag("scriptureSourceNote.bible-note").performClick()
            compose.onNodeWithText(explanation).assertExists()
            compose.onNodeWithTag("bibleVerse.1").assertTextContains("בַּקּבָּה", substring = true)
            compose.onNodeWithTag("bibleVerse").performClick()
            compose.onNodeWithTag("bibleChoice.5").performClick()
            compose.onNodeWithTag("bibleVerse.4").assertTextContains("4–5", substring = true)
            compose.onNodeWithTag("bibleNextChapter").performClick()
            waitFor("bibleVerse.1")
            compose.onNodeWithTag("scriptureSourceNote.bible-note").assertDoesNotExist()
        } finally { AppSettings.readingsEditionId = previous; directory.deleteRecursively() }
    }

    @Test fun sparseChapterNavigationVerseJumpAndRemovalStayWithinTheSelectedEdition() {
        val directory = File(compose.activity.cacheDir, "bible-test-${UUID.randomUUID()}").apply { mkdirs() }
        val previous = AppSettings.readingsEditionId
        val (edition, archive) = fixture(directory)
        val library = BibleLibrary(BibleStore(File(directory, "installed")), File(directory, "download"))
        library.store.install(edition, archive)
        val catalog = json.encodeToString(BibleCatalog(1, listOf(edition)))
        try {
            AppSettings.readingsEditionId = edition.id
            val restoration = StateRestorationTester(compose)
            restoration.setContent { MaterialTheme { BibleScreen(library) { catalog.byteInputStream() } } }
            waitFor("bibleVerse.1")
            compose.onNodeWithTag("biblePartialChapter").assertExists()
            compose.onNodeWithTag("bibleIntroduction").assertTextContains("Unnumbered opening")
            captureScreenshot("bible-partial-chapter.png")
            compose.onNodeWithTag("bibleVerse").performClick()
            compose.onNodeWithTag("bibleChoice.5").performClick()
            compose.onNodeWithTag("bibleVerse.4").assertTextContains("Source verse four", substring = true)
            compose.onNodeWithTag("bibleVerse.4").assertTextContains("4–5", substring = true)
            compose.onNodeWithTag("bibleVerse.2").assertDoesNotExist()
            compose.onNodeWithTag("bibleNextChapter").performClick()
            waitFor("bibleVerse.1")
            compose.onNodeWithTag("bibleChapter").assertTextContains("Chapter 3")
            compose.onNodeWithTag("biblePartialChapter").assertDoesNotExist()
            compose.onNodeWithTag("bibleIntroduction").assertDoesNotExist()
            restoration.emulateSavedInstanceStateRestore()
            waitFor("bibleChapter")
            compose.onNodeWithTag("bibleChapter").assertTextContains("Chapter 3")
            compose.onNodeWithTag("bibleNextChapter").performClick()
            compose.onNodeWithTag("bibleBook").assertTextContains("Exodus")
            compose.onNodeWithTag("bibleChapter").assertTextContains("Chapter 2")
            compose.onNodeWithTag("biblePreviousChapter").performClick()
            compose.onNodeWithTag("bibleBook").assertTextContains("Genesis")
            compose.onNodeWithTag("bibleChapter").performClick()
            compose.onNodeWithTag("bibleChoice.1").performClick()
            waitFor("biblePartialChapter")
            compose.onNodeWithTag("bibleVerses").performScrollToNode(hasTestTag("bibleVerse.4"))
            compose.onNodeWithTag("bibleVerse.4").assertExists()
            compose.onNodeWithTag("bibleRemoveDownload").performClick()
            compose.onNodeWithText(compose.activity.getString(R.string.settings_remove_all_confirm)).performClick()
            waitFor("bibleDownload")
            compose.onNodeWithTag("bibleVerses").assertDoesNotExist()
            assertEquals(null, library.store.installedEdition(edition.id))
        } finally {
            AppSettings.readingsEditionId = previous
            directory.deleteRecursively()
        }
    }

    @Test fun dailyAndBibleModesRetainSelectedDateWithoutChangingIt() {
        val previous = AppSettings.readingsEditionId
        val date = TodayBrowsingDate(LocalDate.of(2026, 10, 1).toEpochDay())
        try {
            AppSettings.readingsEditionId = "douay-rheims-1899"
            compose.setContent { MaterialTheme { ReadingsScreen(onOpenSettings = {}, browsingDate = date) } }
            compose.onNodeWithTag("readingsMode.bible").performClick()
            waitFor("bibleScreen")
            waitFor("bibleDownload")
            captureScreenshot("bible-library.png")
            assertEquals(LocalDate.of(2026, 10, 1).toEpochDay(), date.selectedEpochDay)
            compose.onNodeWithTag("readingsMode.daily").performClick()
            compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag("readingsPrevious"))
            compose.onNodeWithTag("readingsPrevious").performClick()
            assertEquals(LocalDate.of(2026, 9, 30).toEpochDay(), date.selectedEpochDay)
            compose.onNodeWithTag("readingsMode.bible").performClick()
            compose.onNodeWithTag("readingsMode.daily").performClick()
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
    private fun fixture(directory: File, withSourceNote: Boolean = false): Pair<BibleEdition, File> {
        val books = listOf(BibleBook("GEN", "Genesis", listOf(BibleChapterInfo(1, 2, false), BibleChapterInfo(3, 1, true)),
            introduction = "Unnumbered opening"),
            BibleBook("EXO", "Exodus", listOf(BibleChapterInfo(2, 1, false))))
        val revision = "a".repeat(64)
        val version = if (withSourceNote) 2 else 1
        val files = linkedMapOf("manifest.json" to """{"schemaVersion":$version,"editionId":"fixture","revision":"$revision","books":${json.encodeToString(books)}}""")
        books.forEach { book -> book.chapters.forEach { info ->
            var verses = if (info.verseCount == 2) listOf(ReadingVerse(info.number, 1, "Source verse one"), ReadingVerse(info.number, 4, "Source verse four", endVerse = 5))
                else listOf(ReadingVerse(info.number, 1, "Source chapter ${info.number}"))
            if (withSourceNote && book.id == "GEN" && info.number == 1) verses = verses.map { verse ->
                if (verse.verse == 1) verse.copy(text = "בַּקּבָּה", sourceNotes = listOf(ReadingSourceNote("bible-note",
                    "unreadablePoint", "בַּקּבָּה", 1, 2, "vowel", listOf(16), "https://example.org/scan.pdf#page=16"))) else verse
            }
            files[BibleStore.chapterPath(book.id, info.number)] = json.encodeToString(BibleChapter(version, "fixture", book.id, info.number, verses))
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
