package com.dkaluta.prosary.content.today

import java.io.InputStream
import java.net.URI
import com.dkaluta.prosary.content.bible.BibleContentBlock
import com.dkaluta.prosary.content.bible.BibleDisplayItem
import com.dkaluta.prosary.content.bible.BibleStore
import com.dkaluta.prosary.content.bible.strictFields
import com.dkaluta.prosary.content.bible.strictString
import com.dkaluta.prosary.models.LanguageCatalog
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.*

@Serializable
data class ReadingEdition(
    val id: String,
    val languageCode: String,
    val name: String,
    val attribution: String,
    val sourceURL: String,
    val textScript: String? = null,
    val transliteratedTextScript: String? = null,
) {
    val hasAramaicScripts: Boolean get() = languageCode == "arc"
        && textScript == "Hebr" && transliteratedTextScript == "Syrc"
}

@Serializable(with = ReadingVerseSerializer::class)
data class ReadingVerse(val chapter: Int, val verse: Int, val text: String,
    val transliteratedText: String? = null, val endVerse: Int? = null,
    val sourceNotes: List<ReadingSourceNote>? = null) {
    val lastVerse: Int get() = endVerse ?: verse
    val verseLabel: String get() = if (lastVerse > verse) "$verse–$lastVerse" else verse.toString()
    fun displayedText(edition: ReadingEdition?, script: String): String =
        if (edition?.hasAramaicScripts == true && script == edition.transliteratedTextScript)
            transliteratedText.orEmpty() else text
}

data class ReadingPassage(val verses: List<ReadingVerse>, val includesWholeVerses: Boolean = false,
    val source: ReadingPassageSource? = null) {
    val displayItems: List<BibleDisplayItem> get() {
        val primary = verses.associateBy { it.chapter to it.verse }
        return (source?.contentBlocks ?: verses.map {
            BibleContentBlock("daily-${it.chapter}-${it.verse}", "verse", it.chapter, it.verse)
        }).map { block -> BibleDisplayItem(block, if (block.kind == "verse") primary[block.chapter to block.verse] else null) }
    }
}

@Serializable(with = ReadingPassageSourceSerializer::class)
data class ReadingPassageSource(val book: String, val name: String, val attribution: String,
    val sourceURL: String, val isComplete: Boolean, val contentBlocks: List<BibleContentBlock>? = null) {
    internal fun validate(verses: List<ReadingVerse>, paired: Boolean, noteIds: MutableSet<String>) {
        require(!paired && verses.none { it.transliteratedText != null })
        require(Regex("[A-Z0-9]{3}").matches(book) && name.isNotBlank() && attribution.isNotBlank())
        val uri = URI(sourceURL)
        require(uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null)
        val addresses = verses.map { it.chapter to it.verse }
        require(addresses.distinct().size == addresses.size)
        verses.forEachIndexed { index, verse ->
            require(verses.take(index).none { it.chapter == verse.chapter &&
                it.verse <= verse.lastVerse && verse.verse <= it.lastVerse })
        }
        contentBlocks?.let { blocks ->
            require(blocks.isNotEmpty() && blocks.map { it.id }.distinct().size == blocks.size)
            // A source block may stand between primary units, but must not reorder,
            // duplicate or hide the appointment's already reviewed primary sequence.
            require(blocks.filter { it.kind == "verse" }.map { it.chapter to it.verse } == addresses)
            blocks.forEach { block ->
                block.validate()
                block.text?.let { text ->
                    ReadingVerse(1, 1, text, sourceNotes = block.sourceNotes).validateSourceNotes(ids = noteIds)
                }
            }
        }
    }
}

@Serializable
private data class PassageSourceFields(val book: String, val name: String, val attribution: String,
    val sourceURL: String, val isComplete: Boolean, val contentBlocks: List<BibleContentBlock>? = null)

object ReadingPassageSourceSerializer : KSerializer<ReadingPassageSource> {
    override val descriptor: SerialDescriptor = PassageSourceFields.serializer().descriptor
    override fun deserialize(decoder: Decoder): ReadingPassageSource {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Passage sources require JSON")
        val value = input.decodeJsonElement().jsonObject
        strictFields(value, setOf("book", "name", "attribution", "sourceURL", "isComplete"), setOf("contentBlocks"))
        listOf("book", "name", "attribution", "sourceURL").forEach { strictString(value, it) }
        val complete = value["isComplete"] as? JsonPrimitive
        require(complete != null && !complete.isString && complete.booleanOrNull != null)
        if ("contentBlocks" in value) require((value["contentBlocks"] as? JsonArray)?.isNotEmpty() == true)
        return input.json.decodeFromJsonElement<PassageSourceFields>(value).let {
            ReadingPassageSource(it.book, it.name, it.attribution, it.sourceURL, it.isComplete, it.contentBlocks)
        }
    }
    override fun serialize(encoder: Encoder, value: ReadingPassageSource) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Passage sources require JSON")
        val fields = with(value) { PassageSourceFields(book, name, attribution, sourceURL, isComplete, contentBlocks) }
        output.encodeJsonElement(output.json.encodeToJsonElement(fields))
    }
}

