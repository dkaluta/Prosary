package com.dkaluta.prosary.models

/** Pure UI-computed presentation state for the Jesus Prayer's repetition counter — mirrors how
 * BeadLayout (ui/rosaryflow/BeadModels.kt) is a pure class derived from the backend's steps
 * rather than something the backend itself provides. There's no engine/backend for the Jesus
 * Prayer: every repetition prays the same fixed line, so there's nothing for a backend to build
 * beyond this counter.
 *
 * Immutable, unlike iOS's `mutating func` equivalent — [goNext]/[goBack] return a new copy rather
 * than mutating in place, the idiomatic Kotlin/Compose state-holder pattern. */
data class JesusPrayerProgress(
    val target: JesusPrayerTarget,
    /** 0-based, same convention as RosaryFlowScreen's currentIndex. */
    val currentIndex: Int = 0,
) {
    /** Total repetitions for a bounded target; null for [JesusPrayerTarget.Unbounded]. */
    val targetCount: Int?
        get() = (target as? JesusPrayerTarget.Count)?.value

    val canGoBack: Boolean
        get() = currentIndex > 0

    /** False for [JesusPrayerTarget.Unbounded] — an unbounded session never auto-completes; the
     * user ends it explicitly via the Finish action. */
    val isLastRep: Boolean
        get() = targetCount?.let { currentIndex >= it - 1 } ?: false

    /** Null for [JesusPrayerTarget.Unbounded], since there's no total to measure progress against. */
    val progressFraction: Float?
        get() = targetCount?.takeIf { it > 0 }?.let { (currentIndex + 1).toFloat() / it }

    fun goNext(): JesusPrayerProgress = if (isLastRep) this else copy(currentIndex = currentIndex + 1)

    fun goBack(): JesusPrayerProgress = if (canGoBack) copy(currentIndex = currentIndex - 1) else this
}
