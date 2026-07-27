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

private class FixedStationsCalendar : LiturgicalCalendarProviding {
    override fun mysteryGroup(date: Date): MysteryGroup = MysteryGroup.Joyful
    override fun seasonColor(date: Date): Color = Color.Transparent
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = MarianAntiphonOption.SalveRegina
    override fun isEasterSeason(date: Date): Boolean = false
}

/** Mirrors iOS's StationsEngineTests.swift. */
class StationsEngineTest {
    private fun engine() = PrayerEngine(calendar = FixedStationsCalendar())

    private fun steps(languageCode: String = "en") =
        engine().buildSteps(Prayer(kind = PrayerKind.StationsOfTheCross, languageCode = languageCode))

    @Test
    fun openingPrayerThenFourteenStationsThenClosingPrayer() {
        val all = steps()
        assertEquals("Sign of the Cross", all.first().title)
        assertEquals("Opening Prayer", all[1].title)
        assertEquals("Closing Prayer", all.last().title)

        val stationSteps = all.drop(2).dropLast(1)
        assertEquals(14, stationSteps.size)
    }

    @Test
    fun stationsAreInOrderWithCorrectOrdinalSubtitles() {
        val stationSteps = steps().drop(2).dropLast(1)
        assertEquals("1st Station", stationSteps.first().subtitle)
        assertEquals("14th Station", stationSteps[13].subtitle)
    }

    @Test
    fun noStepHasABeadTrackShape() {
        // Stations has no decades/beads — the flow UI shows a plain progress bar instead (see
        // ARCHITECTURE.md's "Bead progress track" section).
        val all = steps()
        assertTrue(all.all { it.mystery == null && it.decadeIndex == null && it.hailMaryIndexInDecade == null })
    }

    @Test
    fun eachStationBodyContainsTheSharedVersicleAndResponse() {
        val stationSteps = steps().drop(2).dropLast(1)
        for (step in stationSteps) {
            assertTrue(step.body.contains("We adore You, O Christ, and we bless You"))
            assertTrue(step.body.contains("Because by Your holy Cross You have redeemed the world"))
        }
    }

    @Test
    fun firstStationIsCondemnedToDeath() {
        val firstStation = steps().drop(2).first()
        assertEquals("Jesus is Condemned to Death", firstStation.title)
        assertEquals("station_01_condemned_to_death", firstStation.imageKey)
    }

    @Test
    fun englishBodyContainsEnglishText() {
        assertTrue(steps(languageCode = "en").any { it.body.contains("We adore You") })
    }

    @Test
    fun latinBodyContainsLatinText() {
        assertTrue(steps(languageCode = "la").any { it.body.contains("Adoramus te, Christe") })
    }
}
