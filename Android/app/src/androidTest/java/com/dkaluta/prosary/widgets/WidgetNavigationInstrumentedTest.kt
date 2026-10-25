package com.dkaluta.prosary.widgets

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.assertIsSelected

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.input.key.Key
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.espresso.Espresso.pressBack
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.runner.lifecycle.ActivityLifecycleMonitorRegistry
import androidx.test.runner.lifecycle.Stage
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.services.AppServices
import kotlinx.coroutines.runBlocking
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

@RunWith(AndroidJUnit4::class)
class WidgetNavigationInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun readingsAndCalendarLinksOpenTheirSheetsWhileBibleRemainsAPrimaryDestination() {
        val app = InstrumentationRegistry.getInstrumentation().targetContext
        val dates = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(app.resources.configuration.locales[0])
        ActivityScenario.launch<MainActivity>(Intent(app, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW).setData(Uri.parse("prosary://widget/readings")))
        try {
            compose.waitUntil(20_000) { compose.onAllNodes(hasTestTag("homeReference.daily")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(LocalDate.now().format(dates))
            compose.onNodeWithTag("readingsPrevious").performClick()
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(LocalDate.now().minusDays(1).format(dates))
            WidgetUpdates.launchIntent(app, "calendar").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeReference.calendar")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("homeReference.daily").assertDoesNotExist()
            pressBack()
            compose.onNodeWithTag("tab.home").assertIsSelected()
            compose.onNodeWithTag("tab.bible").performClick().assertIsSelected()
            compose.onNodeWithTag("bibleScreen").assertExists()
            compose.onNodeWithTag("tab.readings").assertDoesNotExist()
            WidgetUpdates.launchIntent(app, "readings").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeReference.daily")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(LocalDate.now().format(dates))
            compose.onNodeWithTag("readingsDone").performClick()
            compose.onNodeWithTag("tab.home").assertIsSelected()
            compose.onNodeWithTag("homeReference.calendar").assertDoesNotExist()
            WidgetUpdates.launchIntent(app, "readings").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeReference.daily")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("readingsList").performKeyInput { pressKey(Key.Escape) }
            compose.onNodeWithTag("homeReference.daily").assertDoesNotExist()
            compose.onNodeWithTag("tab.home").assertIsSelected()
        } finally {
            closeAppActivities()
        }
    }

    @Test fun coldRosaryWarmSavedResumeAndDeletedPrayerFallback() {
        val app = InstrumentationRegistry.getInstrumentation().targetContext
        AppSettings.init(app)
        val services = AppServices.create(app)
        val prayer = Prayer(name = "Widget navigation prayer", languageCode = "en")
        runBlocking { services.presetStore.save(prayer) }
        PrayerRunProgressStore.clear(app, PrayerRunKeys.rosary("widget-todays-rosary"))
        PrayerRunProgressStore.save(app, PrayerRunKeys.rosary(prayer.id), 4, "en", PrayerRunSignatures.rosary(prayer.rosary))
        ActivityScenario.launch<MainActivity>(Intent(app, MainActivity::class.java)
            .setAction(Intent.ACTION_VIEW).setData(Uri.parse("prosary://widget/rosary")))
        try {
            compose.waitUntil(20_000) { compose.onAllNodes(hasTestTag("prayerProgress")).fetchSemanticsNodes().isNotEmpty() }
            WidgetUpdates.launchIntent(app, "prayer/${prayer.id}").send()
            val continueLabel = app.getString(R.string.flow_continue)
            compose.waitUntil(15_000) { compose.onAllNodes(hasText(continueLabel)).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithText(continueLabel).performClick()
            compose.onNodeWithText(app.getString(R.string.flow_step_of, 5, services.engine.buildSteps(prayer).size)).assertExists()
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(Stage.RESUMED)
                    .filterIsInstance<MainActivity>().single().recreate()
            }
            compose.waitForIdle()
            compose.onNodeWithTag("prayerProgress").assertExists()
            // Warm Today activation replaces the flow and opens the current Home dashboard.
            WidgetUpdates.launchIntent(app, "today").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeDashboard")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("prayerProgress").assertDoesNotExist()
            val dates = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(app.resources.configuration.locales[0])
            compose.onNodeWithTag("homeWidget.readings").performScrollTo().performClick()
            compose.onNodeWithTag("readingsPrevious").performClick()
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(LocalDate.now().minusDays(1).format(dates))
            WidgetUpdates.launchIntent(app, "today").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeDashboard")).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("homeDate").assertTextContains(LocalDate.now().format(
                DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(app.resources.configuration.locales[0])))
            compose.onNodeWithTag("homeReference.daily").assertDoesNotExist()
            compose.onNodeWithTag("homeWidget.readings").performScrollTo().performClick()
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(LocalDate.now().format(dates))
            runBlocking { services.presetStore.delete(prayer) }
            WidgetUpdates.launchIntent(app, "prayer/${prayer.id}").send()
            compose.waitForIdle()
            compose.onNodeWithTag("prayerProgress").assertDoesNotExist()
            compose.onNodeWithTag("homeReference.daily").assertDoesNotExist()
        } finally {
            PrayerRunProgressStore.clear(app, PrayerRunKeys.rosary(prayer.id))
            runBlocking { services.presetStore.delete(prayer) }
            // PendingIntent activation can replace ActivityScenario's tracked Activity.
            // Close every app Activity explicitly before releasing the original scenario.
            closeAppActivities()
        }
    }

    private fun closeAppActivities() {
        InstrumentationRegistry.getInstrumentation().runOnMainSync {
            listOf(Stage.RESUMED, Stage.STARTED, Stage.CREATED, Stage.STOPPED).flatMap {
                ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(it)
            }.filterIsInstance<MainActivity>().forEach { it.finish() }
        }
        InstrumentationRegistry.getInstrumentation().waitForIdleSync()
    }
}
