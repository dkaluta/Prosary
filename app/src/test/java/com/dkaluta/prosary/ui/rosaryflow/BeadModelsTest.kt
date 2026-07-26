package com.dkaluta.prosary.ui.rosaryflow

import com.dkaluta.prosary.engine.MockRosaryEngine
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.models.RosaryStep
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS's BeadModelsTests.swift. */
class BeadModelsTest {
    /** Synthesizes a decade-based session with no Mystery at all — the shape every one of
     * Franciscan Crown/Seven Sorrows/Divine Mercy Chaplet's steps has (unlike the Rosary, which
     * always sets `mystery`). Before the bead-track generalization, BeadLayout.build silently
     * produced zero groupColumns for a session like this instead of one ungrouped column. */
    private fun mysteryLessDecadeSteps(decadeCount: Int): List<RosaryStep> {
        val steps = mutableListOf(RosaryStep(title = "Opening", body = ""))
        for (d in 0 until decadeCount) {
            steps.add(RosaryStep(title = "Our Father", body = "", decadeIndex = d))
            for (h in 1..10) {
                steps.add(RosaryStep(title = "Hail Mary", body = "", decadeIndex = d, hailMaryIndexInDecade = h))
            }
        }
        return steps
    }

    @Test
    fun mysteryLessDecadeStepsProduceOneUngroupedColumn() {
        val steps = mysteryLessDecadeSteps(3)
        val layout = BeadLayout.build(steps, currentIndex = steps.size / 2, hasClosingCross = false)

        assertEquals(1, layout.groupColumns.size)
        assertNull(layout.groupColumns[0].group)
        assertEquals(3, layout.groupColumns[0].beads.size)
    }

    @Test
    fun mysteryLessDecadeStepsKeepDecadesInOrder() {
        val steps = mysteryLessDecadeSteps(3)
        val currentIndex = steps.indexOfFirst { it.decadeIndex == 1 && it.hailMaryIndexInDecade == 5 }
        val layout = BeadLayout.build(steps, currentIndex = currentIndex, hasClosingCross = false)

        val beads = layout.groupColumns[0].beads
        assertEquals(3, beads.size)
        assertEquals(BeadState.Completed, beads[0].state)
        assertEquals(BeadState.Current, beads[1].state)
        assertEquals(BeadState.Upcoming, beads[2].state)
    }

    @Test
    fun mysteryLessDecadeStepsStillPopulateBottomBeads() {
        val steps = mysteryLessDecadeSteps(1)
        val currentIndex = steps.indexOfFirst { it.hailMaryIndexInDecade == 4 }
        val layout = BeadLayout.build(steps, currentIndex = currentIndex, hasClosingCross = false)

        assertTrue(layout.showBottomBeads)
        assertEquals(10, layout.bottomBeads.size)
        assertEquals(BeadState.Current, layout.bottomBeads[3].state)
    }

    /** Sanity check that the existing Rosary-shaped (mystery-grouped) behavior is unaffected by
     * the generalization — still one column per distinct MysteryGroup in session order. */
    @Test
    fun mysteryGroupedStepsStillGroupByMysteryGroup() {
        val steps = MockRosaryEngine().buildSteps(Prayer(rosary = RosaryOptions(mysterySelectionMode = MysterySelectionMode.TwentyMystery)))
        val layout = BeadLayout.build(steps, currentIndex = steps.size / 2, hasClosingCross = true)

        assertEquals(4, layout.groupColumns.size)
        assertEquals(
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious),
            layout.groupColumns.map { it.group },
        )
    }
}
