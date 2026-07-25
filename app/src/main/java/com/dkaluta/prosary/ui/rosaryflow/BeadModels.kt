package com.dkaluta.prosary.ui.rosaryflow

import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.RosaryStep
import java.util.UUID

/** Pure UI-computed presentation state for the bead progress indicator — derived from the
 * backend's RosaryStep list plus the current index, not something the backend provides. */
enum class BeadKind { Cross, Decade, Antiphon }

enum class BeadState { Completed, Current, Upcoming }

/** One dot/glyph in the Rosary progress indicator. */
data class BeadInfo(
    val id: String = UUID.randomUUID().toString(),
    val kind: BeadKind,
    val state: BeadState,
    /** True for the first bead of each group-of-5, so the UI can add extra spacing there. */
    val isGroupStart: Boolean = false,
)

/** One mystery group's column of decade beads, for the wide layout's grid (one column per
 * group in the session, e.g. 3 columns for a 15-mystery session, so a long session grows wider
 * rather than awkwardly taller). */
data class BeadColumn(
    val id: String = UUID.randomUUID().toString(),
    val group: MysteryGroup,
    val beads: List<BeadInfo>,
)

/** The full computed bead layout for the current step of a Rosary session. */
data class BeadLayout(
    /** Decade beads grouped into rows of 5 — like the physical layout of a rosary's Our-Father
     * beads — for the narrow layout's wrapped horizontal grid. */
    val topRows: List<List<BeadInfo>> = emptyList(),
    /** Opening cross, for the wide layout. */
    val openingCross: BeadInfo? = null,
    /** One column per mystery group in the session, each holding that group's decade beads in
     * order, for the wide layout's grid. */
    val groupColumns: List<BeadColumn> = emptyList(),
    /** Marian antiphon "M" bead, for the wide layout. */
    val antiphon: BeadInfo? = null,
    /** Closing cross, for the wide layout. */
    val closingCross: BeadInfo? = null,
    /** Progress through the current decade's 10 Hail Marys. */
    val bottomBeads: List<BeadInfo> = emptyList(),
    val showBottomBeads: Boolean = false,
) {
    /** A single spoken summary of where the beads currently show progress — the dots themselves
     * carry no individual meaning to accessibility services, so the whole track is exposed as one
     * element with this label instead of dozens of unlabeled circles. */
    val accessibilityDescription: String
        get() {
            if (closingCross?.state == BeadState.Current) {
                return "Closing sign of the cross"
            }
            if (antiphon?.state == BeadState.Current) {
                return "Marian antiphon"
            }

            val decadeBeads = groupColumns.flatMap { it.beads }
            val currentDecade = decadeBeads.indexOfFirst { it.state == BeadState.Current }
            if (currentDecade >= 0) {
                var description = "Decade ${currentDecade + 1} of ${decadeBeads.size}"
                if (showBottomBeads) {
                    val currentHailMary = bottomBeads.indexOfFirst { it.state == BeadState.Current }
                    if (currentHailMary >= 0) {
                        description += ", Hail Mary ${currentHailMary + 1} of 10"
                    }
                }
                return description
            }

            if (openingCross?.state == BeadState.Current) {
                return "Opening sign of the cross"
            }

            return "Opening prayers"
        }

    companion object {
        fun build(steps: List<RosaryStep>, currentIndex: Int, hasClosingCross: Boolean): BeadLayout {
            if (!steps.indices.contains(currentIndex)) return BeadLayout()
            val step = steps[currentIndex]

            val totalDecades = (steps.mapNotNull { it.decadeIndex }.maxOrNull()?.plus(1)) ?: 0
            val firstDecadeStepIndex = steps.indexOfFirst { it.decadeIndex != null }
            val antiphonStepIndex = steps.indexOfFirst { it.isAntiphon }

            val crossBead = BeadInfo(kind = BeadKind.Cross, state = if (currentIndex == 0) BeadState.Current else BeadState.Completed)

            val decadeBeads = (0 until totalDecades).map { d ->
                val currentDecade = step.decadeIndex
                val state = if (currentDecade != null) {
                    if (d < currentDecade) BeadState.Completed else if (d == currentDecade) BeadState.Current else BeadState.Upcoming
                } else {
                    if (firstDecadeStepIndex < 0 || currentIndex < firstDecadeStepIndex) BeadState.Upcoming else BeadState.Completed
                }
                BeadInfo(kind = BeadKind.Decade, state = state)
            }

            val antiphonBead = if (antiphonStepIndex >= 0) {
                val state = if (currentIndex < antiphonStepIndex) {
                    BeadState.Upcoming
                } else if (currentIndex == antiphonStepIndex) {
                    BeadState.Current
                } else {
                    BeadState.Completed
                }
                BeadInfo(kind = BeadKind.Antiphon, state = state)
            } else {
                null
            }

            val closingCrossBead = if (hasClosingCross) {
                val closingCrossIndex = steps.size - 1
                BeadInfo(kind = BeadKind.Cross, state = if (currentIndex < closingCrossIndex) BeadState.Upcoming else BeadState.Current)
            } else {
                null
            }

            // Grouped into rows of 5 decade beads, mirroring the physical layout of a rosary's
            // Our-Father beads — the opening cross rides along with the first row, and the
            // antiphon/closing-cross beads (if any) tag onto whatever's left of the last row.
            val rows = mutableListOf(mutableListOf(crossBead))
            decadeBeads.forEachIndexed { index, decadeBead ->
                rows.last().add(decadeBead)
                val decadeCountInRow = rows.last().count { it.kind == BeadKind.Decade }
                if (decadeCountInRow % 5 == 0 && index != decadeBeads.size - 1) {
                    rows.add(mutableListOf())
                }
            }
            antiphonBead?.let { rows.last().add(it) }
            closingCrossBead?.let { rows.last().add(it) }

            // One column per mystery group (in session order), each holding that group's decade
            // beads — a 15/20-mystery session grows into more columns instead of one long,
            // awkwardly-tall strip. Single-group sessions naturally collapse to one column.
            val decadeGroupOf = mutableMapOf<Int, MysteryGroup>()
            for (s in steps) {
                val d = s.decadeIndex
                val group = s.mystery?.group
                if (d != null && group != null && !decadeGroupOf.containsKey(d)) {
                    decadeGroupOf[d] = group
                }
            }

            val orderedGroups = mutableListOf<MysteryGroup>()
            for (d in 0 until totalDecades) {
                val group = decadeGroupOf[d]
                if (group != null && !orderedGroups.contains(group)) {
                    orderedGroups.add(group)
                }
            }

            val groupColumnBeads = orderedGroups.associateWith { mutableListOf<BeadInfo>() }
            for (d in 0 until totalDecades) {
                val group = decadeGroupOf[d] ?: continue
                groupColumnBeads[group]?.add(decadeBeads[d])
            }
            val groupColumns = orderedGroups.map { BeadColumn(group = it, beads = groupColumnBeads[it].orEmpty()) }

            val decadeIndex = step.decadeIndex
                ?: return BeadLayout(
                    topRows = rows, openingCross = crossBead, groupColumns = groupColumns,
                    antiphon = antiphonBead, closingCross = closingCrossBead,
                    bottomBeads = emptyList(), showBottomBeads = false,
                )

            val decadeStepIndices = steps.indices.filter {
                steps[it].decadeIndex == decadeIndex && steps[it].hailMaryIndexInDecade != null
            }
            val firstHailMaryIndex = decadeStepIndices.minOrNull()
            val lastHailMaryIndex = decadeStepIndices.maxOrNull()
            if (firstHailMaryIndex == null || lastHailMaryIndex == null) {
                return BeadLayout(
                    topRows = rows, openingCross = crossBead, groupColumns = groupColumns,
                    antiphon = antiphonBead, closingCross = closingCrossBead,
                    bottomBeads = emptyList(), showBottomBeads = false,
                )
            }

            val bottom = (1..10).map { h ->
                val current = step.hailMaryIndexInDecade
                val state = if (currentIndex < firstHailMaryIndex) {
                    BeadState.Upcoming
                } else if (currentIndex > lastHailMaryIndex) {
                    BeadState.Completed
                } else if (current != null) {
                    if (h < current) BeadState.Completed else if (h == current) BeadState.Current else BeadState.Upcoming
                } else {
                    BeadState.Upcoming
                }
                BeadInfo(kind = BeadKind.Decade, state = state, isGroupStart = h > 1 && (h - 1) % 5 == 0)
            }

            return BeadLayout(
                topRows = rows, openingCross = crossBead, groupColumns = groupColumns,
                antiphon = antiphonBead, closingCross = closingCrossBead,
                bottomBeads = bottom, showBottomBeads = true,
            )
        }
    }
}
