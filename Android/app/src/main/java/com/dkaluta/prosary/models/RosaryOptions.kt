package com.dkaluta.prosary.models

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
    val mysterySelectionSummary: String
        get() = when (mysterySelectionMode) {
            MysterySelectionMode.Specific -> "Always ${specificMysteryGroup.displayName}"
            MysterySelectionMode.SingleMystery -> {
                val chosen = MysteryCatalog.forGroup(specificMysteryGroup).firstOrNull { it.order == specificMysteryOrder }
                val title = chosen?.let { MysteryTranslations.get(languageCode = "en", imageKey = it.imageKey).title } ?: specificMysteryGroup.displayName
                "Only $title"
            }
            MysterySelectionMode.FifteenMystery -> "The 15 Mysteries"
            MysterySelectionMode.TwentyMystery -> "The 20 Mysteries"
            MysterySelectionMode.TodaysMysteries -> "Today's Mysteries"
        }
}
