package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore

/** Looks up fixed prayer text by [PrayerKey] and language code, falling back to Latin (and then
 * the raw key) when a translation is missing. See PrayerTranslations{Language}.kt for the actual
 * per-language tables. */
object PrayerTranslations {
    fun get(languageCode: String?, key: PrayerKey): String {
        if (languageCode != null) {
            val override = PrayerPackStore.prayerOverride(languageCode, key)
            if (override != null) return override
        }

        val table = languageCode?.let { byLanguage[it] }
        val text = table?.get(key)
        if (text != null) return text

        // Community variants ("he-x-gamliel") overlay their base language before Latin.
        val base = languageCode?.let { com.dkaluta.prosary.models.LanguageCatalog.baseLanguage(it) }
        if (base != null) {
            PrayerPackStore.prayerOverride(base, key)?.let { return it }
            byLanguage[base]?.get(key)?.let { return it }
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
