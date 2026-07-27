package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore

/** Looks up the title/fruit/description of a mystery by imageKey and language code, falling
 * back to Latin when a translation is missing — including bundle-provided Latin, since some
 * mystery texts (the Seven Sorrows, the Franciscan Crown's Adoration of the Magi) live only in
 * their bundle's content, not the hardcoded tables. See MysteryTranslations{Language}.kt for the
 * actual per-language tables. */
object MysteryTranslations {
    fun get(languageCode: String?, imageKey: String): MysteryText {
        if (languageCode != null) {
            val override = PrayerPackStore.mysteryOverride(languageCode, imageKey)
            if (override != null) return override
        }

        val table = languageCode?.let { byLanguage[it] }
        val text = table?.get(imageKey)
        if (text != null) return text

        return PrayerPackStore.mysteryOverride("la", imageKey)
            ?: mysteryTranslationsLatin[imageKey]
            ?: MysteryText(title = imageKey, fruit = "", description = "")
    }

    val byLanguage: Map<String, Map<String, MysteryText>> = mapOf(
        "la" to mysteryTranslationsLatin,
        "en" to mysteryTranslationsEnglish,
        "ar" to mysteryTranslationsArabic,
        "he" to mysteryTranslationsHebrew,
        "ru" to mysteryTranslationsRussian,
        "tl" to mysteryTranslationsTagalog,
    )
}
