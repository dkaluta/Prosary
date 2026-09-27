package com.dkaluta.prosary.content.today

import java.net.URI
import kotlinx.serialization.KSerializer
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject

/** Editorial evidence belongs beside Scripture, never in its selectable text. */
@Serializable(with = ReadingSourceNoteSerializer::class)
data class ReadingSourceNote(val id: String, val kind: String, val anchor: String,
    val occurrence: Int, val letterIndex: Int, val mark: String,
    val sourcePages: List<Int>, val sourceURL: String, val retainedVowels: List<String>? = null) {
    val letter: String get() = anchor.filter { it in '\u05d0'..'\u05ea' }
        .getOrNull(letterIndex - 1)?.toString().orEmpty()

    fun validate(text: String): Int {
        require(Regex("[a-z0-9][a-z0-9-]*").matches(id) && kind == "unreadablePoint")
        require(anchor.isNotBlank() && occurrence > 0 && letterIndex > 0)
        var from = 0
        var anchorOffset = -1
        repeat(occurrence) {
            val position = text.indexOf(anchor, from)
            require(position >= 0)
            anchorOffset = position
            from = position + anchor.length
        }
        val position = anchor.indices.filter { anchor[it] in '\u05d0'..'\u05ea' }.getOrNull(letterIndex - 1)
        require(position != null)
        // Resolve into the entire verse: an anchor ending at the letter must not
        // conceal a still-present vowel just outside the quoted substring.
        val marks = text.substring(anchorOffset + position + 1).takeWhile {
            Character.getType(it) in listOf(Character.NON_SPACING_MARK.toInt(),
                Character.COMBINING_SPACING_MARK.toInt(), Character.ENCLOSING_MARK.toInt())
        }
        fun isVowel(char: Char) = char in '\u05b0'..'\u05bb' || char == '\u05c7'
        if (retainedVowels != null) require(mark == "vowel" && retainedVowels.size == 1 &&
            retainedVowels.single().singleOrNull()?.let(::isVowel) == true)
        when (mark) {
            "vowel" -> require(marks.filter(::isVowel).map { it.toString() } == retainedVowels.orEmpty())
            "dagesh" -> require('\u05bc' !in marks)
            else -> throw IllegalArgumentException("Unknown source mark")
        }
        require(sourcePages.isNotEmpty() && sourcePages.all { it > 0 } && sourcePages == sourcePages.distinct().sorted())
        val uri = runCatching { URI(sourceURL) }.getOrNull()
        require(uri?.scheme == "https" && !uri.host.isNullOrBlank() && uri.rawUserInfo == null)
        return anchorOffset + position
    }
}

@Serializable
@OptIn(ExperimentalSerializationApi::class)
private data class SourceNoteFields(val id: String, val kind: String, val anchor: String,
    val occurrence: Int, val letterIndex: Int, val mark: String,
    val sourcePages: List<Int>, val sourceURL: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val retainedVowels: List<String>? = null)

/** Outer files allow additive metadata; notes deliberately reject unknown/missing fields. */
object ReadingSourceNoteSerializer : KSerializer<ReadingSourceNote> {
    override val descriptor: SerialDescriptor = SourceNoteFields.serializer().descriptor
    override fun deserialize(decoder: Decoder): ReadingSourceNote {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Source notes require JSON")
        val value = input.decodeJsonElement()
        val keys = setOf("id", "kind", "anchor", "occurrence", "letterIndex", "mark", "sourcePages", "sourceURL")
        if (value.jsonObject.keys != keys && value.jsonObject.keys != keys + "retainedVowels")
            throw SerializationException("Invalid source-note fields")
        if ("retainedVowels" in value.jsonObject) {
            val retained = value.jsonObject["retainedVowels"]
            require(retained is JsonArray && retained.size == 1)
        }
        val fields = input.json.decodeFromJsonElement<SourceNoteFields>(value)
        return with(fields) { ReadingSourceNote(id, kind, anchor, occurrence, letterIndex, mark, sourcePages, sourceURL, retainedVowels) }
    }
    override fun serialize(encoder: Encoder, value: ReadingSourceNote) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Source notes require JSON")
        val fields = with(value) { SourceNoteFields(id, kind, anchor, occurrence, letterIndex, mark, sourcePages, sourceURL, retainedVowels) }
        output.encodeJsonElement(output.json.encodeToJsonElement(fields))
    }
}

internal fun ReadingVerse.validateSourceNotes(allowed: Boolean = true, paired: Boolean = false,
    ids: MutableSet<String> = mutableSetOf()) {
    val notes = sourceNotes ?: return
    require(allowed && !paired && transliteratedText == null && notes.isNotEmpty())
    val positions = mutableSetOf<Pair<Int, String>>()
    notes.forEach { note ->
        val position = note.validate(text)
        require(ids.add(note.id) && positions.add(position to note.mark))
    }
}
