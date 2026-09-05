package com.dkaluta.prosary.ui.shared

import android.content.Context
import com.dkaluta.prosary.R

/** Translate known category captions while keeping manifest tags stable for filtering. */
object CategoryLabels {
    private val resources = mapOf(
        "marian" to R.string.category_marian,
        "daily" to R.string.category_daily,
        "mercy" to R.string.category_mercy,
        "franciscan" to R.string.category_franciscan,
        "advent" to R.string.category_advent,
        "meditative" to R.string.category_meditative,
        "passion" to R.string.category_passion,
        "eastern" to R.string.category_eastern,
        "short" to R.string.category_short,
        "easter" to R.string.category_easter,
        "other" to R.string.category_other,
    )

    fun label(tag: String, context: Context): String = resources[tag]?.let(context::getString)
        ?: tag.replaceFirstChar { it.uppercaseChar() }
}
