package com.dkaluta.prosary.models

import android.content.Context
import java.time.LocalDate
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json

/** The small piece of an interrupted prayer needed to offer Continue on re-entry. The prayer's
 * authored/configured options remain in its favorite or bundle; a run stores only the current
 * step and the language actually selected inside the flow. */
@Serializable
data class PrayerRunProgress(
    val stepIndex: Int,
    val languageCode: String,
    /** ISO local date, intentionally without a timezone: Rosaries expire when the user's local
     * calendar turns over, even if the saved epoch instant would still be yesterday elsewhere. */
    val savedLocalDate: String,
    /** Stable description of the options that produced this run's step sequence. Null keeps
     * old serialized checkpoints decodable, but they are rejected whenever a current signature
     * is supplied rather than risking a resume into a differently configured prayer. */
    val configurationSignature: String? = null,
) {
    fun canResume(
        stepCount: Int,
        today: LocalDate = LocalDate.now(),
        sameLocalDayOnly: Boolean = false,
        expectedConfigurationSignature: String? = null,
    ): Boolean =
        stepIndex in 1 until stepCount &&
            (expectedConfigurationSignature == null || configurationSignature == expectedConfigurationSignature) &&
            (!sameLocalDayOnly || savedLocalDate == today.toString())
}

/** The raw language choice is persisted separately on [PrayerRunProgress]. A custom devotion's
 * resolved form is included because some languages own a structurally different default form;
 * these values describe configuration that can change the generated sequence or visual identity. */
object PrayerRunSignatures {
    fun rosary(options: RosaryOptions): String = listOf(
        "rosary",
        options.mysterySelectionMode.stableValue,
        options.specificMysteryGroup.stableValue,
        options.specificMysteryOrder.toString(),
        options.includeApostlesCreed.flag,
        options.includeOpeningPrayers.flag,
        options.includeOpeningFatimaPrayer.flag,
        options.includeFatimaPrayer.flag,
        options.eternalRestForDeceased.stableValue,
        options.marianAntiphon.stableValue,
        options.includeClosingIntentions.flag,
        options.includeStMichaelPrayer.flag,
        options.includeFinalSignOfCross.flag,
        options.aramaicSignOfCrossForm,
        options.presenterMode.flag,
        options.mysteryImageStyle.stableValue,
    ).joinToString("|")

    fun custom(
        devotionId: String,
        effectiveVariantId: String?,
        dayIndex: Int,
        options: Map<String, String>,
    ): String {
        val optionText = options.toSortedMap().entries.joinToString("|") { (key, value) ->
            "$key=$value"
        }
        return "custom|$devotionId|${effectiveVariantId.orEmpty()}|$dayIndex|$optionText"
    }

    fun jesus(target: JesusPrayerTarget): String = when (target) {
        is JesusPrayerTarget.Count -> "jesus|count|${target.value}"
        JesusPrayerTarget.Unbounded -> "jesus|unbounded"
    }

    private val Enum<*>.stableValue: String
        get() = name.replaceFirstChar { if (it.isUpperCase()) it.lowercaseChar() else it }

    private val Boolean.flag: String get() = if (this) "1" else "0"
}

/** A language normally changes only text. A devotion may instead declare a different default
 * form for a language; carrying a numeric position into that other sequence would open an
 * unrelated prayer. */
object CustomDevotionLanguageSwitch {
    fun indexAfterSwitch(
        currentIndex: Int,
        previousEffectiveVariantId: String?,
        nextEffectiveVariantId: String?,
        nextStepCount: Int,
    ): Int = if (previousEffectiveVariantId == nextEffectiveVariantId) {
        currentIndex.coerceIn(0, (nextStepCount - 1).coerceAtLeast(0))
    } else {
        0
    }
}

/** Stable platform-local run identities, shared in spelling with the other ports. A custom
 * devotion includes form and day because those can produce different step sequences. */
object PrayerRunKeys {
    fun rosary(prayerId: String): String = "rosary:$prayerId"

    fun custom(devotionId: String, variantId: String?, dayIndex: Int): String =
        "custom:$devotionId:${variantId.orEmpty()}:$dayIndex"

    fun jesus(prayerId: String?, target: JesusPrayerTarget): String =
        "jesus:${prayerId ?: target.toRouteValue()}"
}

/** Platform-local transient run storage. Keys are stable prayer identities, allowing multiple
 * saved Rosaries to keep their own place while ad-hoc Jesus Prayer sessions use their target. */
object PrayerRunProgressStore {
    private const val PREFS = "prayer_run_progress"
    private const val KEY = "runs"
    private val json = Json { ignoreUnknownKeys = true }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun all(context: Context): Map<String, PrayerRunProgress> {
        val raw = prefs(context).getString(KEY, null) ?: return emptyMap()
        return runCatching { json.decodeFromString<Map<String, PrayerRunProgress>>(raw) }
            .getOrDefault(emptyMap())
    }

    private fun saveAll(context: Context, runs: Map<String, PrayerRunProgress>) {
        prefs(context).edit().putString(KEY, json.encodeToString(runs)).apply()
    }

    fun progress(context: Context, runKey: String): PrayerRunProgress? = all(context)[runKey]

    fun save(
        context: Context,
        runKey: String,
        stepIndex: Int,
        languageCode: String,
        configurationSignature: String? = null,
        today: LocalDate = LocalDate.now(),
    ) {
        if (stepIndex <= 0) {
            clear(context, runKey)
            return
        }
        saveAll(
            context,
            all(context) + (runKey to PrayerRunProgress(
                stepIndex = stepIndex,
                languageCode = languageCode,
                savedLocalDate = today.toString(),
                configurationSignature = configurationSignature,
            )),
        )
    }

    fun clear(context: Context, runKey: String) {
        val remaining = all(context) - runKey
        if (remaining.isEmpty()) {
            prefs(context).edit().remove(KEY).apply()
        } else {
            saveAll(context, remaining)
        }
    }
}
