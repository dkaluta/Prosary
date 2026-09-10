package com.dkaluta.prosary

import com.dkaluta.prosary.content.audio.AudioPlaybackController
import java.io.File
import java.io.IOException
import java.nio.file.Files
import org.junit.Assert.*
import org.junit.Test

class AudioCacheRemovalTest {
    @Test
    fun removingOneDownloadClearsOnlyItsExtractedAudio() {
        val cache = Files.createTempDirectory("prosary-audio-removal").toFile()
        try {
            val removed = File(cache, "PrayerAudio/repo.test.prayer/en.opus")
            val retained = File(cache, "PrayerAudio/repo.test.other/en.opus")
            val unrelated = File(cache, "unrelated-cache")
            for (file in listOf(removed, retained, unrelated)) {
                file.parentFile!!.mkdirs()
                file.writeText("audio bytes")
            }
            AudioPlaybackController.removeCachedAudio(cache, "repo.test.prayer")
            assertFalse(removed.parentFile!!.exists())
            assertEquals("audio bytes", retained.readText())
            assertEquals("audio bytes", unrelated.readText())
            AudioPlaybackController.removeCachedAudio(cache, "repo.test.prayer") // already absent is harmless
        } finally { cache.deleteRecursively() }
    }

    @Test
    fun malformedBundleIdsCannotClearTheAudioRootOrAnotherCache() {
        val cache = Files.createTempDirectory("prosary-audio-removal").toFile()
        try {
            val retained = File(cache, "important-cache").apply { writeText("keep") }
            for (id in listOf("..", "../important-cache", ".")) {
                assertTrue(runCatching { AudioPlaybackController.removeCachedAudio(cache, id) }.exceptionOrNull() is IOException)
                assertEquals("keep", retained.readText())
            }
        } finally { cache.deleteRecursively() }
    }
}
