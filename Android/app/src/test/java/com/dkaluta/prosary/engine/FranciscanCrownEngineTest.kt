package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

private class FixedFranciscanCrownCalendar(private val antiphon: MarianAntiphonOption) : LiturgicalCalendarProviding {
    override fun mysteryGroup(date: Date): MysteryGroup = MysteryGroup.Joyful
    override fun seasonColor(date: Date): Color = Color.Transparent
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = antiphon
    override fun isEasterSeason(date: Date): Boolean = false
}

/** Mirrors iOS's FranciscanCrownEngineTests.swift. */
class FranciscanCrownEngineTest {
    private fun engine(antiphon: MarianAntiphonOption = MarianAntiphonOption.SalveRegina) =
        PrayerEngine(calendar = FixedFranciscanCrownCalendar(antiphon))

    @Test
    fun sevenDecadesOfTenHailMarys() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        val decadeIndices = steps.mapNotNull { it.decadeIndex }.toSet()
        assertEquals((0 until 7).toSet(), decadeIndices)

        for (d in 0 until 7) {
            val hailMarysInDecade = steps.filter { it.decadeIndex == d && it.hailMaryIndexInDecade != null }
            assertEquals("decade $d should have 10 Hail Marys", 10, hailMarysInDecade.size)
        }
    }

    @Test
    fun noStepHasAMystery() {
        // Franciscan Crown steps deliberately leave `mystery` null (see BeadModels'
        // generalization) — the Seven Joys aren't Rosary "mysteries" even though 6 of the 7
        // reuse mystery imageKeys.
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        assertTrue(steps.all { it.mystery == null })
    }

    @Test
    fun twoClosingHailMarysAndOneClosingOurFather() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        val nonDecadeHailMarys = steps.filter { it.decadeIndex == null && it.title.startsWith("Hail Mary") }
        assertEquals(2, nonDecadeHailMarys.size)

        val nonDecadeOurFathers = steps.filter { it.decadeIndex == null && it.title == "Our Father" }
        assertEquals(1, nonDecadeOurFathers.size)
    }

    @Test
    fun endsWithSeasonalAntiphonThenClosingCross() {
        val steps = engine(MarianAntiphonOption.ReginaCaeli).buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        assertEquals("Regina Caeli", steps[steps.size - 2].title)
        assertTrue(steps[steps.size - 2].isAntiphon)
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun firstJoyIsAnnunciationReusingExistingMysteryContent() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        val firstJoy = steps.first { it.decadeIndex == 0 && it.isScripture }
        assertEquals("The Annunciation", firstJoy.title)
        assertEquals("joyful_01_annunciation", firstJoy.imageKey)
    }

    @Test
    fun fourthJoyIsTheNewAdorationOfTheMagiContent() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        val fourthJoy = steps.first { it.decadeIndex == 3 && it.isScripture }
        assertEquals("The Adoration of the Magi", fourthJoy.title)
        assertEquals("franciscan_04_adoration_of_the_magi", fourthJoy.imageKey)
    }

    @Test
    fun englishBodyContainsEnglishText() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "en"))
        assertTrue(steps.any { it.body.contains("Hail Mary, full of grace") })
    }

    @Test
    fun latinBodyContainsLatinText() {
        val steps = engine().buildSteps(Prayer(kind = PrayerKind.FranciscanCrown, languageCode = "la"))
        assertTrue(steps.any { it.body.contains("Ave Maria, gratia plena") })
    }
}
