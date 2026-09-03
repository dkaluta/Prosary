package com.dkaluta.prosary.ui.home

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DragHandle
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import com.dkaluta.prosary.R
import com.dkaluta.prosary.typography.HebrewDisplayText

/** The approved reorder pattern (not jiggle): rows with drag handles inside a dialog; the
 * dragged row rides the finger and swaps neighbors as it crosses their midlines. Order is
 * committed on every swap via [onMove]; Reset returns to directory order. */
@Composable
fun HomeOrderEditor(
    titles: List<Pair<String, String>>, // id to display title, in current order
    onMove: (List<String>) -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit,
) = OrderEditor(
    titles = titles,
    dialogTitle = stringResource(R.string.home_order_title),
    onMove = onMove,
    onReset = onReset,
    onDismiss = onDismiss,
)

/** The same drag-handle ordering surface is shared by Home, Basic Prayers, and the language
 * fallback preference. Stable row identity is intentionally implemented once so every list can
 * survive several neighbor swaps during one drag. */
@Composable
fun OrderEditor(
    titles: List<Pair<String, String>>, // id to display title, in current order
    dialogTitle: String,
    footer: String? = null,
    onMove: (List<String>) -> Unit,
    onReset: () -> Unit,
    onDismiss: () -> Unit,
) {
    var ids by remember { mutableStateOf(titles.map { it.first }) }
    val labels = remember(titles) { titles.toMap() }
    var draggingIndex by remember { mutableIntStateOf(-1) }
    var dragOffset by remember { mutableFloatStateOf(0f) }
    val rowHeightPx = with(LocalDensity.current) { 48.dp.toPx() }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(HebrewDisplayText.unpoint(dialogTitle)) },
        text = {
            Column(
                modifier = Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()),
            ) {
                if (footer != null) {
                    Text(
                        footer,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 8.dp),
                    )
                }
                ids.forEachIndexed { index, id ->
                    // key(id) is what makes dragging work at all. Without it the Column reuses
                    // composables positionally, so the first mid-drag swap puts a *different*
                    // id at the dragged position — pointerInput(id) sees its key change,
                    // restarts, and cancels the live gesture coroutine. The visible symptom:
                    // one swap, a row stuck mid-air, and onDragEnd never firing — so onMove
                    // never saved and the order silently reverted (Erez, 2026-08-08). With
                    // stable identity the gesture survives every swap and commits at the end.
                    key(id) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .zIndex(if (index == draggingIndex) 1f else 0f)
                            .graphicsLayer {
                                translationY = if (index == draggingIndex) dragOffset else 0f
                            }
                            .padding(vertical = 12.dp),
                    ) {
                        Icon(
                            Icons.Filled.DragHandle,
                            contentDescription = stringResource(R.string.home_order_reorder, labels[id] ?: ""),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.pointerInput(id) {
                                detectDragGestures(
                                    onDragStart = {
                                        draggingIndex = ids.indexOf(id)
                                        dragOffset = 0f
                                    },
                                    onDragEnd = {
                                        draggingIndex = -1
                                        dragOffset = 0f
                                        onMove(ids)
                                    },
                                    onDragCancel = {
                                        draggingIndex = -1
                                        dragOffset = 0f
                                    },
                                ) { change, dragAmount ->
                                    change.consume()
                                    dragOffset += dragAmount.y
                                    // Crossed a neighbor's midline: swap and rebase the offset.
                                    while (dragOffset > rowHeightPx / 2 && draggingIndex < ids.lastIndex) {
                                        ids = ids.toMutableList().apply {
                                            add(draggingIndex + 1, removeAt(draggingIndex))
                                        }
                                        draggingIndex += 1
                                        dragOffset -= rowHeightPx
                                    }
                                    while (dragOffset < -rowHeightPx / 2 && draggingIndex > 0) {
                                        ids = ids.toMutableList().apply {
                                            add(draggingIndex - 1, removeAt(draggingIndex))
                                        }
                                        draggingIndex -= 1
                                        dragOffset += rowHeightPx
                                    }
                                }
                            },
                        )
                        Text(
                            HebrewDisplayText.unpoint(labels[id] ?: id),
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.padding(start = 12.dp),
                        )
                    }
                    }
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) } },
        dismissButton = { TextButton(onClick = { onReset(); onDismiss() }) { Text(stringResource(R.string.common_reset)) } },
    )
}
