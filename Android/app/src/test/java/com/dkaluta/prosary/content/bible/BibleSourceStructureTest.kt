package com.dkaluta.prosary.content.bible

import com.dkaluta.prosary.content.today.ReadingSourceNote
import com.dkaluta.prosary.content.today.ReadingVerse
import com.dkaluta.prosary.ui.readings.ReadingChapterHeading
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

class BibleSourceStructureTest {
    @get:Rule val temporary = TemporaryFolder()
    private val json = Json { encodeDefaults = true; ignoreUnknownKeys = true }
    private val route = BibleAddressRoute(11, 34, 12, "sir-11-34")
    private fun reference(id: String, chapter: Int, verse: Int, label: String? = null) =
        BibleContentBlock(id, "verse", chapter, verse, printedLabel = label)
    private fun chapter(number: Int, verses: List<ReadingVerse>, blocks: List<BibleContentBlock>? = null) =
        BibleChapter(3, "fixture", "SIR", number, verses, blocks)
    private fun interleaving() = listOf(
        chapter(11, listOf(ReadingVerse(11, 33, "Eleven33"), ReadingVerse(11, 34, "Eleven34")), listOf(
            reference("sir-11-33", 11, 33))),
        chapter(12, listOf(ReadingVerse(12, 1, "Twelve1"), ReadingVerse(12, 2, "Twelve2")), listOf(reference("sir-12-1", 12, 1), reference("sir-11-34", 11, 34), reference("sir-12-2", 12, 2))),
    )
    private fun book(chapters: List<BibleChapter>, routes: List<BibleAddressRoute>? = null) = BibleBook("SIR", "Sirach",
        chapters.map { BibleChapterInfo(it.chapter, it.verses.size, true) }, addressRoutes = routes)
    private fun base(book: BibleBook, version: Int = 3) = BibleEdition("fixture", "he", "Source", "Credit", "https://example.org",
        "a".repeat(64), "https://raw.githubusercontent.com/dkaluta/Prosary/main/Shared/dist/bibles/fixture.zip",
        "0".repeat(64), 1, 1, listOf(book), archiveSchemaVersion = version)
    private fun archive(chapters: List<BibleChapter>, book: BibleBook = book(chapters), version: Int = 3,
        edit: (MutableMap<String, String>) -> Unit = {}): Pair<BibleEdition, File> {
        val edition = base(book, version)
        val files = linkedMapOf("manifest.json" to """{"schemaVersion":$version,"editionId":"fixture","revision":"${edition.revision}","books":${json.encodeToString(edition.books)}}""")
        chapters.forEach { files[BibleStore.chapterPath(it.book, it.chapter)] = json.encodeToString(it) }
        edit(files)
        val archive = temporary.newFile()
        ZipOutputStream(archive.outputStream()).use { zip -> files.forEach { (name, text) ->
            zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry()
        } }
        val hash = MessageDigest.getInstance("SHA-256").digest(archive.readBytes()).joinToString("") { "%02x".format(it) }
        return edition.copy(archiveSHA256 = hash, archiveByteCount = archive.length(), unpackedByteCount = files.values.sumOf { it.toByteArray().size.toLong() }) to archive
    }
    private fun store() = BibleStore(temporary.newFolder())
    private fun rejected(action: () -> Unit) {
        try { action(); fail("Invalid rich source was accepted") } catch (_: IllegalArgumentException) { }
    }
    private fun install(chapters: List<BibleChapter>, book: BibleBook = book(chapters)): Pair<BibleStore, BibleEdition> {
        val (edition, zip) = archive(chapters, book)
        val store = store(); store.install(edition, zip)
        return store to edition
    }

    @Test fun interleavingKeepsPhysicalOrderAndNumericJumpUsesTheExplicitRoute() {
        val chapters = interleaving()
        val (store, edition) = install(chapters, book(chapters, listOf(route)))
        val display = store.displayChapter(edition, "SIR", 11)!!
        assertEquals(listOf("Eleven33"), display.items.map { it.primary!!.text })
        assertEquals(listOf("Twelve1", "Eleven34", "Twelve2"), store.displayChapter(edition, "SIR", 12)!!.items.map { it.primary!!.text })
        assertEquals(BibleTarget(12, "sir-11-34"), store.target(edition, "SIR", 11, 34))
        assertEquals(BibleTarget(12, "sir-12-2"), store.target(edition, "SIR", 12, 2))
        assertNull(store.target(edition, "SIR", 12, 3))
    }


