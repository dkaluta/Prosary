package com.dkaluta.prosary

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AngelusFlowInstrumentedTest {
    @get:Rule
    val composeTestRule = createAndroidComposeRule<MainActivity>()

    @Test
    fun angelusFlowFromPrayToFinish() {
        composeTestRule.onNodeWithTag("tab.pray").performClick()
        composeTestRule.onNodeWithTag("angelusCard").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()

        // 11 default steps: the three Glory Bes and Eternal Rest follow the collect.
        repeat(10) {
            composeTestRule.onNodeWithText("Next").performClick()
        }

        composeTestRule.onNodeWithText("Finish").performClick()

        // Back at Pray.
        composeTestRule.onNodeWithTag("rosaryCard").assertIsDisplayed()
    }

    @Test
    fun angelusBackButtonReturnsToPreviousStep() {
        composeTestRule.onNodeWithTag("tab.pray").performClick()
        composeTestRule.onNodeWithTag("angelusCard").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()

        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Hail Mary").assertIsDisplayed()

        composeTestRule.onNodeWithText("Back").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()
    }
}
