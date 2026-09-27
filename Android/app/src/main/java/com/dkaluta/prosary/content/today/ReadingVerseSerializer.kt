package com.dkaluta.prosary.content.today

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.SerializationException
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonDecoder
import kotlinx.serialization.json.JsonEncoder
import kotlinx.serialization.json.decodeFromJsonElement
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.jsonObject

@Serializable
@OptIn(ExperimentalSerializationApi::class)
private data class VerseFields(val chapter: Int, val verse: Int, val text: String,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val transliteratedText: String? = null,
    val endVerse: Int? = null,
    @EncodeDefault(EncodeDefault.Mode.NEVER) val sourceNotes: List<ReadingSourceNote>? = null)

/** Distinguish absent notes from malformed null/empty arrays before nullable decoding. */
object ReadingVerseSerializer : KSerializer<ReadingVerse> {
    override val descriptor: SerialDescriptor = VerseFields.serializer().descriptor
    override fun deserialize(decoder: Decoder): ReadingVerse {
        val input = decoder as? JsonDecoder ?: throw SerializationException("Scripture requires JSON")
        val value = input.decodeJsonElement()
        val objectValue = value.jsonObject
        if ("sourceNotes" in objectValue) {
            val notes = objectValue["sourceNotes"]
            require(notes is JsonArray && notes.isNotEmpty() && "transliteratedText" !in objectValue)
        }
        val fields = input.json.decodeFromJsonElement<VerseFields>(value)
        return with(fields) { ReadingVerse(chapter, verse, text, transliteratedText, endVerse, sourceNotes) }
    }
    override fun serialize(encoder: Encoder, value: ReadingVerse) {
        val output = encoder as? JsonEncoder ?: throw SerializationException("Scripture requires JSON")
        val fields = with(value) { VerseFields(chapter, verse, text, transliteratedText, endVerse, sourceNotes) }
        output.encodeJsonElement(output.json.encodeToJsonElement(fields))
    }
}
