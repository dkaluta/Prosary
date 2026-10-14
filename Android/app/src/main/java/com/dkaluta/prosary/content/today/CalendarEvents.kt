package com.dkaluta.prosary.content.today

import java.time.LocalDate

data class CalendarEvent(val date: LocalDate, val id: String, val day: FeastDay, val observance: FeastObservance?) {
    fun title(language: String): String = observance?.localizedTitle(language) ?: day.localizedTitle(language)
    fun description(language: String): SaintDescription? = observance?.description(language) ?: observance?.reflection(language)
}

object CalendarEvents {
    fun events(date: LocalDate, feast: FeastDay?): List<CalendarEvent> = if (feast == null) emptyList()
        else if (feast.observances.isEmpty()) listOf(CalendarEvent(date, "$date:day", feast, null))
        else feast.observances.mapIndexed { index, event -> CalendarEvent(date, "$date:$index:${event.identity}", feast, event) }

    fun monthCells(date: LocalDate): List<LocalDate?> {
        val first = date.withDayOfMonth(1)
        val leading = first.dayOfWeek.value - 1
        val count = ((leading + first.lengthOfMonth() + 6) / 7) * 7
        return (0 until count).map { cell -> (cell - leading + 1).takeIf { it in 1..first.lengthOfMonth() }?.let(first::withDayOfMonth) }
    }
}
