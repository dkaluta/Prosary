package com.dkaluta.prosary.ui.readings

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.gestures.awaitEachGesture
import androidx.compose.foundation.gestures.awaitFirstDown
import androidx.compose.foundation.gestures.awaitHorizontalTouchSlopOrCancellation
import androidx.compose.foundation.gestures.horizontalDrag
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.key
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.PointerType
import androidx.compose.ui.input.pointer.positionChange
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleBook
import com.dkaluta.prosary.content.bible.BibleChapterInfo
import com.dkaluta.prosary.content.bible.BibleDisplayChapter
import com.dkaluta.prosary.content.bible.BibleEdition
import com.dkaluta.prosary.content.bible.BibleNavigation
import com.dkaluta.prosary.typography.PrayerTypography
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlin.math.abs

internal data class BiblePageMeasurement(val texts: List<Pair<AnnotatedString, TextStyle>>,
    val extraHeight: Dp = 0.dp, val horizontalInset: Dp = 0.dp)

private data class BibleBookSpread(val firstPage: Int, val turn: Int)

/** The same source rows feed both native reading surfaces. Pagination never rebuilds a verse
 * from its numeric address or substitutes another edition's text. */
@Composable
internal fun BibleAdaptiveChapterReader(
    keys: List<String>, measurements: List<BiblePageMeasurement>, scroll: LazyListState,
    direction: LayoutDirection, anchor: String, onAnchorChange: (String) -> Unit,
    jumpSerial: Int, jumpBlock: String?, rowContent: @Composable (Int) -> Unit,
) {
    val interfaceDirection = LocalLayoutDirection.current
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val bookMode = maxWidth >= 720.dp && maxHeight >= 360.dp
        LaunchedEffect(bookMode, jumpSerial) {
            if (!bookMode) scroll.scrollToItem(keys.indexOf(anchor).coerceAtLeast(0))
        }
        LaunchedEffect(bookMode, scroll, keys) {
            // visibleItemsInfo can include the preceding row inside content padding.
            // firstVisibleItemIndex names the reading viewport rather than that extra row.
            if (!bookMode) snapshotFlow { keys.getOrNull(scroll.firstVisibleItemIndex) }
                .distinctUntilChanged().collect { it?.let(onAnchorChange) }
        }
        SelectionContainer {
            if (bookMode) {
                val density = LocalDensity.current
                val textMeasurer = rememberTextMeasurer(cacheSize = 512)
                val pageWidth = with(density) { ((maxWidth - 64.dp) / 2 - 32.dp).roundToPx().coerceAtLeast(1) }
                val pageHeight = with(density) { (maxHeight - 56.dp - 32.dp).roundToPx().coerceAtLeast(1) }
                val heights = measurements.map { row ->
                    with(density) { row.extraHeight.roundToPx() } + row.texts.sumOf { (text, style) ->
                        textMeasurer.measure(text, style,
                            constraints = Constraints(maxWidth = (pageWidth - with(density) {
                                row.horizontalInset.roundToPx() * 2
                            }).coerceAtLeast(1)), layoutDirection = direction).size.height
                    }
                }
                val pages = BibleBookPagination.pages(heights, pageHeight, with(density) { 12.dp.roundToPx() })
                val start = BibleBookPagination.spreadStart(pages, keys.indexOf(anchor))
                var turnSerial by remember { mutableIntStateOf(0) }
                fun turn(forward: Boolean) {
                    val target = start + if (forward) 2 else -2
                    pages.getOrNull(target)?.first?.let { turnSerial++; onAnchorChange(keys[it]) }
                }
                val threshold = with(density) { 64.dp.toPx() }
                Column(Modifier.fillMaxSize().testTag("bibleBook").pointerInput(direction, start, pages, threshold) {
                    awaitEachGesture {
                        val down = awaitFirstDown(requireUnconsumed = false)
                        // Mouse drags belong to SelectionContainer, not page navigation.
                        if (down.type == PointerType.Mouse) return@awaitEachGesture
                        var distance = 0f
                        val drag = awaitHorizontalTouchSlopOrCancellation(down.id) { change, over ->
                            change.consume()
                            distance = over
                        } ?: return@awaitEachGesture
                        val completed = horizontalDrag(drag.id) { change ->
                            distance += change.positionChange().x
                            change.consume()
                        }
                        if (completed && abs(distance) >= threshold)
                            turn(BibleBookPagination.forwardDrag(distance, direction == LayoutDirection.Rtl))
                    }
                }) {
                    CompositionLocalProvider(LocalLayoutDirection provides direction) {
                        // Compose's animation clock observes the system animator-duration
                        // scale. Reflow and direct verse jumps remain immediate; only a page
                        // turn slides from the Scripture's reading edge.
                        AnimatedContent(BibleBookSpread(start, turnSerial),
                            modifier = Modifier.weight(1f).fillMaxWidth(), contentKey = { it.firstPage },
                            transitionSpec = {
                                if (initialState.turn == targetState.turn) {
                                    EnterTransition.None togetherWith ExitTransition.None
                                } else {
                                    val enterFromRight = (targetState.firstPage > initialState.firstPage) != (direction == LayoutDirection.Rtl)
                                    (slideInHorizontally(tween(240)) { if (enterFromRight) it else -it } + fadeIn(tween(180))) togetherWith
                                        (slideOutHorizontally(tween(240)) { if (enterFromRight) -it else it } + fadeOut(tween(180)))
                                }
                            }, label = "biblePageTurn") { spread ->
                          Row(Modifier.fillMaxSize().padding(horizontal = 20.dp),
                              horizontalArrangement = Arrangement.spacedBy(24.dp)) {
                            for (page in spread.firstPage..spread.firstPage + 1) {
                                Surface(Modifier.weight(1f).fillMaxSize(), color = MaterialTheme.colorScheme.surfaceContainerLow) {
                                    val range = pages.getOrNull(page)
                                    if (range != null) key(keys[range.first]) {
                                        val pageScroll = rememberLazyListState()
                                        LaunchedEffect(jumpSerial, range) {
                                            val requested = keys.indexOf(jumpBlock.takeIf { it == anchor })
                                            if (requested in range) pageScroll.scrollToItem(requested - range.first)
                                        }
                                        LaunchedEffect(pageScroll, range) {
                                            snapshotFlow { pageScroll.isScrollInProgress to pageScroll.firstVisibleItemIndex }
                                                .distinctUntilChanged().collect { (moving, index) ->
                                                    if (moving) onAnchorChange(keys[(range.first + index).coerceAtMost(range.last)])
                                                }
                                        }
                                        CompositionLocalProvider(LocalLayoutDirection provides interfaceDirection,
                                            LocalBibleBookMode provides true) {
                                            LazyColumn(state = pageScroll, modifier = Modifier.fillMaxSize().testTag("biblePage.$page"),
                                                contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                                items(range.toList(), key = { keys[it] }) { rowContent(it) }
                                            }
                                        }
                                    }
                                }
                            }
                          }
                        }
                        Row(Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 12.dp),
                            verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                            IconButton(onClick = { turn(false) }, enabled = start > 0,
                                modifier = Modifier.testTag("biblePreviousPage")) {
                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.bible_previous_page))
                            }
                            Text(stringResource(R.string.bible_page_count, start + 1, minOf(start + 2, pages.size), pages.size),
                                modifier = Modifier.weight(1f).testTag("biblePageCount"),
                                style = MaterialTheme.typography.labelMedium, textAlign = TextAlign.Center)
                            IconButton(onClick = { turn(true) }, enabled = start + 2 < pages.size,
                                modifier = Modifier.testTag("bibleNextPage")) {
                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.bible_next_page))
                            }
                        }
                    }
                }
            } else {
                LazyColumn(state = scroll, modifier = Modifier.fillMaxSize().testTag("bibleVerses"),
                    contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    items(keys.indices.toList(), key = { keys[it] }) { rowContent(it) }
                }
            }
        }
    }
}

