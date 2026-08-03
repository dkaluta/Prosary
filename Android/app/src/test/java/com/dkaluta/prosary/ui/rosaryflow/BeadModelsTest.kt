package com.dkaluta.prosary.ui.rosaryflow

import com.dkaluta.prosary.engine.PrayerEngine
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
        val steps = PrayerEngine().buildSteps(Prayer(rosary = RosaryOptions(mysterySelectionMode = MysterySelectionMode.TwentyMystery)))
        val layout = BeadLayout.build(steps, currentIndex = steps.size / 2, hasClosingCross = true)

        assertEquals(4, layout.groupColumns.size)
        assertEquals(
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious),
            layout.groupColumns.map { it.group },
        )
    }

    /** Presenter mode collapses each decade's 10 Hail Marys + Glory Be into one step carrying
     * hailMaryIndexInDecade = 10 specifically so the bead track still shows the traditional
     * 10-bead-per-decade look (beads 1-9 completed, bead 10 current) instead of collapsing to a
     * single bead — see PrayerEngine.buildRosarySteps' presenter-mode branch. This is the crux of
     * that design decision, even though BeadLayout itself needed no code changes to support it. */
    @Test
    fun presenterModeStepStillShowsTenTraditionalBottomBeads() {
        val steps = PrayerEngine().buildSteps(Prayer(rosary = RosaryOptions(presenterMode = true), languageCode = "en"))
        val currentIndex = steps.indexOfFirst { it.title == "Hail Mary & Glory Be" && it.decadeIndex == 0 }
        val layout = BeadLayout.build(steps, currentIndex = currentIndex, hasClosingCross = true)

        assertTrue(layout.showBottomBeads)
        assertEquals(10, layout.bottomBeads.size)
        for (i in 0 until 9) {
            assertEquals(BeadState.Completed, layout.bottomBeads[i].state)
        }
        assertEquals(BeadState.Current, layout.bottomBeads[9].state)
    }

    /** The narrow layout wraps major beads per mystery group — an ungrouped 7-decade session
     * (Franciscan Crown, Seven Sorrows) must keep every major bead on ONE row (cross + 7
     * decades), never an arbitrary 5+2 split. */
    @Test
    fun mysteryLessSevenDecadeSessionKeepsMajorBeadsOnOneRow() {
        val steps = mysteryLessDecadeSteps(7)
        val layout = BeadLayout.build(steps, currentIndex = 0, hasClosingCross = false)

        assertEquals(1, layout.topRows.size)
        assertEquals(8, layout.topRows[0].size) // opening cross + 7 decade beads
        assertEquals(7, layout.topRows[0].count { it.kind == BeadKind.Decade })
    }

    /** A multi-group Rosary still wraps one row per mystery group (the rows-of-5 the physical
     * rosary loops suggest), with the antiphon/closing cross on the last row. */
    @Test
    fun twentyMysterySessionWrapsOneRowPerGroup() {
        val engine = PrayerEngine()
        val steps = engine.buildSteps(
            Prayer(rosary = RosaryOptions(mysterySelectionMode = MysterySelectionMode.TwentyMystery)),
        )
        val layout = BeadLayout.build(steps, currentIndex = 0, hasClosingCross = true)

        assertEquals(4, layout.topRows.size)
        assertEquals(5, layout.topRows[0].count { it.kind == BeadKind.Decade })
        assertEquals(5, layout.topRows[3].count { it.kind == BeadKind.Decade })
        assertEquals(BeadKind.Cross, layout.topRows[0].first().kind)
        assertEquals(BeadKind.Cross, layout.topRows[3].last().kind)
    }
}
