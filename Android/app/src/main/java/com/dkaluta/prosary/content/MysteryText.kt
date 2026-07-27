package com.dkaluta.prosary.content

import kotlinx.serialization.Serializable

/** The localized display text for one mystery, in a single language. */
@Serializable
data class MysteryText(
    val title: String,
    val fruit: String,
    val description: String,
)
