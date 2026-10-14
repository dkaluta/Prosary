package com.dkaluta.prosary.content.today

/** Select from the source appointments before applying any user-facing reading order. */
object ScriptureOfDay {
    fun citation(readings: List<ReadingCitation>): ReadingCitation? =
        readings.firstOrNull { it.type == "gospel" } ?: readings.firstOrNull()
}
