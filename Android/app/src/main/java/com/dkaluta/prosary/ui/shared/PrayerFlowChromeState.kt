package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.lazy.LazyListState
import androidx.lifecycle.ViewModel

/** UI state belongs to the navigation entry, so a new Activity does not restart a live prayer. */
class PrayerFlowChromeState : ViewModel() {
    val reading = LazyListState()
    private var readingIdentity: String? = null
    private data class ReadingAnchor(val index: Int, val offset: Int)
    private var detachedReadingAnchor: ReadingAnchor? = null
    private var countdownIdentity: String? = null
    private var deadline: Long? = null

    suspend fun showReading(identity: String) {
        if (readingIdentity == identity) return
        releaseReadingAnchor()
        reading.scrollToItem(0)
        readingIdentity = identity
    }

    /** A recreated window can measure before its final system insets arrive. Preserve the
     * person's anchor separately so that transiently larger viewport cannot replace it with
     * a clamped end-of-list offset. An interrupted reattachment keeps its original anchor. */
    fun captureReadingAnchor() {
        if (detachedReadingAnchor == null) {
            detachedReadingAnchor = ReadingAnchor(reading.firstVisibleItemIndex, reading.firstVisibleItemScrollOffset)
        }
    }

    /** Reapply only when the actual reader viewport changes, not on a timer or every frame. */
    fun restoreReadingAnchor() {
        detachedReadingAnchor?.let { reading.requestScrollToItem(it.index, it.offset) }
    }

    /** Once the person interacts, their new scrolling/selection owns the reading position. */
    fun releaseReadingAnchor() {
        detachedReadingAnchor = null
    }

    fun remainingDelay(identity: String, intervalMillis: Long, now: Long): Long {
        if (countdownIdentity != identity || deadline == null) {
            countdownIdentity = identity
            deadline = now + intervalMillis
        }
        return ((deadline ?: now) - now).coerceAtLeast(0)
    }

    fun cancelCountdown() {
        countdownIdentity = null
        deadline = null
    }
}
