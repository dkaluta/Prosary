package com.dkaluta.prosary.ui.shared

import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.font.FontWeight
import com.dkaluta.prosary.typography.PrayerTypography
import org.junit.Assert.assertEquals
import org.junit.Test

class BoldMarkdownTest {
    @Test
    fun holyGodGesturesKeepTheirPositionAndScriptThroughBodyRendering() {
        val openings = mapOf(
            "קַדּישַת ✠▼▲ אַלָהָא" to PrayerTypography.Script.Hebrew,
            "ܩܰܕ݁ܝܫܰܬ݂ ✠▼▲ ܐܰܠܳܗܳܐ" to PrayerTypography.Script.Syriac,
        )
        openings.forEach { (body, script) ->
            assertEquals(body, body.parseBoldMarkdown().text)
            assertEquals(body, "**$body**".parseBoldMarkdown().text)
            // The gestures must not redirect the body to a Latin typeface.
            assertEquals(script, PrayerTypography.scriptOf(body.parseBoldMarkdown().text))
        }
    }

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
