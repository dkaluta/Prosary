package com.dkaluta.prosary

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotSelected
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dkaluta.prosary.models.AppSettings
import org.junit.Assert.assertFalse
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BasicPrayerPinsInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<MainActivity>()

    @Test fun directoryPinAppearsOnPrayAndDetailUnpinSurvivesReopening() {
        val id = "signOfCross"
        var original = false
        compose.runOnIdle {
            original = id in AppSettings.pinnedBasicPrayerIds
            AppSettings.setBasicPrayerPinned(id, false)
        }
        try {
            compose.onNodeWithTag("prayCards").performScrollToNode(hasTestTag("basicPrayersRow"))
            compose.onNodeWithTag("basicPrayersRow").performClick()
            compose.onNodeWithTag("basicPrayersList").performScrollToNode(hasTestTag("basicPrayerPin:$id"))
            compose.onNodeWithTag("basicPrayerPin:$id").assertIsNotSelected().performClick().assertIsSelected()

            pressBack()
            compose.onNodeWithTag("prayCards").performScrollToNode(hasTestTag("basicPrayerCard:$id"))
            compose.onNodeWithTag("basicPrayerCard:$id").assertIsDisplayed().performClick()
            compose.onNodeWithTag("basicPrayerPin:$id").assertIsSelected().performClick().assertIsNotSelected()
            pressBack()
            compose.onNodeWithTag("basicPrayerCard:$id").assertDoesNotExist()

            compose.activityRule.scenario.recreate()
            compose.runOnIdle { assertFalse(id in AppSettings.pinnedBasicPrayerIds) }
            compose.onNodeWithTag("prayCards").performScrollToNode(hasTestTag("basicPrayersRow"))
            compose.onNodeWithTag("basicPrayersRow").performClick()
            compose.onNodeWithTag("basicPrayersList").performScrollToNode(hasTestTag("basicPrayerPin:$id"))
            compose.onNodeWithTag("basicPrayerPin:$id").assertIsNotSelected()
        } finally {
            compose.runOnIdle { AppSettings.setBasicPrayerPinned(id, original) }
        }
    }
}
