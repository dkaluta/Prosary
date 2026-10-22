package com.dkaluta.prosary.ui.readings

import android.icu.text.DateFormat
import android.icu.text.SimpleDateFormat
import android.icu.util.Calendar
import android.icu.util.TimeZone
import java.time.LocalDate
import java.util.Date
import java.util.Locale

/** Native calendar months for display; all event keys remain ISO civil dates. UTC carries
 * date-only arithmetic, so a device time zone or a DST boundary cannot shift a picked day. */
internal class SystemCalendarMonth(date: LocalDate, systemLocale: Locale, private val textLocale: Locale) {
    private val calendar = Calendar.getInstance(TimeZone.getTimeZone("UTC"), systemLocale).apply {
        timeInMillis = date.toEpochDay() * MILLIS_PER_DAY + MILLIS_PER_DAY / 2
    }
    private fun copy() = calendar.clone() as Calendar
    private fun Calendar.civilDate() = LocalDate.ofEpochDay(Math.floorDiv(timeInMillis, MILLIS_PER_DAY))
    private val first = copy().apply { set(Calendar.DAY_OF_MONTH, 1) }
    val start: LocalDate = first.civilDate()
    private val length = first.getActualMaximum(Calendar.DAY_OF_MONTH)
    private val leading = (first.get(Calendar.DAY_OF_WEEK) - calendar.firstDayOfWeek + 7) % 7
    val days: List<LocalDate?> = List(((leading + length + 6) / 7) * 7) { cell ->
        (cell - leading).takeIf { it in 0 until length }?.let { start.plusDays(it.toLong()) }
    }
    val title: String = format(date, "yMMMM")
    val weekdays: List<Pair<String, String>> = List(7) { index ->
        val day = start.plusDays((index - leading).toLong())
        format(day, "ccccc", skeleton = false) to format(day, "cccc", skeleton = false)
    }
    fun adjacentMonth(offset: Int): LocalDate = (first.clone() as Calendar).apply {
        add(Calendar.MONTH, offset)
    }.civilDate()
    fun dayOfMonth(date: LocalDate): Int = copy().apply {
        timeInMillis = date.toEpochDay() * MILLIS_PER_DAY + MILLIS_PER_DAY / 2
    }.get(Calendar.DAY_OF_MONTH)
    fun format(date: LocalDate, pattern: String, skeleton: Boolean = true): String {
        val formatter = if (skeleton) DateFormat.getInstanceForSkeleton(pattern, textLocale)
            else SimpleDateFormat(pattern, textLocale)
        formatter.calendar = copy()
        return formatter.format(Date(date.toEpochDay() * MILLIS_PER_DAY + MILLIS_PER_DAY / 2))
    }
    companion object { private const val MILLIS_PER_DAY = 86_400_000L }
}
