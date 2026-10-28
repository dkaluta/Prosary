package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToIndex
import androidx.compose.ui.test.performSemanticsAction
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.test.performMouseInput
import androidx.compose.ui.test.swipeLeft
import androidx.compose.ui.test.swipeRight
import androidx.compose.ui.text.TextLayoutResult
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.ui.AdaptiveLayoutTestActivity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class BibleBookReaderInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()
    private var width by mutableStateOf(900.dp)
    private var anchor by mutableStateOf("row.0")
    private var jump by mutableStateOf<String?>(null)
    private var jumpSerial by mutableIntStateOf(0)

    private fun showReader(scriptureDirection: LayoutDirection, fontScale: Float = 1f, usesBookTypography: Boolean = false) {
        val texts = (0..11).map { index -> "$index " +
            (if (scriptureDirection == LayoutDirection.Rtl) "טקסט לדוגמה לקריאה בספר. " else "Source text in its printed order. ").repeat(40) }
        compose.setContent {
            CompositionLocalProvider(LocalDensity provides Density(0.5f, fontScale),
                // The Scripture direction is deliberately opposite the app interface.
                LocalLayoutDirection provides if (scriptureDirection == LayoutDirection.Rtl) LayoutDirection.Ltr else LayoutDirection.Rtl) {
                MaterialTheme {
                    val style = MaterialTheme.typography.bodyLarge
                    Box(Modifier.size(width, 850.dp)) {
                        BibleAdaptiveChapterReader(texts.indices.map { "row.$it" },
                            texts.mapIndexed { index, text -> BiblePageMeasurement(listOf(
                                (if (usesBookTypography) BibleBookTypography.body(text, (index + 1).toString()) else AnnotatedString(text)) to
                                    style.copy(textAlign = if (usesBookTypography) TextAlign.Justify else TextAlign.Unspecified))) }, rememberLazyListState(),
                            scriptureDirection, anchor, { anchor = it }, jumpSerial, jump,
                            paragraphContent = { range -> Text(range.joinToString(" ") { texts[it] }, style = style) }) { index ->
                            val book = usesBookTypography && LocalBibleBookMode.current
                            Text(if (book) BibleBookTypography.body(texts[index], (index + 1).toString()) else AnnotatedString(texts[index]),
                                style = style, textAlign = if (book) TextAlign.Justify else TextAlign.Unspecified,
                                modifier = Modifier.fillMaxWidth().testTag("bookRow.$index"))
                        }
                    }
                }
            }
        }
    }

    @Test fun narrowPagesJoinVersesAndContinueAtEditionSectionBoundaries() {
        var forward = 0
        var backward = 0
        compose.setContent {
            MaterialTheme {
                val style = MaterialTheme.typography.bodyLarge.copy(textAlign = TextAlign.Justify)
                val parts = listOf(BibleBookTypography.body("In the beginning.", "1"),
                    BibleBookTypography.body("And the earth.", "2"))
                Box(Modifier.size(400.dp, 600.dp)) {
                    BibleAdaptiveChapterReader(listOf("first", "second"),
                        parts.map { BiblePageMeasurement(listOf(it to style), flowing = true) },
                        rememberLazyListState(), LayoutDirection.Ltr, "first", {}, 0, null,
                        previousSection = { backward++ }, nextSection = { forward++ },
                        paragraphContent = { range ->
                            Text(androidx.compose.ui.text.buildAnnotatedString {
                                range.forEachIndexed { index, value ->
                                    if (index > 0) append(" ")
                                    append(parts[value])
                                }
                            }, style = style, modifier = Modifier.fillMaxWidth().testTag("joinedVerses"))
                        }, rowContent = { Text(parts[it], style = style) })
                }
            }
        }
        compose.onNodeWithTag("joinedVerses").assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag("joinedVerses").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        assertEquals(TextAlign.Justify, layouts.single().layoutInput.style.textAlign)
        assertEquals(2, layouts.single().layoutInput.text.spanStyles.size)
        assertTrue(layouts.single().layoutInput.text.text.contains("And the earth."))
        compose.onNodeWithTag("bibleNextPage").performClick()
        compose.onNodeWithTag("biblePreviousPage").performClick()
        compose.runOnIdle { assertEquals(1, forward); assertEquals(1, backward) }
    }

    @Test fun scriptureOrdersPagesAndControlsAndKeepsItsBlockAcrossNarrowWideChanges() {
        showReader(LayoutDirection.Ltr)
        val first = compose.onNodeWithTag("biblePage.0").fetchSemanticsNode().boundsInRoot
        val second = compose.onNodeWithTag("biblePage.1").fetchSemanticsNode().boundsInRoot
        assertTrue(first.right < second.left)
        val previous = compose.onNodeWithTag("biblePreviousPage").fetchSemanticsNode().boundsInRoot
        val next = compose.onNodeWithTag("bibleNextPage").fetchSemanticsNode().boundsInRoot
        assertTrue(previous.left < next.left)
        compose.onNodeWithTag("bibleNextPage").performClick()
        val selected = compose.runOnIdle { anchor }
        assertNotEquals("row.0", selected)
        compose.runOnIdle { width = 400.dp }
        compose.onNodeWithTag("bookRow.${selected.substringAfter('.')}").assertIsDisplayed()
        compose.runOnIdle { anchor = "row.8"; jump = "row.8"; jumpSerial++ }
        compose.onNodeWithTag("bookRow.8").assertIsDisplayed()
        compose.runOnIdle { assertEquals("row.8", anchor); width = 900.dp }
        compose.onNodeWithTag("bookRow.8").assertIsDisplayed()
    }

    @Test fun rightToLeftScriptureTurnsTowardInlineEndIndependentlyOfTheInterface() {
        showReader(LayoutDirection.Rtl)
        val first = compose.onNodeWithTag("biblePage.0").fetchSemanticsNode().boundsInRoot
        val second = compose.onNodeWithTag("biblePage.1").fetchSemanticsNode().boundsInRoot
        assertTrue(first.left > second.right)
        val previous = compose.onNodeWithTag("biblePreviousPage").fetchSemanticsNode().boundsInRoot
        val next = compose.onNodeWithTag("bibleNextPage").fetchSemanticsNode().boundsInRoot
        assertTrue(previous.left > next.left)
        compose.onNodeWithTag("bibleBook").performTouchInput { swipeRight() }
        compose.runOnIdle { assertNotEquals("row.0", anchor) }
        compose.onNodeWithTag("bibleBook").performTouchInput { swipeLeft() }
        compose.runOnIdle { assertEquals("row.0", anchor) }
    }

    @Test fun mouseDragDoesNotTurnPagesWhileTouchSwipeStillDoes() {
        showReader(LayoutDirection.Ltr)
        compose.onNodeWithTag("bibleBook").performMouseInput {
            enter(centerRight)
            press()
            moveTo(centerLeft, delayMillis = 300)
            release()
            exit()
        }
        compose.runOnIdle { assertEquals("row.0", anchor) }
        compose.onNodeWithTag("bibleBook").performTouchInput { swipeLeft() }
        compose.runOnIdle { assertNotEquals("row.0", anchor) }
    }

    @Test fun verseTargetOpensItsPhysicalPageAndLargeTextIsNeverTruncated() {
        showReader(LayoutDirection.Ltr, fontScale = 2f)
        compose.runOnIdle { anchor = "row.9"; jump = anchor; jumpSerial++ }
        compose.onNodeWithTag("bookRow.9").assertIsDisplayed()
        val layouts = mutableListOf<TextLayoutResult>()
        compose.onNodeWithTag("bookRow.9").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(layouts) }
        assertFalse(layouts.single().didOverflowHeight)
        assertFalse(layouts.single().didOverflowWidth)
        assertEquals(2f, layouts.single().layoutInput.density.fontScale)
        compose.onNodeWithTag("bookRow.9").assertTextEquals("9 " + "Source text in its printed order. ".repeat(40))
    }

    @Test fun justifiedTextAndRaisedMarkersAreScopedToTheBookPages() {
        showReader(LayoutDirection.Ltr, usesBookTypography = true)
        fun layout(): TextLayoutResult {
            val results = mutableListOf<TextLayoutResult>()
            compose.onNodeWithTag("bookRow.0").performSemanticsAction(SemanticsActions.GetTextLayoutResult) { it(results) }
            return results.single()
        }
        val book = layout()
        assertEquals(TextAlign.Justify, book.layoutInput.style.textAlign)
        assertEquals(1, book.layoutInput.text.spanStyles.size)
        assertTrue(book.layoutInput.text.text.startsWith("\u20681\u2069\u00a0"))
        compose.runOnIdle { width = 400.dp }
        val narrow = layout()
        assertEquals(TextAlign.Justify, narrow.layoutInput.style.textAlign)
        assertEquals(1, narrow.layoutInput.text.spanStyles.size)
        assertTrue(narrow.layoutInput.text.text.startsWith("\u20681\u2069\u00a0"))
    }
}
