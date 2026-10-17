package com.dkaluta.prosary.ui

import android.content.Context
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.pressBack
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.HomeWidget
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class HomeDashboardInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun homeReadingCardKeepsFullCitationsAndPrayHasNoTodayContent() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use {
            awaitHome()
            val citations = ReadingCitation.displayOrder(TodayInfoStore.readings(), AppSettings.reverseReadingsOrder)
            val language = TodayTranslationLanguage.resolve(app.resources.configuration.locales[0].toLanguageTag())
            citations.forEachIndexed { index, citation ->
                compose.onNodeWithTag("homeReading.$index", useUnmergedTree = true).performScrollTo()
                    .assertTextContains(citation.localizedFull(language))
            }
            compose.onNodeWithTag("tab.pray").performClick()
            compose.onNodeWithTag("prayCards").assertExists()
            for (tag in listOf("todayChooseDate", "todayYesterday", "todayTomorrow", "todayReadings", "todaySaints", "popeIntention")) {
                compose.onNodeWithTag(tag).assertDoesNotExist()
            }
            compose.onNodeWithTag("tab.home").performClick()
            compose.onNodeWithTag("homeDate").assertExists()
        }
    }

    @Test fun compactHomeWidgetsKeepTheirContentAndPersistAcrossRecreation() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            captureScreenshot("home-large")
            compose.onNodeWithTag("homeWidgetSize.readings").performClick()
            assertTrue(AppSettings.isHomeWidgetCollapsed(HomeWidget.Readings))
            compose.onNodeWithTag("homeReading.0").assertDoesNotExist()
            compose.onNodeWithTag("homeWidgetGraphic.readings").assertDoesNotExist()
            captureScreenshot("home-small")
            scenario.recreate()
            awaitHome()
            assertTrue(AppSettings.isHomeWidgetCollapsed(HomeWidget.Readings))
            compose.onNodeWithTag("homeWidgetSize.readings").performClick()
            assertFalse(AppSettings.isHomeWidgetCollapsed(HomeWidget.Readings))
            compose.onNodeWithTag("homeWidgetGraphic.readings").assertExists()
        }
    }

    @Test fun customAccentKeepsTheLauncherChoiceAndSurvivesRecreation() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            val old = AppSettings.customAccentColorHex
            val system = AppSettings.useSystemColors
            val launcher = AppSettings.appColor
            try {
                compose.onNodeWithContentDescription(app.getString(R.string.common_settings)).performClick()
                compose.onNodeWithTag("settingsAppearance").performScrollTo().performClick()
                compose.onNodeWithTag("customAccentColor").performScrollTo().performClick()
                compose.onNodeWithTag("customAccentSave").assertExists()
                captureScreenshot("accent-color")
                compose.onNodeWithTag("customAccentSave").performClick()
                assertEquals("#1768AC", AppSettings.customAccentColorHex)
                assertFalse(AppSettings.useSystemColors)
                assertEquals(launcher, AppSettings.appColor)
                scenario.recreate()
                compose.onNodeWithTag("appearanceScreen").assertExists()
                assertEquals("#1768AC", AppSettings.customAccentColorHex)
                compose.onNodeWithTag("customAccentColor").performScrollTo().performClick()
                compose.onNodeWithTag("customAccentReset").performScrollTo().performClick()
                assertEquals("", AppSettings.customAccentColorHex)
            } finally {
                scenario.onActivity { AppSettings.customAccentColorHex = old; AppSettings.useSystemColors = system }
            }
        }
    }

    @Test fun homeCardAccentSelectionSurvivesRecreationAndRemovalResetsOnlyThatCard() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            val appColor = AppSettings.appColor
            compose.onNodeWithTag("homeWidgetColor.readings").performClick()
            compose.onNodeWithTag("homeWidgetRemoveAccent.readings").assertDoesNotExist()
            compose.onNodeWithTag("homeWidgetSetAccent.readings").performClick()
            compose.onNodeWithTag("homeWidgetColor.readings.default").assertDoesNotExist()
            compose.onNodeWithTag("homeWidgetColor.readings.blue").performClick()
            compose.runOnIdle {
                assertEquals("blue", AppSettings.homeWidgetColor(HomeWidget.Readings))
                assertEquals("default", AppSettings.homeWidgetColor(HomeWidget.Feast))
                assertEquals(appColor, AppSettings.appColor)
            }
            scenario.onActivity { AppSettings.setHomeWidgetColor(HomeWidget.Feast, "rose") }
            scenario.recreate()
            awaitHome()
            compose.onNodeWithTag("homeWidgetColor.readings").performClick()
            compose.onNodeWithTag("homeWidgetRemoveAccent.readings").assertExists()
            compose.onNodeWithTag("homeWidgetSetAccent.readings").performClick()
            compose.onNodeWithTag("homeWidgetColor.readings.blue").assertIsSelected()
            pressBack()
            compose.onNodeWithTag("homeWidgetColor.readings").performClick()
            compose.onNodeWithTag("homeWidgetRemoveAccent.readings").performClick()
            compose.runOnIdle {
                assertEquals("default", AppSettings.homeWidgetColor(HomeWidget.Readings))
                assertEquals("rose", AppSettings.homeWidgetColor(HomeWidget.Feast))
            }
            compose.onNodeWithTag("homeWidgetColor.readings").performClick()
            compose.onNodeWithTag("homeWidgetRemoveAccent.readings").assertDoesNotExist()
        }
    }

    @Test fun homeCardAccessibilityTraversalFollowsSavedAcrossColumnOrder() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use {
            awaitHome()
            HomeWidget.defaults.forEachIndexed { index, widget ->
                val semantics = compose.onNodeWithTag("homeColumnCard.${widget.id}", useUnmergedTree = true).fetchSemanticsNode().config
                assertEquals(index.toFloat(), semantics[SemanticsProperties.TraversalIndex], 0f)
                assertTrue(semantics[SemanticsProperties.IsTraversalGroup])
            }
        }
    }

    @Test fun widgetImagesHideInSmallCardsAndRemoveOnlyTheirPrivateCopy() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            val old = AppSettings.homeWidgetGraphicPath(HomeWidget.Readings)
            val file = java.io.File(app.filesDir, "homePhotos/home-photo-ui-${java.util.UUID.randomUUID()}.jpg")
            file.parentFile!!.mkdirs()
            val bitmap = android.graphics.Bitmap.createBitmap(20, 20, android.graphics.Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(android.graphics.Color.BLUE)
            file.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) }
            bitmap.recycle()
            try {
                scenario.onActivity { AppSettings.setHomeWidgetGraphicPath(HomeWidget.Readings, file.path) }
                compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("homeWidgetGraphicImage.readings"), useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty() }
                captureScreenshot("card-graphic")
                compose.onNodeWithTag("homeWidgetSize.readings").performClick()
                compose.onNodeWithTag("homeWidgetGraphicImage.readings", useUnmergedTree = true).assertDoesNotExist()
                assertTrue(file.exists())
                compose.onNodeWithTag("homeWidgetSize.readings").performClick()
                compose.onNodeWithTag("homeWidgetGraphicRemove.readings").performScrollTo().performClick()
                compose.waitUntil(15_000) { !file.exists() && AppSettings.homeWidgetGraphicPath(HomeWidget.Readings).isEmpty() }
            } finally {
                scenario.onActivity { AppSettings.setHomeWidgetGraphicPath(HomeWidget.Readings, old) }
                file.delete()
            }
        }
    }

    @Test fun returnedImageKeepsItsOriginalWidgetAfterActivityRecreation() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            val oldGraphic = AppSettings.homeWidgetGraphicPath(HomeWidget.Readings)
            val oldPhoto = AppSettings.homePhotoPath
            val source = java.io.File(app.cacheDir, "picker-result-${java.util.UUID.randomUUID()}.jpg")
            val bitmap = android.graphics.Bitmap.createBitmap(20, 20, android.graphics.Bitmap.Config.ARGB_8888)
            bitmap.eraseColor(android.graphics.Color.BLUE)
            source.outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.JPEG, 90, it) }
            bitmap.recycle()
            var imported: String? = null
            try {
                compose.onNodeWithTag("homeWidgetGraphic.readings").performClick()
                val registryState = android.os.Bundle()
                scenario.onActivity { it.activityResultRegistry.onSaveInstanceState(registryState) }
                val launched = requireNotNull(registryState.getStringArrayList("KEY_COMPONENT_ACTIVITY_LAUNCHED_KEYS")).single()
                val keys = requireNotNull(registryState.getStringArrayList("KEY_COMPONENT_ACTIVITY_REGISTERED_KEYS"))
                val codes = requireNotNull(registryState.getIntegerArrayList("KEY_COMPONENT_ACTIVITY_REGISTERED_RCS"))
                val requestCode = codes[keys.indexOf(launched)]
                var originalActivity: MainActivity? = null
                scenario.onActivity { originalActivity = it; it.recreate() }
                compose.waitUntil(15_000) {
                    var recreated = false
                    runCatching { scenario.onActivity { recreated = it !== originalActivity } }
                    recreated
                }
                // Deliver the same OS result to the restored registry, then foreground Home.
                scenario.onActivity { it.activityResultRegistry.dispatchResult(requestCode, android.app.Activity.RESULT_OK,
                    android.content.Intent().setData(android.net.Uri.fromFile(source))) }
                InstrumentationRegistry.getInstrumentation().uiAutomation.executeShellCommand("input keyevent 4").close()
                compose.waitUntil(15_000) { AppSettings.homeWidgetGraphicPath(HomeWidget.Readings) != oldGraphic }
                imported = AppSettings.homeWidgetGraphicPath(HomeWidget.Readings)
                assertTrue(java.io.File(requireNotNull(imported)).exists())
                assertEquals(oldPhoto, AppSettings.homePhotoPath)
            } finally {
                scenario.onActivity { AppSettings.setHomeWidgetGraphicPath(HomeWidget.Readings, oldGraphic); AppSettings.homePhotoPath = oldPhoto }
                imported?.let { java.io.File(it).delete() }
                source.delete()
            }
        }
    }

    @Test fun eventCalendarMarksEverySourceDateAndOpensIndividualEventDetails() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            val oldCalendar = AppSettings.feastCalendarId
            val oldMode = AppSettings.calendarViewMode
            try {
                scenario.onActivity { AppSettings.feastCalendarId = "mission-provisional"; AppSettings.calendarViewMode = "month" }
                compose.onNodeWithTag("homeOpenCalendar").performScrollTo()
                compose.onNodeWithTag("homeOpenCalendar").performClick()
                val date = LocalDate.now()
                val events = com.dkaluta.prosary.content.today.CalendarEvents.events(date, TodayInfoStore.feast())
                assertTrue(events.isNotEmpty())
                compose.onNodeWithTag("calendarDate.$date", useUnmergedTree = true).assertExists()
                captureScreenshot("calendar-events")
                compose.onNodeWithTag("calendar.monthPicker").performScrollToNode(hasTestTag("calendarEvent.${events.first().id}"))
                compose.onNodeWithTag("calendarEvent.${events.first().id}").performClick()
                compose.onNodeWithText(app.getString(R.string.calendar_event_details)).assertExists()
                captureScreenshot("event-details")
                compose.onNodeWithTag("calendarEventReadings").performClick()
                compose.onNodeWithTag("readingsList").assertExists()
                compose.onNodeWithTag("readingsMode.daily").assertDoesNotExist()
            } finally {
                scenario.onActivity { AppSettings.feastCalendarId = oldCalendar; AppSettings.calendarViewMode = oldMode }
            }
        }
    }

    @Test fun customizingCardsSurvivesRecreationAndRemovingEveryCardKeepsHomeEmpty() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            awaitHome()
            compose.onNodeWithTag("tab.home").assertIsSelected()
            compose.onNodeWithTag("tab.browse").assertDoesNotExist()
            compose.onNodeWithTag("homeCustomize").performClick()
            compose.onNodeWithTag("homeWidgetRemove.readings").performClick()
            compose.onNodeWithTag("homeWidgetAdd.reflection").performScrollTo().performClick()
            compose.onNodeWithText(app.getString(R.string.common_done)).performClick()
            scenario.recreate()
            awaitHome()
            compose.onNodeWithTag("homeWidget.readings").assertDoesNotExist()
            compose.onNodeWithTag("homeWidget.reflection").performScrollTo()
            compose.onNodeWithText(app.getString(R.string.home_widgets_reflection_pending)).assertExists()
            scenario.onActivity { AppSettings.homeWidgetOrder = emptyList() }
            scenario.recreate()
            awaitHome()
            compose.onNodeWithText(app.getString(R.string.home_widgets_empty)).assertExists()
            assertEquals("", preferences.getString("homeWidgetOrder", null))
        }
    }

    @Test fun scriptureAndCalendarShortcutsKeepTheChosenDateAndCommunityLivesInSearch() = withFreshHome {
        ActivityScenario.launch(MainActivity::class.java).use {
            awaitHome()
            compose.onNodeWithTag("tab.readings").performClick()
            compose.onNodeWithTag("readingsPrevious").performClick()
            compose.onNodeWithTag("tab.home").performClick()
            val selected = LocalDate.now().minusDays(1)
            val locale = app.resources.configuration.locales[0]
            compose.onNodeWithTag("homeDate").assertTextContains(selected.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale)))
            compose.onNodeWithTag("homeWidget.scripture").performScrollTo()
            compose.onNodeWithTag("homeWidget.scripture").performClick()
            compose.onNodeWithTag("homeReference.bible").assertExists()
            compose.onNodeWithTag("bibleScreen").assertExists()
            pressBack()
            compose.onNodeWithTag("tab.home").assertIsSelected()
            compose.onNodeWithTag("homeOpenCalendar").performScrollTo()
            compose.onNodeWithTag("homeOpenCalendar").performClick()
            compose.onNodeWithTag("homeReference.calendar").assertExists()
            pressBack()
            compose.onNodeWithTag("tab.home").assertIsSelected()
            compose.onNodeWithTag("tab.readings").performClick()
            compose.onNodeWithTag("readingsMode.bible").assertDoesNotExist()
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(selected.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)))
            compose.onNodeWithTag("tab.search").performClick()
            compose.onNodeWithTag("searchCommunity").performClick()
            compose.onNodeWithTag("searchQuery").assertDoesNotExist()
            compose.onNodeWithText(app.getString(R.string.home_widgets_community)).assertExists()
        }
    }

    private val app get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val preferences get() = app.getSharedPreferences("prosary_settings", Context.MODE_PRIVATE)

    private fun awaitHome() = compose.waitUntil(15_000) {
        compose.onAllNodes(hasTestTag("homeDashboard")).fetchSemanticsNodes().isNotEmpty()
    }

    private fun captureScreenshot(name: String) {
        if (InstrumentationRegistry.getArguments().getString("captureHomeScreenshots") != "true") return
        compose.waitForIdle()
        val automation = InstrumentationRegistry.getInstrumentation().uiAutomation
        automation.waitForIdle(500, 5_000)
        val bitmap = requireNotNull(automation.takeScreenshot())
        val directory = java.io.File(app.getExternalFilesDir(null), "homeScreenshots").apply { mkdirs() }
        java.io.File(directory, "$name.png").outputStream().use { bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
    }

    private fun withFreshHome(block: () -> Unit) {
        val original = preferences.getString("homeWidgetOrder", null)
        val collapsed = preferences.getString("homeWidgetCollapsedIds", null)
        val graphics = preferences.getString("homeWidgetGraphicPaths", null)
        val photo = preferences.getString("homePhotoPath", null)
        val colors = preferences.getString("homeWidgetColors", null)
        try {
            preferences.edit().putString("homeWidgetOrder", HomeWidget.defaults.joinToString("\n") { it.id })
                .putString("homeWidgetCollapsedIds", "").putString("homeWidgetGraphicPaths", "{}").putString("homePhotoPath", "")
                .putString("homeWidgetColors", "{}").commit()
            block()
        } finally {
            preferences.edit().apply {
                if (original == null) remove("homeWidgetOrder") else putString("homeWidgetOrder", original)
                if (collapsed == null) remove("homeWidgetCollapsedIds") else putString("homeWidgetCollapsedIds", collapsed)
                if (graphics == null) remove("homeWidgetGraphicPaths") else putString("homeWidgetGraphicPaths", graphics)
                if (photo == null) remove("homePhotoPath") else putString("homePhotoPath", photo)
                if (colors == null) remove("homeWidgetColors") else putString("homeWidgetColors", colors)
            }.commit()
            InstrumentationRegistry.getInstrumentation().runOnMainSync { AppSettings.init(app) }
        }
    }
}
