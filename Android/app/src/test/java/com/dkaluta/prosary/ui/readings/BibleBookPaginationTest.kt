package com.dkaluta.prosary.ui.readings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class BibleBookPaginationTest {
    @Test fun paginationPreservesEveryPhysicalSourceRowAcrossSizes() {
        // These physical rows may be a heading, repeated witness, primary verse, hymn or
        // colophon. Their source order is authoritative even when verse numbers are not sorted.
        val heights = listOf(20, 110, 80, 900, 40, 60, 30)
        for (height in listOf(1, 140, 300, 1200)) {
            val pages = BibleBookPagination.pages(heights, height, 12)
            assertEquals(heights.indices.toList(), pages.flatMap { it.toList() })
            for (page in pages) {
                if (page.count() == 1) continue // A long unit remains whole and scrollable.
                assertTrue(page.sumOf { heights[it] } + (page.count() - 1) * 12 <= height)
            }
        }
    }

    @Test fun oversizedScriptureUnitGetsOneWholePageBetweenItsNeighbors() {
        assertEquals(listOf(0..1, 2..2, 3..4),
            BibleBookPagination.pages(listOf(20, 80, 900, 30, 40), 200, 12))
    }

    @Test fun anchorRemainsOnTheVisibleSpreadWhenFontOrViewportChanges() {
        for (height in listOf(130, 220, 500)) {
            val pages = BibleBookPagination.pages(List(21) { 60 }, height, 12)
            for (anchor in 0..20) {
                val first = BibleBookPagination.spreadStart(pages, anchor)
                assertTrue(anchor in pages[first] || anchor in pages.getOrElse(first + 1) { IntRange.EMPTY })
                assertEquals(0, first % 2)
            }
        }
    }

    @Test fun pageTurnDirectionFollowsScriptureInsteadOfInterfaceDirection() {
        assertTrue(BibleBookPagination.forwardDrag(-100f, rightToLeft = false))
        assertFalse(BibleBookPagination.forwardDrag(100f, rightToLeft = false))
        assertTrue(BibleBookPagination.forwardDrag(100f, rightToLeft = true))
        assertFalse(BibleBookPagination.forwardDrag(-100f, rightToLeft = true))
    }
}
