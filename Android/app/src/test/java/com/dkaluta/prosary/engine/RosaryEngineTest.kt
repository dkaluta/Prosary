package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryOptions
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Tests that [PrayerEngine] builds the expected step sequences for a range of
 * [RosaryOptions] configurations — mirrors iOS's RosaryEngineTests. */
class RosaryEngineTest {
    private class FixedCalendar(private val group: MysteryGroup) : LiturgicalCalendarProviding {
        override fun mysteryGroup(date: Date) = group
        override fun seasonColor(date: Date) = Color.Transparent
        override fun seasonalMarianAntiphon(date: Date) = MarianAntiphonOption.SalveRegina
        override fun isEasterSeason(date: Date) = false
    }

    private fun engine(group: MysteryGroup = MysteryGroup.Joyful) = PrayerEngine(calendar = FixedCalendar(group))

    private fun prayer(
        group: MysteryGroup = MysteryGroup.Joyful,
        mode: MysterySelectionMode = MysterySelectionMode.Specific,
        order: Int = 1,
        includeCreed: Boolean = true,
        includeOpening: Boolean = true,
        includeFatima: Boolean = true,
        eternalRest: EternalRestPlacement = EternalRestPlacement.None,
        antiphon: MarianAntiphonOption = MarianAntiphonOption.SalveRegina,
        includeMichael: Boolean = false,
        includeFinalCross: Boolean = true,
        presenterMode: Boolean = false,
    ) = Prayer(
        rosary = RosaryOptions(
            mysterySelectionMode = mode,
            specificMysteryGroup = group,
            specificMysteryOrder = order,
            includeApostlesCreed = includeCreed,
            includeOpeningPrayers = includeOpening,
            includeFatimaPrayer = includeFatima,
            eternalRestForDeceased = eternalRest,
            marianAntiphon = antiphon,
            includeStMichaelPrayer = includeMichael,
            includeFinalSignOfCross = includeFinalCross,
            presenterMode = presenterMode,
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
        val e = PrayerEngine(calendar = FixedCalendar(MysteryGroup.Luminous))
        val p = prayer(mode = MysterySelectionMode.TodaysMysteries)
        assertEquals(listOf(MysteryGroup.Luminous), e.resolveMysteryGroups(p))
    }

    @Test
    fun resolveSingleMysteryReturnsOneGroup() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3)
        assertEquals(listOf(MysteryGroup.Sorrowful), engine().resolveMysteryGroups(p))
    }

    // MARK: - Single Mystery

    @Test
    fun singleMysteryProducesExactlyOneDecade() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3)
        val steps = engine().buildSteps(p)
        val decadeIndices = steps.mapNotNull { it.decadeIndex }.toSet()
        assertEquals(setOf(0), decadeIndices)
    }

    @Test
    fun singleMysteryAnnouncesTheChosenMysteryNotTheFirst() {
        // Mystery announcement titles are translated per-language (unlike fixed prayer titles
        // like "Our Father"), so this must be pinned explicitly rather than relying on the
        // app-level default language.
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3).copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val announcement = steps.first { it.isScripture }
        // 3rd Sorrowful Mystery is the Crowning with Thorns, not the 1st (Agony in the Garden).
        assertEquals("The Crowning with Thorns", announcement.title)
        assertEquals("3rd Mystery", announcement.subtitle)
    }

    // MARK: - Presenter Mode

    @Test
    fun presenterModeOffReproducesExistingStepCount() {
        val steps = engine().buildSteps(prayer(presenterMode = false))
        assertEquals(79, steps.size)
    }

    @Test
    fun presenterModeCollapsesHailMaryAndGloryBeIntoOneStepPerDecade() {
        val steps = engine().buildSteps(prayer(presenterMode = true))

        for (d in 0 until 5) {
            val hailMarySteps = steps.filter { it.decadeIndex == d && it.hailMaryIndexInDecade != null }
            assertEquals(1, hailMarySteps.size)
            assertEquals(10, hailMarySteps.first().hailMaryIndexInDecade)
            assertEquals("Hail Mary & Glory Be", hailMarySteps.first().title)
        }
    }

    @Test
    fun presenterModeCombinedStepBodyContainsBothPrayers() {
        val p = prayer(presenterMode = true).copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val combined = steps.first { it.title == "Hail Mary & Glory Be" }
        assertTrue(combined.body.contains("Hail Mary, full of grace"))
        assertTrue(combined.body.contains("Glory be to the Father"))
    }

    @Test
    fun presenterModeStillIncludesFatimaPrayerPerDecade() {
        val steps = engine().buildSteps(prayer(includeFatima = true, presenterMode = true))
        assertEquals(5, steps.count { it.title == "Fatima Prayer" })
    }

    @Test
    fun presenterModeKeepsAnnouncementAndOurFatherAsSeparateSteps() {
        val steps = engine().buildSteps(prayer(presenterMode = true))
        val decadeZeroSteps = steps.filter { it.decadeIndex == 0 }
        // Announcement, Our Father, Hail Mary & Glory Be, Fatima Prayer = 4 (default config includes Fatima).
        assertEquals(4, decadeZeroSteps.size)
        assertTrue(decadeZeroSteps[0].isScripture)
        assertEquals("Our Father", decadeZeroSteps[1].title)
        assertEquals("Hail Mary & Glory Be", decadeZeroSteps[2].title)
    }
}
