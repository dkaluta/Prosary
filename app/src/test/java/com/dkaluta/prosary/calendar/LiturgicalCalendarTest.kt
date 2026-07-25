package com.dkaluta.prosary.calendar

import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class LiturgicalCalendarTest {
    private val cal = MockLiturgicalCalendar()
    private val utc = TimeZone.getTimeZone("UTC")

    private fun date(year: Int, month: Int, day: Int): Date {
        val c = Calendar.getInstance(utc)
        c.clear()
        c.set(year, month - 1, day, 0, 0, 0)
        return c.time
    }

    // MARK: - Easter algorithm (known reference dates)

    @Test
    fun easterSunday2024() {
        // Easter 2024 = March 31
        val easter = MockLiturgicalCalendar.computeEasterSunday(2024)
        assertEquals(Calendar.MARCH, easter.get(Calendar.MONTH))
        assertEquals(31, easter.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun easterSunday2025() {
        // Easter 2025 = April 20
        val easter = MockLiturgicalCalendar.computeEasterSunday(2025)
        assertEquals(Calendar.APRIL, easter.get(Calendar.MONTH))
        assertEquals(20, easter.get(Calendar.DAY_OF_MONTH))
    }

    @Test
    fun easterSunday2026() {
        // Easter 2026 = April 5
        val easter = MockLiturgicalCalendar.computeEasterSunday(2026)
        assertEquals(Calendar.APRIL, easter.get(Calendar.MONTH))
        assertEquals(5, easter.get(Calendar.DAY_OF_MONTH))
    }

    // MARK: - isEasterSeason

    @Test
    fun easterSundayIsEasterSeason() {
        assertTrue(cal.isEasterSeason(date(2026, 4, 5)))
    }

    @Test
    fun dayBeforeEasterIsNotEasterSeason() {
        assertFalse(cal.isEasterSeason(date(2026, 4, 4)))
    }

    @Test
    fun pentecostIsNotEasterSeason() {
        // Pentecost 2026 = May 24 (49 days after April 5)
        assertFalse(cal.isEasterSeason(date(2026, 5, 24)))
    }

    @Test
    fun dayBeforePentecostIsEasterSeason() {
        // May 23, 2026 — last day of Easter season
        assertTrue(cal.isEasterSeason(date(2026, 5, 23)))
    }

    // MARK: - Season identification

    private fun utcCal(d: Date): Calendar = Calendar.getInstance(utc).apply { time = d }

    @Test
    fun lentOnAshWednesday() {
        // Ash Wednesday 2026 = February 18 (46 days before April 5)
        assertEquals(MockLiturgicalCalendar.LiturgicalSeason.Lent, cal.season(utcCal(date(2026, 2, 18))))
    }

    @Test
    fun adventInDecember() {
        // Advent 2025 starts Nov 30
        assertEquals(MockLiturgicalCalendar.LiturgicalSeason.Advent, cal.season(utcCal(date(2025, 12, 1))))
    }

    @Test
    fun christmasDayIsChristmasSeason() {
        assertEquals(MockLiturgicalCalendar.LiturgicalSeason.Christmas, cal.season(utcCal(date(2025, 12, 25))))
    }

    @Test
    fun ordinaryTimeInJune() {
        assertEquals(MockLiturgicalCalendar.LiturgicalSeason.Other, cal.season(utcCal(date(2026, 6, 15))))
    }

    // MARK: - Mystery group by weekday (using known dates)

    @Test
    fun mondayIsJoyful() {
        // 2026-07-20 is a Monday
        assertEquals(MysteryGroup.Joyful, cal.mysteryGroup(date(2026, 7, 20)))
    }

    @Test
    fun tuesdayIsSorrowful() {
        assertEquals(MysteryGroup.Sorrowful, cal.mysteryGroup(date(2026, 7, 21)))
    }

    @Test
    fun wednesdayIsGlorious() {
        assertEquals(MysteryGroup.Glorious, cal.mysteryGroup(date(2026, 7, 22)))
    }

    @Test
    fun thursdayIsLuminous() {
        assertEquals(MysteryGroup.Luminous, cal.mysteryGroup(date(2026, 7, 23)))
    }

    @Test
    fun fridayIsSorrowful() {
        assertEquals(MysteryGroup.Sorrowful, cal.mysteryGroup(date(2026, 7, 24)))
    }

    @Test
    fun saturdayIsJoyful() {
        assertEquals(MysteryGroup.Joyful, cal.mysteryGroup(date(2026, 7, 25)))
    }

    @Test
    fun sundayInOrdinaryTimeIsGlorious() {
        assertEquals(MysteryGroup.Glorious, cal.mysteryGroup(date(2026, 7, 26)))
    }

    @Test
    fun sundayInLentIsSorrowful() {
        // Palm Sunday 2026 = March 29
        assertEquals(MysteryGroup.Sorrowful, cal.mysteryGroup(date(2026, 3, 29)))
    }

    @Test
    fun sundayInAdventIsJoyful() {
        // First Sunday of Advent 2025 = Nov 30
        assertEquals(MysteryGroup.Joyful, cal.mysteryGroup(date(2025, 11, 30)))
    }

    // MARK: - Seasonal Marian antiphon

    @Test
    fun antiphonInOrdinaryTimeIsSalveRegina() {
        assertEquals(MarianAntiphonOption.SalveRegina, cal.seasonalMarianAntiphon(date(2026, 7, 24)))
    }

    @Test
    fun antiphonInAdventIsAlmaRedemptorisMater() {
        assertEquals(MarianAntiphonOption.AlmaRedemptorisMater, cal.seasonalMarianAntiphon(date(2025, 12, 1)))
    }

    @Test
    fun antiphonInLentIsAveReginaCaelorum() {
        assertEquals(MarianAntiphonOption.AveReginaCaelorum, cal.seasonalMarianAntiphon(date(2026, 3, 1)))
    }

    @Test
    fun antiphonInEasterSeasonIsReginaCaeli() {
        val easterMonday = date(2026, 4, 6)
        assertEquals(MarianAntiphonOption.ReginaCaeli, cal.seasonalMarianAntiphon(easterMonday))
    }
}
