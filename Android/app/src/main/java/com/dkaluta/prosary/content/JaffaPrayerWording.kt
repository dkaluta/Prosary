package com.dkaluta.prosary.content

import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog

/** User-confirmed Jaffa wording, applied to the winning Vicariate source at display time.
 * The source dictionaries stay unchanged, and unpointed input stays unpointed.
 * Attribution and the user's confirmation: Shared/content/rosary/SOURCES.markdown. */
object JaffaPrayerWording {
    fun apply(probe: String, text: String): String {
        if (probe != LanguageCatalog.hebrewVicariateContentCode || !AppSettings.useJaffaHailMaryWording) return text
        return text.replace("מְלֵאַת הַחֶסֶד", "בְּרוּכַת הַחֶסֶד")
            .replace("מלאת החסד", "ברוכת החסד")
    }
}
