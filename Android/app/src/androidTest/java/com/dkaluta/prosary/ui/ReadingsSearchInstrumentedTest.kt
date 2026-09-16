package com.dkaluta.prosary.ui

import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ReadingsSearchInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun readingsDateAndSearchCategorySurviveTabsAndActivityRecreation() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("todayChooseDate")).fetchSemanticsNodes().isNotEmpty() }
            assertDateControlHeights("todayYesterday", "todayChooseDate", "todayTomorrow")
            compose.onNodeWithText(context.getString(R.string.tab_readings)).performClick()
            compose.onNodeWithTag("readingsPrevious").performClick()
            val date = LocalDate.now().minusDays(1).format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)
                .withLocale(context.resources.configuration.locales[0]))
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(date)
            assertDateControlHeights("readingsPrevious", "readingsChooseDate", "readingsNext")
            compose.onNodeWithText(context.getString(R.string.tab_search)).performClick()
            compose.onNodeWithTag("searchCategory.eastern").performScrollTo().performClick().assertIsSelected()
            compose.onNodeWithTag("searchQuery").performTextInput("___No matching prayer___")
            scenario.recreate()
            compose.onNodeWithTag("searchQuery").assertTextContains("___No matching prayer___")
            compose.onNodeWithTag("searchCategory.eastern").performScrollTo().assertIsSelected()
            compose.onNodeWithText(context.getString(R.string.search_no_device_match)).performScrollTo().assertExists()
            compose.onNodeWithTag("searchCategoryAll").performScrollTo().performClick().assertIsSelected()
            compose.onNodeWithText(context.getString(R.string.tab_readings)).performClick()
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(date)
            compose.onNodeWithTag("readingsChooseDate").performClick()
            compose.onNodeWithTag("readingsReset").performClick()
            val today = LocalDate.now().format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)
                .withLocale(context.resources.configuration.locales[0]))
            compose.onNodeWithTag("readingsChooseDate").assertTextContains(today)
            // Browsing the independent Readings reference leaves Pray's Today untouched.
            compose.onNodeWithText(context.getString(R.string.tab_pray)).performClick()
            compose.onNodeWithTag("todayChooseDate").assertTextContains(today)
        }
    }

    private fun assertDateControlHeights(previous: String, date: String, next: String) {
        val density = InstrumentationRegistry.getInstrumentation().targetContext.resources.displayMetrics.density
        val dateHeight = compose.onNodeWithTag(date).fetchSemanticsNode().boundsInRoot.height
        for (tag in listOf(previous, date, next)) {
            val height = compose.onNodeWithTag(tag).fetchSemanticsNode().boundsInRoot.height
            assertEquals("$tag must match the date button height", dateHeight, height, 1f)
            assertTrue("$tag must retain a 48dp touch target", height >= 48f * density - 1f)
        }
    }
}
