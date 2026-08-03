package com.dkaluta.prosary.models

import android.content.Context
import com.dkaluta.prosary.R

/** Configuration options specific to the Jesus Prayer. Lives inside a [Prayer] when kind == JesusPrayer. */
data class JesusPrayerOptions(
    var target: JesusPrayerTarget = JesusPrayerTarget.Count(33),
) {
    fun targetDisplayName(context: Context): String = when (val t = target) {
        is JesusPrayerTarget.Count -> context.getString(R.string.jp_count_times, t.value)
        JesusPrayerTarget.Unbounded -> context.getString(R.string.jp_unbounded)
    }
}
