package com.dkaluta.prosary.models

import android.content.Context
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.MysteryTranslations

/** Configuration options specific to the Rosary. Lives inside a [Prayer] when kind == Rosary. */
data class RosaryOptions(
    var mysterySelectionMode: MysterySelectionMode = MysterySelectionMode.TodaysMysteries,
    /** Used when [mysterySelectionMode] is [MysterySelectionMode.Specific] or [MysterySelectionMode.SingleMystery]. */
    var specificMysteryGroup: MysteryGroup = MysteryGroup.Joyful,
    /** 1-based index into `MysteryCatalog.forGroup(specificMysteryGroup)`. Used only when
     * [mysterySelectionMode] is [MysterySelectionMode.SingleMystery]. */
    var specificMysteryOrder: Int = 1,
    var specificMysteryCount: Int = 1,
    var useTraditionalMysteries: Boolean = false,
    /** Retired saved-data field. The engine always includes all five decades. */
    var skipFifthDecade: Boolean = false,
    var includeApostlesCreed: Boolean = true,
    /** The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be. */
    var includeOpeningPrayers: Boolean = true,
    /** An optional Fatima Prayer after the opening Glory Be, following the three opening Hail
     * Marys for faith, hope, and charity. Independent of the Fatima Prayer after each decade. */
    var includeOpeningFatimaPrayer: Boolean = false,
    /** The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade. */
    var includeFatimaPrayer: Boolean = true,
    var eternalRestForDeceased: EternalRestPlacement = EternalRestPlacement.None,
    var marianAntiphon: MarianAntiphonOption = MarianAntiphonOption.Seasonal,
    /** Three closing intentions (for the Pope, the local bishop, and the faithful departed),
     * each an Our Father + Hail Mary + Glory Be, closed by the "Requiescant in pace" versicle. */
    var includeClosingIntentions: Boolean = false,
    /** Retained for saved prayers from the separate-controls version; null inherits the legacy
     * all-intentions choice, and any enabled group now enables the complete closing sequence. */
    var includeClosingPopeIntention: Boolean? = null,
    var includeClosingBishopIntention: Boolean? = null,
    var includeClosingDepartedIntention: Boolean? = null,
    var includeStMichaelPrayer: Boolean = false,
    var includeLitanyOfLoreto: Boolean = false,
    var includeRosaryCollect: Boolean = true,
    var includeFinalSignOfCross: Boolean = true,
    /** Per-Rosary Aramaic form, ignored when Aramaic is the app-wide default language. */
    var aramaicSignOfCrossForm: String = AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A,
    /** Collapses each decade's 10 Hail Marys and Glory Be onto one combined screen — for someone
     * leading a group aloud from memory who doesn't need to tap through 10 visually-identical
     * screens. See `PrayerEngine.buildRosarySteps`. */
    var presenterMode: Boolean = false,
    /** Which artwork set illustrates the mysteries during a session — see [MysteryImageStyle]. */
    var mysteryImageStyle: MysteryImageStyle = MysteryImageStyle.Classic,
) {
    val selectedMysteryStart: Int get() = specificMysteryOrder.coerceIn(1, 5)
    val selectedMysteryCount: Int get() = specificMysteryCount.coerceIn(1, 6 - selectedMysteryStart)
    val selectedMysteryIndices: IntRange get() = (selectedMysteryStart - 1) until
        (selectedMysteryStart - 1 + selectedMysteryCount)
    fun navigationOptions(group: String?, order: Int?): RosaryOptions? {
        if (group == null) return if (order == null) this else null
        val selectedGroup = MysteryGroup.entries.firstOrNull { it.name.lowercase() == group } ?: return null
        if (order == null) return copy(mysterySelectionMode = MysterySelectionMode.Specific, specificMysteryGroup = selectedGroup)
        return if (mysterySelectionMode == MysterySelectionMode.ChooseOnLaunch || mysterySelectionMode == MysterySelectionMode.SingleMystery) {
            if (order == null || order !in 1..5) null else copy(mysterySelectionMode = MysterySelectionMode.SingleMystery,
                specificMysteryGroup = selectedGroup, specificMysteryOrder = order)
        } else {
            null
        }
    }
    companion object {
        val legacyClosingIntentionKeys: Set<String> = setOf(
            "closingPopeIntention", "closingBishopIntention", "closingDepartedIntention",
        )

        /** Generic saved Rosaries used string options for the temporary separate controls.
         * Resolve them before obsolete keys are filtered, then remove them so an explicit
         * combined choice in the editor can turn the complete group off. Other packs retain
         * their own option names and semantics. */
        fun normalizedCustomOptions(bundleId: String, options: Map<String, String>): Map<String, String> {
            if (bundleId != "rosary") return options
            val current = options - "skipFifthDecade"
            if (legacyClosingIntentionKeys.none { it in current }) return current
            val combined = current["closingIntentions"]?.toBooleanStrictOrNull() ?: false
            val enabled = legacyClosingIntentionKeys.any { key ->
                current[key]?.toBooleanStrictOrNull() ?: combined
            }
            return (current - legacyClosingIntentionKeys) + ("closingIntentions" to enabled.toString())
        }
    }

    val effectiveRosaryCollect: Boolean get() = includeLitanyOfLoreto || includeRosaryCollect

    val effectiveClosingIntentions: Boolean
        get() = (includeClosingPopeIntention ?: includeClosingIntentions) ||
            (includeClosingBishopIntention ?: includeClosingIntentions) ||
            (includeClosingDepartedIntention ?: includeClosingIntentions)

    /** Compatibility aliases for older callers and bundle options; the sequence is one group. */
    val effectiveClosingPopeIntention: Boolean get() = effectiveClosingIntentions
    val effectiveClosingBishopIntention: Boolean get() = effectiveClosingIntentions
    val effectiveClosingDepartedIntention: Boolean get() = effectiveClosingIntentions

    /** An explicit combined choice replaces older overrides, including when switching off. */
    fun withClosingIntentions(enabled: Boolean): RosaryOptions = copy(
        includeClosingIntentions = enabled,
        includeClosingPopeIntention = null,
        includeClosingBishopIntention = null,
        includeClosingDepartedIntention = null,
    )

    fun mysterySelectionSummary(context: Context): String = when (mysterySelectionMode) {
        MysterySelectionMode.Specific ->
            context.getString(R.string.summary_always, context.getString(specificMysteryGroup.displayNameRes))
        MysterySelectionMode.SingleMystery -> {
            val chosen = MysteryCatalog.forGroup(specificMysteryGroup).firstOrNull { it.order == specificMysteryOrder }
            val title = chosen?.let { MysteryTranslations.get(languageCode = LanguageCatalog.uiLanguageCode(), imageKey = it.imageKey).title }
                ?: context.getString(specificMysteryGroup.displayNameRes)
            if (selectedMysteryCount > 1) context.getString(R.string.summary_selected_mysteries, selectedMysteryCount, title)
            else context.getString(R.string.summary_only, title)
        }
        MysterySelectionMode.FifteenMystery -> context.getString(R.string.summary_fifteen)
        MysterySelectionMode.TwentyMystery -> context.getString(R.string.summary_twenty)
        MysterySelectionMode.TodaysMysteries -> context.getString(
            if (useTraditionalMysteries) R.string.summary_traditional_today else R.string.mode_todays_mysteries,
        )
        MysterySelectionMode.ChooseOnLaunch -> context.getString(R.string.mode_choose_on_launch)
    }
}
