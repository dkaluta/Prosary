package com.dkaluta.prosary.content

/** Looks up fixed prayer text by [PrayerKey] and language code, falling back to Latin (and then
 * the raw key) when a translation is missing. See PrayerTranslations{Language}.kt for the actual
 * per-language tables. */
object PrayerTranslations {
    fun get(languageCode: String?, key: PrayerKey): String {
        val table = languageCode?.let { byLanguage[it] }
        val text = table?.get(key)
        if (text != null) return text

        return prayerTranslationsLatin[key] ?: key.name
    }

    val byLanguage: Map<String, Map<PrayerKey, String>> = mapOf(
        "la" to prayerTranslationsLatin,
        "en" to prayerTranslationsEnglish,
        "ar" to prayerTranslationsArabic,
        "he" to prayerTranslationsHebrew,
        "ru" to prayerTranslationsRussian,
        "tl" to prayerTranslationsTagalog,
    )
}
