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

    fun mysteryGroupToday(): MysteryGroup = mysteryGroup(Date())
    fun seasonColorToday(): Color = seasonColor(Date())
    fun seasonalMarianAntiphonToday(): MarianAntiphonOption = seasonalMarianAntiphon(Date())
    fun isEasterSeasonToday(): Boolean = isEasterSeason(Date())
}
