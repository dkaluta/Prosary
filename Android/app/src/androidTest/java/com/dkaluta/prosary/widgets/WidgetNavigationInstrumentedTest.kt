package com.dkaluta.prosary.widgets

import android.content.Intent
import android.net.Uri
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
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
            // Warm Today activation replaces the flow and lands above the Today content.
            WidgetUpdates.launchIntent(app, "today").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasText(app.getString(R.string.tab_pray))).fetchSemanticsNodes().isNotEmpty() }
            compose.onNodeWithTag("prayerProgress").assertDoesNotExist()
            val dates = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(app.resources.configuration.locales[0])
            compose.onNodeWithTag("todayYesterday").performClick()
            compose.onNodeWithText(LocalDate.now().minusDays(1).format(dates)).assertExists()
            WidgetUpdates.launchIntent(app, "today").send()
            compose.waitUntil(15_000) { compose.onAllNodes(hasText(LocalDate.now().format(dates))).fetchSemanticsNodes().isNotEmpty() }
            runBlocking { services.presetStore.delete(prayer) }
            WidgetUpdates.launchIntent(app, "prayer/${prayer.id}").send()
            compose.waitForIdle()
            compose.onNodeWithTag("prayerProgress").assertDoesNotExist()
        } finally {
            PrayerRunProgressStore.clear(app, PrayerRunKeys.rosary(prayer.id))
            runBlocking { services.presetStore.delete(prayer) }
            // PendingIntent activation can replace ActivityScenario's tracked Activity.
            // Close every app Activity explicitly before releasing the original scenario.
            InstrumentationRegistry.getInstrumentation().runOnMainSync {
                listOf(Stage.RESUMED, Stage.STARTED, Stage.CREATED, Stage.STOPPED).flatMap {
                    ActivityLifecycleMonitorRegistry.getInstance().getActivitiesInStage(it)
                }.filterIsInstance<MainActivity>().forEach { it.finish() }
            }
            InstrumentationRegistry.getInstrumentation().waitForIdleSync()
        }
    }
}
