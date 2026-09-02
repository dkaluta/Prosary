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
    val titleByLanguage: Map<String, String>? = null,
    val textByLanguage: Map<String, String>? = null,
) {
    fun localizedTitle(language: String) = titleByLanguage?.get(language) ?: title
    fun localizedText(language: String) = textByLanguage?.get(language) ?: text
}

@Serializable
data class ReadingCitation(val type: String, val short: String, val full: String, val hebrew: String)

data class LiturgicalDayInfo(val english: String, val hebrew: String)

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
private data class ReadingDay(val readings: List<ReadingCitation> = emptyList())

@Serializable
private data class ReadingsFile(val days: Map<String, ReadingDay> = emptyMap())

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
    private var readingsByDay: Map<String, ReadingDay> = emptyMap()
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

    fun readings(date: Date = Date()): List<ReadingCitation> =
        readingsByDay[key(date, "yyyy-MM-dd")]?.readings.orEmpty()

    fun liturgicalDayInfo(date: Date = Date()): LiturgicalDayInfo {
        val cal = java.util.Calendar.getInstance().apply { time = date }
        val year = cal.get(java.util.Calendar.YEAR)
        val day = java.time.LocalDate.of(year, cal.get(java.util.Calendar.MONTH) + 1, cal.get(java.util.Calendar.DAY_OF_MONTH))
        val easter = easterSunday(year)
        val ash = easter.minusDays(46)
        val pentecost = easter.plusDays(49)
        val advent = firstSundayOnOrAfter(java.time.LocalDate.of(year, 11, 27))
        val christmas = java.time.LocalDate.of(year, 12, 25)
        val baptism = firstSundayOnOrAfter(java.time.LocalDate.of(year, 1, 7))
        val christmasStart = if (day.monthValue == 1) java.time.LocalDate.of(year - 1, 12, 25) else christmas

        val season = when {
            !day.isBefore(ash) && day.isBefore(easter) -> Triple("Lent", "בצום", week(ash, day))
            !day.isBefore(easter) && !day.isAfter(pentecost) -> Triple("Easter Season", "בזמן הפסחא", week(easter, day))
            !day.isBefore(advent) && day.isBefore(christmas) -> Triple("Advent", "בזמן הציפייה", week(advent, day))
            !day.isBefore(christmasStart) && (day.isBefore(baptism) || !day.isBefore(christmas)) ->
                Triple("Christmas Season", "בזמן חג המולד", week(christmasStart, day))
            day.isAfter(pentecost) && day.isBefore(advent) -> {
                val days = java.time.temporal.ChronoUnit.DAYS.between(day, advent)
                Triple("Ordinary Time", "בזמן הרגיל", maxOf(1, 35 - kotlin.math.ceil(days / 7.0).toInt()))
            }
            else -> Triple("Ordinary Time", "בזמן הרגיל", week(baptism.plusDays(1), day))
        }
        val englishWeekday = java.time.format.DateTimeFormatter.ofPattern("EEEE", Locale.US).format(day)
        val hebrewWeekday = java.time.format.DateTimeFormatter.ofPattern("EEEE", Locale("he", "IL")).format(day)
        return LiturgicalDayInfo(
            "$englishWeekday · Week ${season.third} of ${season.first}",
            "$hebrewWeekday · השבוע ה־${season.third} ${season.second}",
        )
    }

    private fun week(origin: java.time.LocalDate, day: java.time.LocalDate) =
        maxOf(1, (java.time.temporal.ChronoUnit.DAYS.between(origin, day) / 7).toInt() + 1)

    private fun firstSundayOnOrAfter(day: java.time.LocalDate): java.time.LocalDate =
        day.plusDays(((java.time.DayOfWeek.SUNDAY.value - day.dayOfWeek.value + 7) % 7).toLong())

    private fun easterSunday(year: Int): java.time.LocalDate {
        val a = year % 19; val b = year / 100; val c = year % 100; val d = b / 4; val e = b % 4
        val f = (b + 8) / 25; val g = (b - f + 1) / 3; val h = (19 * a + b - d - g + 15) % 30
        val i = c / 4; val k = c % 4; val l = (32 + 2 * e + 2 * i - h - k) % 7
        val m = (a + 11 * h + 22 * l) / 451; val month = (h + l - 7 * m + 114) / 31
        val day = (h + l - 7 * m + 114) % 31 + 1
        return java.time.LocalDate.of(year, month, day)
    }

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
        readingsByDay = decode<ReadingsFile>("readings")?.days ?: emptyMap()
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
