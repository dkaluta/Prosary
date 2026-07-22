package com.dkaluta.Prosary

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
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
    fun angelusFlowFromHomeToFinish() {
        composeTestRule.onNodeWithText("The Angelus").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()

        // 7 steps total: tapping Next 6 times reaches the last one, where the button becomes Finish.
        repeat(6) {
            composeTestRule.onNodeWithText("Next").performClick()
        }

        composeTestRule.onNodeWithText("Finish").performClick()

        // Back at Home.
        composeTestRule.onNodeWithText("Pray the Rosary").assertIsDisplayed()
    }

    @Test
    fun angelusBackButtonReturnsToPreviousStep() {
        composeTestRule.onNodeWithText("The Angelus").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()

        composeTestRule.onNodeWithText("Next").performClick()
        composeTestRule.onNodeWithText("Hail Mary").assertIsDisplayed()

        composeTestRule.onNodeWithText("Back").performClick()
        composeTestRule.onNodeWithText("The Annunciation").assertIsDisplayed()
    }
}
