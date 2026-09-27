package com.dkaluta.prosary.content.bible

import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingVerse
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.URI
import java.security.MessageDigest
import java.util.UUID
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

@Serializable
data class BibleChapterInfo(val number: Int, val verseCount: Int, val isComplete: Boolean)

@Serializable
data class BibleBook(val id: String, val name: String, val chapters: List<BibleChapterInfo>,
    val transliteratedName: String? = null, val attribution: String? = null, val sourceURL: String? = null,
    val introduction: String? = null) {
    fun displayedName(script: String): String = if (script == "Syrc") transliteratedName ?: name else name
}

@Serializable
data class BibleEdition(
    val id: String, val languageCode: String, val name: String, val attribution: String,
    val sourceURL: String, val revision: String, val downloadURL: String,
    val archiveSHA256: String, val archiveByteCount: Long, val unpackedByteCount: Long,
    val books: List<BibleBook>, val textScript: String? = null,
    val transliteratedTextScript: String? = null,
) {
    fun readingEdition() = ReadingEdition(id, languageCode, name, attribution, sourceURL,
        textScript, transliteratedTextScript)
}

@Serializable
data class BibleCatalog(val schemaVersion: Int, val editions: List<BibleEdition>)

@Serializable
private data class BibleManifest(val schemaVersion: Int, val editionId: String,
    val revision: String, val books: List<BibleBook>)

@Serializable
data class BibleChapter(val schemaVersion: Int, val editionId: String, val book: String,
    val chapter: Int, val verses: List<ReadingVerse>)

/** Optional Scripture has its own storage, independent of daily passages and prayer packs.
 * All disk operations belong on an IO dispatcher. Only a completely validated revision
 * becomes active; the previous revision remains readable throughout download/validation. */
class BibleStore(private val directory: File) {
    private val lock = Any()
    private val json = Json { ignoreUnknownKeys = true }

    fun catalog(stream: InputStream): BibleCatalog {
        val result = json.decodeFromString<BibleCatalog>(stream.use { it.readBounded(MAX_CHAPTER_BYTES).decodeToString() })
        require(result.schemaVersion == 1 && result.editions.map { it.id }.distinct().size == result.editions.size)
        result.editions.forEach(::validateEdition)
        return result
    }

    fun installedEdition(id: String): BibleEdition? = synchronized(lock) {
        activeDirectory(id)?.let { active ->
            runCatching {
                val edition = json.decodeFromString<BibleEdition>(File(active, "edition.json").readText())
                validateEdition(edition)
                require(edition.id == id && edition.revision == active.name)
                edition
            }.getOrNull()
        }
    }

    fun chapter(edition: BibleEdition, book: String, number: Int): BibleChapter? = synchronized(lock) {
        val active = activeDirectory(edition.id)?.takeIf { it.name == edition.revision } ?: return@synchronized null
        val bookInfo = edition.books.firstOrNull { it.id == book } ?: return@synchronized null
        val info = bookInfo.chapters.firstOrNull { it.number == number } ?: return@synchronized null
        runCatching {
            File(active, chapterPath(book, number)).inputStream().use {
                decodeChapter(it.readBounded(MAX_CHAPTER_BYTES), edition, bookInfo, info)
            }
        }.getOrNull()
    }

    /** The incoming file is owned by the caller and never becomes the installed archive. */
    fun install(edition: BibleEdition, archive: File) = synchronized(lock) {
        validateEdition(edition)
        require(archive.length() == edition.archiveByteCount)
        val digest = MessageDigest.getInstance("SHA-256")
        archive.inputStream().use { input ->
            val buffer = ByteArray(32 * 1024)
            while (true) {
                val count = input.read(buffer)
                if (count == -1) break
                digest.update(buffer, 0, count)
            }
        }
        require(digest.digest().joinToString("") { "%02x".format(it) } == edition.archiveSHA256)
        check(directory.mkdirs() || directory.isDirectory)
        val staging = File(directory, ".staging-${UUID.randomUUID()}")
        check(staging.mkdir())
        try {
            val expected = edition.books.flatMap { book -> book.chapters.map { chapterPath(book.id, it.number) } }.toSet() + "manifest.json"
            ZipFile(archive).use { zip ->
                val entries = zip.entries().toList()
                require(entries.size == expected.size && entries.map { it.name }.toSet() == expected)
                require(entries.all { !it.isDirectory && it.method in listOf(ZipEntry.STORED, ZipEntry.DEFLATED) })
                var expanded = 0L
                // Exact allowlisted paths prohibit traversal, absolute paths, duplicates and undeclared files.
                for (entry in entries) {
                    require(entry.size in 0..MAX_CHAPTER_BYTES)
                    val bytes = zip.getInputStream(entry).use { it.readBounded(MAX_CHAPTER_BYTES) }
                    require(bytes.size.toLong() == entry.size)
                    expanded += bytes.size
                    require(expanded <= MAX_EXPANDED_BYTES && expanded <= edition.unpackedByteCount)
                    if (entry.name == "manifest.json") {
                        val manifest = json.decodeFromString<BibleManifest>(bytes.decodeToString())
                        require(manifest.schemaVersion == 1 && manifest.editionId == edition.id &&
                            manifest.revision == edition.revision && manifest.books == edition.books)
                    } else {
                        val parts = entry.name.split('/')
                        val book = edition.books.single { it.id == parts[1] }
                        val chapter = book.chapters.single { "${it.number}.json" == parts[2] }
                        decodeChapter(bytes, edition, book, chapter)
                    }
                    val target = File(staging, entry.name)
                    check(target.parentFile!!.mkdirs() || target.parentFile!!.isDirectory)
                    target.writeBytes(bytes)
                }
                require(expanded == edition.unpackedByteCount)
            }
            File(staging, "edition.json").writeText(json.encodeToString(edition))
            val editionDirectory = File(directory, edition.id)
            check(editionDirectory.mkdirs() || editionDirectory.isDirectory)
            val destination = File(editionDirectory, edition.revision)
            // Same-revision reinstalls are unnecessary; avoid replacing a working directory.
            if (destination.exists()) {
                if (installedEdition(edition.id)?.revision == edition.revision) return@synchronized
                // Recover an uncommitted revision left by process death before pointer activation.
                check(destination.deleteRecursively())
            }
            check(staging.renameTo(destination))
            val pointer = File(editionDirectory, ".active-${UUID.randomUUID()}")
            try {
                FileOutputStream(pointer).use { stream ->
                    stream.write(edition.revision.toByteArray(Charsets.UTF_8))
                    stream.fd.sync()
                }
                check(pointer.renameTo(File(editionDirectory, "active")))
            } catch (error: Exception) {
                destination.deleteRecursively()
                throw error
            } finally {
                pointer.delete()
            }
            editionDirectory.listFiles()?.filter { it.isDirectory && it.name != edition.revision }
                ?.forEach { it.deleteRecursively() }
        } finally {
            staging.deleteRecursively()
        }
    }

