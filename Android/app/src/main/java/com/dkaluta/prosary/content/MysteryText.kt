package com.dkaluta.prosary.content

import kotlinx.serialization.Serializable

/** The localized display text for one mystery, in a single language. */
@Serializable
data class MysteryText(
    val title: String,
    val fruit: String,
    val description: String,
    /** The same sourced Scripture in another script when a rite supplies one. It belongs to
     * [description], not to the mystery as a whole, so fallback resolution never borrows it
     * independently from a different language/source. */
    val transliteratedDescription: String? = null,
)