    @Test fun movedPrimaryShowsItsSourceChapterInNativeNumberingWithoutChangingSameChapterLabels() {
        val verse = ReadingVerse(11, 34, "Moved", endVerse = 35)
        assertEquals("11:34–35", BibleNavigation.sourceLabel(verse, 12))
        assertEquals("34–35", BibleNavigation.sourceLabel(verse, 11))
        assertEquals("י״א:ל״ד–ל״ה", BibleNavigation.sourceLabel(verse, 12) { ReadingChapterHeading.number(it, "he") })
        assertEquals("١١:٣٤–٣٥", BibleNavigation.sourceLabel(verse, 12) { ReadingChapterHeading.number(it, "ar") })
    }

    @Test fun readingLoadsOnlyDirectReferencedChaptersOnceWithoutRecursiveExpansion() {
        val chapters = interleaving()
        val loads = mutableListOf<Int>()
        val display = BibleSourceStructure.resolve(chapters.last()) { loads.add(it); chapters.first() }
        assertEquals(listOf(11), loads)
        assertEquals(listOf("sir-12-1", "sir-11-34", "sir-12-2"), display.items.map { it.id })
    }

    @Test fun witnessesOverlapWithoutLosingTheirTextAndNeverOverrideNumericPrimary() {
        val units = listOf(ReadingVerse(41, 14, "Primary14", endVerse = 16))
        val blocks = listOf(reference("primary", 41, 14),
            BibleContentBlock("part-b", "witness", printedLabel = "יד ב", text = "First witness", addresses = listOf(BibleAddress(41, 14, part = "ב"))),
            BibleContentBlock("part-a-range", "witness", printedLabel = "יד א–טז", text = "Second witness", addresses = listOf(BibleAddress(41, 14, 16, "א"))))
        val (store, edition) = install(listOf(chapter(41, units, blocks)))
        val display = store.displayChapter(edition, "SIR", 41)!!
        assertEquals(listOf("primary", "part-b", "part-a-range"), display.items.map { it.id })
        assertEquals("First witness", display.items[1].block.text)
        assertEquals(2, BibleSourceStructure.occurrence(display.items, 1))
        assertEquals(3, BibleSourceStructure.occurrence(display.items, 2))
        assertEquals(BibleTarget(41, "primary"), store.target(edition, "SIR", 41, 15))
    }

    @Test fun repeatedFiftyOneThirteenHymnHeadingsAndColophonStayDistinct() {
        val blocks = listOf(BibleContentBlock("section", "heading", text = "Source heading"), reference("first-13", 51, 13),
            BibleContentBlock("second-13", "witness", printedLabel = "יג", text = "Second printed occurrence", addresses = listOf(BibleAddress(51, 13))),
            BibleContentBlock("hymn", "passage", text = "Unnumbered thanksgiving hymn"),
            BibleContentBlock("ending", "colophon", text = "Source closing metadata"))
        val (store, edition) = install(listOf(chapter(51, listOf(ReadingVerse(51, 13, "First occurrence")), blocks)))
        val display = store.displayChapter(edition, "SIR", 51)!!
        assertEquals(listOf("heading", "verse", "witness", "passage", "colophon"), display.items.map { it.block.kind })
        assertEquals(2, display.items.count { it.addresses.isNotEmpty() })
        assertEquals(2, BibleSourceStructure.occurrence(display.items, 2))
    }

    @Test fun literalPrintedLabelDoesNotChangeCombinedNavigationAddress() {
        val source = chapter(1, listOf(ReadingVerse(1, 40, "Susanna source unit", endVerse = 41)), listOf(reference("sus-40", 1, 40, "כ–כא")))
        val (store, edition) = install(listOf(source))
        assertEquals("כ–כא", store.displayChapter(edition, "SIR", 1)!!.items.single().block.printedLabel)
        assertEquals(BibleTarget(1, "sus-40"), store.target(edition, "SIR", 1, 41))
        assertNull(store.target(edition, "SIR", 1, 20))
    }

