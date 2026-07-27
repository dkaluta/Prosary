package com.dkaluta.prosary.content.today

import java.io.InputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
data class FeastDay(
    val title: String,
    /** "Solemnity" / "Feast" / "Sunday" / "Memorial" / "Optional Memorial". */
    val rank: String,
)

@Serializable
data class PopeIntention(
    val title: String,
    val text: String,
)

@Serializable
private data class FeastsFile(val days: Map<String, FeastDay> = emptyMap())

@Serializable
private data class IntentionsFile(val months: Map<String, PopeIntention> = emptyMap())

/** Backs the Home screen's "Today" section: the day's feast per the Holy Land (Latin
 * Patriarchate of Jerusalem) calendar, and the Pope's monthly prayer intention. Both come from
 * bundled offline datasets (Shared/data/, generated at dev time — the General Roman Calendar
 * with the LPJ's documented propers overlaid, movable feasts baked in per year; and
 * popesprayer.va's published intentions). A date/month outside the datasets returns null and the
 * row simply hides — regenerating the JSON yearly is the only maintenance.
 *
 * Same initialize-with-a-byte-source pattern as [com.dkaluta.prosary.content.prayerpack.PrayerPackStore]
 * so plain JVM unit tests can feed it files directly. */
object TodayInfoStore {
    private val json = Json { ignoreUnknownKeys = true }

    private var feastsByDay: Map<String, FeastDay> = emptyMap()
    private var intentionsByMonth: Map<String, PopeIntention> = emptyMap()
    private var didLoad = false

    fun feast(date: Date = Date()): FeastDay? = feastsByDay[key(date, "yyyy-MM-dd")]

    fun intention(date: Date = Date()): PopeIntention? = intentionsByMonth[key(date, "yyyy-MM")]

    private fun key(date: Date, format: String): String =
        SimpleDateFormat(format, Locale.US).format(date)

    /** [openData] returns a fresh stream for a named data file (e.g.
     * `context.assets.open("data/$it.json")` on-device, or a plain File in tests) — return null
     * for a file that isn't available. Safe to call more than once; only the first call does any
     * work. */
    fun initialize(openData: (String) -> InputStream?) {
        if (didLoad) return
        didLoad = true

        openData("feasts")?.use { stream ->
            runCatching {
                feastsByDay = json.decodeFromString<FeastsFile>(
                    stream.readBytes().toString(Charsets.UTF_8)).days
            }
        }
        openData("pope-intentions")?.use { stream ->
            runCatching {
                intentionsByMonth = json.decodeFromString<IntentionsFile>(
                    stream.readBytes().toString(Charsets.UTF_8)).months
            }
        }
    }
}
