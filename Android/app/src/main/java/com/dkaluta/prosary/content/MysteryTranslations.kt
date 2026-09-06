package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.prayerpack.MysteryTextOverride
import com.dkaluta.prosary.typography.HebrewDisplayText

/** Looks up the title/fruit/description of a mystery by imageKey and language code, falling
 * back to Latin when a translation is missing — including bundle-provided Latin, since some
 * mystery texts (the Seven Sorrows, the Franciscan Crown's Adoration of the Magi) live only in
 * their bundle's content, not the hardcoded tables. See MysteryTranslations{Language}.kt for the
 * actual per-language tables. */
object MysteryTranslations {
    fun get(languageCode: String?, imageKey: String): MysteryText = resolve(
        chain = com.dkaluta.prosary.models.LanguageCatalog.contentFallbackChain(languageCode),
        imageKey = imageKey,
        overrideAt = PrayerPackStore::mysteryOverride,
        completeAt = { code, key -> byLanguage[code]?.get(key) },
    )

    /** Kept as a small pure seam so sparse source overrides and their fallback provenance can
     * be pinned without mutating the process-wide pack store in JVM tests. */
    internal fun resolve(
        chain: List<String>,
        imageKey: String,
        overrideAt: (String, String) -> MysteryTextOverride?,
        completeAt: (String, String) -> MysteryText?,
    ): MysteryText {

        fun resolveField(
            fallback: String,
            fromOverride: (MysteryTextOverride) -> String?,
            fromComplete: (MysteryText) -> String,
        ): String {
            for (code in chain) {
                overrideAt(code, imageKey)?.let(fromOverride)?.let { return it }
                completeAt(code, imageKey)?.let(fromComplete)?.let { return it }
            }
            return fallback
        }

        // Description and transliteration are a pair: if the Peshitta (for example) supplies
        // the description, only that same override may supply its alternate-script form. A
        // transliteration from some later fallback must never be attached to a different text.
        var description = ""
        var transliteratedDescription: String? = null
        for (code in chain) {
            val partial = overrideAt(code, imageKey)
            if (partial?.description != null) {
                description = partial.description
                transliteratedDescription = partial.transliteratedDescription
                break
            }
            val complete = completeAt(code, imageKey)
            if (complete != null) {
                description = complete.description
                transliteratedDescription = complete.transliteratedDescription
                break
            }
        }

        return MysteryText(
            title = HebrewDisplayText.unpoint(resolveField(imageKey, { it.title }, { it.title })),
            fruit = resolveField("", { it.fruit }, { it.fruit }),
            description = description,
            transliteratedDescription = transliteratedDescription,
        )
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
