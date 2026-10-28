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

    fun spreadStart(pages: List<IntRange>, anchorIndex: Int, leaves: Int = 2): Int {
        val page = pages.indexOfFirst { anchorIndex in it }.coerceAtLeast(0)
        return page / leaves.coerceAtLeast(1) * leaves.coerceAtLeast(1)
    }

    fun groups(range: IntRange, flowing: List<Boolean>): List<IntRange> {
        if (range.isEmpty()) return emptyList()
        val result = mutableListOf<IntRange>()
        var first = range.first
        for (index in range.drop(1)) {
            if (flowing.getOrNull(index) != true || flowing.getOrNull(index - 1) != true) {
                result += first until index
                first = index
            }
        }
        result += first..range.last
        return result
    }

    fun flowPages(count: Int, availableHeight: Int, measure: (IntRange) -> Int): List<IntRange> {
        if (count == 0) return emptyList()
        val result = mutableListOf<IntRange>()
        var first = 0
        for (last in 0 until count) {
            if (last > first && measure(first..last) > availableHeight.coerceAtLeast(1)) {
                result += first until last
                first = last
            }
        }
        result += first until count
        return result
    }

    /** A drag toward Scripture's inline start exposes later text, regardless of UI language. */
    fun forwardDrag(horizontalDistance: Float, rightToLeft: Boolean): Boolean =
        if (rightToLeft) horizontalDistance > 0 else horizontalDistance < 0
}
