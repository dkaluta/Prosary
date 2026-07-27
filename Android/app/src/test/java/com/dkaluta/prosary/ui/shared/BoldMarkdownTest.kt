package com.dkaluta.prosary.ui.shared

import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import org.junit.Assert.assertEquals
import org.junit.Test

class BoldMarkdownTest {
    @Test
    fun plainTextHasNoSpans() {
        val result = "Hail Mary, full of grace.".parseBoldMarkdown()
        assertEquals("Hail Mary, full of grace.", result.text)
        assertEquals(0, result.spanStyles.size)
    }

    @Test
    fun boldRunBecomesABoldSpanWithTheAsterisksStripped() {
        val result = "Ora pro nobis.\n**Ut digni efficiamur.**".parseBoldMarkdown()
        assertEquals("Ora pro nobis.\nUt digni efficiamur.", result.text)
        assertEquals(1, result.spanStyles.size)
        val span = result.spanStyles.single()
        assertEquals(SpanStyle(fontWeight = FontWeight.Bold), span.item)
        assertEquals("Ut digni efficiamur.", result.text.substring(span.start, span.end))
    }

    @Test
    fun unterminatedAsterisksAreLeftAsPlainText() {
        val result = "no closing **marker here".parseBoldMarkdown()
        assertEquals("no closing **marker here", result.text)
        assertEquals(0, result.spanStyles.size)
    }
}
