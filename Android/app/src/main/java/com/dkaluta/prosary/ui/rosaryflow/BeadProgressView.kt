package com.dkaluta.prosary.ui.rosaryflow

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.VerticalDivider
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.unit.dp

/** The single gap used everywhere in the major/minor bead tracks, so cross-to-decade,
 * decade-to-decade, and decade-to-antiphon gaps all read as one consistent rhythm. */
private val beadSpacing = 6.dp

@Composable
private fun MajorBeadsNarrowView(rows: List<List<BeadInfo>>) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(beadSpacing)) {
        rows.forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(beadSpacing)) {
                row.forEach { bead -> BeadDotView(bead = bead) }
            }
        }
    }
}

/** One column per mystery group, each a plain vertical stack of that group's decade beads — a
 * 15/20-mystery session grows wider (more columns) rather than one long, awkwardly-tall strip. */
@Composable
private fun GroupColumnsGridView(columns: List<BeadColumn>) {
    Row(horizontalArrangement = Arrangement.spacedBy(beadSpacing), verticalAlignment = Alignment.Top) {
        columns.forEach { column ->
            Column(verticalArrangement = Arrangement.spacedBy(beadSpacing)) {
                column.beads.forEach { bead -> BeadDotView(bead = bead) }
            }
        }
    }
}

/** Evenly spaced — deliberately no group-of-5 gap: decades that aren't 10 beads long (the
 * Seven Sorrows' 7) would split awkwardly (5+2) around it. */
@Composable
private fun MinorBeadsRowView(beads: List<BeadInfo>) {
    Row(horizontalArrangement = Arrangement.spacedBy(beadSpacing)) {
        beads.forEach { bead -> BeadDotView(bead = bead) }
    }
}

@Composable
private fun MinorBeadsColumnView(beads: List<BeadInfo>) {
    Column(verticalArrangement = Arrangement.spacedBy(beadSpacing)) {
        beads.forEach { bead -> BeadDotView(bead = bead) }
    }
}

/** Splits the minor beads into two half-length columns (5+5 for a 10-bead decade) instead of
 * one tall column — half the height, for when there isn't enough vertical room for the single
 * tall column (a phone in landscape, or a resized short window). */
@Composable
private fun MinorBeadsTwoColumnView(beads: List<BeadInfo>) {
    val half = (beads.size + 1) / 2
    val columns = listOf(beads.take(half), beads.drop(half))

    Row(horizontalArrangement = Arrangement.spacedBy(beadSpacing), verticalAlignment = Alignment.Top) {
        columns.forEach { column ->
            Column(verticalArrangement = Arrangement.spacedBy(beadSpacing)) {
                column.forEach { bead -> BeadDotView(bead = bead) }
            }
        }
    }
}

@Composable
fun BeadProgressView(
    layout: BeadLayout,
    isWide: Boolean,
    hasRoomForSingleMinorColumn: Boolean = true,
    modifier: Modifier = Modifier,
) {
    // The individual dots carry no meaning of their own to accessibility services — expose the
    // whole track as a single element with a spoken summary instead of dozens of unlabeled circles.
    val beadSummary = layout.accessibilityDescription(LocalContext.current)
    val progressLabel = stringResource(R.string.bead_progress, beadSummary)
    val semanticsModifier = modifier.clearAndSetSemantics {
        contentDescription = progressLabel
    }

    if (isWide) {
        // Minor beads sit beside the major-beads column rather than stacked below it —
        // that keeps the whole track's height pinned to the major-beads column alone, so
        // it still fits a short window (a phone in landscape) instead of growing taller than
        // the screen. Centered rather than top-aligned, since the minor beads are usually
        // shorter than the major-beads block.
        Row(modifier = semanticsModifier, verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(beadSpacing)) {
            Column(verticalArrangement = Arrangement.spacedBy(beadSpacing)) {
                layout.openingCross?.let { BeadDotView(bead = it) }
                GroupColumnsGridView(columns = layout.groupColumns)
                layout.antiphon?.let { BeadDotView(bead = it) }
                layout.closingCross?.let { BeadDotView(bead = it) }
            }

            if (layout.showBottomBeads) {
                VerticalDivider(modifier = Modifier.padding(horizontal = 4.dp))
                if (hasRoomForSingleMinorColumn) {
                    MinorBeadsColumnView(beads = layout.bottomBeads)
                } else {
                    MinorBeadsTwoColumnView(beads = layout.bottomBeads)
                }
            }
        }
    } else {
        Column(
            modifier = semanticsModifier,
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(beadSpacing),
        ) {
            MajorBeadsNarrowView(rows = layout.topRows)
            if (layout.showBottomBeads) {
                MinorBeadsRowView(beads = layout.bottomBeads)
            }
        }
    }
}
