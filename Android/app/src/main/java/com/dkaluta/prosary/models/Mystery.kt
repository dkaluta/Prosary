package com.dkaluta.prosary.models

/** One of the twenty mysteries of the Rosary. Carries no display text of its own — title,
 * fruit, and description are looked up by [imageKey] from the content/localization layer in
 * the currently chosen prayer language. */
data class Mystery(
    val group: MysteryGroup,
    val order: Int,
    /** File stem (no extension) for the illustration drawable, and the lookup key
     * into the content layer's mystery translations. */
    val imageKey: String,
) {
    val id: String get() = imageKey
}
