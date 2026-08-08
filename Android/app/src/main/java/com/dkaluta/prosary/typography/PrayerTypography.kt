package com.dkaluta.prosary.typography

import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.sp
import com.dkaluta.prosary.R

/**
 * Resolves the serif typeface used for prayer/Scripture body text, per language and content
 * type. Scripture quotations (the mystery-announcement step) get a dedicated typeface distinct
 * from ordinary prayer text — Cardo (Latin/English) and Scheherazade New (Arabic) were both
 * designed for classical/Biblical typesetting, the same reasoning behind using Shofar (rather
 * than Frank Ruhl Libre) for Hebrew. Latin/English prayers use the platform's built-in serif
 * design rather than a bundled font, since it's not ours to redistribute.
 */
object PrayerTypography {
    private val cardo = FontFamily(Font(R.font.cardo_regular))
    private val frankRuhlLibre = FontFamily(Font(R.font.frank_ruhl_libre_regular))
    private val shofar = FontFamily(Font(R.font.shofar_regular))
    private val amiri = FontFamily(Font(R.font.amiri_regular))
    private val scheherazadeNew = FontFamily(Font(R.font.scheherazade_new_regular))

    /** Only ever reached through a transliteration: no language ships its own text in Syriac
     * letters, because "arc" is Aramaic in Hebrew script. */
    private val notoSansSyriac = FontFamily(Font(R.font.noto_sans_syriac_regular))

    /** The writing system a run of text is actually in.
     *
     * Nearly always this follows from the language. The exception is a transliteration, which is
     * *by definition* in a different script from its own language's — and the bundle format
     * deliberately leaves which script to the author (Hebrew letters for Tagalog, Syriac letters
     * for Aramaic). So rather than have the format declare it and risk the declaration drifting
     * from the text, it is read off the characters, which cannot disagree with themselves. */
    enum class Script { Hebrew, Arabic, Syriac, Latin }

    /** The script most of a text's letters belong to. Counted rather than sampled: a citation
     * line ("— ܡܬܝ 28:1-7") mixes digits and punctuation into every body. */
    fun scriptOf(text: String): Script {
        var hebrew = 0; var arabic = 0; var syriac = 0; var latin = 0
        for (ch in text) {
            when (ch.code) {
                in 0x0590..0x05FF -> hebrew++
                in 0x0600..0x06FF, in 0x0750..0x077F -> arabic++
                in 0x0700..0x074F, in 0x0860..0x086F -> syriac++
                in 0x0041..0x005A, in 0x0061..0x007A, in 0x0370..0x03FF, in 0x1F00..0x1FFF -> latin++
            }
        }
        return listOf(
            hebrew to Script.Hebrew, arabic to Script.Arabic,
            syriac to Script.Syriac, latin to Script.Latin,
        ).maxByOrNull { it.first }?.second ?: Script.Latin
    }

    /** [script] overrides what the language would imply — pass it for a transliteration. */
    // Variants key on their base script: "he-x-gamliel" typesets exactly like "he".
    fun style(languageCode: String?, isScripture: Boolean, script: Script? = null): TextStyle =
        when (script ?: when (languageCode?.let { com.dkaluta.prosary.models.LanguageCatalog.baseLanguage(it) ?: it }) {
            "he", "arc" -> Script.Hebrew
            "ar" -> Script.Arabic
            else -> Script.Latin
        }) {
        // includeFontPadding is forced back ON for the marked scripts. Compose's modern default
        // (false) clips combining marks that rise above the ascender — and Masoretic Scripture
        // stacks cantillation over niqqud exactly there, so the first line of the first
        // station's Isaiah reading (מֵעֹ֤צֶר, a mahpakh on its first word) lost its marks on
        // Android while iOS drew them whole. The scripture line height also gains headroom:
        // te'amim above and vowels below need more than 1.4em or neighbouring lines collide.
        Script.Hebrew -> if (isScripture) {
            TextStyle(
                fontFamily = shofar, fontSize = 16.sp, lineHeight = 26.sp,
                platformStyle = PlatformTextStyle(includeFontPadding = true),
            )
        } else {
            TextStyle(
                fontFamily = frankRuhlLibre, fontSize = 21.sp, lineHeight = 29.sp,
                platformStyle = PlatformTextStyle(includeFontPadding = true),
            )
        }

        Script.Arabic -> if (isScripture) {
            TextStyle(
                fontFamily = scheherazadeNew, fontSize = 16.sp, lineHeight = 24.sp,
                platformStyle = PlatformTextStyle(includeFontPadding = true),
            )
        } else {
            TextStyle(
                fontFamily = amiri, fontSize = 18.sp, lineHeight = 26.sp,
                platformStyle = PlatformTextStyle(includeFontPadding = true),
            )
        }

        // Without a face covering the block the toggle would draw a line of tofu, which is
        // worse than not offering it at all.
        Script.Syriac -> TextStyle(fontFamily = notoSansSyriac, fontSize = 19.sp, lineHeight = 27.sp)

        Script.Latin -> if (isScripture) {
            TextStyle(fontFamily = cardo, fontSize = 19.sp, lineHeight = 27.sp)
        } else {
            TextStyle(fontFamily = FontFamily.Serif, fontSize = 17.sp, lineHeight = 24.sp)
        }
    }
}
