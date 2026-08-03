package com.dkaluta.prosary.models

import android.content.Context

/** The user's personal ordering of the Home cards (v0.7, Gamaliel item 2): a persisted list
 * of card ids. Cards absent from the list (newly installed devotions) keep their natural
 * directory order after the ordered ones; an empty list means pure directory order. Mirrors
 * iOS's HomeOrder. */
object HomeOrder {
    private const val PREFS = "home_order"
    private const val KEY = "order"

    fun saved(context: Context): List<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null)?.split('\n')?.filter { it.isNotEmpty() } ?: emptyList()

    fun save(context: Context, ids: List<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, ids.joinToString("\n")).apply()
    }

    fun reset(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(KEY).apply()
    }

    /** Stable: unknown ids keep their relative (directory) order after the ordered ones. */
    fun <T> apply(context: Context, cards: List<T>, id: (T) -> String): List<T> {
        val order = saved(context)
        if (order.isEmpty()) return cards
        return cards.withIndex().sortedWith(
            compareBy({ order.indexOf(id(it.value)).let { i -> if (i < 0) Int.MAX_VALUE else i } }, { it.index }),
        ).map { it.value }
    }

    /** "My most important prayer first" — the one-move path (card long-press menu). */
    fun moveToTop(context: Context, cardId: String, allIdsInDisplayOrder: List<String>) {
        save(context, listOf(cardId) + allIdsInDisplayOrder.filter { it != cardId })
    }
}
