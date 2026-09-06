package com.dkaluta.prosary.typography

import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.text.TextRunShaper
import android.os.Build
import androidx.annotation.RequiresApi
import java.util.Locale

/** Identifies the font actually used for a sample, never an OEM's private font setting. */
object SystemSansFontProbe {
    enum class SampleScript { LATIN, CYRILLIC, HEBREW }

    /** null means the device cannot identify its current face; keep the explicit option. */
    fun usesBundledSans(script: SampleScript): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null
        return runCatching { probe(script) }.getOrNull()
    }

    fun shouldOfferBundledFont(matches: Boolean?, isSelected: Boolean): Boolean =
        isSelected || matches != true

    @RequiresApi(Build.VERSION_CODES.S)
    private fun probe(script: SampleScript): Boolean? {
        val paint = Paint().apply {
            typeface = Typeface.SANS_SERIF
            textSize = 24f
        }
        fun files(text: String, rtl: Boolean): List<String?> {
            val glyphs = TextRunShaper.shapeTextRun(
                text, 0, text.length, 0, text.length, 0f, 0f, rtl, paint,
            )
            return (0 until glyphs.glyphCount()).map { glyphs.getFont(it).file?.name }
        }
        val latin = matchesFontFiles(files("AgpqR", false), "Roboto")
        return when (script) {
            SampleScript.LATIN -> latin
            SampleScript.CYRILLIC -> matchesFontFiles(files("БДЖийя", false), "Roboto")
            SampleScript.HEBREW -> combine(
                latin, matchesFontFiles(files("אבגמך", true), "NotoSansHebrew"),
            )
        }
    }

    /** Missing files remain unknown; unfamiliar names do not match, keeping the choice visible. */
    internal fun matchesFontFiles(files: List<String?>, family: String): Boolean? {
        if (files.isEmpty() || files.any { it.isNullOrBlank() }) return null
        val expected = family.lowercase(Locale.ROOT)
        return files.all { file ->
            val stem = file!!.substringBeforeLast('.').lowercase(Locale.ROOT)
            stem == expected || stem.startsWith("$expected-") || stem.startsWith("$expected[") ||
                (expected == "roboto" && (stem == "robotoflex" || stem.startsWith("robotoflex-")))
        }
    }

    private fun combine(first: Boolean?, second: Boolean?): Boolean? = when {
        first == false || second == false -> false
        first == null || second == null -> null
        else -> true
    }
}
