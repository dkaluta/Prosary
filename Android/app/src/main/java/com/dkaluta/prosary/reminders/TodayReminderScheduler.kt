package com.dkaluta.prosary.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.FeastDay
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.Date

/** One alarm for each enabled daily topic; date-specific text is resolved at delivery. */
object TodayReminderScheduler {
    fun refresh(context: Context) {
        schedule(context, "readings", AppSettings.readingsReminderEnabled, AppSettings.readingsReminderMinutes)
        schedule(context, "saints", AppSettings.saintReminderEnabled, AppSettings.saintReminderMinutes)
    }

    private fun schedule(context: Context, kind: String, enabled: Boolean, minutes: Int) {
        val intent = Intent(context, TodayReminderReceiver::class.java).apply { action = kind }
        val pending = PendingIntent.getBroadcast(context, kind.hashCode(), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pending)
        if (enabled) ReminderScheduler.arm(context,
            ReminderScheduler.nextTriggerTimeMillis(minutes / 60, minutes % 60), pending)
    }

    fun saintBody(feast: FeastDay, calendarId: String, language: String, context: Context? = null): String {
        val descriptions = feast.saintDescriptions(calendarId, language)
        return if (descriptions.isEmpty()) "${feast.localizedTitle(language)} · ${feast.localizedRank(language, context)}"
        else descriptions.joinToString("\n\n") { listOfNotNull(it.title, it.text, it.credit).filter { text -> text.isNotEmpty() }.joinToString("\n") }
    }
}

class TodayReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val result = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                AppSettings.init(context)
                TodayInfoStore.initialize { name -> runCatching { context.assets.open("data/$name.json") }.getOrNull() }
                TodayReminderScheduler.refresh(context)
                val language = AppSettings.effectiveInterfaceLanguageCode
                val localized = com.dkaluta.prosary.content.today.TodayTranslationLanguage.localizedContext(context, language)
                val content = when (intent.action) {
                    "readings" -> if (AppSettings.readingsReminderEnabled) {
                        val citations = TodayInfoStore.readings(Date())
                        if (citations.isEmpty()) null else Triple(localized.getString(R.string.home_today_readings),
                            citations.joinToString("; ") { it.localizedFull(language) }, "prosary://widget/readings")
                    } else null
                    "saints" -> if (AppSettings.saintReminderEnabled) TodayInfoStore.feast(Date())?.let { feast ->
                        Triple(feast.localizedTitle(language), TodayReminderScheduler.saintBody(feast, TodayInfoStore.selectedCalendarId, language, context), "prosary://widget/today")
                    } else null
                    else -> null
                }
                content?.let { (title, body, url) ->
                    ReminderBroadcastReceiver().onReceive(context, Intent().apply {
                        putExtra(ReminderScheduler.ExtraPrayerId, "today:${intent.action}")
                        putExtra(ReminderScheduler.ExtraPrayerName, title)
                        putExtra(ReminderScheduler.ExtraBody, body)
                        putExtra(ReminderScheduler.ExtraUrl, url)
                    })
                }
            } finally { result.finish() }
        }
    }
}
