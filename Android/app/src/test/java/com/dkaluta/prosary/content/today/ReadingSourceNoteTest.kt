package com.dkaluta.prosary.content.today

import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import org.junit.Assert.*
import org.junit.Test

class ReadingSourceNoteTest {
    private val text = "בַּקּבָּה"
    private val note = ReadingSourceNote("lje-1-9-qoph-vowel", "unreadablePoint", text,
        1, 2, "vowel", listOf(16), "https://example.org/scan.pdf#page=16")
    private fun verse(value: ReadingSourceNote = note, body: String = text) =
        ReadingVerse(1, 9, body, sourceNotes = listOf(value))
    private fun rejected(block: () -> Unit) {
        try { block(); fail("Invalid source evidence accepted") } catch (_: IllegalArgumentException) { }
    }

    @Test fun hebrewLetterIndexIgnoresPointsPunctuationAndSupplementaryScalars() {
        val value = note.copy(anchor = "😀 — $text")
        value.validate("Prefix 😀 — $text suffix")
        assertEquals("ק", value.letter)
        val decoded = Json.decodeFromString<ReadingVerse>(Json.encodeToString(verse()))
        assertEquals(verse(), decoded)
        assertEquals(text, decoded.displayedText(null, "Hebr"))
    }

    @Test fun nonoverlappingOccurrenceSelectsTheIntendedActualWord() {
        val second = note.copy(occurrence = 2)
        second.validate("$text $text")
        rejected { second.validate(text) }
        rejected { note.copy(anchor = "אב אב", occurrence = 2).validate("אב אב אב") }
    }

    @Test fun guessedVowelsAndDageshCannotRemainUnderAnUnreadableNote() {
        for (mark in ('\u05b0'..'\u05bb').toList() + '\u05c7') {
            val pointed = "בַּקּ${mark}בָּה"
            rejected { verse(note.copy(anchor = pointed), pointed).validateSourceNotes() }
        }
        // An anchor ending just before the following mark cannot conceal it.
        rejected { note.copy(anchor = "ק", letterIndex = 1).validate("קָ") }
        rejected { note.copy(anchor = "ק", letterIndex = 1, mark = "dagesh").validate("קּ") }
        note.copy(anchor = "קָ", letterIndex = 1, mark = "dagesh").validate("קָ")
        note.copy(anchor = "קּ֑", letterIndex = 1).validate("קּ֑")
    }

    @Test fun readableCompanionVowelMustBeExplicitAndExactlyRetained() {
        val word = "יְרוּשָׁלִם"
        val value = note.copy(anchor = word, letterIndex = 5, retainedVowels = listOf("ִ"))
        value.validate(word)
        assertEquals(value, Json.decodeFromString<ReadingSourceNote>(Json.encodeToString(value)))
        rejected { value.copy(retainedVowels = null).validate(word) }
        rejected { value.copy(retainedVowels = listOf("ַ")).validate(word) }
        rejected { value.copy(anchor = "יְרוּשָׁלם").validate("יְרוּשָׁלם") }
        rejected { value.copy(anchor = "יְרוּשָׁלִַם").validate("יְרוּשָׁלִַם") }
        rejected { value.copy(anchor = "ל", letterIndex = 1).validate("לִִ") }
        for (invalid in listOf(emptyList(), listOf("ִ", "ַ"), listOf("ִִ"), listOf("x"), listOf("ּ"))) {
            rejected { value.copy(retainedVowels = invalid).validate(word) }
        }
        rejected { value.copy(mark = "dagesh").validate(word) }
        val json = Json.encodeToString(note)
        for (retained in listOf("null", "[]")) rejected {
            Json.decodeFromString<ReadingSourceNote>(json.dropLast(1) + ",\"retainedVowels\":$retained}")
        }
    }

    @Test fun restoredLetterPreservesItsReadablePointsAndTheDisplayedScripture() {
        // The second fixture verifies readable dagesh preservation on the restored letter itself.
        for (word in listOf("כָּלְתָה", "כָּלְּתָה")) {
            val value = note.copy(id = "wis-1-16-restored-lamed", kind = "restoredLetter",
                mark = "consonant", anchor = word, letterIndex = 2)
            assertEquals("ל", value.letter)
            value.validate(word)
            val original = verse(value, word)
            original.validateSourceNotes()
            val decoded = Json.decodeFromString<ReadingVerse>(Json.encodeToString(original))
            decoded.validateSourceNotes()
            assertEquals(original, decoded)
            assertEquals(word, decoded.displayedText(null, "Hebr"))
        }
    }

