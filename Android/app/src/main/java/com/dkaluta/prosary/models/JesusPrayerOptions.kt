package com.dkaluta.prosary.models

/** Configuration options specific to the Jesus Prayer. Lives inside a [Prayer] when kind == JesusPrayer. */
data class JesusPrayerOptions(
    var target: JesusPrayerTarget = JesusPrayerTarget.Count(33),
) {
    val targetDisplayName: String
        get() = when (val t = target) {
            is JesusPrayerTarget.Count -> "${t.value}×"
            JesusPrayerTarget.Unbounded -> "Unbounded"
        }
}
