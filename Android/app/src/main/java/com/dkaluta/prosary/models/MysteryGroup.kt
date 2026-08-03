package com.dkaluta.prosary.models

import androidx.annotation.StringRes
import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.R

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

    /** UI-language name for chrome like Home's "Today: …" line. [displayName] above stays
     * English on purpose: the engine uses it as a *prayer-language* content fallback. */
    @get:StringRes
    val displayNameRes: Int
        get() = when (this) {
            Joyful -> R.string.mystery_group_joyful
            Sorrowful -> R.string.mystery_group_sorrowful
            Glorious -> R.string.mystery_group_glorious
            Luminous -> R.string.mystery_group_luminous
        }

    /** Accent color for the Home screen's Rosary card — distinct per mystery group, not the
     * liturgical season color used inside the flow screen's top banner. */
    val color: Color
        get() = when (this) {
            Joyful -> Color(0xFF1565C0) // blue
            Sorrowful -> Color(0xFF6A1B9A) // purple
            Glorious -> Color(0xFFC62828) // red
            Luminous -> Color(0xFF2E7D32) // green
        }
}
