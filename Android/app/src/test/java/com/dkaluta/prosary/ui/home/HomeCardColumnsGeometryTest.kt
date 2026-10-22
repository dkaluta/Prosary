package com.dkaluta.prosary.ui.home

import org.junit.Assert.*
import org.junit.Test

class HomeCardColumnsGeometryTest {
    @Test fun columnCountRespectsReadableWidthAndThreeColumnLimit() {
        assertEquals(listOf(320), HomeCardColumnsGeometry.columnWidths(320, 340, 12))
        assertEquals(listOf(340, 340), HomeCardColumnsGeometry.columnWidths(692, 340, 12))
        assertEquals(listOf(340, 340, 340), HomeCardColumnsGeometry.columnWidths(1044, 340, 12))
        assertEquals(3, HomeCardColumnsGeometry.columnWidths(2000, 340, 12).size)
    }

    @Test fun tallCardDoesNotPushDownFollowersInTheAdjacentColumn() {
        val widths = HomeCardColumnsGeometry.columnWidths(720, 340, 12)
        val result = HomeCardColumnsGeometry.arrange(widths, 12, listOf(240, 60, 80, 90, 50))
        assertEquals(listOf(0, 1, 1, 1, 0), result.placements.map { it.column })
        assertEquals(listOf(0, 0, 72, 164, 252), result.placements.map { it.y })
        assertEquals(listOf(0, 366, 366, 366, 0), result.placements.map { it.x })
        assertEquals(302, result.height)
    }

    @Test fun threeColumnsFillTheShortestColumnInSavedOrder() {
        val widths = HomeCardColumnsGeometry.columnWidths(1044, 340, 12)
        val result = HomeCardColumnsGeometry.arrange(widths, 12, listOf(100, 50, 70, 90, 10, 5, 20))
        assertEquals((0..6).toList(), result.placements.map { it.index })
        assertEquals(listOf(0, 1, 2, 1, 2, 2, 0), result.placements.map { it.column })
        assertEquals(listOf(0, 0, 0, 62, 82, 104, 112), result.placements.map { it.y })
    }

    @Test fun reflowRetainsSourceOrderAndUsesNaturalSingleColumnHeights() {
        val heights = listOf(100, 40, 80, 30)
        val narrow = HomeCardColumnsGeometry.arrange(HomeCardColumnsGeometry.columnWidths(320, 340, 12), 12, heights)
        val wide = HomeCardColumnsGeometry.arrange(HomeCardColumnsGeometry.columnWidths(720, 340, 12), 12, heights)
        assertEquals(wide.placements.map { it.index }, narrow.placements.map { it.index })
        assertEquals(listOf(0, 112, 164, 256), narrow.placements.map { it.y })
        assertEquals(286, narrow.height)
    }

    @Test fun roundingKeepsColumnWidthsBalancedAndFitsTheAvailableWidth() {
        val widths = HomeCardColumnsGeometry.columnWidths(701, 340, 12)
        assertEquals(listOf(345, 344), widths)
        assertEquals(701, widths.sum() + 12 * (widths.size - 1))
    }

    @Test fun emptyLayoutHasNoHeightOrPlacements() {
        val result = HomeCardColumnsGeometry.arrange(listOf(340, 340), 12, emptyList())
        assertTrue(result.placements.isEmpty())
        assertEquals(0, result.height)
    }

    @Test fun addingACardKeepsEarlierPlacementsAndMinimizesTheNewHeight() {
        val before = HomeCardColumnsGeometry.arrange(listOf(340, 340), 12, listOf(400, 100, 80))
        val after = HomeCardColumnsGeometry.arrange(listOf(340, 340), 12, listOf(400, 100, 80, 90))
        assertEquals(before.placements, after.placements.take(3))
        assertEquals(400, after.height)
        assertEquals(204, after.placements.last().y)
    }
}
