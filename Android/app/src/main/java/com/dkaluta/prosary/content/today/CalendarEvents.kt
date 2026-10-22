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

}
