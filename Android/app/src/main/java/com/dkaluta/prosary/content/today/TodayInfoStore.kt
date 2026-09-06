package com.dkaluta.prosary.content.today

import android.content.Context
import android.content.res.Configuration
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.typography.HebrewDisplayText
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
    val titleByLanguage: Map<String, String>? = null,
) {
    fun localizedTitle(language: String): String =
        HebrewDisplayText.unpoint(titleByLanguage.localized(language) ?: title)

    /** Follow the Today toggle rather than the app UI language. Roman rank terms follow the
     * Saint James Vicariate's 2025–2026 calendar, pp. 4, 6–7:
     * https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_SJVLiturgicalCalendar202526.pdf
     * Other entries are ordinary UI descriptions; canonical ranks remain unchanged. */
    fun localizedRank(language: String, context: Context? = null): String {
        val (resourceId, hebrewFallback) = when (rank) {
            "Solemnity" -> R.string.home_today_rank_solemnity to "מועד"
            "Feast" -> R.string.home_today_rank_feast to "חג"
            "Memorial" -> R.string.home_today_rank_memorial to "זיכרון"
            "Optional Memorial" -> R.string.home_today_rank_optional_memorial to "זיכרון רשות"
            "Sunday" -> R.string.home_today_rank_sunday to "יום ראשון"
            "Great Feast" -> R.string.home_today_rank_great_feast to "חג גדול"
            "Holy Week" -> R.string.home_today_rank_holy_week to "השבוע הקדוש"
            "Fast" -> R.string.home_today_rank_fast to "צום"
            "1st Class" -> R.string.home_today_rank_1st_class to "דרגה ראשונה"
            "2nd Class" -> R.string.home_today_rank_2nd_class to "דרגה שנייה"
            "3rd Class" -> R.string.home_today_rank_3rd_class to "דרגה שלישית"
            else -> return rank
        }
        val displayLanguage = TodayTranslationLanguage.resolve(language)
        val fallback = if (displayLanguage == "he") hebrewFallback else rank
        if (context == null) return fallback
        return runCatching {
            TodayTranslationLanguage.localizedContext(context, displayLanguage).getString(resourceId)
        }.getOrDefault(fallback)
    }
}

@Serializable
data class PopeIntention(
    val title: String,
    val text: String,
    val titleByLanguage: Map<String, String>? = null,
    val textByLanguage: Map<String, String>? = null,
) {
    fun localizedTitle(language: String) =
        HebrewDisplayText.unpoint(titleByLanguage.localized(language) ?: title)
    fun localizedText(language: String) = textByLanguage.localized(language) ?: text
}

@Serializable
data class ReadingCitation(
    val type: String,
    val short: String,
    val full: String,
    /** Legacy field in the first Roman readings table. New tables use [fullByLanguage]. */
    val hebrew: String? = null,
    val shortByLanguage: Map<String, String>? = null,
    val fullByLanguage: Map<String, String>? = null,
) {
    fun localizedShort(language: String): String = shortByLanguage.localized(language) ?: short

    fun localizedFull(language: String): String {
        val normalized = LanguageCatalog.uiLanguageCode(language)
        return fullByLanguage.localized(normalized)
            ?: if ((LanguageCatalog.baseLanguage(normalized) ?: normalized) == "he") hebrew ?: full else full
    }
}

@Serializable
data class TorahPortion(
    val saturday: String,
    val title: String,
    val titleByLanguage: Map<String, String>? = null,
    val isHoliday: Boolean = false,
    val readings: List<ReadingCitation> = emptyList(),
    val sourceUrl: String = "https://www.hebcal.com",
) {
    fun localizedTitle(language: String): String =
        HebrewDisplayText.unpoint(titleByLanguage.localized(language) ?: title)
}

/** A prayer-language variant first uses its own authored text, then its base language's text.
 * This keeps the Hebrew Mission variant on sourced Hebrew feast titles and citations without
 * duplicating those maps under `he-x-gamliel`. */
private fun Map<String, String>?.localized(language: String): String? {
    val normalized = LanguageCatalog.uiLanguageCode(language)
    return this?.get(normalized)?.takeIf { it.isNotBlank() }
        ?: LanguageCatalog.baseLanguage(normalized)?.let { this?.get(it)?.takeIf(String::isNotBlank) }
}

data class LiturgicalDayInfo(val byLanguage: Map<String, String>) {
    val english: String get() = byLanguage.getValue("en")
    val hebrew: String get() = byLanguage.getValue("he")
    fun localized(language: String): String = byLanguage[TodayTranslationLanguage.resolve(language)] ?: english
}

/** Today follows the app interface language, independently of the prayer language. */
object TodayTranslationLanguage {
    val supportedCodes = listOf("en", "he", "ar", "ru", "tl", "fr", "it")

