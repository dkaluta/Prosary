package com.dkaluta.Prosary.models

import java.util.UUID

/** A saved, user-configurable Rosary preset. Persisted via a PresetStore implementation. */
data class RosaryConfig(
    val id: String = UUID.randomUUID().toString(),
    var name: String = "My Rosary",
    /** The one preset used when the user just taps "Pray" without picking one explicitly. */
    var isDefault: Boolean = false,
    var mysterySelectionMode: MysterySelectionMode = MysterySelectionMode.TodaysMysteries,
    /** Used only when [mysterySelectionMode] is [MysterySelectionMode.Specific]. */
    var specificMysteryGroup: MysteryGroup = MysteryGroup.Joyful,
    var includeApostlesCreed: Boolean = true,
    /** The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be. */
    var includeOpeningPrayers: Boolean = true,
    /** The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade. */
    var includeFatimaPrayer: Boolean = true,
    var eternalRestForDeceased: EternalRestPlacement = EternalRestPlacement.None,
    var marianAntiphon: MarianAntiphonOption = MarianAntiphonOption.Seasonal,
    var includeStMichaelPrayer: Boolean = false,
    var includeFinalSignOfCross: Boolean = true,
    /** Prayer language for this preset. See [LanguageCatalog]. */
    var languageCode: String = LanguageCatalog.defaultCode,
) {
    val isNotDefault: Boolean get() = !isDefault

    val languageNativeName: String get() = LanguageCatalog.resolve(languageCode).nativeName

    val mysterySelectionSummary: String
        get() = when (mysterySelectionMode) {
            MysterySelectionMode.Specific -> "Always ${specificMysteryGroup.displayName}"
            MysterySelectionMode.FifteenMystery -> "The 15 Mysteries"
            MysterySelectionMode.TwentyMystery -> "The 20 Mysteries"
            MysterySelectionMode.TodaysMysteries -> "Today's Mysteries"
        }
}
