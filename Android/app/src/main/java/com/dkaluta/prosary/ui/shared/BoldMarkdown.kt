package com.dkaluta.prosary.ui.shared

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle

/** Minimal, dependency-free "bold-only markdown" renderer: turns `**bold**` runs into bold spans,
 * everything else passed through unstyled. Prayer bodies only ever use this one construct — the
 * traditional versicle/response typographic distinction, versicle in the body's normal weight,
 * response `**bold**` (see PrayerEngine.kt's versicle/response bodies) — so a full CommonMark
 * parser/library isn't needed. */
fun String.parseBoldMarkdown(): AnnotatedString = buildAnnotatedString {
    var remaining = this@parseBoldMarkdown
    while (true) {
        val start = remaining.indexOf("**")
        if (start == -1) {
            append(remaining)
            break
        }
        val end = remaining.indexOf("**", startIndex = start + 2)
        if (end == -1) {
            append(remaining)
            break
        }
        append(remaining.substring(0, start))
        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) {
            append(remaining.substring(start + 2, end))
        }
        remaining = remaining.substring(end + 2)
    }
}
