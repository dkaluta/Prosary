package com.dkaluta.prosary.ui.home

internal data class HomeCardColumnPlacement(
    val index: Int, val column: Int, val x: Int, val y: Int, val width: Int, val height: Int,
)

internal data class HomeCardColumnArrangement(val placements: List<HomeCardColumnPlacement>, val height: Int)

/** Saved order runs across columns; each column then advances only by its own card heights. */
internal object HomeCardColumnsGeometry {
    fun columnWidths(width: Int, minimumWidth: Int, gap: Int, maximumColumns: Int = 3): List<Int> {
        require(width >= 0 && minimumWidth > 0 && gap >= 0 && maximumColumns > 0)
        val count = ((width + gap) / (minimumWidth + gap)).coerceIn(1, maximumColumns)
        val available = (width - gap * (count - 1)).coerceAtLeast(0)
        return List(count) { column -> available / count + if (column < available % count) 1 else 0 }
    }

    fun arrange(widths: List<Int>, gap: Int, heights: List<Int>): HomeCardColumnArrangement {
        require(widths.isNotEmpty() && widths.all { it >= 0 } && gap >= 0 && heights.all { it >= 0 })
        val nextY = IntArray(widths.size)
        val positionsX = widths.runningFold(0) { position, width -> position + width + gap }
        val placements = heights.mapIndexed { index, height ->
            val column = index % widths.size
            HomeCardColumnPlacement(index, column, positionsX[column], nextY[column], widths[column], height)
                .also { nextY[column] += height + gap }
        }
        return HomeCardColumnArrangement(placements, placements.maxOfOrNull { it.y + it.height } ?: 0)
    }
}
