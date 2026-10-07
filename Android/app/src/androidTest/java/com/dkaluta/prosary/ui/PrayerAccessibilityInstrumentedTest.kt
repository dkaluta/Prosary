package com.dkaluta.prosary.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsOn
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.ui.favorites.SwitchRow
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.Rule
import org.junit.Test

class PrayerAccessibilityInstrumentedTest {
    @get:Rule val compose = createComposeRule()

    @Test fun settingSwitchAnnouncesItsNameAndValueAtLargeText() {
        compose.setContent {
            val density = LocalDensity.current
            CompositionLocalProvider(LocalDensity provides Density(density.density, fontScale = 2f)) {
                ProsaryTheme {
                    var enabled by remember { mutableStateOf(false) }
                    Column(Modifier.width(320.dp)) {
                        SwitchRow("Prayer reminders", enabled) { enabled = it }
                    }
                }
            }
        }
        compose.onNodeWithContentDescription("Prayer reminders").assertIsDisplayed().assertIsOff()
            .performClick().assertIsOn()
    }

    @Test fun scriptToggleAnnouncesTheActionForTheTextActuallyShown() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        AppSettings.init(context)
        val originalScript = AppSettings.aramaicDefaultScript
        try {
            AppSettings.setAramaicDefaultScript("Hebr")
            compose.setContent {
                ProsaryTheme {
                    PrayerStepFlowScreen(title = "Aramaic prayer",
                        step = RosaryStep(title = "Prayer", body = "אבא", transliteratedBody = "ܐܒܐ"),
                        currentIndex = 0, totalSteps = 1, seasonColor = Color.Green,
                        isRightToLeft = true, languageCode = "arc", canGoBack = false,
                        onBack = {}, onNext = {}, onNavigateUp = {}, speechAvailable = false)
                }
            }
            compose.onNodeWithText("אבא").assertIsDisplayed()
            compose.onNodeWithContentDescription(context.getString(R.string.flow_show_transliteration))
                .assertIsDisplayed().performClick()
            compose.onNodeWithText("ܐܒܐ").assertIsDisplayed()
            compose.onNodeWithContentDescription(context.getString(R.string.flow_show_original_text))
                .assertIsDisplayed().performClick()
            compose.onNodeWithText("אבא").assertIsDisplayed()
            compose.onNodeWithTag("transliterationToggle").assertIsDisplayed()
        } finally {
            AppSettings.setAramaicDefaultScript(originalScript)
        }
    }
}
