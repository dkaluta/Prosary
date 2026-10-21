package com.dkaluta.prosary.ui.readings

import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.BaselineShift
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.em

/** Book typography is scoped to the facing pages; the continuous reader stays unchanged. */
internal val LocalBibleBookMode = staticCompositionLocalOf { false }

internal object BibleBookTypography {
    fun body(text: String, verseLabel: String?): AnnotatedString = buildAnnotatedString {
        if (verseLabel != null) {
            withStyle(SpanStyle(fontSize = 0.72.em, baselineShift = BaselineShift.Superscript)) {
                append("\u2068$verseLabel\u2069")
            }
            append('\u00a0')
        }
        append(text)
    }
}
