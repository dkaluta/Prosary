package com.dkaluta.prosary.ui.readings

import org.junit.Assert.assertEquals
import org.junit.Test

class ReadingChapterHeadingTest {
    @Test fun hebrewChaptersUseTraditionalNumeralsAndPunctuation() {
        val examples = mapOf(1 to "א׳", 9 to "ט׳", 10 to "י׳", 15 to "ט״ו", 16 to "ט״ז", 100 to "ק׳",
            115 to "קט״ו", 116 to "קט״ז", 119 to "קי״ט", 150 to "ק״נ", 151 to "קנ״א", 176 to "קע״ו")
        examples.forEach { (number, expected) -> assertEquals(expected, ReadingChapterHeading.number(number, "he")) }
        assertEquals("ט״ו", ReadingChapterHeading.number(15, "iw-IL"))
    }

    @Test fun arabicChaptersUseEasternArabicDigitsWithoutGrouping() {
        assertEquals("١٥", ReadingChapterHeading.number(15, "ar"))
        assertEquals("١١٩", ReadingChapterHeading.number(119, "ar-LB"))
        assertEquals("١٥٠", ReadingChapterHeading.number(150, "ar"))
    }

    @Test fun otherEditionLanguagesKeepTheirOwnOrdinaryNumbers() {
        for (language in listOf("en", "fr", "it", "ru", "uk", "tl", "fil-PH", "el")) {
            assertEquals("119", ReadingChapterHeading.number(119, language))
        }
    }

    @Test fun pairedAramaicFollowsDisplayedScriptAndSyriacFifteenKeepsItsOwnLetters() {
        assertEquals("ט״ו", ReadingChapterHeading.number(15, "arc", "Hebr"))
        assertEquals("קפ״ז", ReadingChapterHeading.number(187, "arc", "Hebr"))
        val examples = mapOf(1 to "ܐ", 15 to "ܝܗ", 16 to "ܝܘ", 100 to "ܩ", 119 to "ܩܝܛ", 150 to "ܩܢ")
        examples.forEach { (number, expected) -> assertEquals(expected, ReadingChapterHeading.number(number, "arc", "Syrc")) }
    }
}
