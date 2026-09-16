package com.dkaluta.prosary.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.services.AppServices
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Date
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TodayWidgetProvider : ProsaryWidgetProvider()
class SavedPrayerWidgetProvider : ProsaryWidgetProvider() {
    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        appWidgetIds.forEach { SavedPrayerWidgetStore.remove(context, it) }
    }

    override fun onRestored(context: Context, oldWidgetIds: IntArray, newWidgetIds: IntArray) {
        SavedPrayerWidgetStore.restore(context, oldWidgetIds, newWidgetIds)
    }
}

/** Each broadcast owns the asynchronous work until all RemoteViews have reached the launcher. */
open class ProsaryWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val pending = goAsync()
        WidgetUpdates.scope.launch {
            try {
                WidgetUpdates.updateAll(context.applicationContext)
            } catch (error: Exception) {
                Log.w("ProsaryWidgets", "Unable to refresh widgets", error)
            } finally {
                pending.finish()
            }
        }
    }
}

object WidgetUpdates {
    internal val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val lock = Mutex()
    private val handler = Handler(Looper.getMainLooper())
    private var pendingRefresh: Runnable? = null
    private var observed = false
    // SharedPreferences retains listeners weakly; keep this process-lifetime listener alive.
    private var listener: SharedPreferences.OnSharedPreferenceChangeListener? = null

    @Synchronized
    fun observe(context: Context) {
        if (observed) return
        observed = true
        val app = context.applicationContext
        listener = SharedPreferences.OnSharedPreferenceChangeListener { _, _ -> request(app) }.also { observer ->
            listOf("prosary_settings", "prayer_run_progress", "multi_day_runs").forEach {
                app.getSharedPreferences(it, Context.MODE_PRIVATE).registerOnSharedPreferenceChangeListener(observer)
            }
        }
    }

    /** Coalesces frequent checkpoint writes; backgrounding flushes the final position. */
    @Synchronized
    fun request(context: Context) {
        if (pendingRefresh != null || !hasWidgets(context)) return
        pendingRefresh = Runnable { refresh(context) }.also { handler.postDelayed(it, 5_000) }
    }

    @Synchronized
    fun refresh(context: Context) {
        pendingRefresh?.let(handler::removeCallbacks)
        pendingRefresh = null
        if (!hasWidgets(context)) return
        context.sendBroadcast(Intent(context, TodayWidgetProvider::class.java).setAction(ACTION_REFRESH))
    }

    private fun ids(context: Context, provider: Class<out AppWidgetProvider>): IntArray =
        AppWidgetManager.getInstance(context).getAppWidgetIds(ComponentName(context, provider))

    private fun hasWidgets(context: Context): Boolean =
        ids(context, TodayWidgetProvider::class.java).isNotEmpty() || ids(context, SavedPrayerWidgetProvider::class.java).isNotEmpty()

