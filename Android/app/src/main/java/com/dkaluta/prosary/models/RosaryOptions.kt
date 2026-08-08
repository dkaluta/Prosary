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
    var includeApostlesCreed: Boolean = true,
    /** The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be. */
    var includeOpeningPrayers: Boolean = true,
    /** The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade. */
    var includeFatimaPrayer: Boolean = true,
    var eternalRestForDeceased: EternalRestPlacement = EternalRestPlacement.None,
    var marianAntiphon: MarianAntiphonOption = MarianAntiphonOption.Seasonal,
    var includeStMichaelPrayer: Boolean = false,
    var includeFinalSignOfCross: Boolean = true,
    /** Collapses each decade's 10 Hail Marys and Glory Be onto one combined screen — for someone
     * leading a group aloud from memory who doesn't need to tap through 10 visually-identical
     * screens. See `PrayerEngine.buildRosarySteps`. */
    var presenterMode: Boolean = false,
) {
    fun mysterySelectionSummary(context: Context): String = when (mysterySelectionMode) {
        MysterySelectionMode.Specific ->
            context.getString(R.string.summary_always, context.getString(specificMysteryGroup.displayNameRes))
        MysterySelectionMode.SingleMystery -> {
            val chosen = MysteryCatalog.forGroup(specificMysteryGroup).firstOrNull { it.order == specificMysteryOrder }
            val title = chosen?.let { MysteryTranslations.get(languageCode = LanguageCatalog.uiLanguageCode(), imageKey = it.imageKey).title }
                ?: context.getString(specificMysteryGroup.displayNameRes)
            context.getString(R.string.summary_only, title)
        }
        MysterySelectionMode.FifteenMystery -> context.getString(R.string.summary_fifteen)
        MysterySelectionMode.TwentyMystery -> context.getString(R.string.summary_twenty)
        MysterySelectionMode.TodaysMysteries -> context.getString(R.string.mode_todays_mysteries)
    }
}
