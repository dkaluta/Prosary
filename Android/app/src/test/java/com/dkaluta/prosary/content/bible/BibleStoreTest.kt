package com.dkaluta.prosary.content.bible

import com.dkaluta.prosary.content.today.ReadingVerse
import com.dkaluta.prosary.content.today.ReadingSourceNote
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class BibleStoreTest {
    @get:Rule val temporary = TemporaryFolder()
    private val json = Json { encodeDefaults = true }
    private val books = listOf(
        BibleBook("GEN", "Genesis", listOf(BibleChapterInfo(1, 2, false), BibleChapterInfo(3, 1, true))),
        BibleBook("EXO", "Exodus", listOf(BibleChapterInfo(2, 1, false))),
    )
    private fun revision(marker: String) = sha(marker.toByteArray())
    private fun sha(bytes: ByteArray) = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }
    private fun base(marker: String = "first", paired: Boolean = false): BibleEdition = BibleEdition(
        "fixture", if (paired) "arc" else "en", "Fixture Bible", "Fixture attribution", "https://example.org/source",
        revision(marker), "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip",
        "0".repeat(64), 1, 1,
        if (paired) books.map { it.copy(transliteratedName = "ܟܬܒܐ") } else books,
        if (paired) "Hebr" else null, if (paired) "Syrc" else null,
    )
    private fun entries(edition: BibleEdition): LinkedHashMap<String, ByteArray> {
        val manifest = """{"schemaVersion":${edition.archiveSchemaVersion},"editionId":"${edition.id}","revision":"${edition.revision}","books":${json.encodeToString(edition.books)}}"""
        return linkedMapOf("manifest.json" to manifest.toByteArray()).apply {
            edition.books.forEach { book -> book.chapters.forEach { info ->
                val labels = if (info.verseCount == 2) listOf(1, 4) else listOf(1)
                val verses = labels.map { ReadingVerse(info.number, it, "Printed $it", if (edition.textScript != null) "ܟܬܒܐ $it" else null) }
                put(BibleStore.chapterPath(book.id, info.number), json.encodeToString(BibleChapter(edition.archiveSchemaVersion, edition.id, book.id, info.number, verses)).toByteArray())
            } }
        }
    }
    private fun archive(edition: BibleEdition, entries: Map<String, ByteArray> = entries(edition)): Pair<BibleEdition, File> {
        val zip = temporary.newFile()
        ZipOutputStream(zip.outputStream()).use { output ->
            entries.forEach { (name, bytes) -> output.putNextEntry(ZipEntry(name)); output.write(bytes); output.closeEntry() }
        }
        return edition.copy(archiveSHA256 = sha(zip.readBytes()), archiveByteCount = zip.length(),
            unpackedByteCount = entries.values.sumOf { it.size.toLong() }) to zip
    }
    private fun store() = BibleStore(temporary.newFolder())
    private fun rejected(block: () -> Unit) {
        try { block(); fail("Untrusted content was accepted") } catch (_: IllegalArgumentException) { }
    }

    @Test fun installsPersistsAndLoadsSparseSourceLabelsWithoutRenumbering() {
        val directory = temporary.newFolder()
        val (edition, zip) = archive(base())
        BibleStore(directory).install(edition, zip)
        val reopened = BibleStore(directory)
        assertEquals(edition, reopened.installedEdition(edition.id))
        assertEquals(listOf(1, 4), reopened.chapter(edition, "GEN", 1)!!.verses.map { it.verse })
        assertNull(reopened.chapter(edition, "GEN", 2))
        assertNull(reopened.chapter(edition, "MAT", 1))
        assertFalse(edition.books.first().chapters.first().isComplete)
    }

    @Test fun versionTwoSourceNotesSurviveInstallationAndRequireMatchingArchiveVersions() {
        val note = ReadingSourceNote("source-word", "unreadablePoint", "בַּקּבָּה", 1, 2,
            "vowel", listOf(16), "https://example.org/source.pdf#page=16")
        val initial = base().copy(archiveSchemaVersion = 2)
        val chapter = BibleChapter(2, initial.id, "GEN", 1,
            listOf(ReadingVerse(1, 1, note.anchor, sourceNotes = listOf(note)), ReadingVerse(1, 4, "Four")))
        val files = entries(initial).apply { put("chapters/GEN/1.json", json.encodeToString(chapter).toByteArray()) }
        val (edition, zip) = archive(initial, files)
        val store = store()
        store.install(edition, zip)
        assertEquals(note, store.chapter(edition, "GEN", 1)!!.verses.first().sourceNotes!!.single())
        rejected { store().install(edition.copy(archiveSchemaVersion = 1), zip) }
        for (wrong in listOf(1, 3)) {
            val mismatched = files.toMutableMap().apply {
                put("chapters/GEN/1.json", json.encodeToString(chapter.copy(schemaVersion = wrong)).toByteArray())
            }
            val (bad, badZip) = archive(initial, mismatched)
            rejected { store().install(bad, badZip) }
        }
        for (version in listOf(0, 4)) rejected { BibleStore.validateEdition(initial.copy(archiveSchemaVersion = version)) }
        val old = base()
        val oldFiles = entries(old).apply {
            put("chapters/GEN/1.json", json.encodeToString(chapter.copy(schemaVersion = 1)).toByteArray())
        }
        val (oldEdition, oldZip) = archive(old, oldFiles)
        rejected { store().install(oldEdition, oldZip) }
    }

    @Test fun sourceNoteIdsAreUniqueAcrossEveryChapterOfOneBook() {
        val note = ReadingSourceNote("duplicate", "unreadablePoint", "ק", 1, 1, "vowel", listOf(1), "https://example.org")
        val initial = base().copy(archiveSchemaVersion = 2)
        val files = entries(initial).apply {
            for (chapter in listOf(1, 3)) {
                val units = listOf(ReadingVerse(chapter, 1, "ק", sourceNotes = listOf(note))) +
                    if (chapter == 1) listOf(ReadingVerse(1, 4, "Four")) else emptyList()
                put("chapters/GEN/$chapter.json", json.encodeToString(BibleChapter(2, initial.id, "GEN", chapter, units)).toByteArray())
            }
        }
        val (edition, zip) = archive(initial, files)
        rejected { store().install(edition, zip) }
    }
    @Test fun rejectsWrongHashAndByteCount() {
        val (edition, zip) = archive(base())
        rejected { store().install(edition.copy(archiveSHA256 = "0".repeat(64)), zip) }
        rejected { store().install(edition.copy(archiveByteCount = edition.archiveByteCount + 1), zip) }
    }
    @Test fun rejectsTraversalEvenWhenArchiveHashIsCorrect() {
        val initial = base()
        val files = entries(initial).apply { put("../outside.json", "escape".toByteArray()) }
        val (edition, zip) = archive(initial, files)
        rejected { store().install(edition, zip) }
        assertFalse(File(temporary.root, "outside.json").exists())
    }
    @Test fun requiresEveryDeclaredChapterAndNoExtraEntries() {
        val initial = base()
        val missing = entries(initial).apply { remove("chapters/GEN/3.json") }
        val (edition, zip) = archive(initial, missing)
        rejected { store().install(edition, zip) }
        val extra = entries(initial).apply { put("chapters/GEN/2.json", getValue("chapters/GEN/3.json")) }
        val (edition2, zip2) = archive(initial, extra)
        rejected { store().install(edition2, zip2) }
    }
    @Test fun manifestMustMatchEveryCatalogBookAndRevision() {
        val initial = base()
        for (replacement in listOf("other", "0".repeat(64))) {
            val files = entries(initial).apply {
                put("manifest.json", getValue("manifest.json").decodeToString()
                    .replace(if (replacement == "other") "Genesis" else initial.revision, replacement).toByteArray())
            }
            val (edition, zip) = archive(initial, files)
            rejected { store().install(edition, zip) }
        }
    }
    @Test fun chapterIdentityLabelsCountsAndTextAreValidated() {
        val initial = base()
        val valid = BibleChapter(1, initial.id, "GEN", 1, listOf(ReadingVerse(1, 1, "One"), ReadingVerse(1, 4, "Four")))
        val invalid = listOf(
            valid.copy(editionId = "other"), valid.copy(book = "EXO"), valid.copy(chapter = 2),
            valid.copy(schemaVersion = 2), valid.copy(verses = listOf(ReadingVerse(1, 1, "One"))),
            valid.copy(verses = listOf(ReadingVerse(1, 1, "One"), ReadingVerse(1, 1, "Again"))),
            valid.copy(verses = listOf(ReadingVerse(1, 0, "Zero"), ReadingVerse(1, 1, "One"))),
            valid.copy(verses = listOf(ReadingVerse(2, 1, "Wrong chapter"), ReadingVerse(1, 4, "Four"))),
            valid.copy(verses = listOf(ReadingVerse(1, 1, "  \n"), ReadingVerse(1, 4, "Four"))),
        )
        invalid.forEach { chapter ->
            val files = entries(initial).apply { put("chapters/GEN/1.json", json.encodeToString(chapter).toByteArray()) }
            val (edition, zip) = archive(initial, files)
            rejected { store().install(edition, zip) }
        }
    }
    @Test fun pairedEditionRequiresBothScripts() {
        val initial = base(paired = true)
        val (edition, zip) = archive(initial)
        val store = store()
        store.install(edition, zip)
        assertEquals("ܟܬܒܐ 1", store.chapter(edition, "GEN", 1)!!.verses.first().transliteratedText)
        val files = entries(initial).apply {
            val chapter = json.decodeFromString<BibleChapter>(getValue("chapters/GEN/1.json").decodeToString())
            put("chapters/GEN/1.json", json.encodeToString(chapter.copy(verses = chapter.verses.map { it.copy(transliteratedText = null) })).toByteArray())
        }
        val (broken, brokenZip) = archive(initial, files)
        rejected { store().install(broken, brokenZip) }
    }
    @Test fun failedUpdateLeavesWorkingEditionAndMetadataIntact() {
        val store = store()
        val (first, firstZip) = archive(base())
        store.install(first, firstZip)
        val second = base("second").copy(books = books.map { it.copy(name = "New ${it.name}") })
        val files = entries(second).apply { put("chapters/GEN/1.json", "{}".toByteArray()) }
        val (badUpdate, badZip) = archive(second, files)
        try { store.install(badUpdate, badZip); fail("Invalid chapter accepted") } catch (_: Exception) { }
        assertEquals(first, store.installedEdition(first.id))
        assertEquals("Printed 1", store.chapter(first, "GEN", 1)!!.verses.first().text)
        val (update, updateZip) = archive(second)
        store.install(update, updateZip)
        assertEquals(update, store.installedEdition(first.id))
        assertNull(store.chapter(first, "GEN", 1))
    }
    @Test fun removeClearsOnlySelectedEditionAndOldReaderCannotLoadIt() {
        val store = store()
        val (first, zip) = archive(base())
        val (second, otherZip) = archive(base("second").copy(id = "second"))
        store.install(first, zip)
        store.install(second, otherZip)
        store.remove(first.id)
        assertNull(store.installedEdition(first.id))
        assertNull(store.chapter(first, "GEN", 1))
        assertEquals(second, store.installedEdition(second.id))
        assertNotNull(store.chapter(second, "GEN", 1))
        store.remove(first.id)
    }
    @Test fun malformedCatalogUrlsIdentitiesAndBudgetsAreRejected() {
        val initial = base()
        for (url in listOf("http://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip",
            "https://example.org/fixture.zip", "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/../fixture.zip",
            "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip?other=1",
            "https://raw.githubusercontent.com:443/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip")) {
            rejected { BibleStore.validateEdition(initial.copy(downloadURL = url)) }
        }
        for (bad in listOf(initial.copy(id = "../escape"), initial.copy(revision = "bad"),
            initial.copy(archiveByteCount = BibleStore.MAX_ARCHIVE_BYTES + 1),
            initial.copy(unpackedByteCount = BibleStore.MAX_EXPANDED_BYTES + 1),
            initial.copy(books = books + books.first()),
            initial.copy(books = listOf(books.first().copy(chapters = listOf(BibleChapterInfo(2, 1, true), BibleChapterInfo(1, 1, true))))))) {
            rejected { BibleStore.validateEdition(bad) }
        }
    }
    @Test fun oversizedExpandedEntryIsRejectedBeforeInstallation() {
        val initial = base()
        val files = entries(initial).apply { put("chapters/GEN/1.json", ByteArray(BibleStore.MAX_CHAPTER_BYTES.toInt() + 1) { 32 }) }
        val (edition, zip) = archive(initial, files)
        rejected { store().install(edition, zip) }
    }
    @Test fun catalogParsesRealNativeMetadata() {
        val catalog = File("src/main/assets/data/bible-catalog.json").inputStream().use { store().catalog(it) }
        assertEquals(1, catalog.schemaVersion)
        assertEquals(10, catalog.editions.size)
        assertTrue(catalog.editions.any { it.id == "jesuit-arabic-1897" && it.books.any { book -> book.chapters.any { chapter -> !chapter.isComplete } } })
        assertTrue(catalog.editions.single { it.id == "peshitta-1905" }.readingEdition().hasAramaicScripts)
    }
    @Test fun nativeCatalogArchivesInstallAndEveryChapterLoads() {
        val catalog = File("src/main/assets/data/bible-catalog.json").inputStream().use { store().catalog(it) }
        val store = store()
        for (edition in catalog.editions) {
            val archive = File("../../Shared/dist/bibles", edition.downloadURL.substringAfterLast('/'))
            assertTrue("Missing canonical Bible archive: $archive", archive.isFile)
            store.install(edition, archive)
            for (book in edition.books) for (chapter in book.chapters) {
                val result = store.chapter(edition, book.id, chapter.number)
                assertNotNull("${edition.id} ${book.id} ${chapter.number}", result)
                assertEquals(chapter.verseCount, result!!.verses.size)
            }
        }
    }
    @Test fun navigationSkipsUnavailableChaptersAndCrossesBooks() {
        val edition = base()
        assertEquals(BibleNavigation.Position("GEN", 1), BibleNavigation.resolve(edition, null, null))
        assertEquals(BibleNavigation.Position("GEN", 1), BibleNavigation.resolve(edition, "GEN", 2))
        assertEquals(BibleNavigation.Position("EXO", 2), BibleNavigation.resolve(edition, "EXO", 999))
        val first = BibleNavigation.Position("GEN", 1)
        val third = BibleNavigation.Position("GEN", 3)
        val nextBook = BibleNavigation.Position("EXO", 2)
        assertNull(BibleNavigation.neighbor(edition, first, -1))
        assertEquals(third, BibleNavigation.neighbor(edition, first, 1))
        assertEquals(nextBook, BibleNavigation.neighbor(edition, third, 1))
        assertEquals(third, BibleNavigation.neighbor(edition, nextBook, -1))
        assertNull(BibleNavigation.neighbor(edition, nextBook, 1))
    }

    @Test fun combinedSourceUnitPreservesItsRangeAndJumpMatchesEitherNumber() {
        val initial = base()
        val units = listOf(ReadingVerse(1, 10, "One indivisible source unit", endVerse = 11),
            ReadingVerse(1, 14, "Later source unit"))
        val files = entries(initial).apply {
            put("chapters/GEN/1.json", json.encodeToString(BibleChapter(1, initial.id, "GEN", 1, units)).toByteArray())
        }
        val (edition, zip) = archive(initial, files)
        val store = store()
        store.install(edition, zip)
        val verses = store.chapter(edition, "GEN", 1)!!.verses
        assertEquals("10–11", verses.first().verseLabel)
        assertEquals(0, BibleNavigation.verseIndex(verses, 10))
        assertEquals(0, BibleNavigation.verseIndex(verses, 11))
        assertEquals(-1, BibleNavigation.verseIndex(verses, 12))
        assertEquals(1, BibleNavigation.verseIndex(verses, 14))
    }

    @Test fun reversedAndOverlappingSourceRangesAreRejected() {
        val initial = base()
        for (units in listOf(
            listOf(ReadingVerse(1, 10, "Invalid", endVerse = 9), ReadingVerse(1, 14, "Later")),
            listOf(ReadingVerse(1, 10, "Combined", endVerse = 11), ReadingVerse(1, 11, "Overlap")),
            listOf(ReadingVerse(1, 10, "Unbounded", endVerse = Int.MAX_VALUE), ReadingVerse(1, 14, "Later")),
        )) {
            val files = entries(initial).apply {
                put("chapters/GEN/1.json", json.encodeToString(BibleChapter(1, initial.id, "GEN", 1, units)).toByteArray())
            }
            val (edition, zip) = archive(initial, files)
            rejected { store().install(edition, zip) }
        }
    }

    @Test fun displacedSirachLabelsKeepPrintedOrderAndJumpFindsThePrintedUnit() {
        val labels = listOf(24, 26, 27, 25, 28)
        val initial = base().copy(books = listOf(BibleBook("SIR", "Sirach",
            listOf(BibleChapterInfo(3, labels.size, false)))))
        val units = labels.map { ReadingVerse(3, it, "Source unit $it") }
        val files = entries(initial).apply {
            put("chapters/SIR/3.json", json.encodeToString(BibleChapter(1, initial.id, "SIR", 3, units)).toByteArray())
        }
        val (edition, zip) = archive(initial, files)
        val directory = temporary.newFolder()
        BibleStore(directory).install(edition, zip)
        val restored = BibleStore(directory).chapter(edition, "SIR", 3)!!.verses
        assertEquals(labels, restored.map { it.verse })
        assertEquals(units, restored)
        assertEquals(3, BibleNavigation.verseIndex(restored, 25))
        assertEquals(1, BibleNavigation.verseIndex(restored, 26))
        assertEquals(-1, BibleNavigation.verseIndex(restored, 29))
    }

    @Test fun displacedUnitsStillRejectGlobalOverlapsAndDuplicateLabels() {
        val initial = base().copy(books = listOf(BibleBook("SIR", "Sirach",
            listOf(BibleChapterInfo(3, 3, false)))))
        for (units in listOf(
            listOf(ReadingVerse(3, 26, "Combined", endVerse = 27), ReadingVerse(3, 24, "Earlier"), ReadingVerse(3, 25, "Overlaps first", endVerse = 26)),
            listOf(ReadingVerse(3, 26, "First"), ReadingVerse(3, 24, "Earlier"), ReadingVerse(3, 26, "Duplicate")),
        )) {
            val files = entries(initial).apply {
                put("chapters/SIR/3.json", json.encodeToString(BibleChapter(1, initial.id, "SIR", 3, units)).toByteArray())
            }
            val (edition, zip) = archive(initial, files)
            rejected { store().install(edition, zip) }
        }
    }

    @Test fun unnumberedBookIntroductionIsPreservedAsMetadataAndNeverCreatesAVerse() {
        val initial = base().copy(books = books.map { it.copy(introduction = "The printed opening, without a verse label.") })
        val (edition, zip) = archive(initial)
        val store = store()
        store.install(edition, zip)
        assertEquals(initial.books.first().introduction, store.installedEdition(edition.id)!!.books.first().introduction)
        assertEquals(listOf(1, 4), store.chapter(edition, "GEN", 1)!!.verses.map { it.verse })
        rejected { BibleStore.validateEdition(initial.copy(books = listOf(books.first().copy(introduction = " ")))) }
    }
}
