package com.dkaluta.prosary.ui.readings

import com.dkaluta.prosary.ui.shared.TodayBrowsingDate

enum class HomeReadingsMode(val id: String) { Daily("daily"), Calendar("calendar"), Bible("bible") }

/** Home shortcuts preserve the browsed day; system widgets deliberately open the current day. */
internal data class ReadingsOpenRequest(val sequence: Long, val mode: HomeReadingsMode, val followsToday: Boolean) {
    fun applyTo(date: TodayBrowsingDate): String {
        if (followsToday) date.selectedEpochDay = null
        return mode.id
    }

    companion object {
        fun latest(calendarWidget: Long, readingsWidget: Long, home: Long, homeMode: HomeReadingsMode): ReadingsOpenRequest? =
            listOf(ReadingsOpenRequest(calendarWidget, HomeReadingsMode.Calendar, true),
                ReadingsOpenRequest(readingsWidget, HomeReadingsMode.Daily, true),
                ReadingsOpenRequest(home, homeMode, false))
                .filter { it.sequence != 0L }.maxByOrNull { it.sequence }
    }
}
