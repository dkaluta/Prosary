package com.dkaluta.prosary.ui.home

import org.junit.Assert.*
import org.junit.Test

class HomeFoldGeometryTest {
    private val viewport = HomePaneBounds(0, 0, 1000, 800)
    private fun vertical(left: Int, right: Int = left, separating: Boolean = true, occluding: Boolean = false) =
        HomeFoldBoundary(HomePaneBounds(left, 0, right, 800), false, separating, occluding)
    private fun horizontal(top: Int, bottom: Int = top) =
        HomeFoldBoundary(HomePaneBounds(0, top, 1000, bottom), true, true, false)

    @Test fun noFeatureAndFlatNonseparatingFoldKeepTheWholeGrid() {
        assertEquals(viewport, HomeFoldGeometry.safePane(viewport, emptyList()))
        assertEquals(viewport, HomeFoldGeometry.safePane(viewport, listOf(vertical(500, separating = false))))
    }

    @Test fun zeroWidthBookFoldUsesThePhysicalRightPaneWhenEqual() {
        assertEquals(HomePaneBounds(500, 0, 1000, 800), HomeFoldGeometry.safePane(viewport, listOf(vertical(500))))
    }

    @Test fun occludingVerticalHingeChoosesLargestPaneAndExcludesTheGap() {
        val pane = HomeFoldGeometry.safePane(viewport, listOf(vertical(350, 380, separating = false, occluding = true)))
        assertEquals(HomePaneBounds(380, 0, 1000, 800), pane)
        assertTrue(pane.left >= 380)
    }

    @Test fun horizontalPartialFoldPrefersReachableLowerPaneAndExcludesOcclusion() {
        assertEquals(HomePaneBounds(0, 400, 1000, 800), HomeFoldGeometry.safePane(viewport, listOf(horizontal(400))))
        assertEquals(HomePaneBounds(0, 420, 1000, 800), HomeFoldGeometry.safePane(viewport, listOf(horizontal(380, 420))))
    }

    @Test fun offsetHomeViewportUsesWindowCoordinatesWithoutMirroringOrDoubleInsets() {
        val offset = HomePaneBounds(80, 100, 980, 750)
        assertEquals(HomePaneBounds(500, 100, 980, 750), HomeFoldGeometry.safePane(offset, listOf(vertical(480, 500))))
        assertEquals(HomePaneBounds(80, 430, 980, 750), HomeFoldGeometry.safePane(offset, listOf(horizontal(400, 430))))
    }

    @Test fun nonintersectingAndBoundaryOnlyFeaturesDoNotShrinkTheViewport() {
        for (fold in listOf(vertical(-40, 0), vertical(1000, 1010), horizontal(-20, 0), horizontal(800, 820),
            HomeFoldBoundary(HomePaneBounds(400, 900, 420, 1200), false, true, true))) {
            assertEquals(viewport, HomeFoldGeometry.safePane(viewport, listOf(fold)))
        }
    }

    @Test fun multipleBoundariesChooseTheLargestUnobstructedPaneRegardlessOfInputOrder() {
        val boundaries = listOf(vertical(400, 420), horizontal(300, 320))
        val expected = HomePaneBounds(420, 320, 1000, 800)
        assertEquals(expected, HomeFoldGeometry.safePane(viewport, boundaries))
        assertEquals(expected, HomeFoldGeometry.safePane(viewport, boundaries.reversed()))
    }

    @Test fun emptyAndFullyOccludedAreasRemainBounded() {
        val empty = HomePaneBounds(10, 20, 10, 20)
        assertEquals(empty, HomeFoldGeometry.safePane(empty, listOf(vertical(0, 1000))))
        assertEquals(HomePaneBounds(0, 0, 0, 0), HomeFoldGeometry.safePane(viewport, listOf(vertical(0, 1000, occluding = true))))
    }
}
