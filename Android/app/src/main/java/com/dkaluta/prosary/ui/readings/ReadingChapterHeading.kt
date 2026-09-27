package com.dkaluta.prosary.ui.readings

import android.content.Context
import android.content.res.Configuration
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.LanguageCatalog
import java.text.NumberFormat
import java.util.Locale

/** Chapter labels follow the selected Bible, independently of the interface language. */
internal object ReadingChapterHeading {
    fun label(context: Context, chapter: Int, language: String, script: String = "Hebr"): String {
        val code = languageCode(language)
        val number = number(chapter, code, script)
        // Sourced edition metadata, independent of which interface locales Android ships.
        // Aramaic chapter term: CAL, lemma qpl'wn; numbering follows the Peshitta edition.
        if (code == "arc") return "${if (script == "Syrc") "ܩܦܠܐܘܢ" else "קפלאון"} $number"
        if (code == "el") return "Κεφάλαιο $number"
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(Locale.forLanguageTag(if (code == "tl") "fil" else code))
        }
        return context.createConfigurationContext(configuration).getString(R.string.readings_chapter, number)
    }

    fun number(chapter: Int, language: String, script: String = "Hebr"): String = when (val code = languageCode(language)) {
        "he" -> if (chapter in 1..999) hebrewNumber(chapter) else chapter.toString()
        "ar" -> chapter.toString().map { if (it in '0'..'9') '\u0660' + (it - '0') else it }.joinToString("")
        "arc" -> if (chapter !in 1..999) chapter.toString()
            else if (script == "Syrc") syriacNumber(chapter) else hebrewNumber(chapter)
        else -> NumberFormat.getIntegerInstance(Locale.forLanguageTag(code)).apply { isGroupingUsed = false }.format(chapter)
    }

    private fun languageCode(language: String): String = LanguageCatalog.uiLanguageCode(language).let {
        LanguageCatalog.baseLanguage(it) ?: it
    }

    private fun hebrewNumber(number: Int): String {
        var remaining = number
        val letters = buildString {
            for ((value, letter) in listOf(400 to 'ת', 300 to 'ש', 200 to 'ר', 100 to 'ק')) {
                while (remaining >= value) { append(letter); remaining -= value }
            }
            if (remaining == 15 || remaining == 16) {
                append(if (remaining == 15) "טו" else "טז")
            } else {
                for ((value, letter) in listOf(90 to 'צ', 80 to 'פ', 70 to 'ע', 60 to 'ס', 50 to 'נ',
                    40 to 'מ', 30 to 'ל', 20 to 'כ', 10 to 'י', 9 to 'ט', 8 to 'ח', 7 to 'ז', 6 to 'ו',
                    5 to 'ה', 4 to 'ד', 3 to 'ג', 2 to 'ב', 1 to 'א')) {
                    if (remaining >= value) { append(letter); remaining -= value }
                }
            }
        }
        return if (letters.length == 1) "$letters׳" else letters.dropLast(1) + '״' + letters.last()
    }

    private fun syriacNumber(number: Int): String = buildString {
        var remaining = number
        for ((value, letter) in listOf(400 to 'ܬ', 300 to 'ܫ', 200 to 'ܪ', 100 to 'ܩ', 90 to 'ܨ',
            80 to 'ܦ', 70 to 'ܥ', 60 to 'ܣ', 50 to 'ܢ', 40 to 'ܡ', 30 to 'ܠ', 20 to 'ܟ', 10 to 'ܝ',
            9 to 'ܛ', 8 to 'ܚ', 7 to 'ܙ', 6 to 'ܘ', 5 to 'ܗ', 4 to 'ܕ', 3 to 'ܓ', 2 to 'ܒ', 1 to 'ܐ')) {
            while (remaining >= value) { append(letter); remaining -= value }
        }
    }
}
