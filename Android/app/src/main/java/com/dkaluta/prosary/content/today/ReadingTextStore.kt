package com.dkaluta.prosary.content.today

import java.io.InputStream
import com.dkaluta.prosary.models.LanguageCatalog
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.decodeFromStream

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

@Serializable
data class ReadingVerse(val chapter: Int, val verse: Int, val text: String,
    val transliteratedText: String? = null) {
    fun displayedText(edition: ReadingEdition?, script: String): String =
        if (edition?.hasAramaicScripts == true && script == edition.transliteratedTextScript)
            transliteratedText.orEmpty() else text
}

data class ReadingPassage(val verses: List<ReadingVerse>, val includesWholeVerses: Boolean = false)

@Serializable
private data class ReadingTextFile(
    val schemaVersion: Int,
    val editions: List<ReadingEdition> = emptyList(),
    val passages: Map<String, Map<String, List<ReadingVerse>>> = emptyMap(),
    val wholeVersePassages: Set<String> = emptySet(),
)

/** Exact, edition-specific appointments authored by the shared generator. Runtime code never
 * parses a display citation or guesses a verse-number conversion. Open on an IO dispatcher. */
class ReadingTextStore(private val openData: (String) -> InputStream?) {
    private val json = Json { ignoreUnknownKeys = true }
    @OptIn(ExperimentalSerializationApi::class)
    private fun load(name: String): ReadingTextFile? =
        runCatching {
            openData(name)?.use { stream ->
                // Read UTF-8 directly instead of allocating a second, full-file string.
                json.decodeFromStream<ReadingTextFile>(stream)
                    .takeIf { it.schemaVersion == 1 }
            }
        }.getOrNull()
    private val data: ReadingTextFile? by lazy { load("readings-texts") }
    private val metadata: ReadingTextFile? by lazy { load("readings-editions") }

    val editions: List<ReadingEdition> get() = metadata?.editions.orEmpty()

    fun passage(citation: ReadingCitation, editionId: String, isTorah: Boolean = false): ReadingPassage? {
        val file = data ?: return null
        val key = "${if (isTorah) "torah" else "daily"}|${citation.full}"
        val verses = file.passages[key]?.get(editionId)
            ?.takeIf { verses -> verses.isNotEmpty() && verses.all { it.chapter > 0 && it.verse > 0 && it.text.isNotBlank() } }
            ?: return null
        // A paired edition must be complete in both scripts: never mix a fallback into a verse.
        if (editions.firstOrNull { it.id == editionId }?.hasAramaicScripts == true
            && verses.any { it.transliteratedText.isNullOrBlank() }) return null
        return ReadingPassage(verses, includesWholeVerses = key in file.wholeVersePassages)
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
