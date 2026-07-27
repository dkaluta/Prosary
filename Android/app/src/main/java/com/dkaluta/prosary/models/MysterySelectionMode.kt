package com.dkaluta.prosary.models

/** How a [RosaryOptions] decides which mystery group(s) to pray in a given session. */
enum class MysterySelectionMode {
    /** Follow the traditional weekday assignment (with liturgical-season overrides on Sundays). */
    TodaysMysteries,

    /** Always pray a specific, user-chosen set regardless of the day. */
    Specific,

    /** The traditional 15 mysteries: Joyful, Sorrowful, and Glorious (no Luminous), prayed in one session. */
    FifteenMystery,

    /** All 20 mysteries in one session, in the chronological order of Christ's life: Joyful, Luminous, Sorrowful, Glorious. */
    TwentyMystery,

    /** Pray exactly one specific mystery (one decade) — see [RosaryOptions.specificMysteryOrder].
     * Added last, not grouped with [Specific] above: Windows persists this enum by raw integer
     * ordinal (not name), so inserting a case earlier would silently reassign the stored values
     * of every case after it for existing saved favorites. Keep new cases appended here even
     * though iOS/Android's own storage (name-keyed) wouldn't require it. */
    SingleMystery;

    val displayName: String
        get() = when (this) {
            TodaysMysteries -> "Today's Mysteries"
            Specific -> "Always a Specific Set"
            FifteenMystery -> "The 15 Mysteries (Joyful, Sorrowful, Glorious)"
            TwentyMystery -> "The 20 Mysteries (All Four Sets)"
            SingleMystery -> "One Mystery Only"
        }
}
