package com.dkaluta.prosary.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS's DivineMercyEngineTests.swift. */
class DivineMercyEngineTest {
    private val engine = MockDivineMercyEngine()

    @Test
    fun fiveDecadesOfTenPetitions() {
        val steps = engine.buildSteps("en")
        val decadeIndices = steps.mapNotNull { it.decadeIndex }.toSet()
        assertEquals((0 until 5).toSet(), decadeIndices)

        for (d in 0 until 5) {
            val petitionsInDecade = steps.filter { it.decadeIndex == d && it.hailMaryIndexInDecade != null }
            assertEquals("decade $d should have 10 petitions", 10, petitionsInDecade.size)
        }
    }

    @Test
    fun noStepHasAMystery() {
        val steps = engine.buildSteps("en")
        assertTrue(steps.all { it.mystery == null })
    }

    @Test
    fun everyStepReusesTheSingleDivineMercyImage() {
        // Unlike the Rosary/Franciscan Crown/Seven Sorrows, every step — opening, decades, and
        // closing alike — reuses the one divine_mercy_image illustration (the same reuse
        // pattern the Angelus uses for joyful_01_annunciation), since there's no per-decade
        // content to illustrate separately.
        val steps = engine.buildSteps("en")
        assertTrue(steps.all { it.imageKey == "divine_mercy_image" })
    }

    @Test
    fun offeringIsRepeatedIdenticallyAcrossEveryDecade() {
        val steps = engine.buildSteps("en")
        val offerings = steps.filter { it.decadeIndex != null && it.hailMaryIndexInDecade == null }
        assertEquals(5, offerings.size)
        assertTrue(offerings.all { it.body.contains("Eternal Father, I offer You") })
    }

    @Test
    fun openingReusesExistingPrayersNotNewContent() {
        val steps = engine.buildSteps("en")
        assertEquals("Sign of the Cross", steps[0].title)
        assertEquals("Our Father", steps[1].title)
        assertEquals("Hail Mary", steps[2].title)
        assertEquals("The Apostles' Creed", steps[3].title)
    }

    @Test
    fun closingAcclamationRepeatedThreeTimesThenClosingCross() {
        val steps = engine.buildSteps("en")
        val closingAcclamations = steps.filter { it.decadeIndex == null && it.body.contains("Holy God") }
        assertEquals(3, closingAcclamations.size)
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun englishBodyContainsEnglishText() {
        val steps = engine.buildSteps("en")
        assertTrue(steps.any { it.body.contains("For the sake of His sorrowful Passion") })
    }

    @Test
    fun latinBodyContainsLatinText() {
        val steps = engine.buildSteps("la")
        assertTrue(steps.any { it.body.contains("Pro dolorosa Eius passione") })
    }
}
