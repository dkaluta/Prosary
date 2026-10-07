package com.dkaluta.prosary.ui

import android.content.Context
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.pressBack
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.HomeWidget
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test

class HomeDashboardInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

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
            compose.onNodeWithTag("homeDashboard").performScrollToNode(hasTestTag("homeWidget.reflection"))
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
            compose.onNodeWithTag("homeDashboard").performScrollToNode(hasTestTag("homeWidget.scripture"))
            compose.onNodeWithTag("homeWidget.scripture").performClick()
            compose.onNodeWithTag("readingsMode.bible").assertIsSelected()
            compose.onNodeWithTag("tab.home").performClick()
            compose.onNodeWithTag("homeDashboard").performScrollToNode(hasTestTag("homeOpenCalendar"))
            compose.onNodeWithTag("homeOpenCalendar").performClick()
            pressBack()
            compose.onNodeWithTag("readingsMode.daily").assertIsSelected()
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

    private fun withFreshHome(block: () -> Unit) {
        val original = preferences.getString("homeWidgetOrder", null)
        try {
            preferences.edit().putString("homeWidgetOrder", HomeWidget.defaults.joinToString("\n") { it.id }).commit()
            block()
        } finally {
            preferences.edit().apply {
                if (original == null) remove("homeWidgetOrder") else putString("homeWidgetOrder", original)
            }.commit()
            InstrumentationRegistry.getInstrumentation().runOnMainSync { AppSettings.init(app) }
        }
    }
}