    fun remove(id: String) = synchronized(lock) {
        require(ID.matches(id))
        val installed = File(directory, id)
        if (!installed.exists()) return@synchronized
        // Detach first. Existing callers cannot read a half-removed chapter.
        val removed = File(directory, ".removed-${UUID.randomUUID()}")
        check(installed.renameTo(removed))
        removed.deleteRecursively()
    }

    private fun activeDirectory(id: String): File? {
        if (!ID.matches(id)) return null
        val editionDirectory = File(directory, id)
        val revision = runCatching { File(editionDirectory, "active").readText() }.getOrNull() ?: return null
        if (!HASH.matches(revision)) return null
        return File(editionDirectory, revision).takeIf { it.isDirectory }
    }

    private fun decodeChapter(bytes: ByteArray, edition: BibleEdition, book: BibleBook,
        info: BibleChapterInfo): BibleChapter {
        val chapter = json.decodeFromString<BibleChapter>(bytes.decodeToString())
        require(chapter.schemaVersion == 1 && chapter.editionId == edition.id && chapter.book == book.id && chapter.chapter == info.number)
        require(chapter.verses.size == info.verseCount)
        val labels = mutableSetOf<Int>()
        for (verse in chapter.verses) {
            require(verse.chapter == chapter.chapter && verse.verse > 0 &&
                verse.lastVerse in verse.verse..1000 && verse.text.isNotBlank())
            require(!edition.readingEdition().hasAramaicScripts || !verse.transliteratedText.isNullOrBlank())
            // Some editions print displaced labels. Preserve their order while rejecting
            // duplicate coordinates, including overlaps with any earlier combined unit.
            require((verse.verse..verse.lastVerse).all { labels.add(it) })
        }
        return chapter
    }

    companion object {
        const val MAX_ARCHIVE_BYTES = 32L * 1024 * 1024
        const val MAX_EXPANDED_BYTES = 128L * 1024 * 1024
        const val MAX_CHAPTER_BYTES = 2L * 1024 * 1024
        private val ID = Regex("[a-z0-9][a-z0-9-]{0,79}")
        private val BOOK_ID = Regex("[A-Z0-9]{1,12}")
        private val HASH = Regex("[a-f0-9]{64}")
        fun chapterPath(book: String, chapter: Int) = "chapters/$book/$chapter.json"

        fun validateEdition(edition: BibleEdition) {
            require(ID.matches(edition.id) && HASH.matches(edition.revision) && HASH.matches(edition.archiveSHA256))
            require(edition.name.isNotBlank() && edition.languageCode.isNotBlank() && edition.attribution.isNotBlank())
            require(edition.archiveByteCount in 1..MAX_ARCHIVE_BYTES && edition.unpackedByteCount in 1..MAX_EXPANDED_BYTES)
            val url = URI(edition.downloadURL)
            require(url.scheme == "https" && url.host == "raw.githubusercontent.com" &&
                url.port == -1 && url.rawUserInfo == null && url.rawQuery == null && url.rawFragment == null &&
                url.rawPath.startsWith("/dkaluta/Prosary/main/Shared/dist/bibles/") &&
                Regex("[a-zA-Z0-9._/-]+\\.zip").matches(url.rawPath) &&
                url.rawPath.split('/').none { it == "." || it == ".." })
            require(edition.books.isNotEmpty() && edition.books.size <= 200 && edition.books.map { it.id }.distinct().size == edition.books.size)
            require((edition.textScript == null && edition.transliteratedTextScript == null) || edition.readingEdition().hasAramaicScripts)
            require(edition.books.sumOf { it.chapters.size } <= 2000)
            for (book in edition.books) {
                require(BOOK_ID.matches(book.id) && book.name.isNotBlank() && book.chapters.isNotEmpty())
                require(book.introduction == null || book.introduction.isNotBlank())
                var previous = 0
                for (chapter in book.chapters) {
                    require(chapter.number > previous && chapter.verseCount in 1..1000)
                    previous = chapter.number
                }
            }
        }
    }
}

internal fun InputStream.readBounded(limit: Long): ByteArray {
    val output = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(32 * 1024)
    var total = 0L
    while (true) {
        val count = read(buffer)
        if (count == -1) break
        total += count
        require(total <= limit)
        output.write(buffer, 0, count)
    }
    return output.toByteArray()
}
