package com.dkaluta.prosary.ui.readings

/** Page boundaries refer to physical source rows, never numeric verse order. A source unit
 * taller than the viewport gets its own scrollable page rather than being split or omitted. */
internal object BibleBookPagination {
    fun pages(heights: List<Int>, availableHeight: Int, spacing: Int): List<IntRange> {
        if (heights.isEmpty()) return emptyList()
        val result = mutableListOf<IntRange>()
        var first = 0
        var used = 0L
        heights.forEachIndexed { index, height ->
            val needed = height.coerceAtLeast(0).toLong() + if (index > first) spacing.coerceAtLeast(0) else 0
            if (index > first && used + needed > availableHeight.coerceAtLeast(1)) {
                result += first until index
                first = index
                used = height.coerceAtLeast(0).toLong()
            } else used += needed
        }
        result += first..heights.lastIndex
        return result
    }

    fun spreadStart(pages: List<IntRange>, anchorIndex: Int): Int {
        val page = pages.indexOfFirst { anchorIndex in it }.coerceAtLeast(0)
        return page / 2 * 2
    }

    /** A drag toward Scripture's inline start exposes later text, regardless of UI language. */
    fun forwardDrag(horizontalDistance: Float, rightToLeft: Boolean): Boolean =
        if (rightToLeft) horizontalDistance > 0 else horizontalDistance < 0
}
