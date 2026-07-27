package com.dkaluta.prosary.calendar

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import java.util.Calendar
import java.util.Date
import java.util.TimeZone

/**
 * A fully-working [LiturgicalCalendarProviding] used to drive the app today. Not necessarily the
 * final production implementation.
 *
 * Resolves "today's mysteries" per the traditional weekday assignment: Mon/Sat Joyful,
 * Tue/Fri Sorrowful, Wed Glorious, Thu Luminous, and on Sundays the mysteries proper to the
 * liturgical season (Joyful in Advent/Christmas, Sorrowful in Lent, Glorious otherwise).
 */
class MockLiturgicalCalendar : LiturgicalCalendarProviding {

    override fun mysteryGroup(date: Date): MysteryGroup {
        val cal = utcCalendar(date)
        return when (cal.get(Calendar.DAY_OF_WEEK)) {
            Calendar.MONDAY, Calendar.SATURDAY -> MysteryGroup.Joyful
            Calendar.TUESDAY, Calendar.FRIDAY -> MysteryGroup.Sorrowful
            Calendar.WEDNESDAY -> MysteryGroup.Glorious
            Calendar.THURSDAY -> MysteryGroup.Luminous
            Calendar.SUNDAY -> mysteryGroupForSunday(cal)
            else -> MysteryGroup.Joyful
        }
    }

    /** The Marian antiphon traditionally used during the current liturgical season. */
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = when (season(utcCalendar(date))) {
        LiturgicalSeason.Advent, LiturgicalSeason.Christmas -> MarianAntiphonOption.AlmaRedemptorisMater
        LiturgicalSeason.Lent -> MarianAntiphonOption.AveReginaCaelorum
        LiturgicalSeason.EasterSeason -> MarianAntiphonOption.ReginaCaeli
        LiturgicalSeason.Other -> MarianAntiphonOption.SalveRegina
    }

    override fun isEasterSeason(date: Date): Boolean = season(utcCalendar(date)) == LiturgicalSeason.EasterSeason

    /** The traditional liturgical color for the day, for use as an accent/banner color. */
    override fun seasonColor(date: Date): Color {
        val cal = utcCalendar(date)
        val easter = computeEasterSunday(cal.get(Calendar.YEAR))
        val pentecost = addDays(easter, 49)
        if (isSameDay(cal, pentecost)) return Color(0xFFB22222) // Pentecost: red

        return when (season(cal)) {
            LiturgicalSeason.Advent, LiturgicalSeason.Lent -> Color(0xFF6A3E8E) // violet
            LiturgicalSeason.Christmas, LiturgicalSeason.EasterSeason -> Color(0xFFB8860B) // gold/white
            LiturgicalSeason.Other -> Color(0xFF2E7D32) // green: Ordinary Time
        }
    }

    private fun mysteryGroupForSunday(cal: Calendar): MysteryGroup = when (season(cal)) {
        LiturgicalSeason.Advent, LiturgicalSeason.Christmas -> MysteryGroup.Joyful
        LiturgicalSeason.Lent -> MysteryGroup.Sorrowful
        LiturgicalSeason.EasterSeason, LiturgicalSeason.Other -> MysteryGroup.Glorious
    }

    // Internal (not private) visibility for unit tests in the same module, mirroring iOS's
    // equivalent `internal` season logic in StubLiturgicalCalendar.swift.
    internal enum class LiturgicalSeason { Advent, Christmas, Lent, EasterSeason, Other }

    internal fun season(dateCal: Calendar): LiturgicalSeason {
        val date = startOfDay(dateCal)
        val year = date.get(Calendar.YEAR)
        val easter = computeEasterSunday(year)
        val ashWednesday = addDays(easter, -46)

        if (!date.before(ashWednesday) && date.before(easter)) {
            return LiturgicalSeason.Lent
        }

        val pentecost = addDays(easter, 49)
        if (!date.before(easter) && date.before(pentecost)) {
            return LiturgicalSeason.EasterSeason
        }

        val adventStart = firstSundayOnOrAfter(dateFrom(year, 11, 27))
        val christmas = dateFrom(year, 12, 25)
        if (!date.before(adventStart) && date.before(christmas)) {
            return LiturgicalSeason.Advent
        }

        // Christmas season runs from Dec 25 through the Baptism of the Lord (approximated as the
        // first Sunday on/after Jan 7), spanning new year's day.
        val nextEpiphanySunday = firstSundayOnOrAfter(dateFrom(year + 1, 1, 7))
        if (!date.before(christmas) && date.before(nextEpiphanySunday)) {
            return LiturgicalSeason.Christmas
        }

        val previousChristmas = dateFrom(year - 1, 12, 25)
        val thisEpiphanySunday = firstSundayOnOrAfter(dateFrom(year, 1, 7))
        if (date.before(christmas) && date.before(thisEpiphanySunday) && !date.before(previousChristmas)) {
            return LiturgicalSeason.Christmas
        }

        return LiturgicalSeason.Other
    }

    companion object {
        private fun utcCalendar(date: Date): Calendar =
            Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply { time = date }

        private fun startOfDay(cal: Calendar): Calendar {
            val copy = cal.clone() as Calendar
            copy.set(Calendar.HOUR_OF_DAY, 0)
            copy.set(Calendar.MINUTE, 0)
            copy.set(Calendar.SECOND, 0)
            copy.set(Calendar.MILLISECOND, 0)
            return copy
        }

        private fun dateFrom(year: Int, month: Int, day: Int): Calendar {
            val cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"))
            cal.clear()
            cal.set(year, month - 1, day, 0, 0, 0)
            return cal
        }

        private fun addDays(cal: Calendar, days: Int): Calendar {
            val copy = cal.clone() as Calendar
            copy.add(Calendar.DAY_OF_YEAR, days)
            return copy
        }

        private fun isSameDay(a: Calendar, b: Calendar): Boolean =
            a.get(Calendar.YEAR) == b.get(Calendar.YEAR) && a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)

        private fun firstSundayOnOrAfter(cal: Calendar): Calendar {
            val weekday = cal.get(Calendar.DAY_OF_WEEK) // Calendar.SUNDAY = 1
            val offset = (1 - weekday + 7) % 7
            return addDays(cal, offset)
        }

        /** Anonymous Gregorian algorithm (Meeus/Jones/Butcher). Internal (not private) visibility
         * for unit tests in the same module. */
        internal fun computeEasterSunday(year: Int): Calendar {
            val a = year % 19
            val b = year / 100
            val c = year % 100
            val d = b / 4
            val e = b % 4
            val f = (b + 8) / 25
            val g = (b - f + 1) / 3
            val h = (19 * a + b - d - g + 15) % 30
            val i = c / 4
            val k = c % 4
            val l = (32 + 2 * e + 2 * i - h - k) % 7
            val m = (a + 11 * h + 22 * l) / 451
            val month = (h + l - 7 * m + 114) / 31
            val day = (h + l - 7 * m + 114) % 31 + 1
            return dateFrom(year, month, day)
        }
    }
}