    @Test fun restorationRequiresItsOwnKindMarkPairAndRejectsRetainedVowels() {
        val value = note.copy(kind = "restoredLetter", mark = "consonant", anchor = "כָּלְתָה")
        for ((kind, mark) in listOf("restoredLetter" to "vowel", "restoredLetter" to "dagesh",
            "unreadablePoint" to "consonant", "unknown" to "consonant", "restoredLetter" to "unknown")) {
            val invalid = value.copy(kind = kind, mark = mark)
            rejected { invalid.validate(value.anchor) }
            rejected { Json.decodeFromString<ReadingSourceNote>(Json.encodeToString(invalid)) }
        }
        for (retained in listOf(emptyList(), listOf("ְ"))) {
            rejected { value.copy(retainedVowels = retained).validate(value.anchor) }
        }
        val encoded = Json.encodeToString(value)
        for (retained in listOf("null", "[]", "[\"ְ\"]")) {
            rejected { Json.decodeFromString<ReadingSourceNote>(encoded.dropLast(1) + ",\"retainedVowels\":$retained}") }
        }
    }

    @Test fun unknownKindsFieldsAndMalformedAnchorsFailClosed() {
        for (invalid in listOf(note.copy(id = "Invalid ID"), note.copy(kind = "guess"),
            note.copy(mark = "accent"), note.copy(anchor = "missing"), note.copy(anchor = ""),
            note.copy(occurrence = 0), note.copy(letterIndex = 0), note.copy(letterIndex = 99),
            note.copy(sourcePages = emptyList()), note.copy(sourcePages = listOf(16, 16)),
            note.copy(sourcePages = listOf(17, 16)), note.copy(sourcePages = listOf(0)),
            note.copy(sourceURL = "http://example.org/scan"), note.copy(sourceURL = "https://user@example.org/scan"),
            note.copy(sourceURL = "https://example.org/bad path"))) {
            rejected { verse(invalid).validateSourceNotes() }
        }
        val encoded = Json.encodeToString(note)
        val permissiveOuter = Json { ignoreUnknownKeys = true }
        rejected { permissiveOuter.decodeFromString<ReadingSourceNote>(encoded.dropLast(1) + ",\"invented\":true}") }
        rejected { permissiveOuter.decodeFromString<ReadingSourceNote>(encoded.replace("\"occurrence\":1,", "")) }
        for (notes in listOf("null", "[]")) {
            rejected { permissiveOuter.decodeFromString<ReadingVerse>("""{"chapter":1,"verse":1,"text":"ק","sourceNotes":$notes}""") }
        }
    }

    @Test fun pairedRowsDuplicateIdsAndOverlappingAnchorsAreRejected() {
        rejected { verse().copy(transliteratedText = "ܐ").validateSourceNotes() }
        rejected { verse().validateSourceNotes(paired = true) }
        rejected { verse().validateSourceNotes(allowed = false) }
        rejected { verse().copy(sourceNotes = emptyList()).validateSourceNotes() }
        rejected { verse().copy(sourceNotes = listOf(note, note)).validateSourceNotes() }
        rejected { verse().copy(sourceNotes = listOf(note,
            note.copy(id = "overlap", anchor = "קּבָּה", letterIndex = 1))).validateSourceNotes() }
    }

    @Test fun bundledDailyVersionOneCarriesNotesButRejectsInvalidEvidence() {
        val citation = ReadingCitation("reading", "Fixture", "Fixture 1:9")
        fun store(value: ReadingVerse) = ReadingTextStore {
            """{"schemaVersion":1,"passages":{"daily|Fixture 1:9":{"he":[${Json.encodeToString(value)}]}}}""".byteInputStream()
        }
        val valid = store(verse()).passage(citation, "he")!!.verses.single()
        assertEquals(note, valid.sourceNotes!!.single())
        assertEquals(text, valid.text)
        assertNull(store(verse(note.copy(kind = "unknown"))).passage(citation, "he"))
        assertNull(store(verse(note.copy(anchor = "missing"))).passage(citation, "he"))
        val restored = note.copy(id = "wis-1-16-restored-lamed", kind = "restoredLetter",
            mark = "consonant", anchor = "כָּלְתָה")
        val restoredVerse = verse(restored, restored.anchor)
        assertEquals(restoredVerse, store(restoredVerse).passage(citation, "he")!!.verses.single())
    }
}
