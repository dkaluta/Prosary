package com.dkaluta.prosary.content.today

import com.dkaluta.prosary.models.AppSettings
import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class FeastDay(
    val title: String,
    /** The calendar's own vocabulary: "Solemnity" / "Feast" / "Sunday" / "Memorial" /
     * "Optional Memorial" (Roman), "1st Class" … "3rd Class" (1962). Display styling bolds
     * "Solemnity" and "1st Class". */
    val rank: String,
)

@Serializable
data class PopeIntention(
    val title: String,
    val text: String,
)

/** One entry of calendars.json — a switchable feast calendar. */
@Serializable
data class FeastCalendar(
    val id: String,
    /** Basename of the calendar's dataset ("feasts", "feasts-roman", …). */
    val file: String,
    val name: String,
    val nameByLanguage: Map<String, String>? = null,
) {
    /** The Settings picker label, resolved by UI language with the plain name as fallback.
     * [Locale.getDefault] still reports Hebrew as the legacy "iw"; the registry speaks
     * BCP 47's "he". */
    val displayName: String
        get() {
            val uiLanguage = Locale.getDefault().language.let { if (it == "iw") "he" else it }
            return nameByLanguage?.get(uiLanguage) ?: name
        }
}

@Serializable
private data class FeastsFile(val days: Map<String, FeastDay> = emptyMap())

@Serializable
private data class IntentionsFile(val months: Map<String, PopeIntention> = emptyMap())

@Serializable
private data class CalendarsFile(
    val default: String,
    val calendars: List<FeastCalendar> = emptyList(),
)

/** Backs the Pray tab's "Today" section: the day's feast per the selected liturgical
 * calendar, and the Pope's monthly prayer intention. Everything comes from bundled offline
 * datasets (Shared/data/, generated at dev time — movable feasts baked in per year, no computus
 * in the app). calendars.json is the registry of switchable calendars (2026-08, Erez's
 * request): the app-wide [AppSettings.feastCalendarId] setting picks one, defaulting — also for
 * unknown ids — to the registry's default (the Latin Patriarchate of Jerusalem overlay). The
 * feast table reloads whenever the selection changes; the calendar affects this row only, never
 * the engine's season/mystery machinery. A date/month outside the datasets returns null and the
 * row simply hides — regenerating the JSON yearly is the only maintenance.
 *
 * Same initialize-with-a-byte-source pattern as [com.dkaluta.prosary.content.prayerpack.PrayerPackStore]
 * so plain JVM unit tests can feed it files directly. */
object TodayInfoStore {
    private val json = Json { ignoreUnknownKeys = true }

    private var openData: ((String) -> InputStream?)? = null
    private var feastsByDay: Map<String, FeastDay> = emptyMap()
    private var intentionsByMonth: Map<String, PopeIntention> = emptyMap()
    private var registry: CalendarsFile? = null
    private var loadedCalendarId: String? = null
    private var didLoad = false

    /** The registry's calendars, in picker order. */
    val calendars: List<FeastCalendar>
        get() = registry?.calendars ?: emptyList()

    /** The selected calendar id, resolved: an unset or unknown stored id reads as the
     * registry's default, so a calendar removed from the registry can never dead-end the row. */
    val selectedCalendarId: String
        get() {
            val registry = registry ?: return "lpj"
            val stored = AppSettings.feastCalendarId
            if (stored.isNotEmpty() && registry.calendars.any { it.id == stored }) return stored
            return registry.default
        }

    fun feast(date: Date = Date()): FeastDay? {
        ensureFeastsLoaded()
        return feastsByDay[key(date, "yyyy-MM-dd")]
    }

    fun intention(date: Date = Date()): PopeIntention? = intentionsByMonth[key(date, "yyyy-MM")]

    private fun key(date: Date, format: String): String =
        SimpleDateFormat(format, Locale.US).format(date)

    /** [openData] returns a fresh stream for a named data file (e.g.
     * `context.assets.open("data/$it.json")` on-device, or a plain File in tests) — return null
     * for a file that isn't available. Safe to call more than once; only the first call does any
     * work. The opener is kept so the feast table can reload when the calendar selection
     * changes. */
    fun initialize(openData: (String) -> InputStream?) {
        if (didLoad) return
        didLoad = true
        this.openData = openData

        registry = decode<CalendarsFile>("calendars")
        intentionsByMonth = decode<IntentionsFile>("pope-intentions")?.months ?: emptyMap()
    }

    /** The feast table is per-calendar: whenever the resolved selection differs from what is
     * loaded, reload it from the selected registry entry's file (plain "feasts" if the
     * registry itself is missing). */
    private fun ensureFeastsLoaded() {
        val selected = selectedCalendarId
        if (selected == loadedCalendarId) return
        loadedCalendarId = selected
        val file = registry?.calendars?.firstOrNull { it.id == selected }?.file ?: "feasts"
        feastsByDay = decode<FeastsFile>(file)?.days ?: emptyMap()
    }

    private inline fun <reified T> decode(name: String): T? =
        openData?.invoke(name)?.use { stream ->
            runCatching {
                json.decodeFromString<T>(stream.readBytes().toString(Charsets.UTF_8))
            }.getOrNull()
        }
}
