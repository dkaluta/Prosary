package com.dkaluta.prosary.widgets

import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.PrayerRunProgress
import java.net.URI
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/** Widget links carry identities only. The app always re-reads the saved prayer and checkpoint. */
sealed interface WidgetDestination {
    data object Today : WidgetDestination
    data object Rosary : WidgetDestination
    data class SavedPrayer(val id: String) : WidgetDestination

    companion object {
        fun parse(value: String?): WidgetDestination? = runCatching {
            val uri = URI(value ?: return null)
            if (uri.scheme != "prosary" || uri.rawAuthority != "widget" || uri.query != null || uri.fragment != null) return null
            when (uri.path) {
                "/today" -> Today
                "/rosary" -> Rosary
                else -> uri.path.removePrefix("/prayer/").takeIf {
                    uri.path.startsWith("/prayer/") && it.matches(Regex("[A-Za-z0-9_-]{1,128}"))
                }?.let(::SavedPrayer)
            }
        }.getOrNull()
    }
}

data class WidgetLaunchRequest(val destination: WidgetDestination, val sequence: Long)

data class TodayWidgetContent(
    val feast: String?,
    val day: String?,
    val readings: String?,
    val intention: String?,
    val torah: String?,
) {
    companion object {
        /** Shares the app's offline provider; hidden rows are never looked up. */
        fun load(date: LocalDate, appLanguage: String): TodayWidgetContent {
            val language = TodayTranslationLanguage.resolve(appLanguage)
            val instant = TodayDateSelection.lookupDate(date)
            return TodayWidgetContent(
                feast = if (AppSettings.showTodayFeast) TodayInfoStore.feast(instant)?.localizedTitle(language) else null,
                day = if (TodayInfoStore.shouldShowLiturgicalDay(instant)) TodayInfoStore.liturgicalDayInfo(instant).localized(language) else null,
                readings = TodayInfoStore.readings(instant).takeIf { it.isNotEmpty() }?.joinToString(" · ") { it.localizedShort(language) },
                intention = if (AppSettings.showTodayIntention) TodayInfoStore.intention(instant)?.localizedTitle(language) else null,
                torah = if (AppSettings.showTodayTorahPortion) TodayInfoStore.torahPortion(instant)?.localizedTitle(language) else null,
            )
        }
    }
}

/** Civil midnight, including 23/25-hour DST days and zone changes. */
internal fun nextWidgetMidnight(now: Instant, zone: ZoneId): Instant =
    now.atZone(zone).toLocalDate().plusDays(1).atStartOfDay(zone).toInstant()

data class WidgetProgress(val position: Int, val total: Int?) {
    companion object {
        fun validated(
            checkpoint: PrayerRunProgress?,
            stepCount: Int,
            signature: String,
            sameDayOnly: Boolean,
            today: LocalDate = LocalDate.now(),
            unbounded: Boolean = false,
        ): WidgetProgress? = checkpoint?.takeIf {
            it.canResume(stepCount, today, sameDayOnly, signature)
        }?.let { WidgetProgress(it.stepIndex + 1, if (unbounded) null else stepCount) }
    }
}
