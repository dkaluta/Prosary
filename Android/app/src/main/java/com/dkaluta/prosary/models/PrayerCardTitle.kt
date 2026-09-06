package com.dkaluta.prosary.models

import com.dkaluta.prosary.typography.HebrewDisplayText

/** Bilingual names are independent of a card's preset, progress, or descriptive subtitle. */
data class PrayerCardTitle(val primary: String, val interfaceSubtitle: String? = null) {
    companion object {
        fun resolve(
            interfaceTitle: String,
            prayerTitle: String,
            enabled: Boolean = AppSettings.showPrayerNameInPrayerLanguage,
        ): PrayerCardTitle {
            val native = HebrewDisplayText.unpoint(interfaceTitle).trim()
            val prayer = HebrewDisplayText.unpoint(prayerTitle).trim().ifBlank { native }
            return if (enabled && prayer != native) PrayerCardTitle(prayer, native.takeIf(String::isNotBlank))
            else PrayerCardTitle(native)
        }
    }
}
