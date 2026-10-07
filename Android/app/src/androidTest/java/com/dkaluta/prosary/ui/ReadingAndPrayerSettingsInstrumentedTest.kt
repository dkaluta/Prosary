package com.dkaluta.prosary.ui

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.graphics.Bitmap
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.TextButton
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.home.HomeScreen
import com.dkaluta.prosary.ui.readings.ReadingsScreen
import com.dkaluta.prosary.ui.settings.SettingsScreen
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import java.time.LocalDate
import java.util.UUID
import java.io.File
import java.io.FileOutputStream

class ReadingAndPrayerSettingsInstrumentedTest {
    @get:Rule val compose = createComposeRule()
    private lateinit var context: IsolatedContext
    private val route = mutableStateOf("prayer")
    private val scripture = mutableStateOf(false)

    private class IsolatedContext(base: Context) : ContextWrapper(base) {
        private val prefix = "reading-prayer-preferences-test-${UUID.randomUUID()}-"
        private val names = mutableSetOf<String>()
        override fun getApplicationContext(): Context = this
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
            val privateName = prefix + name
            names += privateName
            return baseContext.getSharedPreferences(privateName, mode)
        }
        fun cleanup() { names.forEach { baseContext.deleteSharedPreferences(it) } }
    }

    private fun launch(initialRoute: String) {
        route.value = initialRoute
        val app = InstrumentationRegistry.getInstrumentation().targetContext
        PrayerPackStore.initialize(app.assets)
        val date = LocalDate.now()
        TodayInfoStore.resetForTesting()
        TodayInfoStore.initialize { name -> when (name) {
            "calendars" -> """{"default":"fixture","calendars":[{"id":"fixture","name":"Fixture calendar","file":"fixture-feasts","readingsFile":"fixture-readings"}]}""".byteInputStream()
            "fixture-readings" -> """{"days":{"$date":{"readings":[{"type":"reading","short":"Gen 1","full":"Genesis 1:1–2"},{"type":"psalm","short":"Ps 2","full":"Psalm 2:1–3"},{"type":"gospel","short":"Mk 1","full":"Mark 1:1–3"}]}}}""".byteInputStream()
            else -> null
        } }
        val services = AppServices(MockPresetStore(emptyList()), PrayerEngine(), MockLiturgicalCalendar())
        compose.setContent {
            val base = LocalContext.current
            val isolated = remember { IsolatedContext(base).also {
                context = it
                AppSettings.init(it)
                AppSettings.setInterfaceLanguageCode("en")
                AppSettings.feastCalendarId = "fixture"
            } }
            CompositionLocalProvider(LocalContext provides isolated, LocalAppServices provides services) {
                ProsaryTheme {
                    Column(Modifier.fillMaxSize()) {
                        Row {
                            listOf("prayer", "pray", "readings", "settings").forEach { target ->
                                TextButton(onClick = { route.value = target }, modifier = Modifier.testTag("testRoute.$target")) { Text(target) }
                            }
                        }
                        Box(Modifier.weight(1f)) {
                            when (route.value) {
                                "prayer" -> PrayerStepFlowScreen(title = "Prayer", step = RosaryStep(title = "Prayer heading",
                                    body = "Our Father.", isScripture = scripture.value), currentIndex = 0, totalSteps = 1,
                                    seasonColor = Color.Green, isRightToLeft = false, languageCode = "en", canGoBack = false,
                                    onBack = {}, onNext = {}, onNavigateUp = {}, speechAvailable = false)
                                "pray" -> HomeScreen(onOpenPrayer = {}, onOpenReminders = {}, onOpenRosaryPicker = {}, onAddPreset = {},
                                    onOpenAbout = {}, onOpenSettings = { route.value = "settings" }, onOpenJesusPrayerSetup = {},
                                    onOpenCustomDevotion = {}, onOpenBasicPrayers = {}, onOpenBasicPrayer = {})
                                "readings" -> ReadingsScreen()
                                else -> SettingsScreen(onBack = { route.value = "prayer" }, onOpenAppearance = {})
                            }
                        }
                    }
                }
            }
        }
    }

    @Test fun prayerSizePickerChangesPrayerBodyButPreservesHeadingsAndScripture() {
        try {
            launch("prayer")
            val originalBody = compose.onNodeWithTag("prayerParagraph:0").fetchSemanticsNode().boundsInRoot.height
            val originalHeading = compose.onNodeWithTag("prayerStepTitle").fetchSemanticsNode().boundsInRoot.height
            capture("prayer-system-size")
            compose.onNodeWithTag("testRoute.settings").performClick()
            compose.onNodeWithTag("prayerTextSizePercent").performScrollTo()
            compose.onNode(hasClickAction() and hasAnyAncestor(hasTestTag("prayerTextSizePercent"))).performClick()
            compose.onNodeWithText(java.text.NumberFormat.getPercentInstance(context.resources.configuration.locales[0]).format(1.5)).performClick()
            compose.onNodeWithTag("testRoute.prayer").performClick()
            assertTrue(compose.onNodeWithTag("prayerParagraph:0").fetchSemanticsNode().boundsInRoot.height > originalBody * 1.4f)
            assertEquals(originalHeading, compose.onNodeWithTag("prayerStepTitle").fetchSemanticsNode().boundsInRoot.height, 1f)
            capture("prayer-size-150-percent")
            compose.runOnIdle { scripture.value = true }
            val scriptureHeight = compose.onNodeWithTag("prayerParagraph:0").fetchSemanticsNode().boundsInRoot.height
            compose.runOnIdle { AppSettings.prayerTextSizePercent = 200 }
            assertEquals(scriptureHeight, compose.onNodeWithTag("prayerParagraph:0").fetchSemanticsNode().boundsInRoot.height, 1f)
            capture("scripture-unchanged-at-200-percent-preference")
        } finally { cleanup() }
    }

    @Test fun readingsSettingsShareOrderAndDisabledRemindersWithGlobalSettingsWhilePrayStaysPrayerOnly() {
        try {
            launch("pray")
            compose.onNodeWithTag("prayCards").assertIsDisplayed()
            compose.onNodeWithTag("todayChooseDate").assertDoesNotExist()
            compose.onNodeWithTag("todayReadings").assertDoesNotExist()
            capture("pray-without-today")
            compose.onNodeWithTag("testRoute.readings").performClick()
            val firstBefore = compose.onNodeWithText("Genesis 1:1–2").fetchSemanticsNode().boundsInRoot.top
            val gospelBefore = compose.onNodeWithText("Mark 1:1–3").fetchSemanticsNode().boundsInRoot.top
            assertTrue(firstBefore < gospelBefore)
            capture("readings-original-order")
            compose.onNodeWithTag("readingsSettingsButton").performClick()
            compose.onNodeWithTag("readingSettings").assertIsDisplayed()
            val reminder = context.getString(R.string.settings_reminders_readings)
            compose.onNodeWithContentDescription(reminder).assertIsOff()
            compose.onNodeWithText(context.getString(R.string.settings_reminders_saints)).assertDoesNotExist()
            capture("readings-settings-reminders-off")
            compose.onNodeWithTag("reverseReadingsOrder").performClick().assertIsOn()
            compose.onNodeWithText(context.getString(R.string.common_done)).performClick()
            assertTrue(compose.onNodeWithText("Mark 1:1–3").fetchSemanticsNode().boundsInRoot.top <
                compose.onNodeWithText("Genesis 1:1–2").fetchSemanticsNode().boundsInRoot.top)
            capture("readings-gospel-first")
            compose.onNodeWithTag("testRoute.settings").performClick()
            compose.onNodeWithContentDescription(reminder).performScrollTo().assertIsOff()
            compose.onNodeWithTag("reverseReadingsOrder").performScrollTo().assertIsOn()
            compose.runOnIdle { assertFalse(AppSettings.readingsReminderEnabled) }
        } finally { cleanup() }
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        Thread.sleep(200)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        val directory = File(instrumentation.targetContext.getExternalFilesDir(null), "reading-prayer-settings-smoke").apply { mkdirs() }
        FileOutputStream(File(directory, "$name.png")).use { assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)) }
        bitmap.recycle()
    }

    private fun cleanup() {
        if (::context.isInitialized) context.cleanup()
        TodayInfoStore.resetForTesting()
        TodayInfoStore.initialize { name -> runCatching { InstrumentationRegistry.getInstrumentation().targetContext.assets.open("data/$name.json") }.getOrNull() }
    }
}