    @Test fun colophonNoteSurvivesInstallationWithoutBecomingScriptureOrVerseChoice() {
        val note = ReadingSourceNote("closing-dot", "unreadablePoint", "ו", 1, 1, "shuruq",
            listOf(225), "https://example.org/source.pdf#page=225")
        val closing = BibleContentBlock("closing", "colophon", text = "ו", sourceNotes = listOf(note))
        fun source(block: BibleContentBlock = closing, primary: ReadingVerse = ReadingVerse(1, 1, "Primary")) =
            listOf(chapter(1, listOf(primary), listOf(reference("primary", 1, 1), block)))
        val (store, edition) = install(source())
        val display = store.displayChapter(edition, "SIR", 1)!!
        assertEquals(listOf(note), display.items.last().sourceNotes)
        assertEquals("ו", display.items.last().block.text)
        assertTrue(display.items.last().addresses.isEmpty())
        assertEquals("colophon", display.items.last().block.kind)
        assertNull(store.target(edition, "SIR", 1, 2))
        rejected { install(source(closing.copy(sourceNotes = listOf(note.copy(anchor = "missing"))))) }
        rejected { install(source(closing.copy(text = "וּ"))) }
        rejected { install(source(primary = ReadingVerse(1, 1, "ו", sourceNotes = listOf(note)))) }
        rejected { install(source(closing.copy(kind = "heading"))) }
    }

    @Test fun missingDuplicatedDanglingAndWrongRoutesAreRejectedBeforeActivation() {
        val valid = interleaving()
        val badChapters = listOf(
            valid.map { if (it.chapter == 11) it.copy(contentBlocks = it.contentBlocks!!.dropLast(1)) else it },
            valid.map { if (it.chapter == 11) it.copy(contentBlocks = it.contentBlocks!! + reference("duplicate", 11, 33)) else it },
            valid.map { if (it.chapter == 11) it.copy(contentBlocks = it.contentBlocks!! + reference("missing", 11, 32)) else it },
            valid.map { if (it.chapter == 12) it.copy(contentBlocks = listOf(reference("sir-11-33", 12, 2))) else it },
        )
        badChapters.forEach { rejected { install(it, book(it, listOf(route))) } }
        for (routes in listOf(null, listOf(route.copy(blockId = "wrong")), listOf(route.copy(verse = 2)), listOf(route, route))) {
            rejected { install(valid, book(valid, routes)) }
        }
        // The implicit chapter would present the moved primary a second time.
        rejected { install(valid.map { if (it.chapter == 11) it.copy(contentBlocks = null) else it }, book(valid, listOf(route))) }
    }

    @Test fun invalidBlockFieldsNullsNumbersKindsAndAddressRecordsAreRejected() {
        val valid = """{"id":"b","kind":"witness","text":"Source","printedLabel":"יג","addresses":[{"chapter":51,"verse":13}]}"""
        for (bad in listOf(
            valid.replace("\"witness\"", "\"mystery\""), valid.replace("\"text\":\"Source\"", "\"text\":null"),
            valid.replace("\"printedLabel\":\"יג\",", ""), valid.replace("\"chapter\":51", "\"chapter\":\"51\""),
            valid.replace("\"verse\":13", "\"verse\":0"), valid.replace("\"verse\":13", "\"verse\":13,\"endVerse\":12"),
            valid.replace("\"verse\":13", "\"verse\":13,\"part\":null"), valid.replace("\"verse\":13", "\"verse\":13,\"part\":\"\""),
            valid.replace("\"text\":\"Source\"", "\"text\":\"Source\",\"transliteratedText\":\"other\""),
            valid.replace("\"verse\":13", "\"verse\":13,\"extra\":true"),
            valid.replace("[{\"chapter\":51,\"verse\":13}]", "[]"),
            valid.replace("[{\"chapter\":51,\"verse\":13}]", "[{\"chapter\":51,\"verse\":13},{\"chapter\":51,\"verse\":13}]"),
            valid.replace("[{\"chapter\":51,\"verse\":13}]", "[{\"chapter\":51,\"verse\":13},{\"chapter\":51,\"verse\":13,\"endVerse\":13}]"),
            valid.replace("\"text\":\"Source\"", "\"text\":13"),
        )) rejected { json.decodeFromString<BibleContentBlock>(bad) }
    }

