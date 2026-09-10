package com.dkaluta.prosary.widgets

import android.content.Context
import android.content.res.Configuration
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.view.View
import android.widget.FrameLayout
import android.widget.RemoteViews
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import java.time.LocalDate
import java.util.Locale
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.services.AppServices
import kotlinx.coroutines.runBlocking

@RunWith(AndroidJUnit4::class)
class WidgetRenderingInstrumentedTest {
    @Test fun frameworkHostReceivesSavedPrayerSelectionProgressAndDeletion() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val app = ApplicationProvider.getApplicationContext<Context>()
        fun shell(command: String) = ParcelFileDescriptor.AutoCloseInputStream(instrumentation.uiAutomation.executeShellCommand(command)).use { it.readBytes() }
        val userId = shell("am get-current-user").toString(Charsets.UTF_8).trim().toInt()
        shell("appwidget grantbind --package ${app.packageName} --user $userId")
        AppSettings.init(app)
        val services = AppServices.create(app)
        val prayer = Prayer(name = "Widget instrumented prayer")
        val host = AppWidgetHost(app, 76109)
        val manager = AppWidgetManager.getInstance(app)
        var id = AppWidgetManager.INVALID_APPWIDGET_ID
        var view: AppWidgetHostView? = null
        fun awaitAction(expected: String) {
            val deadline = SystemClock.uptimeMillis() + 5_000
            do {
                var actual: String? = null
                instrumentation.runOnMainSync { actual = view?.findViewById<TextView>(R.id.widget_action)?.text?.toString() }
                if (actual == expected) return
                SystemClock.sleep(50)
            } while (SystemClock.uptimeMillis() < deadline)
            instrumentation.runOnMainSync { assertEquals(expected, view?.findViewById<TextView>(R.id.widget_action)?.text?.toString()) }
        }
        try {
            runBlocking { services.presetStore.save(prayer) }
            id = host.allocateAppWidgetId()
            assertTrue(manager.bindAppWidgetIdIfAllowed(id, ComponentName(app, SavedPrayerWidgetProvider::class.java)))
            manager.updateAppWidgetOptions(id, Bundle().apply {
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 280)
                putInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 250)
            })
            instrumentation.runOnMainSync {
                host.startListening()
                view = host.createView(app, id, manager.getAppWidgetInfo(id))
            }
            SavedPrayerWidgetStore.select(app, id, prayer.id)
            PrayerRunProgressStore.save(app, PrayerRunKeys.rosary(prayer.id), 4, "en", PrayerRunSignatures.rosary(prayer.rosary))
            assertNotNull(SavedPrayerWidgetStore.progress(app, services, prayer))
            runBlocking { WidgetUpdates.updateAll(app) }
            // AppWidgetHost callbacks arrive asynchronously over Binder after updateAll returns.
            awaitAction(app.getString(R.string.flow_continue))
            instrumentation.runOnMainSync {
                assertEquals(prayer.name, view!!.findViewById<TextView>(R.id.widget_title).text.toString())
                assertEquals(app.getString(R.string.flow_continue), view!!.findViewById<TextView>(R.id.widget_action).text.toString())
                assertTrue(view!!.findViewById<TextView>(R.id.widget_details).text.toString().contains("5"))
            }
            runBlocking { services.presetStore.delete(prayer); WidgetUpdates.updateAll(app) }
            awaitAction(app.getString(R.string.widget_choose_prayer))
            instrumentation.runOnMainSync {
                assertEquals(app.getString(R.string.widget_choose_prayer), view!!.findViewById<TextView>(R.id.widget_action).text.toString())
            }
        } finally {
            if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
                SavedPrayerWidgetStore.remove(app, id)
                host.deleteAppWidgetId(id)
            }
            host.stopListening()
            host.deleteHost()
            PrayerRunProgressStore.clear(app, PrayerRunKeys.rosary(prayer.id))
            runBlocking { services.presetStore.delete(prayer) }
            shell("appwidget revokebind --package ${app.packageName} --user $userId")
        }
    }

    @Test fun remoteViewsInflateWithClickableActionsInLightDarkAndRtl() {
        val app = ApplicationProvider.getApplicationContext<Context>()
        for (language in listOf("en", "he", "ar", "fil")) {
            for (night in listOf(false, true)) {
                val locale = Locale.forLanguageTag(language)
                val context = app.createConfigurationContext(Configuration(app.resources.configuration).apply {
                    setLocale(locale)
                    setLayoutDirection(locale)
                    uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                        if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
                })
                for (expanded in listOf(false, true)) {
                    InstrumentationRegistry.getInstrumentation().runOnMainSync {
                        val content = TodayWidgetContent("Feast title", "Day", "Jn. 3", "Intention", "Torah")
                        val views = WidgetUpdates.todayViews(context, LocalDate.of(2026, 9, 10), content, expanded)
                        val parent = FrameLayout(context)
                        val view = views.apply(context, parent)
                        parent.addView(view)
                        val density = context.resources.displayMetrics.density
                        val width = ((if (expanded) 280 else 180) * density).toInt()
                        val height = ((if (expanded) 250 else 150) * density).toInt()
                        parent.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
                        parent.layout(0, 0, width, height)
                        assertEquals(if (language in listOf("he", "ar")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, view.layoutDirection)
                        assertEquals("Feast title", view.findViewById<TextView>(R.id.widget_title).text.toString())
                        assertTrue(view.hasOnClickListeners())
                        val action = view.findViewById<TextView>(R.id.widget_action)
                        assertTrue(action.hasOnClickListeners())
                        assertTrue(action.height >= (48 * density).toInt())
                        assertTrue(action.bottom <= view.height)
                        assertEquals(if (expanded) View.VISIBLE else View.GONE, view.findViewById<View>(R.id.widget_details).visibility)
                        // Launcher previews use the same supported RemoteViews vocabulary.
                        RemoteViews(context.packageName, R.layout.saved_prayer_widget_preview).apply(context, parent)
                    }
                }
            }
        }
    }
}