/** TextMeasurer uses the actual selected fonts, density and line wrapping. Native overflow
 * scrolling also keeps expanded source notes and exceptionally long indivisible units whole. */
@Composable
internal fun biblePageMeasurements(chapter: BibleDisplayChapter, book: BibleBook,
    info: BibleChapterInfo, edition: BibleEdition, script: String): List<BiblePageMeasurement> {
    val context = androidx.compose.ui.platform.LocalContext.current
    val readingEdition = edition.readingEdition()
    val heading = info.canonicalReference ?: ReadingChapterHeading.label(context, info.number, edition.languageCode, script)
    return buildList {
        add(if (info.isComplete) BiblePageMeasurement(emptyList()) else BiblePageMeasurement(
            listOf(AnnotatedString(stringResource(R.string.bible_partial_chapter)) to MaterialTheme.typography.bodyMedium), 24.dp, 12.dp))
        val introduction = book.introduction?.takeIf { info.number == book.chapters.first().number }
        add(BiblePageMeasurement(buildList {
            if (introduction != null) add(AnnotatedString(introduction) to PrayerTypography.styleForText(introduction, true).copy(textAlign = TextAlign.Justify))
            add(AnnotatedString(heading) to MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold))
        }, if (introduction != null) 12.dp else 0.dp))
        chapter.items.forEach { item ->
            val verse = item.primary
            val text = verse?.displayedText(readingEdition, script) ?: item.block.text.orEmpty()
            val label = verse?.let { unit -> if (unit.chapter == info.number) unit.verseLabel
                else BibleNavigation.sourceLabel(unit, info.number) { ReadingChapterHeading.number(it, edition.languageCode, script) }
            } ?: item.block.printedLabel
            val usesPrintedLabels = verse != null && info.canonicalReference != null
            val display = if (item.block.kind in listOf("heading", "colophon")) AnnotatedString(text)
                else BibleBookTypography.body(text, label.takeUnless { usesPrintedLabels })
            val style = when (item.block.kind) {
                "heading" -> PrayerTypography.styleForText(text, true).copy(fontWeight = FontWeight.Bold)
                "colophon" -> MaterialTheme.typography.bodySmall
                else -> PrayerTypography.styleForText(text, true).copy(textAlign = TextAlign.Justify)
            }
            val printed = if (verse != null) item.block.printedLabel ?: label.takeIf { usesPrintedLabels } else null
            add(BiblePageMeasurement(buildList {
                add(display to style)
                if (printed != null) add(AnnotatedString(stringResource(R.string.bible_printed_label, "\u2068$printed\u2069")) to MaterialTheme.typography.labelMedium)
            }, if (item.sourceNotes.isNullOrEmpty()) 0.dp else 56.dp))
        }
        add(BiblePageMeasurement(buildList {
            if (!book.attribution.isNullOrBlank()) add(AnnotatedString(book.attribution) to MaterialTheme.typography.bodySmall)
            add(AnnotatedString(edition.attribution) to MaterialTheme.typography.bodySmall)
        }, 56.dp + if (!book.attribution.isNullOrBlank()) 64.dp else 0.dp))
    }
}