    @Test fun unknownWitnessChapterAndPairedScriptRichPayloadAreRejected() {
        val blocks = listOf(reference("main", 51, 13), BibleContentBlock("witness", "witness", printedLabel = "יג", text = "Text", addresses = listOf(BibleAddress(52, 13))))
        rejected { install(listOf(chapter(51, listOf(ReadingVerse(51, 13, "Main")), blocks))) }
        val chapters = listOf(chapter(51, listOf(ReadingVerse(51, 13, "Main", "Other")), listOf(reference("main", 51, 13))))
        val (edition, zip) = archive(chapters)
        rejected { store().install(edition.copy(languageCode = "arc", textScript = "Hebr", transliteratedTextScript = "Syrc"), zip) }
        val paired = base(book(chapters)).copy(languageCode = "arc", textScript = "Hebr", transliteratedTextScript = "Syrc")
        rejected { store().catalog(json.encodeToString(BibleCatalog(1, listOf(paired))).byteInputStream()) }
        for (version in listOf(1, 2)) BibleStore.validateEdition(paired.copy(archiveSchemaVersion = version))
    }

    @Test fun oldVersionsRejectRichFieldsEvenWhenEmptyOrNull() {
        val ordinary = chapter(1, listOf(ReadingVerse(1, 1, "One")))
        for (version in listOf(1, 2)) for (payload in listOf("[]", "null")) {
            val chapters = listOf(ordinary.copy(schemaVersion = version))
            val (edition, zip) = archive(chapters, version = version) { files ->
                files["chapters/SIR/1.json"] = files.getValue("chapters/SIR/1.json").dropLast(1) + ",\"contentBlocks\":$payload}"
            }
            rejected { store().install(edition, zip) }
            val invalidCatalog = json.encodeToString(BibleCatalog(1, listOf(base(book(chapters), version))))
                .replace("\"chapters\":[", "\"addressRoutes\":$payload,\"chapters\":[")
            rejected { store().catalog(invalidCatalog.byteInputStream()) }
        }
    }

    @Test fun witnessAndPassageNotesUseExactAnchorsAndBookWideUniqueIds() {
        val note = ReadingSourceNote("witness-note", "unreadablePoint", "ק", 1, 1, "vowel", listOf(500), "https://example.org/scan.pdf#page=500")
        val primary = ReadingVerse(51, 13, "Primary")
        val blocks = listOf(reference("main", 51, 13), BibleContentBlock("witness", "witness", text = "ק", printedLabel = "יג",
            addresses = listOf(BibleAddress(51, 13)), sourceNotes = listOf(note)))
        val (store, edition) = install(listOf(chapter(51, listOf(primary), blocks)))
        assertEquals(note, store.displayChapter(edition, "SIR", 51)!!.items.last().sourceNotes!!.single())
        for (bad in listOf(blocks + BibleContentBlock("passage", "passage", text = "ק", sourceNotes = listOf(note)),
            blocks.dropLast(1) + blocks.last().copy(text = "קַ"), blocks.dropLast(1) + blocks.last().copy(kind = "heading"))) {
            rejected { install(listOf(chapter(51, listOf(primary), bad))) }
        }
        rejected { install(listOf(chapter(51, listOf(primary.copy(text = "ק", sourceNotes = listOf(note))), blocks))) }
    }

    @Test fun badBookStructureAndForgedHashDoNotReplaceWorkingDownload() {
        val chapters = interleaving(); val book = book(chapters, listOf(route))
        val (edition, zip) = archive(chapters, book); val store = store(); store.install(edition, zip)
        val bad = chapters.map { if (it.chapter == 11) it.copy(contentBlocks = it.contentBlocks!!.drop(1)) else it }
        val (badEdition, badZip) = archive(bad, book)
        rejected { store.install(badEdition, badZip) }
        rejected { store.install(edition.copy(archiveSHA256 = "0".repeat(64)), zip) }
        assertEquals(edition, store.installedEdition(edition.id))
        assertEquals(3, store.displayChapter(edition, "SIR", 12)!!.items.size)
    }
}
