package com.dkaluta.prosary.models

import android.content.Context

/**
 * Which devotions are pinned to the Pray tab. Deliberately separate from [Prayer]: a Prayer is a
 * *saved configuration* (a preset), while this is only "show it on Pray", so unpinning a devotion
 * never destroys the presets underneath it. Devotion ids are the ones the rest of the app already
 * uses — "rosary", "jesusPrayer", or a bundle id. Port of iOS's FavoriteDevotions.swift (which
 * syncs the same list through iCloud; Android keeps it local).
 */
object FavoriteDevotions {
    private const val PREFS = "favorite_devotions"
    private const val KEY = "favoriteDevotionIds"

    /** Null until the user first pins or unpins something, which is what lets a fresh install
     * fall back to "whatever already has a preset" instead of an empty Pray tab. */
    private fun stored(context: Context): List<String>? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)?.split('\n')?.filter { it.isNotEmpty() }

    fun ids(context: Context, implied: List<String>): List<String> = stored(context) ?: implied

    fun contains(context: Context, devotionId: String, implied: List<String>): Boolean =
        devotionId in ids(context, implied)

    /** Pins or unpins, materialising the implied set on the first explicit choice so the other
     * devotions keep their current state rather than silently vanishing. */
    fun toggle(context: Context, devotionId: String, implied: List<String>) {
        val current = ids(context, implied).toMutableList()
        if (!current.remove(devotionId)) current.add(devotionId)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, current.joinToString("\n")).apply()
    }

    fun pin(context: Context, devotionId: String, implied: List<String>) {
        if (!contains(context, devotionId, implied)) toggle(context, devotionId, implied)
    }

    fun reset(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }
}
