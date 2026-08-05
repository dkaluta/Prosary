package com.dkaluta.prosary.models

import android.content.Context
import android.text.format.DateFormat
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * What a multi-day devotion should say about itself on the Pray card: how far through a run you
 * are, or — for a series that has not begun — when it traditionally starts, so a pinned novena
 * announces itself ahead of its first day rather than sitting there mute until you remember.
 * Port of iOS's MultiDayStatus.swift.
 */
object MultiDayStatus {
    /** Null for anything that is not a tracked series, so single-day devotions and free day-sets
     * keep their ordinary subtitle. */
    fun subtitle(context: Context, devotionId: String, now: Long = System.currentTimeMillis()): String? {
        val definition = PrayerPackStore.definition(devotionId) ?: return null
        val days = definition.days ?: return null
        if (days.size <= 1 || (definition.dayProgression ?: "series") != "series") return null

        val run = MultiDayRuns.run(context, devotionId)
        if (run != null) {
            if (run.isComplete(days.size)) return context.getString(R.string.multi_day_complete)
            val day = (run.nextUnprayedDay(days.size) ?: 0) + 1
            return context.getString(R.string.multi_day_day_of, day, days.size)
        }

        val start = startDate(definition.suggestedStart, now) ?: return null
        return if (isSameDay(start, now)) {
            context.getString(R.string.multi_day_starts_today)
        } else {
            val pattern = DateFormat.getBestDateTimePattern(Locale.getDefault(), "dMMMM")
            context.getString(
                R.string.multi_day_starts_on,
                SimpleDateFormat(pattern, Locale.getDefault()).format(start),
            )
        }
    }

    /** The next occurrence of an annual "MM-DD" — this year's if it is still ahead, otherwise
     * next year's, so a devotion whose date has passed announces the coming one. */
    fun startDate(suggestedStart: String?, now: Long = System.currentTimeMillis()): Long? {
        val parts = suggestedStart?.split('-')?.mapNotNull { it.toIntOrNull() } ?: return null
        if (parts.size != 2) return null

        val today = startOfDay(now)
        val candidate = Calendar.getInstance().apply {
            timeInMillis = today
            set(Calendar.MONTH, parts[0] - 1)
            set(Calendar.DAY_OF_MONTH, parts[1])
        }
        if (candidate.timeInMillis < today) candidate.add(Calendar.YEAR, 1)
        return candidate.timeInMillis
    }

    /** The devotion to offer when a run finishes, or null. A bundle may point at something this
     * device has never installed — a hand-written series naming its author's other work, say —
     * so an unresolvable suggestion is simply not offered rather than shown as a dead end. */
    fun suggestedNext(devotionId: String): Pair<String, String>? {
        val suggestion = PrayerPackStore.definition(devotionId)?.suggestedNext ?: return null
        val info = PrayerPackStore.info(suggestion) ?: return null
        return suggestion to info.localizedDisplayName
    }

    private fun startOfDay(millis: Long): Long = Calendar.getInstance().apply {
        timeInMillis = millis
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun isSameDay(a: Long, b: Long): Boolean = startOfDay(a) == startOfDay(b)
}
