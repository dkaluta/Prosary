package com.dkaluta.Prosary.content

import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Test

/**
 * Guards against a missed cell in the per-language content tables — [PrayerTranslations.get]
 * silently falls back to Latin (then the raw key) when a translation is missing, so a gap here
 * wouldn't otherwise surface until someone actually reads that language in the app.
 */
class PrayerTranslationsCompletenessTest {
    private val supportedLanguages = listOf("la", "en", "ar", "he", "ru", "tl")

    private val angelusAndJesusPrayerKeys = listOf(
        PrayerKey.VersiculumAngelusPrimus, PrayerKey.ResponsiumAngelusPrimus,
        PrayerKey.VersiculumAngelusSecundus, PrayerKey.ResponsiumAngelusSecundus,
        PrayerKey.VersiculumAngelusTertius, PrayerKey.ResponsiumAngelusTertius,
        PrayerKey.CollectaAngelus, PrayerKey.OratioIesu,
    )

    @Test
    fun everyNewKeyIsPresentInEverySupportedLanguage() {
        for (key in angelusAndJesusPrayerKeys) {
            for (language in supportedLanguages) {
                val text = PrayerTranslations.byLanguage[language]?.get(key)
                assertNotNull("$key missing a $language translation", text)
                assertFalse("$key has an empty $language translation", text.isNullOrEmpty())
            }
        }
    }
}
