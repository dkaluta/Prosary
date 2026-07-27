package com.dkaluta.prosary.models

/** One of the fourteen Stations of the Cross. Carries no display text of its own — title and
 * meditation are looked up by [imageKey] from the content/localization layer in the currently
 * chosen prayer language. Structurally the Stations equivalent of [Mystery], but with no
 * [MysteryGroup] — there's only one fixed sequence, no user-chosen variant. */
data class Station(
    val order: Int,
    /** File stem (no extension) for the illustration drawable, and the lookup key
     * into the content layer's station translations. */
    val imageKey: String,
) {
    val id: String get() = imageKey
}
