package com.dkaluta.prosary.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.ui.shared.PrayerStepFlowScreen
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test

/** Checks the reader's common horizontal column and the direction of the text actually shown. */
class PrayerReadingLayoutInstrumentedTest {
    @get:Rule val compose = createComposeRule()
    private var step by mutableStateOf(RosaryStep(title = "Prayer", subtitle = "Context",
        acclamation = "V. Begin.", body = "A short prayer body."))
    private var languageCode = "en"
    private var originalRightToLeft = false
    private var densityForTest = 1f
    private var originalScript = "Hebr"
    private var originalAutoAdvance = 0

    @Before fun prepareSettings() {
        AppSettings.init(InstrumentationRegistry.getInstrumentation().targetContext)
        originalScript = AppSettings.aramaicDefaultScript
        originalAutoAdvance = AppSettings.autoAdvanceSeconds
        AppSettings.setAramaicDefaultScript("Hebr")
        AppSettings.setAutoAdvanceSeconds(0)
    }

    @After fun restoreSettings() {
        AppSettings.setAramaicDefaultScript(originalScript)
        AppSettings.setAutoAdvanceSeconds(originalAutoAdvance)
    }

    @Test fun shortAndLongPrayersShareTheSameHeaderAcclamationAndBodyColumn() {
        showReader()
        val firstColumn = assertCommonColumn()
        compose.runOnIdle {
            step = RosaryStep(title = "A longer prayer heading", subtitle = "A longer context label",
                acclamation = "V. A longer response still shares the prayer column.",
                body = "A longer prayer body uses the same readable margins. ".repeat(40))
        }
        compose.waitForIdle()
        assertHorizontalBounds(firstColumn, assertCommonColumn())
    }

    @Test fun alphabetPickerIsCenteredOnTheReaderInEitherScript() {
        languageCode = "arc"
        originalRightToLeft = true
        step = RosaryStep(title = "Prayer", body = "אבא", transliteratedBody = "ܐܒܐ")
        showReader()
        assertPickerCentered()
        compose.onNodeWithTag("aramaicScript.Syrc").performClick()
        compose.waitForIdle()
        assertPickerCentered()
    }

    @Test fun rightToLeftReadingAidStartsAtTheRightEdgeOfAnOriginallyLtrPrayer() {
        step = RosaryStep(title = "Prayer", body = "A short body.", transliteratedBody = "אבא")
        showReader()
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasTestTag("transliterationToggle"))
        compose.onNodeWithTag("transliterationToggle").performClick()
        compose.waitForIdle()
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasTestTag("prayerParagraph:0"))
        val layouts = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag("prayerParagraph:0", useUnmergedTree = true)
            .performSemanticsAction(SemanticsActions.GetTextLayoutResult) { action -> assertTrue(action(layouts)) }
        val layout = layouts.single()
        assertEquals(LayoutDirection.Rtl, layout.layoutInput.layoutDirection)
        assertEquals(TextAlign.Start, layout.layoutInput.style.textAlign)
        assertEquals(layout.size.width.toFloat(), layout.getLineRight(0), 1f)
        assertTrue("Short RTL text starts at the right side of the common column",
            layout.getLineLeft(0) > layout.size.width / 2f)
    }

    @Test fun wideReaderKeepsTheSameMarginsAndCapsItsViewportWidth() {
        showReader(densityScale = 0.35f)
        compose.onNodeWithTag("prayerWideLayout").assertExists()
        val reader = bounds("prayerBody")
        assertTrue("Wide windows keep a readable column", reader.width <= 640f * densityForTest + 1f)
        assertCommonColumn()
    }

    private fun showReader(densityScale: Float = 1f) {
        compose.setContent {
            val density = LocalDensity.current
            val readerDensity = Density(density.density * densityScale, fontScale = 1f)
            densityForTest = readerDensity.density
            CompositionLocalProvider(LocalDensity provides readerDensity) {
                ProsaryTheme {
                    PrayerStepFlowScreen(title = "Layout test", step = step,
                        currentIndex = 0, totalSteps = 1, seasonColor = Color.Transparent,
                        isRightToLeft = originalRightToLeft, languageCode = languageCode,
                        canGoBack = false, onBack = {}, onNext = {}, onNavigateUp = {},
                        speechAvailable = false)
                }
            }
        }
        compose.waitForIdle()
    }

    private fun assertCommonColumn(): Rect {
        val reader = bounds("prayerBody")
        val header = scrollToBounds("prayerStepTitle")
        val subtitle = requireNotNull(step.subtitle)
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasText(subtitle))
        val subtitleBounds = compose.onNodeWithText(subtitle).fetchSemanticsNode().boundsInRoot
        val acclamation = scrollToBounds("prayerAcclamation")
        val paragraph = scrollToBounds("prayerParagraph:0")
        val padding = 16f * densityForTest
        assertEquals(reader.left + padding, paragraph.left, 1f)
        assertEquals(reader.right - padding, paragraph.right, 1f)
        assertHorizontalBounds(paragraph, header)
        assertHorizontalBounds(paragraph, subtitleBounds)
        assertHorizontalBounds(paragraph, acclamation)
        return paragraph
    }

    private fun assertPickerCentered() {
        scrollToBounds("transliterationToggle")
        val syriac = bounds("aramaicScript.Syrc")
        val hebrew = bounds("aramaicScript.Hebr")
        val pickerCenter = (minOf(syriac.left, hebrew.left) + maxOf(syriac.right, hebrew.right)) / 2f
        assertEquals(bounds("prayerBody").center.x, pickerCenter, 1f)
    }

    private fun scrollToBounds(tag: String): Rect {
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasTestTag(tag))
        return bounds(tag)
    }

    private fun bounds(tag: String) = compose.onNodeWithTag(tag, useUnmergedTree = true)
        .fetchSemanticsNode().boundsInRoot

    private fun assertHorizontalBounds(expected: Rect, actual: Rect) {
        assertEquals(expected.left, actual.left, 1f)
        assertEquals(expected.right, actual.right, 1f)
    }
}