    fun resolve(appLanguage: String = LanguageCatalog.uiLanguageCode()): String {
        val normalized = LanguageCatalog.uiLanguageCode(appLanguage)
        return (LanguageCatalog.baseLanguage(normalized) ?: normalized).takeIf { it in supportedCodes } ?: "en"
    }

    fun isRightToLeft(code: String): Boolean = resolve(code) in setOf("he", "ar")

    fun localizedContext(context: Context, code: String): Context {
        // Filipino is Android's per-app locale; prayer/data dictionaries use canonical tl.
        val locale = Locale.forLanguageTag(if (resolve(code) == "tl") "fil" else resolve(code))
        val configuration = Configuration(context.resources.configuration).apply {
            setLocale(locale)
            setLayoutDirection(locale)
        }
        return context.createConfigurationContext(configuration)
    }
}

/** One entry of calendars.json — a switchable feast calendar. */
@Serializable
data class FeastCalendar(
    val id: String,
    /** Basename of the calendar's dataset ("feasts", "feasts-roman", …). */
    val file: String,
    val name: String,
    val nameByLanguage: Map<String, String>? = null,
    /** Basename of this rite's readings table. Null deliberately means no readings. */
    val readingsFile: String? = null,
) {
    /** The Settings picker label, resolved by UI language with the plain name as fallback.
     * [Locale.getDefault] still reports Hebrew as the legacy "iw"; the registry speaks
     * BCP 47's "he". */
    val displayName: String
        get() {
            val uiLanguage = LanguageCatalog.uiLanguageCode()
            return HebrewDisplayText.unpoint(nameByLanguage?.get(uiLanguage) ?: name)
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
private data class TorahPortionsFile(val days: Map<String, TorahPortion> = emptyMap())

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
 * feast and readings tables reload whenever the selection changes; this setting does not alter
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
    private var torahByDay: Map<String, TorahPortion> = emptyMap()
    private var didLoadTorah = false
    private var registry: CalendarsFile? = null
    private var loadedCalendarId: String? = null
    private var loadedReadingsCalendarId: String? = null
    private var didLoad = false

    /** The registry's calendars, in picker order. */
    val calendars: List<FeastCalendar>
        get() = registry?.calendars ?: emptyList()

    /** The selected calendar id, resolved: an unset or unknown stored id reads as the
     * registry's default, so a calendar removed from the registry can never dead-end the row. */
    val selectedCalendarId: String
        get() {
            val registry = registry ?: return "lpj"
            // v0.10 folded the Hebrew-title Roman entry into the ordinary General Roman
            // calendar. Preserve that old selection instead of unexpectedly sending it to LPJ.
            val stored = if (AppSettings.feastCalendarId == "roman-he") "roman" else AppSettings.feastCalendarId
            if (stored.isNotEmpty() && registry.calendars.any { it.id == stored }) return stored
            return registry.default
        }

    fun feast(date: Date = Date()): FeastDay? {
        ensureFeastsLoaded()
        return feastsByDay[key(date, "yyyy-MM-dd")]
    }

    fun intention(date: Date = Date()): PopeIntention? = intentionsByMonth[key(date, "yyyy-MM")]

    fun readings(date: Date = Date()): List<ReadingCitation> {
        ensureReadingsLoaded()
        return readingsByDay[key(date, "yyyy-MM-dd")]?.readings.orEmpty()
    }

    /** Israel's weekly cycle, mapped to the upcoming Saturday (including Saturday itself).
     * The optional dataset is opened only when the row is requested. */
    fun torahPortion(date: Date = Date()): TorahPortion? {
        if (!didLoadTorah) {
            didLoadTorah = true
            torahByDay = decode<TorahPortionsFile>("torah-portions")?.days.orEmpty()
        }
        return torahByDay[key(date, "yyyy-MM-dd")]
    }

    fun shouldShowLiturgicalDay(date: Date = Date()): Boolean =
        java.util.Calendar.getInstance().apply { time = date }.get(java.util.Calendar.DAY_OF_WEEK) != java.util.Calendar.SUNDAY

    fun liturgicalDayInfo(date: Date = Date(), calendarId: String = selectedCalendarId): LiturgicalDayInfo {
        val cal = java.util.Calendar.getInstance().apply { time = date }
        val year = cal.get(java.util.Calendar.YEAR)
        val day = java.time.LocalDate.of(year, cal.get(java.util.Calendar.MONTH) + 1, cal.get(java.util.Calendar.DAY_OF_MONTH))
        if (calendarId !in setOf("lpj", "roman", "roman-he")) {
            return LiturgicalDayInfo(TodayTranslationLanguage.supportedCodes.associateWith { language ->
                val locale = Locale.forLanguageTag(if (language == "tl") "fil" else language)
                val month = java.time.format.DateTimeFormatter.ofPattern("MMMM", locale).format(day)
                val number = day.dayOfMonth
                when (language) {
                    "he" -> "יום $number בחודש $month"
                    "ar" -> "اليوم $number من $month"
                    "ru" -> day.format(java.time.format.DateTimeFormatter.ofPattern("d MMMM", locale))
                    "tl" -> "Ika-$number ng $month"
                    "fr" -> "Jour $number de $month"
                    "it" -> "Giorno $number di $month"
                    else -> "Day $number of $month"
                }
            })
        }
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
        val seasonIndex = listOf("Lent", "Easter Season", "Advent", "Christmas Season", "Ordinary Time").indexOf(season.first)
        val seasonNames = mapOf(
            "ar" to listOf("الصوم الكبير", "زمن الفصح", "زمن المجيء", "زمن الميلاد", "الزمن العادي"),
            "ru" to listOf("Великого поста", "Пасхального времени", "Адвента", "Рождественского времени", "Рядового времени"),
            "tl" to listOf("Kuwaresma", "Panahon ng Pasko ng Pagkabuhay", "Adbiyento", "Panahon ng Pasko", "Karaniwang Panahon"),
            "fr" to listOf("Carême", "Temps pascal", "Avent", "Temps de Noël", "Temps ordinaire"),
            "it" to listOf("Quaresima", "Tempo di Pasqua", "Avvento", "Tempo di Natale", "Tempo ordinario"),
        )
        val translations = mutableMapOf(
            "en" to "$englishWeekday · Week ${season.third} of ${season.first}",
            "he" to "$hebrewWeekday · השבוע ה־${season.third} ${season.second}",
        )
        for ((language, names) in seasonNames) {
            val weekday = java.time.format.DateTimeFormatter.ofPattern("EEEE", Locale.forLanguageTag(if (language == "tl") "fil" else language)).format(day)
            val name = names[seasonIndex]
            translations[language] = when (language) {
                "ar" -> "$weekday · الأسبوع ${season.third} من $name"
                "ru" -> "$weekday · ${season.third}-я неделя $name"
                "tl" -> "$weekday · Ika-${season.third} linggo ng $name"
                "fr" -> "$weekday · Semaine ${season.third} · $name"
                else -> "$weekday · Settimana ${season.third} · $name"
            }
        }
        return LiturgicalDayInfo(translations)
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
    }

    /** Gives plain JVM tests an isolated store for custom registries and missing-file cases. */
    internal fun resetForTesting() {
        openData = null
        feastsByDay = emptyMap()
        intentionsByMonth = emptyMap()
        readingsByDay = emptyMap()
        torahByDay = emptyMap()
        didLoadTorah = false
        registry = null
        loadedCalendarId = null
        loadedReadingsCalendarId = null
        didLoad = false
    }

    /** The feast table is per-calendar: whenever the resolved selection differs from what is
     * loaded, reload it from the selected registry entry's file (plain "feasts" if the
     * registry itself is missing). */
    private fun ensureFeastsLoaded() {
        val selected = selectedCalendarId
        val selectionKey = if (selected == "ugcc") "$selected:${AppSettings.easternPaschaStyle}" else selected
        if (selectionKey == loadedCalendarId) return
        loadedCalendarId = selectionKey
        val file = if (selected == "ugcc" && AppSettings.easternPaschaStyle == "gregorian") "feasts-ugcc-gregorian"
            else registry?.calendars?.firstOrNull { it.id == selected }?.file ?: "feasts"
        feastsByDay = decode<FeastsFile>(file)?.days ?: emptyMap()
    }

    /** Readings are selected independently from feasts because two calendars can share a
     * lectionary (LPJ and the General Roman calendar), while another calendar can safely ship no
     * table at all. A missing or malformed file produces an empty row; it must never leak the
     * Roman readings into a Byzantine, Vetus Ordo, or Syriac selection. */
    private fun ensureReadingsLoaded() {
        val selected = selectedCalendarId
        val selectionKey = if (selected == "ugcc") "$selected:${AppSettings.easternPaschaStyle}" else selected
        if (selectionKey == loadedReadingsCalendarId) return
        loadedReadingsCalendarId = selectionKey
        val file = if (selected == "ugcc" && AppSettings.easternPaschaStyle == "gregorian") "readings-ugcc-gregorian"
            else registry?.calendars?.firstOrNull { it.id == selected }?.readingsFile
        readingsByDay = file?.let { decode<ReadingsFile>(it)?.days }.orEmpty()
    }

    private inline fun <reified T> decode(name: String): T? =
        openData?.invoke(name)?.use { stream ->
            runCatching {
                json.decodeFromString<T>(stream.readBytes().toString(Charsets.UTF_8))
            }.getOrNull()
        }
}
