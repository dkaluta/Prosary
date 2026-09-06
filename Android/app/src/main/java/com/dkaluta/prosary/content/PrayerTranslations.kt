package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.typography.PrayerTypography

/** Looks up fixed prayer text by [PrayerKey] and language code, falling back to Latin (and then
 * the raw key) when a translation is missing. See PrayerTranslations{Language}.kt for the actual
 * per-language tables. */
object PrayerTranslations {
    fun initialTransliteration(languageCode: String?, body: String, alternate: String?,
                               script: String = AppSettings.aramaicDefaultScript): Boolean? {
        if (LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return null
        val desired = if (script == "Syrc") PrayerTypography.Script.Syriac else PrayerTypography.Script.Hebrew
        if (PrayerTypography.scriptOf(body) == desired || alternate == null) return false
        return PrayerTypography.scriptOf(alternate) == desired
    }

    fun aramaicProgress(index: Int, total: Int, languageCode: String?, sourceScript: Boolean): String? {
        if (LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return null
        val connector = if (sourceScript) PrayerPackStore.transliteration(
            "rosary", "arc", "repetitionCounterConnector") else null
        return "$index ${connector ?: get("arc", PrayerKey.RepetitionCounterConnector)} $total"
    }

    fun flowTitle(title: String, languageCode: String?, sourceScript: Boolean): String {
        val unpointed = HebrewDisplayText.unpoint(title)
        if (!sourceScript || LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return unpointed
        val connector = PrayerPackStore.transliteration("rosary", "arc", "repetitionCounterConnector") ?: return unpointed
        val original = HebrewDisplayText.unpoint(get("arc", PrayerKey.RepetitionCounterConnector))
        return Regex("""(\(\d+) ${Regex.escape(original)} (\d+\))$""").replace(unpointed, "\$1 $connector \$2")
    }

    fun get(languageCode: String?, key: PrayerKey): String {
        for (code in com.dkaluta.prosary.models.LanguageCatalog.fallbackChain(languageCode)) {
            PrayerPackStore.prayerOverride(code, key)?.let { return it }
            byLanguage[code]?.get(key)?.let { return it }
        }

        return prayerTranslationsLatin[key] ?: key.name
    }

    val byLanguage: Map<String, Map<PrayerKey, String>> = mapOf(
        "la" to prayerTranslationsLatin,
        "en" to prayerTranslationsEnglish,
        "ar" to prayerTranslationsArabic,
        "he" to prayerTranslationsHebrew,
        // The Mission of St. Gamaliel's wording, overlaying plain Hebrew key by key.
        "he-x-gamliel" to prayerTranslationsHebrewGamaliel,
        "el" to prayerTranslationsGreek,
        "es" to prayerTranslationsSpanish,
        "ru" to prayerTranslationsRussian,
        "tl" to prayerTranslationsTagalog,
    )
}
