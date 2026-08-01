package com.dkaluta.prosary.content.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableDoubleStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.dkaluta.prosary.content.prayerpack.DevotionAudioTrack
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.io.File

/**
 * Plays one bundle audio track (see Shared/ARCHITECTURE.md "Audio"): extracts the Ogg Opus
 * bytes from the pack into the cache directory (recordings dwarf every other bundle asset, so
 * they are never held in memory) and plays them with the platform [MediaPlayer] — Android
 * demuxes Ogg Opus natively, no Media3 dependency needed. Compose-observable state mirrors
 * iOS's AudioPlaybackController; chapter → step syncing lives in the flow screen, because only
 * it knows the built step sequence the chapters' advisory stepIndex hints point into.
 *
 * [MediaPlayer] has no position listener, so the owning screen drives [refreshTime] on a coarse
 * tick while [isPlaying] — 4 Hz is plenty for a progress bar and chapter boundaries.
 */
class AudioPlaybackController {
    var track by mutableStateOf<DevotionAudioTrack?>(null)
        private set
    var isPlaying by mutableStateOf(false)
        private set
    var currentTime by mutableDoubleStateOf(0.0)
        private set
    var duration by mutableDoubleStateOf(0.0)
        private set

    val isLoaded: Boolean get() = player != null

    /** Index into the track's chapters of the chapter [currentTime] falls in. */
    val currentChapterIndex: Int?
        get() = track?.chapters?.let { chapterIndexFor(it, currentTime) }

    private var player: MediaPlayer? = null

    /** Extracts and opens the track; leaves the player paused at 0. Any previous track stops. */
    fun load(context: Context, bundleId: String, track: DevotionAudioTrack) {
        stop()
        val file = extractedFile(context, bundleId, track) ?: return
        val prepared = MediaPlayer()
        try {
            prepared.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build(),
            )
            prepared.setDataSource(file.absolutePath)
            prepared.prepare()
        } catch (_: Exception) {
            prepared.release()
            return
        }
        prepared.setOnCompletionListener {
            isPlaying = false
            currentTime = duration
        }
        // seekTo is asynchronous — this corrects the optimistic time in [seek] to wherever the
        // player actually landed (callbacks arrive on the creating thread's Looper: main).
        prepared.setOnSeekCompleteListener { currentTime = it.currentPosition / 1000.0 }
        player = prepared
        duration = prepared.duration / 1000.0
        currentTime = 0.0
        this.track = track
    }

    /** The cached audio file for a track, extracted from the pack on first use. */
    private fun extractedFile(context: Context, bundleId: String, track: DevotionAudioTrack): File? {
        val dir = File(context.cacheDir, "PrayerAudio/$bundleId")
        val file = File(dir, track.file.substringAfterLast('/'))
        if (file.length() > 0) return file
        val data = PrayerPackStore.audioData(bundleId, track.file) ?: return null
        dir.mkdirs()
        return runCatching { file.writeBytes(data); file }.getOrNull()
    }

    fun playPause() {
        val player = player ?: return
        if (player.isPlaying) {
            player.pause()
            isPlaying = false
            // No seek can be pending while playing normally, so this read-back is safe.
            currentTime = player.currentPosition / 1000.0
        } else {
            // Finished-and-restarted: tapping play at the end starts over instead of nothing.
            // Through seek() so the published time updates optimistically — a read-back here
            // would briefly report the end position and bounce the step to the last chapter.
            if (duration > 0 && currentTime >= duration - 0.05) seek(0.0)
            player.start()
            isPlaying = true
        }
    }

    fun seek(seconds: Double) {
        val player = player ?: return
        val clamped = seconds.coerceIn(0.0, if (duration > 0) duration else seconds)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Frame-precise; the legacy int overload lands on the nearest sync point.
            player.seekTo((clamped * 1000).toLong(), MediaPlayer.SEEK_CLOSEST)
        } else {
            @Suppress("DEPRECATION")
            player.seekTo((clamped * 1000).toInt())
        }
        // seekTo is asynchronous and currentPosition reports the OLD position until it
        // completes — reading it back here left paused chapter skips and slider drags looking
        // dead (the published time snapped straight back). Publish the requested time now;
        // OnSeekComplete corrects to the actual landing frame.
        currentTime = clamped
    }

    fun seekToChapter(index: Int) {
        val chapters = track?.chapters ?: return
        if (index in chapters.indices) seek(chapters[index].start)
    }

    /** Back within a chapter's first moments goes to the previous chapter (the audiobook
     * convention); later in a chapter it restarts the chapter. */
    fun previousChapter() {
        val chapters = track?.chapters ?: return
        val index = currentChapterIndex ?: return
        seekToChapter(previousChapterTarget(chapters, index, currentTime))
    }

    fun nextChapter() {
        val chapters = track?.chapters ?: return
        val index = currentChapterIndex ?: return
        if (index + 1 < chapters.size) seekToChapter(index + 1)
    }

    /** Mirrors the player's clock into observable state — the owning screen calls this on its
     * playback tick. */
    fun refreshTime() {
        val player = player ?: return
        if (player.isPlaying) currentTime = player.currentPosition / 1000.0
    }

    fun stop() {
        player?.release()
        player = null
        track = null
        isPlaying = false
        currentTime = 0.0
        duration = 0.0
    }

    companion object {
        /** Pure chapter math, shared with tests: the chapter a time falls in (with a hair of
         * tolerance so landing exactly on a boundary via seekToChapter counts as inside it). */
        fun chapterIndexFor(chapters: List<DevotionAudioTrack.Chapter>, time: Double): Int? {
            if (chapters.isEmpty()) return null
            return chapters.indexOfLast { it.start <= time + 0.01 }.coerceAtLeast(0)
        }

        fun previousChapterTarget(
            chapters: List<DevotionAudioTrack.Chapter>,
            currentIndex: Int,
            time: Double,
        ): Int {
            val restartThreshold = chapters[currentIndex].start + 2
            return if (time < restartThreshold) (currentIndex - 1).coerceAtLeast(0) else currentIndex
        }
    }
}
