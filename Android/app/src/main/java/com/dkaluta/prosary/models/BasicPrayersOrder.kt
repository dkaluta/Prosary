package com.dkaluta.prosary.models

import android.content.Context

/** The user's personal ordering of the basic-prayers list (Erez, 2026-08-08) — the [HomeOrder]
 * pattern on a fixed catalog: a persisted list of prayer ids, catalog order for ids it does
 * not name (so a prayer added in an update appears after the ordered ones), an empty list
 * meaning pure catalog order. Mirrors iOS's BasicPrayersOrder. */
object BasicPrayersOrder {
    private const val PREFS = "basic_prayers_order"
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

    /** Stable: unknown ids keep their relative (catalog) order after the ordered ones. */
    fun apply(context: Context, prayers: List<BasicPrayer>): List<BasicPrayer> {
        val order = saved(context)
        if (order.isEmpty()) return prayers
        return prayers.withIndex().sortedWith(
            compareBy({ order.indexOf(it.value.id).let { i -> if (i < 0) Int.MAX_VALUE else i } }, { it.index }),
        ).map { it.value }
    }
}
