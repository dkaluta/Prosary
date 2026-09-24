package com.dkaluta.prosary.content

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.typography.PrayerTypography

/** Looks up fixed prayer text by [PrayerKey] and language code, falling back to Latin (and then
 * the raw key) when a translation is missing. See PrayerTranslations{Language}.kt for the actual
 * per-language tables. */
object PrayerTranslations {
    fun initialTransliteration(languageCode: String?, body: String, alternate: String?,
                               script: String = AppSettings.aramaicDefaultScript): Boolean? {
        if (LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return null
        val desired = if (script == "Syrc") PrayerTypography.Script.Syriac else PrayerTypography.Script.Hebrew
        if (PrayerTypography.scriptOf(body) == desired || alternate == null) return false
        return PrayerTypography.scriptOf(alternate) == desired
    }

    fun aramaicProgress(index: Int, total: Int, languageCode: String?, sourceScript: Boolean): String? {
        if (LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return null
        val connector = if (sourceScript) PrayerPackStore.transliteration(
            "rosary", "arc", "repetitionCounterConnector") else null
        return "$index ${connector ?: get("arc", PrayerKey.RepetitionCounterConnector)} $total"
    }

    fun flowTitle(title: String, languageCode: String?, sourceScript: Boolean, bundleId: String = "rosary"): String {
        val unpointed = HebrewDisplayText.unpoint(title)
        if (LanguageCatalog.fallbackChain(languageCode).firstOrNull() != "arc") return unpointed
        val pairs = PrayerPackStore.titleScriptPairs(bundleId, "arc")
        val definition = PrayerPackStore.definition(bundleId)
        val ordinalKeys = listOfNotNull(definition?.decades?.ordinalNounKey) +
            definition?.variants.orEmpty().mapNotNull { it.decades?.ordinalNounKey }
        val ordinalNouns = ordinalKeys.flatMap { key ->
            listOfNotNull(PrayerPackStore.resolveBodyText(bundleId, "arc", key),
                PrayerPackStore.transliteration(bundleId, "arc", key)).map(HebrewDisplayText::unpoint)
        }.toSet()
        if (" — " in unpointed) {
            val parts = unpointed.split(" — ")
            fun isPaired(value: String) = pairs.any {
                HebrewDisplayText.unpoint(it.first) == value || HebrewDisplayText.unpoint(it.second) == value
            }
            // Recognize the authored ordinal/mystery caption, preserving personal dash titles.
            if (parts.size !in 2..3) return unpointed
            fun isOrdinal(value: String): Boolean {
                val suffix = Regex(""" \d+$""").find(value)?.value ?: return false
                return value.removeSuffix(suffix) in ordinalNouns
            }
            val ordinalIndex = if (isOrdinal(parts.last())) parts.lastIndex else parts.size - 2
            if (!isOrdinal(parts[ordinalIndex]) || (ordinalIndex != parts.lastIndex && !isPaired(parts.last()))) return unpointed
            return parts.map { part ->
                flowTitle(part, languageCode, sourceScript, bundleId)
            }.joinToString(" — ")
        }
        val hebrewConnector = HebrewDisplayText.unpoint(get("arc", PrayerKey.RepetitionCounterConnector))
        val syriacConnector = PrayerPackStore.transliteration("rosary", "arc", "repetitionCounterConnector")
        val connectors = listOfNotNull(hebrewConnector, syriacConnector).joinToString("|", transform = Regex::escape)
        val ordinalSuffix = Regex(""" \d+$""").find(unpointed)
            ?.takeIf { unpointed.removeSuffix(it.value) in ordinalNouns }
        val suffix = (Regex("""( \(\d+ (?:$connectors) \d+\))$""")
            .find(unpointed) ?: ordinalSuffix)?.value.orEmpty()
        val base = unpointed.removeSuffix(suffix)
        val connector = if (sourceScript) syriacConnector ?: hebrewConnector else hebrewConnector
        val adjustedSuffix = suffix.replace(hebrewConnector, connector).let {
            if (syriacConnector == null) it else it.replace(syriacConnector, connector)
        }
        // These are paired, authored headings in the active bundle and shared Rosary. Never derive
        // a title from the body or transliterate an unknown/fallback heading ourselves.
        for ((primary, alternate) in pairs) {
            val primaryScript = PrayerTypography.scriptOf(primary)
            val alternateScript = PrayerTypography.scriptOf(alternate)
            val pair = when {
                primaryScript == PrayerTypography.Script.Hebrew && alternateScript == PrayerTypography.Script.Syriac -> primary to alternate
                primaryScript == PrayerTypography.Script.Syriac && alternateScript == PrayerTypography.Script.Hebrew -> alternate to primary
                else -> continue
            }
            val hebrew = HebrewDisplayText.unpoint(pair.first)
            val syriac = pair.second
            if (base != hebrew && base != syriac) continue
            return (if (sourceScript) syriac else hebrew) + adjustedSuffix
        }
        return base + adjustedSuffix
    }

    fun get(languageCode: String?, key: PrayerKey): String {
        for (code in LanguageCatalog.contentFallbackChain(languageCode)) {
            PrayerPackStore.prayerOverride(code, key)?.let { return JaffaPrayerWording.apply(code, it) }
            byLanguage[code]?.get(key)?.let { return JaffaPrayerWording.apply(code, it) }
        }

        return prayerTranslationsLatin[key] ?: key.name
    }

    private val genericHebrewKeys = setOf(
        PrayerKey.DecadeOrdinalFormat, PrayerKey.RepetitionCounterConnector, PrayerKey.FructusMysteriiLabel,
    )

    val byLanguage: Map<String, Map<PrayerKey, String>> = mapOf(
        "la" to prayerTranslationsLatin,
        "en" to prayerTranslationsEnglish,
        "ar" to prayerTranslationsArabic,
        "he" to prayerTranslationsHebrew.filterKeys { it in genericHebrewKeys },
        LanguageCatalog.hebrewVicariateContentCode to prayerTranslationsHebrew.filterKeys { it !in genericHebrewKeys },
        // The Mission wording has its own slot in the user's fallback order.
        "he-x-gamliel" to prayerTranslationsHebrewGamaliel,
        "el" to prayerTranslationsGreek,
        "es" to prayerTranslationsSpanish,
        "ru" to prayerTranslationsRussian,
        "tl" to prayerTranslationsTagalog,
    )
}
