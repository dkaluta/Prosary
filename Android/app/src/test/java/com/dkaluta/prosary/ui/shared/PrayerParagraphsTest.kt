package com.dkaluta.prosary.ui.shared

import androidx.compose.ui.text.buildAnnotatedString
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerParagraphsTest {
    @Test fun splittingPreservesEveryCharacterAndBoldAcrossBlankLines() {
        val source = "First line\nsecond line\n\n**Bold paragraph\r\n\r\nStill bold**\n \nFinal line\n".parseBoldMarkdown()
        val parts = prayerParagraphs(source)
        val restored = buildAnnotatedString { parts.forEach { append(it) } }
        assertTrue(parts.size > 1)
        assertEquals(source.text, restored.text)
        for (index in source.indices) {
            fun stylesAt(text: androidx.compose.ui.text.AnnotatedString) = text.spanStyles
                .filter { index >= it.start && index < it.end }.map { it.item }.toSet()
            assertEquals("Style at character $index", stylesAt(source), stylesAt(restored))
        }
    }

    @Test fun singleLineBreaksAndEmptyBodiesRemainIntact() {
        val lines = "One\nTwo\nThree".parseBoldMarkdown()
        assertEquals(listOf(lines), prayerParagraphs(lines))
        assertEquals(listOf("".parseBoldMarkdown()), prayerParagraphs("".parseBoldMarkdown()))
    }
}
