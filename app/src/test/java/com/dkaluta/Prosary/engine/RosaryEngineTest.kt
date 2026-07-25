package com.dkaluta.Prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.Prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.Prosary.models.EternalRestPlacement
import com.dkaluta.Prosary.models.MarianAntiphonOption
import com.dkaluta.Prosary.models.MysteryGroup
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.RosaryOptions
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Tests that [MockRosaryEngine] builds the expected step sequences for a range of
 * [RosaryOptions] configurations — mirrors iOS's RosaryEngineTests against StubRosaryEngine. */
class RosaryEngineTest {
    private class FixedCalendar(private val group: MysteryGroup) : LiturgicalCalendarProviding {
        override fun mysteryGroup(date: Date) = group
        override fun seasonColor(date: Date) = Color.Transparent
        override fun seasonalMarianAntiphon(date: Date) = MarianAntiphonOption.SalveRegina
        override fun isEasterSeason(date: Date) = false
    }

    private fun engine(group: MysteryGroup = MysteryGroup.Joyful) = MockRosaryEngine(calendar = FixedCalendar(group))

    private fun prayer(
        group: MysteryGroup = MysteryGroup.Joyful,
        mode: MysterySelectionMode = MysterySelectionMode.Specific,
        includeCreed: Boolean = true,
        includeOpening: Boolean = true,
        includeFatima: Boolean = true,
        eternalRest: EternalRestPlacement = EternalRestPlacement.None,
        antiphon: MarianAntiphonOption = MarianAntiphonOption.SalveRegina,
        includeMichael: Boolean = false,
        includeFinalCross: Boolean = true,
    ) = Prayer(
        rosary = RosaryOptions(
            mysterySelectionMode = mode,
            specificMysteryGroup = group,
            includeApostlesCreed = includeCreed,
            includeOpeningPrayers = includeOpening,
            includeFatimaPrayer = includeFatima,
            eternalRestForDeceased = eternalRest,
            marianAntiphon = antiphon,
            includeStMichaelPrayer = includeMichael,
            includeFinalSignOfCross = includeFinalCross,
        ),
    )

    // MARK: - Step count

    @Test
    fun fiveDecadeStepCountDefaultConfig() {
        val steps = engine().buildSteps(prayer())
        // 1 sign of cross + 1 creed + 1 OurFather + 3 HailMarys + 1 GloryBe = 7 opening
        // Per decade: 1 mystery + 1 OurFather + 10 HailMarys + 1 GloryBe + 1 Fatima = 14
        // 5 decades = 70
        // 1 antiphon + 1 closing cross = 2
        // Total = 7 + 70 + 2 = 79
        assertEquals(79, steps.size)
    }

    @Test
    fun noOpeningPrayersReducesCount() {
        val withOpening = engine().buildSteps(prayer(includeOpening = true)).size
        val withoutOpening = engine().buildSteps(prayer(includeOpening = false)).size
        assertEquals(withOpening - 5, withoutOpening)
    }

    @Test
    fun noApostlesCreedReducesCount() {
        val with = engine().buildSteps(prayer(includeCreed = true)).size
        val without = engine().buildSteps(prayer(includeCreed = false)).size
        assertEquals(with - 1, without)
    }

    @Test
    fun noFatimaPrayerReducesCountByFiveDecades() {
        val with = engine().buildSteps(prayer(includeFatima = true)).size
        val without = engine().buildSteps(prayer(includeFatima = false)).size
        assertEquals(with - 5, without)
    }

    @Test
    fun noFinalCrossReducesCountByOne() {
        val with = engine().buildSteps(prayer(includeFinalCross = true)).size
        val without = engine().buildSteps(prayer(includeFinalCross = false)).size
        assertEquals(with - 1, without)
    }

    @Test
    fun stMichaelPrayerAddsOneStep() {
        val without = engine().buildSteps(prayer(includeMichael = false)).size
        val with = engine().buildSteps(prayer(includeMichael = true)).size
        assertEquals(without + 1, with)
    }

    @Test
    fun eternalRestAfterEachDecadeAddsOnePerDecade() {
        val without = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.None)).size
        val perDecade = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.AfterEachDecade)).size
        assertEquals(without + 5, perDecade)
    }

    @Test
    fun eternalRestAtEndAddsOneTotal() {
        val without = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.None)).size
        val atEnd = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.AtEndOnly)).size
        assertEquals(without + 1, atEnd)
    }

    // MARK: - Twenty mysteries

    @Test
    fun twentyMysteryDecadeCount() {
        val steps = engine().buildSteps(prayer(mode = MysterySelectionMode.TwentyMystery))
        val mysteries = steps.filter { it.isScripture }
        assertEquals(20, mysteries.size)
    }

    // MARK: - Step titles & content

    @Test
    fun firstStepIsSignOfCross() {
        val steps = engine().buildSteps(prayer())
        assertEquals("Sign of the Cross", steps.first().title)
    }

    @Test
    fun lastStepIsSignOfCrossWhenEnabled() {
        val steps = engine().buildSteps(prayer(includeFinalCross = true))
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun stepsContainHailMarys() {
        val steps = engine().buildSteps(prayer())
        val hailMarys = steps.filter { it.title.startsWith("Hail Mary") }
        // 3 opening + 50 decade = 53
        assertEquals(53, hailMarys.size)
    }

    @Test
    fun antiphonStepIsMarkedIsAntiphon() {
        val steps = engine().buildSteps(prayer())
        assertTrue(steps.any { it.isAntiphon })
    }

    @Test
    fun noAntiphonOptionProducesNoAntiphonStep() {
        val steps = engine().buildSteps(prayer(antiphon = MarianAntiphonOption.None))
        assertFalse(steps.any { it.isAntiphon })
    }

    // MARK: - Language passthrough

    @Test
    fun englishBodyContainsEnglishText() {
        val p = prayer().copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val creed = steps.firstOrNull { it.title == "Apostles' Creed" }
        assertNotNull(creed)
        assertTrue(creed!!.body.contains("I believe in God"))
    }

    @Test
    fun latinBodyContainsLatinText() {
        val p = prayer().copy(languageCode = "la")
        val steps = engine().buildSteps(p)
        val creed = steps.firstOrNull { it.title == "Apostles' Creed" }
        assertTrue(creed!!.body.contains("Credo in Deum"))
    }

    // MARK: - resolveMysteryGroups

    @Test
    fun resolveSpecificReturnsOneGroup() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.Specific)
        assertEquals(listOf(MysteryGroup.Sorrowful), engine().resolveMysteryGroups(p))
    }

    @Test
    fun resolveFifteenReturnsTraditionalThree() {
        val p = prayer(mode = MysterySelectionMode.FifteenMystery)
        assertEquals(listOf(MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious), engine().resolveMysteryGroups(p))
    }

    @Test
    fun resolveTwentyReturnsFourGroups() {
        val p = prayer(mode = MysterySelectionMode.TwentyMystery)
        assertEquals(
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious),
            engine().resolveMysteryGroups(p),
        )
    }

    @Test
    fun resolveTodaysMysteriesUsesCalendar() {
        val e = MockRosaryEngine(calendar = FixedCalendar(MysteryGroup.Luminous))
        val p = prayer(mode = MysterySelectionMode.TodaysMysteries)
        assertEquals(listOf(MysteryGroup.Luminous), e.resolveMysteryGroups(p))
    }
}
