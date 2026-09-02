package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore

/** Looks up fixed prayer text by [PrayerKey] and language code, falling back to Latin (and then
 * the raw key) when a translation is missing. See PrayerTranslations{Language}.kt for the actual
 * per-language tables. */
object PrayerTranslations {
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
