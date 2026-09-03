package com.dkaluta.prosary.ui.rosaryflow

import android.content.Context
import com.dkaluta.prosary.R
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
)

/** One mystery group's column of decade beads, for the wide layout's grid (one column per
 * group in the session, e.g. 3 columns for a 15-mystery session, so a long session grows wider
 * rather than awkwardly taller). [group] is null for devotions whose decades aren't tied to a
 * Rosary [MysteryGroup] at all (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) — those
 * sessions always collapse to a single ungrouped column, since there's no group-switching to
 * grow multiple columns for in the first place. */
data class BeadColumn(
    val id: String = UUID.randomUUID().toString(),
    val group: MysteryGroup?,
    val beads: List<BeadInfo>,
)

/** Pure step-index math for the Rosary's mystery-skip buttons. A mystery begins at the first
 * step carrying its dense decade index (the announcement); closing prayers have no decade and
 * therefore navigate back to the final announcement, while opening prayers navigate forward to
 * the first. */
object MysteryStepNavigation {
    fun previous(steps: List<RosaryStep>, currentIndex: Int): Int? {
        val starts = mysteryStarts(steps)
        val currentDecade = steps.getOrNull(currentIndex)?.decadeIndex
        return if (currentDecade != null) {
            starts.firstOrNull { it.first == currentDecade - 1 }?.second
        } else {
            starts.lastOrNull { it.second < currentIndex }?.second
        }
    }

    fun next(steps: List<RosaryStep>, currentIndex: Int): Int? {
        val starts = mysteryStarts(steps)
        val currentDecade = steps.getOrNull(currentIndex)?.decadeIndex
        return if (currentDecade != null) {
            starts.firstOrNull { it.first == currentDecade + 1 }?.second
        } else {
            starts.firstOrNull { it.second > currentIndex }?.second
        }
    }

    private fun mysteryStarts(steps: List<RosaryStep>): List<Pair<Int, Int>> {
        val seen = mutableSetOf<Int>()
        return steps.mapIndexedNotNull { index, step ->
            step.decadeIndex?.takeIf(seen::add)?.let { it to index }
        }
    }
}

/** The full computed bead layout for the current step of a Rosary session. */
data class BeadLayout(
    /** Decade beads wrapped into one row per mystery group — like the physical five-decade
     * loops of a rosary — for the narrow layout's horizontal grid. Ungrouped custom-rosary
     * sessions (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) collapse to a single
     * row. */
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
    fun accessibilityDescription(context: Context): String {
        if (closingCross?.state == BeadState.Current) {
            return context.getString(R.string.bead_closing_cross)
        }
        if (antiphon?.state == BeadState.Current) {
            return context.getString(R.string.bead_marian_antiphon)
        }

        val decadeBeads = groupColumns.flatMap { it.beads }
        val currentDecade = decadeBeads.indexOfFirst { it.state == BeadState.Current }
        if (currentDecade >= 0) {
            var description = context.getString(R.string.bead_decade_of, currentDecade + 1, decadeBeads.size)
            if (showBottomBeads) {
                val currentHailMary = bottomBeads.indexOfFirst { it.state == BeadState.Current }
                if (currentHailMary >= 0) {
                    description += ", " + context.getString(R.string.bead_hail_mary_of, currentHailMary + 1, bottomBeads.size)
                }
            }
            return description
        }

        if (openingCross?.state == BeadState.Current) {
            return context.getString(R.string.bead_opening_cross)
        }

        // Not on a decade, the opening cross, the antiphon, or the closing cross — one of the
        // closing steps between the last decade and the closing cross (e.g. Franciscan
        // Crown's/Seven Sorrows' extra closing Hail Marys and closing prayer) if every decade
        // bead already reads completed, otherwise the pre-decade opening prayers.
        if (decadeBeads.isNotEmpty() && decadeBeads.all { it.state == BeadState.Completed }) {
            return context.getString(R.string.bead_closing_prayers)
        }

        return context.getString(R.string.bead_opening_prayers)
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

            // Which mystery group each decade belongs to — null for decades with no mystery at
            // all (Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet — none of which are
            // "mysteries" in the Rosary sense). Feeds both the narrow layout's row wrapping and
            // the wide layout's group columns below. Unlike Swift, Kotlin's
            // MutableMap.put/subscript-assignment stores an explicit null value correctly (it
            // doesn't remove the entry), so containsKey is enough to distinguish "decade not
            // yet recorded" from "decade recorded with no mystery".
            val decadeGroupOf = mutableMapOf<Int, MysteryGroup?>()
            for (s in steps) {
                val d = s.decadeIndex
                if (d != null && !decadeGroupOf.containsKey(d)) {
                    decadeGroupOf[d] = s.mystery?.group
                }
            }

            // Wrapped per mystery group — like the physical five-decade loops of a rosary — so
            // a 15/20-mystery session breaks into one row per group, while an ungrouped
            // custom-rosary session (the Franciscan Crown's 7 Joys, the Seven Sorrows) keeps
            // all its decade beads on a single row instead of an arbitrary 5+2 split. The
            // opening cross rides along with the first row, and the antiphon/closing-cross
            // beads (if any) tag onto the last row.
            val rows = mutableListOf(mutableListOf(crossBead))
            for (d in 0 until totalDecades) {
                if (d > 0 && decadeGroupOf[d] != decadeGroupOf[d - 1]) {
                    rows.add(mutableListOf())
                }
                rows.last().add(decadeBeads[d])
            }
            antiphonBead?.let { rows.last().add(it) }
            closingCrossBead?.let { rows.last().add(it) }

            // One column per mystery group (in session order), each holding that group's decade
            // beads — a 15/20-mystery session grows into more columns instead of one long,
            // awkwardly-tall strip. Single-group sessions naturally collapse to one column, and
            // mystery-less decades collapse into one shared ungrouped (null-group) column
            // instead of being dropped entirely.

            val orderedGroups = mutableListOf<MysteryGroup?>()
            for (d in 0 until totalDecades) {
                if (decadeGroupOf.containsKey(d)) {
                    val group = decadeGroupOf[d]
                    if (!orderedGroups.contains(group)) {
                        orderedGroups.add(group)
                    }
                }
            }

            val groupColumnBeads = orderedGroups.associateWith { mutableListOf<BeadInfo>() }
            for (d in 0 until totalDecades) {
                if (!decadeGroupOf.containsKey(d)) continue
                val group = decadeGroupOf[d]
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

            // Hail-Marys-per-decade isn't always 10 (Seven Sorrows uses 7) — derive it from the
            // session's own step data instead of hardcoding, so this stays correct for every devotion.
            val hailMarysPerDecade = steps.mapNotNull { it.hailMaryIndexInDecade }.maxOrNull() ?: 10

            val bottom = (1..hailMarysPerDecade).map { h ->
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
                BeadInfo(kind = BeadKind.Decade, state = state)
            }

            return BeadLayout(
                topRows = rows, openingCross = crossBead, groupColumns = groupColumns,
                antiphon = antiphonBead, closingCross = closingCrossBead,
                bottomBeads = bottom, showBottomBeads = true,
            )
        }
    }
}
