package com.dkaluta.prosary.ui.rosaryflow

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryOptions
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.BeforeClass
import org.junit.Test
import java.io.File

class MysteryStepNavigationTest {
    companion object {
        @BeforeClass
        @JvmStatic
        fun loadPacks() {
            PrayerPackStore.initialize { packName ->
                val file = File("src/main/assets/$packName.prosaryprayer")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    @Test
    fun finalMysteryWithoutClosingPrayersHasCompletionTargetInEverySessionMode() {
        val modes = listOf(MysterySelectionMode.SingleMystery to 1, MysterySelectionMode.Specific to 5,
            MysterySelectionMode.TodaysMysteries to 5, MysterySelectionMode.FifteenMystery to 15,
            MysterySelectionMode.TwentyMystery to 20)
        for ((mode, count) in modes) {
            for (presenter in listOf(false, true)) {
                val options = RosaryOptions(mysterySelectionMode = mode, specificMysteryOrder = 5,
                    marianAntiphon = MarianAntiphonOption.None, includeClosingIntentions = false,
                    includeStMichaelPrayer = false, includeLitanyOfLoreto = false,
                    includeRosaryCollect = false, includeFinalSignOfCross = false, presenterMode = presenter)
                val steps = PrayerEngine().buildSteps(Prayer(languageCode = "en", rosary = options))
                val starts = steps.indices.filter { index ->
                    val decade = steps[index].decadeIndex ?: return@filter false
                    steps.take(index).none { it.decadeIndex == decade }
                }
                assertEquals(count, starts.size)
                assertEquals(count - 1, steps.last().decadeIndex)
                steps.indices.filter { steps[it].decadeIndex == count - 1 }.forEach {
                    assertEquals(steps.size, MysteryStepNavigation.next(steps, it))
                }
                assertNull(MysteryStepNavigation.next(steps, steps.size))
                if (count > 1) {
                    assertEquals(starts.last(), MysteryStepNavigation.next(steps, starts[count - 2]))
                    assertEquals(starts[count - 2], MysteryStepNavigation.previous(steps, steps.lastIndex))
                } else {
                    assertNull(MysteryStepNavigation.previous(steps, steps.lastIndex))
                }
            }
        }
    }
}
