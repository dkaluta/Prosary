package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import com.dkaluta.prosary.R

/** Where (if at all) "Eternal rest grant unto them, O Lord" is prayed for the faithful departed. */
enum class EternalRestPlacement {
    None,

    /** Pray it after the Glory Be of every decade. */
    AfterEachDecade,

    /** Pray it once, near the end, before the closing prayers. */
    AtEndOnly;

    @get:StringRes
    val displayNameRes: Int
        get() = when (this) {
            None -> R.string.eternal_rest_none
            AfterEachDecade -> R.string.eternal_rest_each_decade
            AtEndOnly -> R.string.eternal_rest_at_end
        }
}
