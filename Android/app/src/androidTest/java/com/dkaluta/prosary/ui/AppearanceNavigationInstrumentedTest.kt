package com.dkaluta.prosary.ui

import android.os.Build
import android.graphics.Bitmap
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.v2.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performSemanticsAction
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.pressBack
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.LauncherIconController
import com.dkaluta.prosary.MainActivity
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.AppSettings
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import java.io.File
import java.io.FileOutputStream

class AppearanceNavigationInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()

    @Test fun choosingColorsStaysOnAppearanceAndBackRestoresSettings() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            compose.waitUntil(15_000) { compose.onAllNodes(hasTestTag("todayChooseDate")).fetchSemanticsNodes().isNotEmpty() }
            val originalColor = AppSettings.appColor
            val originalSystemColors = AppSettings.useSystemColors
            try {
                compose.onNodeWithContentDescription(context.getString(R.string.common_settings)).performClick()
                compose.onNodeWithTag("settingsAppearance").performScrollTo().assertIsDisplayed()
                compose.onNodeWithTag("appColorPicker").assertDoesNotExist()
                compose.onNodeWithTag("useSystemColors").assertDoesNotExist()
                compose.onNodeWithTag("settingsList").performSemanticsAction(SemanticsActions.ScrollBy) { it(0f, 48f) }
                val previousScroll = settingsScroll()
                assertTrue(previousScroll > 0f)
                // Two rapid activations must add just one navigation entry.
                val open = requireNotNull(compose.onNodeWithTag("settingsAppearance").fetchSemanticsNode()
                    .config[SemanticsActions.OnClick].action)
                compose.runOnIdle { open(); open() }
                compose.onNodeWithTag("appearanceScreen").assertExists()
                for (color in AppColor.entries) {
                    compose.onNodeWithTag("appColorIcon.${color.id}", useUnmergedTree = true)
                        .performScrollTo().assertIsDisplayed()
                    if (color == AppColor.Blue || color == AppColor.White) captureScreenshot("appearance-${color.id}")
                }
                compose.onNodeWithTag("appColor.purple").performScrollTo().performClick().assertIsSelected()
                assertEquals("purple", AppSettings.appColor)
                compose.onNodeWithTag("appearanceScreen").assertExists()
                captureScreenshot("appearance-selected")
                if (Build.VERSION.SDK_INT >= 31) {
                    compose.onNodeWithTag("useSystemColors").performScrollTo().performClick()
                    assertEquals(!originalSystemColors, AppSettings.useSystemColors)
                } else compose.onNodeWithTag("useSystemColors").assertDoesNotExist()
                scenario.recreate()
                compose.onNodeWithTag("appearanceScreen").assertExists()
                compose.onNodeWithTag("appColor.purple").performScrollTo().assertIsSelected()
                pressBack()
                compose.onNodeWithTag("settingsAppearance").assertIsDisplayed()
                assertEquals(previousScroll, settingsScroll(), 1f)
                compose.onNodeWithTag("settingsAppearance").performClick()
                compose.onNodeWithContentDescription(context.getString(R.string.common_back)).performClick()
                compose.onNodeWithTag("settingsAppearance").assertIsDisplayed()
            } finally {
                scenario.onActivity {
                    assertTrue(LauncherIconController.select(it, originalColor))
                    AppSettings.useSystemColors = originalSystemColors
                }
            }
        }
    }

    private fun settingsScroll(): Float = compose.onNodeWithTag("settingsList").fetchSemanticsNode()
        .config[SemanticsProperties.VerticalScrollAxisRange].value()

    private fun captureScreenshot(name: String) {
        if (InstrumentationRegistry.getArguments().getString("captureAppearanceScreenshots") != "true") return
        compose.waitForIdle()
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        FileOutputStream(File(instrumentation.targetContext.getExternalFilesDir(null), "$name.png")).use {
            assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it))
        }
        bitmap.recycle()
    }
}
