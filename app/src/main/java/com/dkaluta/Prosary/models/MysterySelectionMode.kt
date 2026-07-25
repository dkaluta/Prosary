package com.dkaluta.Prosary.models

/** How a [RosaryOptions] decides which mystery group(s) to pray in a given session. */
enum class MysterySelectionMode {
    /** Follow the traditional weekday assignment (with liturgical-season overrides on Sundays). */
    TodaysMysteries,

    /** Always pray a specific, user-chosen set regardless of the day. */
    Specific,

    /** The traditional 15 mysteries: Joyful, Sorrowful, and Glorious (no Luminous), prayed in one session. */
    FifteenMystery,

    /** All 20 mysteries in one session, in the chronological order of Christ's life: Joyful, Luminous, Sorrowful, Glorious. */
    TwentyMystery;

    val displayName: String
        get() = when (this) {
            TodaysMysteries -> "Today's Mysteries"
            Specific -> "Always a Specific Set"
            FifteenMystery -> "The 15 Mysteries (Joyful, Sorrowful, Glorious)"
            TwentyMystery -> "The 20 Mysteries (All Four Sets)"
        }
}
