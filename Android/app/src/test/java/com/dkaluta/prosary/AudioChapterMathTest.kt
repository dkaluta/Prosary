package com.dkaluta.prosary

import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.DevotionAudioTrack
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** The pure chapter math the playback controller and flow syncing rest on — the MediaPlayer
 * half needs a device, but which chapter a time falls in (and where "previous" goes) doesn't. */
class AudioChapterMathTest {
    private fun chapter(start: Double, stepIndex: Int? = null) =
        DevotionAudioTrack.Chapter(start = start, title = "c$start", stepIndex = stepIndex)

    // The fixture bundle's Latin track shape: cross, three Kyries, Gloria.
    private val chapters = listOf(
        chapter(0.0, 0), chapter(4.7, 1), chapter(9.29, 2), chapter(13.88, 3), chapter(18.47, 4),
    )

    @Test
    fun timeFallsInTheChapterThatStartedBeforeIt() {
        assertEquals(0, AudioPlaybackController.chapterIndexFor(chapters, 0.0))
        assertEquals(0, AudioPlaybackController.chapterIndexFor(chapters, 4.5))
        assertEquals(1, AudioPlaybackController.chapterIndexFor(chapters, 4.7))
        assertEquals(4, AudioPlaybackController.chapterIndexFor(chapters, 60.0))
    }

    @Test
    fun boundaryToleranceCountsALandingSeekAsInsideTheChapter() {
        // Seeking to 9.29 may report 9.285 back from the player — still chapter 2.
        assertEquals(2, AudioPlaybackController.chapterIndexFor(chapters, 9.285))
    }

    @Test
    fun timeBeforeTheFirstChapterClampsToItAndEmptyChaptersHaveNoIndex() {
        assertEquals(0, AudioPlaybackController.chapterIndexFor(listOf(chapter(3.0)), 1.0))
        assertNull(AudioPlaybackController.chapterIndexFor(emptyList(), 5.0))
    }

    @Test
    fun previousMeansTheChapterBeforeEarlyAndRestartLate() {
        // Just after chapter 3 begins → the chapter before it.
        assertEquals(2, AudioPlaybackController.previousChapterTarget(chapters, 3, 14.5))
        // Deep into chapter 3 → restart chapter 3.
        assertEquals(3, AudioPlaybackController.previousChapterTarget(chapters, 3, 17.0))
        // At the very start there is nothing before — stays at 0.
        assertEquals(0, AudioPlaybackController.previousChapterTarget(chapters, 0, 0.5))
    }
}
