package com.dkaluta.prosary.engine

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mirrors iOS's SevenSorrowsEngineTests.swift. */
class SevenSorrowsEngineTest {
    private val engine = PrayerEngine()

    @Test
    fun sevenDecadesOfSevenHailMarys() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        val decadeIndices = steps.mapNotNull { it.decadeIndex }.toSet()
        assertEquals((0 until 7).toSet(), decadeIndices)

        for (d in 0 until 7) {
            val hailMarysInDecade = steps.filter { it.decadeIndex == d && it.hailMaryIndexInDecade != null }
            assertEquals("decade $d should have 7 Hail Marys", 7, hailMarysInDecade.size)
        }
    }

    @Test
    fun noStepHasAMystery() {
        // Seven Sorrows steps deliberately leave `mystery` null (see BeadModels'
        // generalization) — the Seven Sorrows aren't Rosary "mysteries", and unlike Franciscan
        // Crown, none of the seven reuse an existing mystery imageKey either.
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        assertTrue(steps.all { it.mystery == null })
    }

    @Test
    fun threeClosingHailMarysForOurLadysTears() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        val nonDecadeHailMarys = steps.filter { it.decadeIndex == null && it.title.startsWith("Hail Mary") }
        assertEquals(3, nonDecadeHailMarys.size)
    }

    @Test
    fun endsWithClosingPrayerThenClosingCross() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        assertEquals("Our Lady of Sorrows", steps[steps.size - 2].title)
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun firstSorrowIsProphecyOfSimeon() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        val firstSorrow = steps.first { it.decadeIndex == 0 && it.hailMaryIndexInDecade == null && it.title != "Our Father" }
        assertEquals("The Prophecy of Simeon", firstSorrow.title)
        assertEquals("seven_sorrows_01_prophecy_of_simeon", firstSorrow.imageKey)
        assertTrue(firstSorrow.isScripture)
    }

    @Test
    fun fourthSorrowHasNoScriptureCitation() {
        // "Mary Meets Jesus on the Way of the Cross" isn't narrated in any Gospel — a
        // traditional devotional scene, not a quoted verse — so unlike the other six, it's not
        // isScripture.
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        val fourthSorrow = steps.first { it.decadeIndex == 3 && it.hailMaryIndexInDecade == null && it.title != "Our Father" }
        assertEquals("Mary Meets Jesus on the Way of the Cross", fourthSorrow.title)
        assertFalse(fourthSorrow.isScripture)
    }

    @Test
    fun englishBodyContainsEnglishText() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "en"))
        assertTrue(steps.any { it.body.contains("Hail Mary, full of grace") })
    }

    @Test
    fun latinBodyContainsLatinText() {
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.SevenSorrows, languageCode = "la"))
        assertTrue(steps.any { it.body.contains("Ave Maria, gratia plena") })
    }
}
