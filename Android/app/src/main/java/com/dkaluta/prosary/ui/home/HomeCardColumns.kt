package com.dkaluta.prosary.ui.home

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.foundation.layout.Box
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.HomeWidget

/** Flat keyed children keep card state and saved accessibility order while columns reflow. */
@Composable
internal fun HomeCardColumns(widgets: List<HomeWidget>, modifier: Modifier = Modifier, content: @Composable (HomeWidget) -> Unit) {
    Layout(content = {
        widgets.forEachIndexed { index, widget ->
            key(widget.id) {
                Box(Modifier.testTag("homeColumnCard.${widget.id}").semantics {
                    isTraversalGroup = true
                    traversalIndex = index.toFloat()
                }) { content(widget) }
            }
        }
    }, modifier = modifier.semantics { isTraversalGroup = true }) { measurables, constraints ->
        val gap = 12.dp.roundToPx()
        val widths = HomeCardColumnsGeometry.columnWidths(constraints.maxWidth, 340.dp.roundToPx(), gap)
        val children = measurables.mapIndexed { index, measurable ->
            val width = widths[index % widths.size]
            measurable.measure(Constraints(minWidth = width, maxWidth = width))
        }
        val arrangement = HomeCardColumnsGeometry.arrange(widths, gap, children.map { it.height })
        layout(constraints.maxWidth, arrangement.height) {
            arrangement.placements.forEach { card -> children[card.index].placeRelative(card.x, card.y) }
        }
    }
}
