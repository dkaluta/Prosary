package com.dkaluta.Prosary.models

/** One of the four traditional sets of Rosary mysteries. */
enum class MysteryGroup {
    Joyful,
    Sorrowful,
    Glorious,
    Luminous;

    /** Display name in English, used as a fallback when no localized name is supplied by the
     * content layer (e.g. in preset summaries before the real backend is wired up). */
    val displayName: String
        get() = when (this) {
            Joyful -> "Joyful"
            Sorrowful -> "Sorrowful"
            Glorious -> "Glorious"
            Luminous -> "Luminous"
        }
}
