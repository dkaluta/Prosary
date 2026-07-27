package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

private class FixedLiturgicalCalendar(private val easterSeasonValue: Boolean) : LiturgicalCalendarProviding {
    override fun mysteryGroup(date: Date): MysteryGroup = MysteryGroup.Joyful
    override fun seasonColor(date: Date): Color = Color.Transparent
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = MarianAntiphonOption.SalveRegina
    override fun isEasterSeason(date: Date): Boolean = easterSeasonValue
}

class AngelusEngineTest {
    @Test
    fun standardFormOutsideEastertide() {
        val engine = PrayerEngine(calendar = FixedLiturgicalCalendar(easterSeasonValue = false))
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Angelus, languageCode = "en"))

        assertEquals(7, steps.size)
        assertEquals(
            listOf(
                "The Annunciation", "Hail Mary",
                "The Fiat", "Hail Mary",
                "The Incarnation", "Hail Mary",
                "Let Us Pray",
            ),
            steps.map { it.title },
        )
        assertTrue(steps[0].body.contains("The Angel of the Lord declared unto Mary"))
        assertTrue(steps[1].body.contains("Hail Mary, full of grace"))
        assertTrue(steps.last().body.contains("Pour forth, we beseech Thee"))
        assertFalse(steps.any { it.body.contains("Queen of Heaven") })
    }

    @Test
    fun reginaCaeliSubstitutionDuringEastertide() {
        val engine = PrayerEngine(calendar = FixedLiturgicalCalendar(easterSeasonValue = true))
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Angelus, languageCode = "en"))

        assertEquals(1, steps.size)
        assertEquals("Regina Caeli", steps[0].title)
        assertTrue(steps[0].body.contains("Queen of Heaven, rejoice"))
        assertTrue(steps[0].body.contains("Rejoice and be glad, O Virgin Mary"))
        assertFalse(steps[0].body.contains("Pour forth, we beseech Thee"))
    }

    @Test
    fun fallsBackToLatinWhenLanguageIsNull() {
        val engine = PrayerEngine(calendar = FixedLiturgicalCalendar(easterSeasonValue = false))
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Angelus))

        assertTrue(steps[0].body.contains("Angelus Domini nuntiavit Mariae"))
    }
}
