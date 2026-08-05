package com.dkaluta.prosary.models

/** A prayer language the app can display, independent of the device's own UI/system language. */
data class LanguageOption(
    /** ISO 639-1 code used as the key into the content layer's prayer/mystery translations. */
    val code: String,
    /** The language's own name, in its own script (shown in pickers). */
    val nativeName: String,
    /** Whether prayer text in this language should be displayed right-to-left. */
    val isRightToLeft: Boolean,
)

/** Languages available for prayer text. Latin is the default — it's the neutral fallback every
 * lookup falls back to if a translation is missing in the chosen language. */
object LanguageCatalog {
    /** "he-x-gamliel" → "he": community variants overlay their base language — resolve
     * chains try the exact code first, then this. Null when the code has no subtag. */
    fun baseLanguage(code: String): String? =
        code.indexOf('-').takeIf { it > 0 }?.let { code.substring(0, it) }

    const val defaultCode = "la"

    /** Sentinel stored in a favorite's `languageCode` meaning "follow the app-level default setting". */
    const val defaultSentinel = ""

    val all: List<LanguageOption> = listOf(
        LanguageOption(code = "la", nativeName = "Latina", isRightToLeft = false),
        LanguageOption(code = "en", nativeName = "English", isRightToLeft = false),
        LanguageOption(code = "ar", nativeName = "العربية", isRightToLeft = true),
        LanguageOption(code = "he", nativeName = "עברית", isRightToLeft = true),
        // Aramaic in Hebrew script — the Aramaic-rite communities' liturgical language.
        LanguageOption(code = "arc", nativeName = "ארמית", isRightToLeft = true),
        // The Mission of St. Gamaliel's own wording, sent by Erez 2026-08-05: an overlay on "he",
        // so the prayers they have not sent still read in the app's Hebrew.
        LanguageOption(code = "he-x-gamliel", nativeName = "עברית — נוסח השליחות", isRightToLeft = true),
        LanguageOption(code = "ru", nativeName = "Русский", isRightToLeft = false),
        LanguageOption(code = "tl", nativeName = "Tagalog", isRightToLeft = false),
    )

    fun resolve(code: String?): LanguageOption {
        if (code == null || code == defaultSentinel) {
            return all.firstOrNull { it.code == AppSettings.defaultLanguageCode }
                ?: all.first { it.code == defaultCode }
        }
        return all.firstOrNull { it.code == code } ?: all.first { it.code == defaultCode }
    }
}
