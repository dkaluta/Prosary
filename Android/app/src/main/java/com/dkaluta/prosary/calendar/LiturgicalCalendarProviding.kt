package com.dkaluta.prosary.calendar

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import java.util.Date

/** What the UI needs from the backend to know "today's" mystery group, season accent color, and
 * seasonal Marian antiphon. This is the liturgical-calendar boundary — implement your own
 * production version with real season/date logic; see [MockLiturgicalCalendar] for a
 * fully-working implementation used to drive the app today. */
interface LiturgicalCalendarProviding {
    fun mysteryGroup(date: Date): MysteryGroup
    fun seasonColor(date: Date): Color

    /** The Marian antiphon traditionally used during the current liturgical season. */
    fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption

    /** True from Easter Sunday through the day before Pentecost, inclusive — the window in which
     * the Angelus is traditionally replaced by the Regina Caeli. */
    fun isEasterSeason(date: Date): Boolean

    /** True through Lent — the season that strips the Alleluia from the liturgy, and so from
     * any devotion's step that carries one. */
    fun isLent(date: Date): Boolean

    fun mysteryGroup(date: Date, useTraditionalMysteries: Boolean): MysteryGroup {
        if (!useTraditionalMysteries) return mysteryGroup(date)
        val weekday = java.util.Calendar.getInstance().apply { time = date }.get(java.util.Calendar.DAY_OF_WEEK)
        return when (weekday) {
            java.util.Calendar.THURSDAY -> MysteryGroup.Joyful
            java.util.Calendar.SATURDAY -> MysteryGroup.Glorious
            else -> mysteryGroup(date)
        }
    }
    fun mysteryGroupToday(useTraditionalMysteries: Boolean = false): MysteryGroup =
        mysteryGroup(Date(), useTraditionalMysteries)
    fun seasonColorToday(): Color = seasonColor(Date())
    fun seasonalMarianAntiphonToday(): MarianAntiphonOption = seasonalMarianAntiphon(Date())
    fun isEasterSeasonToday(): Boolean = isEasterSeason(Date())
    fun isLentToday(): Boolean = isLent(Date())
}