@Serializable(with = PassageSourcesSerializer::class)
private data class PassageSources(val entries: Map<String, Map<String, ReadingPassageSource>> = emptyMap())

private object PassageSourcesSerializer : KSerializer<PassageSources> {
    private val delegate = MapSerializer(String.serializer(), MapSerializer(String.serializer(), ReadingPassageSourceSerializer))
    override val descriptor: SerialDescriptor = delegate.descriptor
    override fun deserialize(decoder: Decoder): PassageSources {
        val entries = delegate.deserialize(decoder)
        require(entries.isNotEmpty() && entries.all { (key, editions) ->
            Regex("(daily|torah)\\|.+").matches(key) && editions.isNotEmpty() && editions.keys.all { it.isNotBlank() }
        })
        return PassageSources(entries)
    }
    override fun serialize(encoder: Encoder, value: PassageSources) = delegate.serialize(encoder, value.entries)
}

@Serializable
private data class ReadingTextFile(
    val schemaVersion: Int,
    val editions: List<ReadingEdition> = emptyList(),
    val passages: Map<String, Map<String, List<ReadingVerse>>> = emptyMap(),
    val wholeVersePassages: Set<String> = emptySet(),
    val passageSources: PassageSources = PassageSources(),
    val passageBooks: Map<String, Map<String, String>> = emptyMap(),
)

/** Exact, edition-specific appointments authored by the shared generator. Runtime code never
 * parses a display citation or guesses a verse-number conversion. Open on an IO dispatcher. */
class ReadingTextStore(private val bibleStore: BibleStore? = null, private val openData: (String) -> InputStream?) {
    private val json = Json { ignoreUnknownKeys = true }
    @OptIn(ExperimentalSerializationApi::class)
    private fun load(name: String): ReadingTextFile? =
        runCatching {
            openData(name)?.use { stream ->
                // Read UTF-8 directly instead of allocating a second, full-file string.
                json.decodeFromStream<ReadingTextFile>(stream)
                    .takeIf { file -> file.schemaVersion == 1 && file.passageSources.entries.all { (key, sources) ->
                        sources.keys.all { it in file.passages[key].orEmpty() }
                    } && file.passageBooks.all { (key, books) ->
                        books.isNotEmpty() && books.all { (id, book) ->
                            id in file.passages[key].orEmpty() && Regex("[A-Z0-9]{3}").matches(book)
                                && (file.passageSources.entries[key]?.get(id)?.book?.let { it == book } ?: true)
                        }
                    } }
            }
        }.getOrNull()
    private val data: ReadingTextFile? by lazy {
        load("readings-texts")?.takeIf { file ->
            file.passageSources.entries.values.all { sources ->
                sources.keys.all { id -> editions.any { it.id == id } }
            }
        }
    }
    private val metadata: ReadingTextFile? by lazy { load("readings-editions") }

    val editions: List<ReadingEdition> get() = metadata?.editions.orEmpty()

    fun availableEditions(citation: ReadingCitation, isTorah: Boolean = false): List<ReadingEdition> =
        editions.filter { passage(citation, it.id, isTorah) != null }

    fun passage(citation: ReadingCitation, editionId: String, isTorah: Boolean = false): ReadingPassage? {
        val file = data ?: return null
        val key = "${if (isTorah) "torah" else "daily"}|${citation.full}"
        val verses = file.passages[key]?.get(editionId)
            ?.takeIf { verses -> verses.isNotEmpty() && verses.all {
                it.chapter > 0 && it.verse > 0 && it.lastVerse >= it.verse && it.text.isNotBlank()
            } }
            ?: return null
        // A paired edition must be complete in both scripts: never mix a fallback into a verse.
        if (editions.firstOrNull { it.id == editionId }?.hasAramaicScripts == true
            && verses.any { it.transliteratedText.isNullOrBlank() }) return null
        // Any declared second script requires paired anchors, even if its language
        // metadata does not match the currently supported Aramaic picker.
        val paired = editions.firstOrNull { it.id == editionId }?.transliteratedTextScript != null
        val noteIds = mutableSetOf<String>()
        val source = file.passageSources.entries[key]?.get(editionId)
        if (runCatching {
            verses.forEach { it.validateSourceNotes(paired = paired, ids = noteIds) }
            source?.validate(verses, paired, noteIds)
        }.isFailure) return null
        val installed = file.passageBooks[key]?.get(editionId)?.let { book ->
            bibleStore?.reviewedPassage(editionId, book, verses)
        }
        return ReadingPassage(installed ?: verses, includesWholeVerses = key in file.wholeVersePassages, source = source)
    }

    companion object {
        fun effectiveEditionId(savedId: String, interfaceLanguage: String, editions: List<ReadingEdition>): String? =
            if (savedId.isNotBlank()) editions.firstOrNull { it.id == savedId }?.id
            else editions.firstOrNull {
                baseLanguage(it.languageCode) == baseLanguage(interfaceLanguage)
            }?.id

        private fun baseLanguage(language: String): String = LanguageCatalog.uiLanguageCode(language).let {
            LanguageCatalog.baseLanguage(it) ?: it
        }
    }
}
