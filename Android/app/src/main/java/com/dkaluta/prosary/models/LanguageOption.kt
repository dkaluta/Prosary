package com.dkaluta.prosary.models

/** A prayer language the app can display, independent of the device's own UI/system language. */
data class LanguageOption(
    /** Prayer-language identifier used as the key into the content layer's translations. */
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

    /** The UI language as the content layer spells it. Android's Locale still reports Hebrew by
     * its pre-1989 legacy code — getLanguage() returns "iw", never "he" — so every lookup that
     * fed it straight into a manifest's displayNameByLanguage / nameByLanguage / reminderBody
     * missed the "he" keys and quietly fell back to English for exactly the audience those keys
     * were written for. Normalized here once; the other two legacy codes come along for free. */
    fun uiLanguageCode(raw: String = java.util.Locale.getDefault().language): String {
        val normalized = raw.replace('_', '-').lowercase(java.util.Locale.ROOT)
        val base = normalized.substringBefore('-')
        val canonicalBase = when (base) {
            "iw" -> "he"
            "in" -> "id"
            "ji" -> "yi"
            "fil" -> "tl"
            else -> base
        }
        return canonicalBase + normalized.removePrefix(base)
    }

    /** Sentinel stored in a favorite's `languageCode` meaning "follow the app-level default setting". */
    const val defaultSentinel = ""

    val all: List<LanguageOption> = listOf(
        LanguageOption(code = "la", nativeName = "Latina", isRightToLeft = false),
        LanguageOption(code = "en", nativeName = "English", isRightToLeft = false),
        LanguageOption(code = "ar", nativeName = "العربية", isRightToLeft = true),
        LanguageOption(code = "he", nativeName = "עברית — נוסח הנציגות", isRightToLeft = true),
        LanguageOption(code = "he-x-gamliel", nativeName = "עברית — נוסח השליחות", isRightToLeft = true),
        // Aramaic in Hebrew script — the Aramaic-rite communities' liturgical language.
        LanguageOption(code = "arc", nativeName = "ארמית", isRightToLeft = true),
        // Greek: the language a great deal of the app's own Scripture and prayer was first
        // written in — the Creed, the Sub Tuum, the Jesus Prayer.
        LanguageOption(code = "el", nativeName = "Ἑλληνικά", isRightToLeft = false),
        LanguageOption(code = "es", nativeName = "Español", isRightToLeft = false),
        LanguageOption(code = "fr", nativeName = "Français", isRightToLeft = false),
        LanguageOption(code = "it", nativeName = "Italiano", isRightToLeft = false),
        LanguageOption(code = "ru", nativeName = "Русский", isRightToLeft = false),
        LanguageOption(code = "tl", nativeName = "Tagalog", isRightToLeft = false),
    )

    /** Picker choices for a bundle's declared languages. The Mission is a sparse overlay rather
     * than a manifest language of its own, so every bundle offering Hebrew exposes both sourced
     * Hebrew uses as adjacent, independent choices. */
    fun availableOptions(declaredCodes: List<String>): List<LanguageOption> {
        val available = declaredCodes.flatMap { code ->
            if (code == "he") listOf("he", "he-x-gamliel") else listOf(code)
        }.toSet()
        return all.filter { it.code in available }
    }

    val fallbackOrder: List<String>
        get() {
            val known = all.map { it.code }.toSet()
            val stored = AppSettings.languageFallbackOrder.filter { it in known }.distinct()
            val defaults = all.map { it.code }.filter { it != defaultCode } + defaultCode
            val missing = defaults.filter { it !in stored }
            // A saved order from before a language was added keeps Latin as its final fallback.
            // Explicit user placement of Latin elsewhere remains intact.
            return if (stored.lastOrNull() == defaultCode) {
                stored.dropLast(1) + missing + defaultCode
            } else {
                (stored + missing).distinct()
            }
        }

    fun fallbackChain(requested: String?): List<String> = buildList {
        fun append(code: String?) {
            val normalized = code?.let(::uiLanguageCode) ?: return
            if (normalized in this) return
            add(normalized)
            baseLanguage(normalized)?.takeIf { it !in this }?.let(::add)
        }
        append(requested?.takeIf { it.isNotEmpty() } ?: AppSettings.defaultLanguageCode)
        fallbackOrder.forEach(::append)
        append(defaultCode)
    }

    /** Legacy grouping metadata for the two Hebrew community uses. Pickers expose them beside
     * one another as independent prayer languages; the relationship remains useful when
     * resolving older stored codes and documenting the base-language fallback.
     *
     * The first entry of each list is the language's own (base) use; the rest overlay it. */
    val ritesByLanguage: Map<String, List<LanguageOption>> = mapOf(
        "he" to listOf(
            LanguageOption(code = "he", nativeName = "נוסח הנציגות", isRightToLeft = true),
            // The Mission of St. Gamaliel's wording, sent by Erez 2026-08-05.
            LanguageOption(code = "he-x-gamliel", nativeName = "נוסח השליחות", isRightToLeft = true),
        ),
    )

    /** The rites offered for a code's language — empty when there is only one way to pray it. */
    fun rites(code: String): List<LanguageOption> =
        ritesByLanguage[baseLanguage(code) ?: code].orEmpty()

    fun resolve(code: String?): LanguageOption {
        if (code == null || code == defaultSentinel) {
            return option(uiLanguageCode(AppSettings.defaultLanguageCode))
        }
        return option(uiLanguageCode(code))
    }

    /** Resolves a stored code, which may name a rite ("he-x-gamliel") rather than a plain
     * language — the rite keeps its own code so every lookup can overlay it on the base. */
    private fun option(code: String?): LanguageOption {
        all.firstOrNull { it.code == code }?.let { return it }
        val rite = code?.let { c -> rites(c).firstOrNull { it.code == c } }
        if (rite != null) {
            // A rite carries its language's name in pickers; its own name belongs to the rite row.
            val language = all.firstOrNull { it.code == (baseLanguage(rite.code) ?: rite.code) }
            if (language != null) return rite.copy(nativeName = language.nativeName)
        }
        return all.firstOrNull { it.code == code }
            ?: code?.let(::baseLanguage)?.let { base -> all.firstOrNull { it.code == base } }
            ?: all.first { it.code == defaultCode }
    }
}
