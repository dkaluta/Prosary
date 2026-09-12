package com.dkaluta.prosary.ui

import androidx.compose.ui.test.assertTextContains
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.lifecycle.Lifecycle
import androidx.test.core.app.ActivityScenario
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test

class ReadingsExpansionInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun passagesOpenPerVisitAndDateWhileCollapseSurvivesRefresh() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("todayChooseDate")).fetchSemanticsNodes().isNotEmpty() }
            val originalCalendar = AppSettings.feastCalendarId
            val originalEdition = AppSettings.readingsEditionId
            val originalTorah = AppSettings.showTodayTorahPortion
            val today = LocalDate.now()
            val dates = listOf(today, today.minusDays(1))
            val citation = """{"type":"reading","short":"Gen. 1","full":"Genesis 1:1"}"""
            val daily = dates.joinToString(",") { """"$it":{"readings":[$citation]}""" }
            val torah = dates.joinToString(",") { """"$it":{"saturday":"$today","title":"Fixture portion","readings":[$citation]}""" }
            try {
                scenario.onActivity {
                    TodayInfoStore.resetForTesting()
                    TodayInfoStore.initialize { name ->
                        when (name) {
                            "calendars" -> """{"default":"fixture","calendars":[{"id":"fixture","name":"Fixture calendar","file":"fixture-feasts","readingsFile":"fixture-readings"},{"id":"fixture-other","name":"Other fixture calendar","file":"fixture-feasts","readingsFile":"fixture-readings"}]}""".byteInputStream()
                            "fixture-readings" -> """{"days":{$daily}}""".byteInputStream()
                            "torah-portions" -> """{"days":{$torah}}""".byteInputStream()
                            else -> null
                        }
                    }
                    AppSettings.feastCalendarId = "fixture"
                    AppSettings.readingsEditionId = "fixture-unavailable"
                    AppSettings.showTodayTorahPortion = true
                }
                compose.onNodeWithText(context.getString(R.string.tab_readings)).performClick()
                assertExpansion("daily", true)
                assertExpansion("torah", true)
                toggle("daily")
                toggle("torah")
                scenario.onActivity { AppSettings.readingsEditionId = "fixture-other-unavailable" }
                scenario.moveToState(Lifecycle.State.STARTED)
                scenario.moveToState(Lifecycle.State.RESUMED)
                assertExpansion("daily", false)
                assertExpansion("torah", false)

                navigateDate("readingsPrevious")
                assertExpansion("daily", true)
                assertExpansion("torah", true)
                navigateDate("readingsNext")
                assertExpansion("daily", true)
                toggle("daily")
                scenario.onActivity { AppSettings.feastCalendarId = "fixture-other" }
                // Calendar preferences refresh when the reader returns to the foreground.
                scenario.moveToState(Lifecycle.State.STARTED)
                scenario.moveToState(Lifecycle.State.RESUMED)
                assertExpansion("daily", true)
                toggle("daily")
                toggle("torah")
                compose.onNodeWithText(context.getString(R.string.tab_pray)).performClick()
                compose.onNodeWithText(context.getString(R.string.tab_readings)).performClick()
                assertExpansion("daily", true)
                assertExpansion("torah", true)
            } finally {
                scenario.onActivity {
                    TodayInfoStore.resetForTesting()
                    TodayInfoStore.initialize { name -> context.assets.open("data/$name.json") }
                    AppSettings.feastCalendarId = originalCalendar
                    AppSettings.readingsEditionId = originalEdition
                    AppSettings.showTodayTorahPortion = originalTorah
                }
            }
        }
    }

    private fun assertExpansion(kind: String, expanded: Boolean) {
        val tag = "readingExpand.$kind.Genesis 1:1"
        compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag(tag))
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        compose.onNodeWithTag(tag).assertTextContains(context.getString(
            if (expanded) R.string.readings_hide_text else R.string.readings_show_text))
    }

    private fun toggle(kind: String) {
        val tag = "readingExpand.$kind.Genesis 1:1"
        compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag(tag))
        compose.onNodeWithTag(tag).performClick()
    }

    private fun navigateDate(tag: String) {
        compose.onNodeWithTag("readingsList").performScrollToNode(hasTestTag(tag))
        compose.onNodeWithTag(tag).performClick()
    }
}
