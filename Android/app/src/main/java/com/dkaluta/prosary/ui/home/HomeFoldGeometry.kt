package com.dkaluta.prosary.ui.home

/** Physical window coordinates; these rectangles deliberately do not mirror with UI language. */
internal data class HomePaneBounds(val left: Int, val top: Int, val right: Int, val bottom: Int) {
    val width: Int get() = (right - left).coerceAtLeast(0)
    val height: Int get() = (bottom - top).coerceAtLeast(0)
    val area: Long get() = width.toLong() * height
}

internal data class HomeFoldBoundary(
    val bounds: HomePaneBounds,
    val horizontal: Boolean,
    val separating: Boolean,
    val occluding: Boolean,
)

internal object HomeFoldGeometry {
    /** Keep all controls in one unobstructed pane. Equal panes prefer the lower/right side. */
    fun safePane(viewport: HomePaneBounds, boundaries: List<HomeFoldBoundary>): HomePaneBounds {
        if (viewport.area == 0L) return viewport
        var candidates = listOf(viewport)
        for (boundary in boundaries) {
            if (!boundary.separating && !boundary.occluding) continue
            candidates = candidates.flatMap { pane ->
                val fold = boundary.bounds
                if (boundary.horizontal) {
                    if (fold.right <= pane.left || fold.left >= pane.right || fold.bottom <= pane.top || fold.top >= pane.bottom) {
                        listOf(pane)
                    } else listOf(
                        HomePaneBounds(pane.left, pane.top, pane.right, fold.top.coerceIn(pane.top, pane.bottom)),
                        HomePaneBounds(pane.left, fold.bottom.coerceIn(pane.top, pane.bottom), pane.right, pane.bottom),
                    )
                } else {
                    if (fold.bottom <= pane.top || fold.top >= pane.bottom || fold.right <= pane.left || fold.left >= pane.right) {
                        listOf(pane)
                    } else listOf(
                        HomePaneBounds(pane.left, pane.top, fold.left.coerceIn(pane.left, pane.right), pane.bottom),
                        HomePaneBounds(fold.right.coerceIn(pane.left, pane.right), pane.top, pane.right, pane.bottom),
                    )
                }
            }.filter { it.area > 0 }
            if (candidates.isEmpty()) return HomePaneBounds(viewport.left, viewport.top, viewport.left, viewport.top)
        }
        return candidates.maxWithOrNull(compareBy<HomePaneBounds> { it.area }.thenBy { it.top }.thenBy { it.left }) ?: viewport
    }
}
