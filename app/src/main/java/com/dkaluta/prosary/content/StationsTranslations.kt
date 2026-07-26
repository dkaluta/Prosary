package com.dkaluta.prosary.content

/** Looks up a Station's display text by imageKey and language code, falling back to Latin (and
 * then a bare placeholder) when a translation is missing. See StationsTranslations{Language}.kt
 * for the actual per-language tables. Only `la`/`en` are populated for now — `ar`/`he`/`ru`/`tl`
 * fall back to Latin until dedicated translations are added. Mirrors MysteryTranslations. */
object StationsTranslations {
    fun get(languageCode: String?, imageKey: String): StationText {
        val table = languageCode?.let { byLanguage[it] }
        val text = table?.get(imageKey)
        if (text != null) return text

        return stationsTranslationsLatin[imageKey] ?: StationText(title = imageKey, meditation = "")
    }

    val byLanguage: Map<String, Map<String, StationText>> = mapOf(
        "la" to stationsTranslationsLatin,
        "en" to stationsTranslationsEnglish,
    )
}
