package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import com.dkaluta.prosary.R

/** Which artwork set illustrates the Rosary's mysteries during a session. The classical
 * paintings are the default; the eastern set is the same 20 mysteries in an
 * Eastern/illuminated-manuscript style (the "eastern_"-prefixed image keys). Windows persists
 * its twin enum as a raw integer ordinal, so new cases must only ever be appended. */
enum class MysteryImageStyle {
    Classic,
    Eastern;

    @get:StringRes
    val displayNameRes: Int
        get() = when (this) {
            Classic -> R.string.image_style_classic
            Eastern -> R.string.image_style_eastern
        }
}
