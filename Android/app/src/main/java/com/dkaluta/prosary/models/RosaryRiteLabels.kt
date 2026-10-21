package com.dkaluta.prosary.models

import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.typography.HebrewDisplayText

/** Hebrew interface labels name the prayers in this session's authored Hebrew tradition.
 * The surrounding interface prose stays localized; other language combinations retain their
 * existing interface labels. No prayer name is inferred from its body or translated here. */
object RosaryRiteLabels {
    fun title(
        titleKey: String,
        prayerLanguage: String?,
        interfaceLanguage: String = LanguageCatalog.uiLanguageCode(),
        bundleId: String = "rosary",
    ): String? {
        if (LanguageCatalog.pickerLanguageCode(interfaceLanguage) != "he" ||
            LanguageCatalog.pickerLanguageCode(LanguageCatalog.resolve(prayerLanguage).code) != "he") return null
        val language = PrayerPackStore.effectiveLanguage(bundleId, prayerLanguage)
        return HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText(bundleId, language, titleKey))
    }

    /** Shared by the native Rosary options and the bundle-driven options editor. */
    fun optionLabel(
        optionKey: String,
        prayerLanguage: String?,
        interfaceLanguage: String = LanguageCatalog.uiLanguageCode(),
        format: (Int, List<Any>) -> String,
    ): String? {
        fun name(key: String) = title(key, prayerLanguage, interfaceLanguage)
        val ourFather = name("paterNosterTitle") ?: return null
        fun formatted(resource: Int, vararg titles: String) = format(resource, titles.toList())
        return when (optionKey) {
            "invitatory" -> name("invitatoryTitle")
            "apostlesCreed" -> name("symbolumApostolorumTitle")
            "openingPrayers" -> formatted(R.string.ro_opening_prayers_named, ourFather, name("aveMariaTitle").orEmpty())
            "openingFatimaPrayer" -> formatted(R.string.ro_opening_fatima_named,
                name("oratioFatimaeTitle").orEmpty(), name("gloriaPatriTitle").orEmpty())
            "fatimaPrayer" -> formatted(R.string.ro_fatima_named, name("oratioFatimaeTitle").orEmpty())
            "eternalRest" -> name("requiemAeternamTitle")
            "presenterHint" -> formatted(R.string.ro_presenter_hint_named,
                name("aveMariaTitle").orEmpty(), name("gloriaPatriTitle").orEmpty())
            "stMichael" -> name("sanctusMichaelTitle")
            "finalSignOfCross" -> formatted(R.string.ro_final_sign_named, name("signumCrucisTitle").orEmpty())
            else -> null
        }
    }

    fun antiphonTitle(
        caseId: String,
        prayerLanguage: String?,
        interfaceLanguage: String = LanguageCatalog.uiLanguageCode(),
    ): String? = caseId.takeIf { it in setOf("salveRegina", "almaRedemptorisMater",
        "aveReginaCaelorum", "reginaCaeli", "subTuumPraesidium") }
        ?.let { title("${it}Title", prayerLanguage, interfaceLanguage) }
}