    internal suspend fun updateAll(context: Context) = lock.withLock {
        val manager = AppWidgetManager.getInstance(context)
        val todayIds = ids(context, TodayWidgetProvider::class.java)
        val savedIds = ids(context, SavedPrayerWidgetProvider::class.java)
        scheduleMidnight(context, todayIds.isNotEmpty() || savedIds.isNotEmpty())
        if (todayIds.isEmpty() && savedIds.isEmpty()) return@withLock
        val appContext = com.dkaluta.prosary.InterfaceLanguageController.localizedContext(context)
        AppSettings.init(appContext)
        val language = TodayTranslationLanguage.resolve(appContext.resources.configuration.locales[0].toLanguageTag())
        val localized = TodayTranslationLanguage.localizedContext(appContext, language)
        TodayInfoStore.initialize { name -> runCatching { context.assets.open("data/$name.json") }.getOrNull() }
        val today = LocalDate.now()
        val content = TodayWidgetContent.load(today, language)
        for (id in todayIds) {
            val small = todayViews(localized, today, content, expanded = false)
            val expanded = todayViews(localized, today, content, expanded = true)
            val views = if (Build.VERSION.SDK_INT >= 31) RemoteViews(mapOf(SizeF(180f, 150f) to small, SizeF(280f, 250f) to expanded))
                else if (manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT) >= 250) expanded else small
            manager.updateAppWidget(id, views)
        }
        if (savedIds.isNotEmpty()) {
            val services = AppServices.create(context)
            for (id in savedIds) {
                val prayer = SavedPrayerWidgetStore.selectedId(context, id)?.let { services.presetStore.get(it) }
                val views = baseViews(localized)
                views.setTextViewText(R.id.widget_header, localized.getString(R.string.widget_saved_name))
                views.setViewVisibility(R.id.widget_details, View.VISIBLE)
                if (prayer == null) {
                    views.setTextViewText(R.id.widget_title, localized.getString(R.string.widget_choose_prayer))
                    views.setTextViewText(R.id.widget_details, localized.getString(R.string.widget_saved_missing))
                    views.setTextViewText(R.id.widget_action, localized.getString(R.string.widget_choose_prayer))
                    val configure = configurationIntent(context, id)
                    views.setOnClickPendingIntent(R.id.widget_root, configure)
                    views.setOnClickPendingIntent(R.id.widget_action, configure)
                } else {
                    val progress = SavedPrayerWidgetStore.progress(context, services, prayer)
                    views.setTextViewText(R.id.widget_title, prayer.name)
                    views.setTextViewText(R.id.widget_details, when {
                        progress?.total != null -> localized.getString(R.string.widget_progress, progress.position, progress.total)
                        progress != null -> localized.getString(R.string.widget_progress_unbounded, progress.position)
                        else -> localized.getString(R.string.widget_ready)
                    })
                    views.setTextViewText(R.id.widget_action, localized.getString(if (progress != null) R.string.flow_continue else R.string.widget_pray))
                    val open = launchIntent(context, "prayer/${prayer.id}")
                    views.setOnClickPendingIntent(R.id.widget_root, open)
                    views.setOnClickPendingIntent(R.id.widget_action, open)
                }
                manager.updateAppWidget(id, views)
            }
        }
    }

    private fun baseViews(context: Context) = RemoteViews(context.packageName, R.layout.prosary_widget).apply {
        val rtl = TodayTranslationLanguage.isRightToLeft(context.resources.configuration.locales[0].toLanguageTag())
        setInt(R.id.widget_root, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
    }

    internal fun todayViews(context: Context, today: LocalDate, content: TodayWidgetContent, expanded: Boolean): RemoteViews = baseViews(context).apply {
        val date = today.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(context.resources.configuration.locales[0]))
        setTextViewText(R.id.widget_header, date)
        setTextViewText(R.id.widget_title, content.feast ?: content.day ?: context.getString(R.string.widget_today_name))
        setInt(R.id.widget_title, "setMaxLines", if (expanded) 3 else if (context.resources.configuration.fontScale > 1.3f) 1 else 2)
        val details = buildList {
            content.readings?.let { add(it) }
            if (expanded) {
                content.intention?.let { add(context.getString(R.string.home_pope_intention, it)) }
                content.torah?.let { add(context.getString(R.string.home_today_torah) + ": " + it) }
            }
        }.joinToString("\n")
        setViewVisibility(R.id.widget_details, if (expanded && details.isNotBlank()) View.VISIBLE else View.GONE)
        setTextViewText(R.id.widget_details, details)
        setInt(R.id.widget_details, "setMaxLines", 6)
        val mysteries = context.getString(MockLiturgicalCalendar().mysteryGroup(Date()).displayNameRes)
        setTextViewText(R.id.widget_action, context.getString(R.string.widget_pray_rosary))
        setContentDescription(R.id.widget_action, context.getString(R.string.widget_pray_rosary) + ". " + mysteries)
        setContentDescription(R.id.widget_root, context.getString(R.string.widget_today_name) + ". " + date)
        setOnClickPendingIntent(R.id.widget_root, launchIntent(context, "today"))
        setOnClickPendingIntent(R.id.widget_action, launchIntent(context, "rosary"))
    }

    internal fun launchIntent(context: Context, path: String): PendingIntent = PendingIntent.getActivity(context, 0,
        Intent(context, MainActivity::class.java).setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse("prosary://widget/$path"))
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun configurationIntent(context: Context, id: Int): PendingIntent = PendingIntent.getActivity(context, id,
        Intent(context, SavedPrayerWidgetConfigurationActivity::class.java)
            .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            .setData(Uri.parse("prosary://widget/configure/$id")),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun scheduleMidnight(context: Context, enabled: Boolean) {
        val alarm = context.getSystemService(AlarmManager::class.java)
        val pending = PendingIntent.getBroadcast(context, 0,
            Intent(context, TodayWidgetProvider::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        if (!enabled) {
            alarm.cancel(pending)
            return
        }
        // An inexact alarm needs no exact-alarm permission. The hourly provider update is a
        // fallback after Doze/OEM delays; tapping always re-resolves the actual current day.
        alarm.setAndAllowWhileIdle(AlarmManager.RTC, nextWidgetMidnight(Instant.now(), ZoneId.systemDefault()).toEpochMilli(), pending)
    }

    private const val ACTION_REFRESH = "com.dkaluta.prosary.widgets.REFRESH"
}
