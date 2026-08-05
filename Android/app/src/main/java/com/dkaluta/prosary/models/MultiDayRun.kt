package com.dkaluta.prosary.models

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * One run through a multi-day devotion — a novena's nine days, a triduum's three, a 33-day
 * consecration. The day count always comes from the bundle's own `days` array; nothing here
 * assumes nine. Port of iOS's MultiDayRun.swift.
 *
 * Records *which* days were prayed rather than only how far you got, because "the day you
 * missed" and "the day today's date calls for" are different answers and the app offers both.
 */
@Serializable
data class MultiDayRun(
    val devotionId: String,
    /** Epoch millis of the day the run began; day 1 belongs to this date. */
    val startedOn: Long,
    val prayedDays: List<Int> = emptyList(),
    val lastPrayedOn: Long? = null,
) {
    private fun startOfDay(millis: Long): Long = Calendar.getInstance().apply {
        timeInMillis = millis
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    private fun elapsedDays(now: Long): Int =
        TimeUnit.MILLISECONDS.toDays(startOfDay(now) - startOfDay(startedOn)).toInt()

    /** The day the calendar calls for today, clamped to the devotion's length. */
    fun dueDay(dayCount: Int, now: Long = System.currentTimeMillis()): Int =
        elapsedDays(now).coerceIn(0, (dayCount - 1).coerceAtLeast(0))

    /** The earliest day still unprayed, or null when the run is finished. */
    fun nextUnprayedDay(dayCount: Int): Int? = (0 until dayCount).firstOrNull { it !in prayedDays }

    /** A day that should have been prayed but was not, the calendar having moved past it. */
    fun missedDay(dayCount: Int, now: Long = System.currentTimeMillis()): Int? {
        val next = nextUnprayedDay(dayCount) ?: return null
        return if (next < dueDay(dayCount, now)) next else null
    }

    fun isComplete(dayCount: Int): Boolean = nextUnprayedDay(dayCount) == null

    /** Reopening the devotion the same day shows that day again rather than advancing. */
    fun hasPrayedToday(now: Long = System.currentTimeMillis()): Boolean =
        lastPrayedOn?.let { startOfDay(it) == startOfDay(now) } ?: false

    fun recordingPrayed(day: Int, now: Long = System.currentTimeMillis()): MultiDayRun = copy(
        prayedDays = if (day in prayedDays) prayedDays else prayedDays + day,
        lastPrayedOn = now,
    )

    /** What opening the devotion should offer. */
    sealed interface Resumption {
        data object Start : Resumption
        data class Resume(val day: Int) : Resumption
        data class Choose(val missed: Int, val next: Int) : Resumption
        data object Complete : Resumption
    }

    fun resumption(dayCount: Int, now: Long = System.currentTimeMillis()): Resumption {
        if (dayCount <= 1) return Resumption.Start
        nextUnprayedDay(dayCount) ?: return Resumption.Complete
        val missed = missedDay(dayCount, now)
        if (missed != null) {
            val due = dueDay(dayCount, now)
            return if (missed == due) Resumption.Resume(missed) else Resumption.Choose(missed, due)
        }
        return Resumption.Resume(nextUnprayedDay(dayCount)!!)
    }
}

/**
 * Where runs live: one per devotion, keyed by bundle id. Small transient state rather than
 * records, so it stays out of Room — the same call iOS makes by keeping them beside the pins
 * instead of in SwiftData.
 */
object MultiDayRuns {
    private const val PREFS = "multi_day_runs"
    private const val KEY = "runs"
    private val json = Json { ignoreUnknownKeys = true }

    private fun prefs(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun all(context: Context): Map<String, MultiDayRun> {
        val raw = prefs(context).getString(KEY, null) ?: return emptyMap()
        return runCatching { json.decodeFromString<Map<String, MultiDayRun>>(raw) }.getOrDefault(emptyMap())
    }

    private fun save(context: Context, runs: Map<String, MultiDayRun>) {
        prefs(context).edit().putString(KEY, json.encodeToString(runs)).apply()
    }

    fun run(context: Context, devotionId: String): MultiDayRun? = all(context)[devotionId]

    fun startFresh(context: Context, devotionId: String, now: Long = System.currentTimeMillis()): MultiDayRun {
        val run = MultiDayRun(devotionId = devotionId, startedOn = now)
        save(context, all(context) + (devotionId to run))
        return run
    }

    fun recordPrayed(context: Context, devotionId: String, day: Int, now: Long = System.currentTimeMillis()) {
        val existing = all(context)[devotionId] ?: MultiDayRun(devotionId = devotionId, startedOn = now)
        save(context, all(context) + (devotionId to existing.recordingPrayed(day, now)))
    }

    fun clear(context: Context, devotionId: String) {
        save(context, all(context) - devotionId)
    }

    fun reset(context: Context) {
        prefs(context).edit().remove(KEY).apply()
    }
}
