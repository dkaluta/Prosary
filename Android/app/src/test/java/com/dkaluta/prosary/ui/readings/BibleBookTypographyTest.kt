package com.dkaluta.prosary.ui.readings

import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.unit.em
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class BibleBookTypographyTest {
    @Test fun verseMarkerIsInlineRaisedAndKeepsTheIndivisibleSourceRange() {
        val body = "The source text keeps its exact punctuation."
        val result = BibleBookTypography.body(body, "12–13")
        val marker = "\u206812–13\u2069"
        assertEquals("$marker\u00a0$body", result.text)
        val span = result.spanStyles.single()
        assertEquals(0, span.start)
        assertEquals(marker.length, span.end)
        assertEquals(BaselineShift.Superscript, span.item.baselineShift)
        assertEquals(0.72.em, span.item.fontSize)
        // The Scripture inherits its selected typeface and size; only the marker is styled.
        assertEquals(body, result.subSequence(span.end + 1, result.length).text)
    }

    @Test fun rightToLeftMarkersKeepExactPrintedCharactersAndBody() {
        val body = "בְּרֵאשִׁית בָּרָא"
        assertEquals("\u2068כ–כא\u2069\u00a0$body", BibleBookTypography.body(body, "כ–כא").text)
    }

    @Test fun unnumberedScriptureHasNoInventedMarker() {
        val body = "Unnumbered source introduction."
        val result = BibleBookTypography.body(body, null)
        assertEquals(body, result.text)
        assertTrue(result.spanStyles.isEmpty())
    }
}
