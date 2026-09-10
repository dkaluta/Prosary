package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModelProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.typography.PrayerTypography
import com.dkaluta.prosary.ui.AdaptiveLayoutTestActivity
import com.dkaluta.prosary.ui.rosaryflow.BeadColumn
import com.dkaluta.prosary.ui.rosaryflow.BeadInfo
import com.dkaluta.prosary.ui.rosaryflow.BeadKind
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import com.dkaluta.prosary.ui.rosaryflow.BeadProgressView
import com.dkaluta.prosary.ui.rosaryflow.BeadState
import com.dkaluta.prosary.ui.rosaryflow.beadWideWidth
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PrayerReadingLayoutInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()
    private val width = mutableStateOf(400.dp)
    private val currentStep = mutableIntStateOf(7)
    private val groups = MysteryGroup.entries.map { group ->
        BeadColumn(group = group, beads = List(5) { BeadInfo(kind = BeadKind.Decade, state = BeadState.Upcoming) })
    }
    private val beads = BeadLayout(
        topRows = groups.map { it.beads }, groupColumns = groups,
        bottomBeads = List(10) { BeadInfo(kind = BeadKind.Decade, state = BeadState.Upcoming) },
        showBottomBeads = true,
    )

    private fun showReader(rtl: Boolean = false, fontScale: Float = 1f, suppliedStep: RosaryStep? = null, counter: Boolean = false) {
        val sample = if (rtl) "קטע בדיקה של פריסת טקסט. ".repeat(16) else "Sample text for testing a resized reading column. ".repeat(12)
        val step = suppliedStep ?: RosaryStep(id = "resize-fixture", title = "Reading layout test", body =
            (0 until 35).joinToString("\n\n") { "$it $sample" })
        compose.setContent {
            // Deterministic dp widths fit inside the emulator regardless of its real density.
            CompositionLocalProvider(LocalDensity provides Density(0.5f, fontScale)) {
                ProsaryTheme {
                    Box(Modifier.size(width.value, 1000.dp)) {
                        PrayerStepFlowScreen(
                            title = "Reading layout test", step = step, currentIndex = currentStep.intValue,
                            totalSteps = 100, seasonColor = Color.Green,
                            isRightToLeft = rtl, languageCode = if (rtl) "he" else "en",
                            canGoBack = true, onBack = {}, onNext = { currentStep.intValue += 1 }, onNavigateUp = {},
                            sessionPaused = true,
                            centralActionLabel = if (counter) "Count" else null,
                            wideAccessoryWidth = beadWideWidth(beads),
                            accessory = { wide, single -> BeadProgressView(beads, wide, single) },
                        )
                    }
                }
            }
        }
    }

    @Test fun sameParagraphAndOffsetSurviveNarrowWideNarrowWithTwentyMysteries() {
        showReader()
        compose.onNodeWithTag("prayerNarrowLayout").assertIsDisplayed()
        compose.onNodeWithTag("prayerBody").performScrollToIndex(14)
        compose.onNodeWithTag("prayerParagraph:12").assertIsDisplayed()
        val chrome = compose.runOnIdle { ViewModelProvider(compose.activity)[PrayerFlowChromeState::class.java] }
        val anchor = compose.runOnIdle { chrome.reading.firstVisibleItemIndex to chrome.reading.firstVisibleItemScrollOffset }

        // At 840dp a short viewport can fit the compact artwork, while a tall viewport
        // needs the narrow layout. Both must keep the reader inside the available width.
        compose.runOnIdle { width.value = 840.dp }
        val intermediate = compose.onNodeWithTag("prayerBody").fetchSemanticsNode().boundsInRoot
        val intermediateLayout = compose.onNode(
            hasTestTag("prayerNarrowLayout") or hasTestTag("prayerWideLayout"),
        ).fetchSemanticsNode().boundsInRoot
        assertTrue(intermediate.width >= 280 * 0.5f)
        assertTrue(intermediate.left >= intermediateLayout.left && intermediate.right <= intermediateLayout.right)
        compose.onNodeWithTag("prayerParagraph:12").assertIsDisplayed()
        compose.runOnIdle { width.value = 1100.dp }
        compose.onNodeWithTag("prayerWideLayout").assertIsDisplayed()
        compose.onNodeWithTag("prayerParagraph:12").assertIsDisplayed()
        compose.runOnIdle { assertEquals(anchor, chrome.reading.firstVisibleItemIndex to chrome.reading.firstVisibleItemScrollOffset) }

        compose.runOnIdle { width.value = 400.dp }
        compose.onNodeWithTag("prayerNarrowLayout").assertIsDisplayed()
        compose.onNodeWithTag("prayerParagraph:12").assertIsDisplayed()
        compose.runOnIdle { assertEquals(anchor, chrome.reading.firstVisibleItemIndex to chrome.reading.firstVisibleItemScrollOffset) }
    }

    @Test fun wideRtlReadingAndDoubleSizeTextStayInsideTheAvailableColumn() {
        width.value = 1100.dp
        showReader(rtl = true, fontScale = 2f)
        compose.onNodeWithTag("prayerBody").performScrollToIndex(14)
        val layout = compose.onNodeWithTag("prayerWideLayout").fetchSemanticsNode().boundsInRoot
        val reading = compose.onNodeWithTag("prayerBody").fetchSemanticsNode().boundsInRoot
        val accessory = compose.onNodeWithTag("prayerAccessory").fetchSemanticsNode().boundsInRoot
        assertTrue(reading.left >= layout.left && reading.right <= layout.right)
        assertTrue(reading.top >= layout.top && reading.bottom <= layout.bottom)
        assertTrue(accessory.right <= reading.left)
        val results = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag("prayerParagraph:12").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
        assertEquals(LayoutDirection.Rtl, results.single().layoutInput.layoutDirection)
        assertEquals(2f, results.single().layoutInput.density.fontScale)
        assertFalse(results.single().didOverflowWidth)
        assertFalse(results.single().didOverflowHeight)
    }

    @Test fun alternateScriptUsesItsOwnTypefaceAfterResizing() {
        width.value = 1100.dp
        val original = "אבגדהוז ".repeat(12)
        val alternate = "Alphabet sample text. ".repeat(12)
        showReader(rtl = true, suppliedStep = RosaryStep(
            id = "alternate-script-fixture", title = "Alphabet sample",
            body = original, transliteratedBody = alternate,
        ))
        fun assertBodyTypeface(body: String) {
            val results = mutableListOf<TextLayoutResult>()
            compose.onNodeWithTag("prayerParagraph:0").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
            assertEquals(body, results.single().layoutInput.text.text)
            assertEquals(PrayerTypography.styleForText(body, false).fontFamily,
                results.single().layoutInput.style.fontFamily)
        }
        assertBodyTypeface(original)
        compose.onNodeWithContentDescription(compose.activity.getString(R.string.flow_show_transliteration)).performClick()
        assertBodyTypeface(alternate)
        compose.runOnIdle { width.value = 400.dp }
        compose.onNodeWithTag("prayerBody").performScrollToIndex(2)
        assertBodyTypeface(alternate)
    }

    @Test fun changingThePrayerStepStartsItsReadingAtTheTop() {
        showReader()
        compose.onNodeWithTag("prayerBody").performScrollToIndex(14)
        val chrome = compose.runOnIdle { ViewModelProvider(compose.activity)[PrayerFlowChromeState::class.java] }
        compose.runOnIdle {
            assertEquals(14, chrome.reading.firstVisibleItemIndex)
            currentStep.intValue += 1
        }
        compose.waitForIdle()
        compose.runOnIdle {
            assertEquals(0, chrome.reading.firstVisibleItemIndex)
            assertEquals(0, chrome.reading.firstVisibleItemScrollOffset)
        }
    }

    @Test fun repeatingTheSameCounterPrayerKeepsItsButtonAndReadingPosition() {
        showReader(counter = true)
        compose.onNodeWithTag("prayerBody").performScrollToIndex(37)
        compose.onNodeWithText("Count").assertIsDisplayed()
        val chrome = compose.runOnIdle { ViewModelProvider(compose.activity)[PrayerFlowChromeState::class.java] }
        val anchor = compose.runOnIdle { chrome.reading.firstVisibleItemIndex to chrome.reading.firstVisibleItemScrollOffset }
        repeat(4) { compose.onNodeWithText("Count").performClick() }
        compose.onNodeWithText("Count").assertIsDisplayed()
        compose.runOnIdle {
            assertEquals(11, currentStep.intValue)
            assertEquals(anchor, chrome.reading.firstVisibleItemIndex to chrome.reading.firstVisibleItemScrollOffset)
        }
    }
}
