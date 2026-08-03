package com.dkaluta.prosary.typography

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

    fun style(languageCode: String?, isScripture: Boolean): TextStyle = when (languageCode) {
        "he", "arc" -> if (isScripture) {
            TextStyle(fontFamily = shofar, fontSize = 16.sp, lineHeight = 23.sp)
        } else {
            TextStyle(fontFamily = frankRuhlLibre, fontSize = 21.sp, lineHeight = 29.sp)
        }

        "ar" -> if (isScripture) {
            TextStyle(fontFamily = scheherazadeNew, fontSize = 16.sp, lineHeight = 23.sp)
        } else {
            TextStyle(fontFamily = amiri, fontSize = 18.sp, lineHeight = 26.sp)
        }

        else -> if (isScripture) {
            TextStyle(fontFamily = cardo, fontSize = 19.sp, lineHeight = 27.sp)
        } else {
            TextStyle(fontFamily = FontFamily.Serif, fontSize = 17.sp, lineHeight = 24.sp)
        }
    }
}
