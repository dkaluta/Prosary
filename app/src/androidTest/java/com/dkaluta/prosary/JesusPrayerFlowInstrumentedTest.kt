package com.dkaluta.prosary

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsEnabled
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class JesusPrayerFlowInstrumentedTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun boundedTargetDefaultsTo33AndTracksCount() {
        composeTestRule.onNodeWithTag("jesusPrayerCard").performClick()
        composeTestRule.onNodeWithText("33").assertIsSelected()

        composeTestRule.onNodeWithText("Begin").performClick()
        composeTestRule.onNodeWithText("1 of 33").assertIsDisplayed()

        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("3 of 33").assertIsDisplayed()

        composeTestRule.onNodeWithText("Back").performClick()
        composeTestRule.onNodeWithText("2 of 33").assertIsDisplayed()
    }

    @Test
    fun unboundedTargetHasNoFixedTotalAndAlwaysOffersFinish() {
        composeTestRule.onNodeWithTag("jesusPrayerCard").performClick()
        composeTestRule.onNodeWithText("Unbounded").performClick()
        composeTestRule.onNodeWithText("Begin").performClick()

        composeTestRule.onNodeWithText("1").assertIsDisplayed()
        composeTestRule.onNodeWithText("1 of 33").assertDoesNotExist()

        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("3").assertIsDisplayed()
        // The footer button never turns into "Finish" for an unbounded session — only the
        // separate top-bar action (checked below) can end it.
        composeTestRule.onNodeWithText("Next").assertIsDisplayed()

        composeTestRule.onNodeWithText("Finish").performClick()
        composeTestRule.onNodeWithTag("rosaryCard").assertIsDisplayed()
    }

    @Test
    fun customTargetRequiresAValidNumberBeforeBeginIsEnabled() {
        composeTestRule.onNodeWithTag("jesusPrayerCard").performClick()
        composeTestRule.onNodeWithText("Custom").performClick()

        composeTestRule.onNodeWithText("Begin").assertIsNotEnabled()

        composeTestRule.onNodeWithText("Number of repetitions").performTextInput("12")

        composeTestRule.onNodeWithText("Begin").assertIsEnabled()
        composeTestRule.onNodeWithText("Begin").performClick()
        composeTestRule.onNodeWithText("1 of 12").assertIsDisplayed()
    }
}
