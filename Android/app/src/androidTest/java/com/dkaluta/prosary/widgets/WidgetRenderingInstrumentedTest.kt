package com.dkaluta.prosary.widgets

import android.content.Context
import android.content.res.Configuration
import android.appwidget.AppWidgetHost
import android.appwidget.AppWidgetHostView
import android.appwidget.AppWidgetManager
import android.content.ContentValues
import android.content.ComponentName
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Rect
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.provider.MediaStore
import android.view.View
import android.view.ViewGroup
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
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayDateSelection
import kotlinx.coroutines.runBlocking

@RunWith(AndroidJUnit4::class)
class WidgetRenderingInstrumentedTest {
    @Test fun calendarSaintAndOneCellTemplatesRenderInEveryLocaleAndAppearance() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val app = ApplicationProvider.getApplicationContext<Context>()
        AppSettings.init(app)
        AppServices.create(app)
        TodayInfoStore.initialize { name -> runCatching { app.assets.open("data/$name.json") }.getOrNull() }
        val previousCalendar = AppSettings.feastCalendarId
        val previousBasicLanguage = AppSettings.basicPrayersLanguageCode
        val previousPrayerLanguage = AppSettings.defaultLanguageCode
        try {
            AppSettings.feastCalendarId = "roman"
            for (language in listOf("en", "he", "ar", "ru", "fil", "fr", "it", "uk")) {
                AppSettings.setBasicPrayersLanguageCode(language)
                AppSettings.setDefaultLanguageCode(language)
                for (night in listOf(false, true)) {
                    val locale = Locale.forLanguageTag(language)
                    val context = app.createConfigurationContext(Configuration(app.resources.configuration).apply {
                        setLocale(locale)
                        setLayoutDirection(locale)
                        uiMode = (uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                            if (night) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO
                    })
                    val appearance = if (night) "dark" else "light"
                    val calendarDate = LocalDate.of(2027, 10, 1)
                    val saintDate = LocalDate.of(2027, 10, 4)
                    val expectedCalendarTitle = TodayInfoStore.feast(TodayDateSelection.lookupDate(calendarDate))!!.localizedTitle(language)
                    val saint = TodayInfoStore.feast(TodayDateSelection.lookupDate(saintDate))!!
                    val description = saint.saintDescriptions("roman", language).firstOrNull()
                    instrumentation.runOnMainSync {
                        for (expanded in listOf(false, true)) {
                            val size = if (expanded) "expanded" else "compact"
                            val width = if (expanded) 280 else 180
                            val height = if (expanded) 250 else 150
                            val calendar = renderWidget(context, WidgetUpdates.calendarViews(context, calendarDate, expanded), width, height)
                            saveRendererBitmap(context, calendar, "calendar_${language}_${appearance}_$size")
                            assertWidgetTextAndActions(calendar, language, expectedCalendarTitle, context.getString(R.string.widget_calendar_open))
                            assertVisibleText(calendar, calendar.findViewById(R.id.widget_details))
                            assertTrue(calendar.findViewById<TextView>(R.id.widget_details).text.toString().contains("2"))

                            val saintView = renderWidget(context, WidgetUpdates.saintViews(context, saintDate, expanded), width, height)
                            saveRendererBitmap(context, saintView, "saint_${language}_${appearance}_$size")
                            assertWidgetTextAndActions(saintView, language, description?.title ?: saint.localizedTitle(language), context.getString(R.string.widget_today_open))
                            val body = saintView.findViewById<TextView>(R.id.widget_details).text.toString()
                            val credit = saintView.findViewById<TextView>(R.id.widget_credit)
                            assertVisibleText(saintView, saintView.findViewById(R.id.widget_details))
                            if (description == null) {
                                assertEquals(context.getString(R.string.widget_saint_no_description), body)
                                assertEquals(View.GONE, credit.visibility)
                            }
                            else {
                                assertEquals(description.text, body)
                                assertEquals(description.credit, credit.text.toString())
                                assertEquals(if (expanded) View.VISIBLE else View.GONE, credit.visibility)
                                if (expanded) {
                                    assertVisibleText(saintView, credit)
                                    assertTrue(credit.textSize < saintView.findViewById<TextView>(R.id.widget_details).textSize)
                                }
                            }
                        }
                        for (identity in listOf("basic:ourFather", "devotion:rosary")) {
                            val template = CatalogWidgetPrayers.all(context).first { it.identity == identity }
                            val shortcut = renderWidget(context, WidgetUpdates.shortcutViews(context, template.title,
                                WidgetUpdates.launchIntent(context, template.templatePath!!)), 80, 80)
                            saveRendererBitmap(context, shortcut, "shortcut_${identity.substringBefore(':')}_${language}_$appearance")
                            assertEquals(template.title, shortcut.findViewById<TextView>(R.id.widget_title).text.toString())
                            assertEquals(template.title, shortcut.contentDescription.toString())
                            assertTrue(shortcut.hasOnClickListeners())
                            assertEquals(if (language in listOf("he", "ar")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, shortcut.layoutDirection)
                            assertVisibleText(shortcut, shortcut.findViewById(R.id.widget_title))
                            assertTrue(shortcut.width >= (48 * context.resources.displayMetrics.density).toInt())
                            assertTrue(shortcut.height >= (48 * context.resources.displayMetrics.density).toInt())
                        }
                    }
                }
            }
        } finally {
            AppSettings.feastCalendarId = previousCalendar
            AppSettings.setBasicPrayersLanguageCode(previousBasicLanguage)
            AppSettings.setDefaultLanguageCode(previousPrayerLanguage)
        }
    }

    private fun renderWidget(context: Context, remoteViews: RemoteViews, widthDp: Int, heightDp: Int): View {
        val parent = FrameLayout(context)
        val view = remoteViews.apply(context, parent)
        parent.addView(view)
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).toInt()
        val height = (heightDp * density).toInt()
        parent.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY), View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY))
        parent.layout(0, 0, width, height)
        return view
    }

    private fun assertWidgetTextAndActions(view: View, language: String, title: String, action: String) {
        assertEquals(if (language in listOf("he", "ar")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR, view.layoutDirection)
        assertEquals(title, view.findViewById<TextView>(R.id.widget_title).text.toString())
        assertVisibleText(view, view.findViewById(R.id.widget_title))
        val details = view.findViewById<TextView>(R.id.widget_details)
        assertTrue("Widget preview text must have room for a full line: height=${details.height}, padding=${details.compoundPaddingTop + details.compoundPaddingBottom}, firstLine=${details.layout.getLineBottom(0)}", details.height - details.compoundPaddingTop - details.compoundPaddingBottom >= details.layout.getLineBottom(0))
        val actionView = view.findViewById<TextView>(R.id.widget_action)
        assertEquals(action, actionView.text.toString())
        assertTrue(view.hasOnClickListeners())
        assertTrue(actionView.hasOnClickListeners())
        assertVisibleText(view, actionView)
        assertTrue(actionView.height >= (48 * view.resources.displayMetrics.density).toInt())
        // A title may deliberately ellipsize; the short action label must remain complete.
        for (line in 0 until actionView.layout.lineCount) assertEquals(0, actionView.layout.getEllipsisCount(line))
    }

    private fun assertVisibleText(root: View, text: TextView) {
        assertTrue(text.width > 0 && text.height > 0)
        val visibleLines = minOf(text.layout.lineCount, text.maxLines)
        val visibleHeight = text.layout.getLineBottom(visibleLines - 1)
        assertTrue("Text layout clipped inside ${text.text}: visible=$visibleHeight, height=${text.height}, padding=${text.compoundPaddingTop + text.compoundPaddingBottom}", visibleHeight <= text.height - text.compoundPaddingTop - text.compoundPaddingBottom)
        var child: View = text
        var bounds = Rect(0, 0, text.width, text.height)
        while (child !== root) {
            val parent = child.parent as ViewGroup
            bounds.offset(child.left - parent.scrollX, child.top - parent.scrollY)
            assertTrue("Text clipped by parent: ${text.text}", bounds.left >= 0 && bounds.top >= 0 && bounds.right <= parent.width && bounds.bottom <= parent.height)
            child = parent
        }
    }

    /** Native RemoteViews bitmap evidence; this is not an installed-launcher screenshot. */
    private fun saveRendererBitmap(context: Context, view: View, name: String) {
        val bitmap = Bitmap.createBitmap(view.width, view.height, Bitmap.Config.ARGB_8888)
        view.draw(Canvas(bitmap))
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, "$name.png")
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/ProsaryWidgetRenderer")
        }
        val uri = context.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)!!
        context.contentResolver.openOutputStream(uri)!!.use { assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        bitmap.recycle()
    }

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
                        assertEquals(View.VISIBLE, view.findViewById<View>(R.id.widget_details).visibility)
                        // Launcher previews use the same supported RemoteViews vocabulary.
                        RemoteViews(context.packageName, R.layout.saved_prayer_widget_preview).apply(context, parent)
                    }
                }
            }
        }
    }
}
