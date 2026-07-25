package com.dkaluta.prosary.models

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class JesusPrayerProgressTest {
    @Test
    fun canGoBack() {
        var progress = JesusPrayerProgress(target = JesusPrayerTarget.Count(33))
        assertFalse(progress.canGoBack)
        progress = progress.goNext()
        assertTrue(progress.canGoBack)
    }

    @Test
    fun boundedCompletionAtVariousTargets() {
        for (target in listOf(33, 66, 99, 47)) {
            var progress = JesusPrayerProgress(target = JesusPrayerTarget.Count(target))
            repeat(target - 1) {
                assertFalse("target $target", progress.isLastRep)
                progress = progress.goNext()
            }
            assertTrue("target $target", progress.isLastRep)
            assertEquals(target - 1, progress.currentIndex)
        }
    }

    @Test
    fun goNextDoesNotOvershootBoundedTarget() {
        var progress = JesusPrayerProgress(target = JesusPrayerTarget.Count(3), currentIndex = 2)
        progress = progress.goNext()
        assertEquals(2, progress.currentIndex)
    }

    @Test
    fun goBackDoesNotUndershootZero() {
        var progress = JesusPrayerProgress(target = JesusPrayerTarget.Count(33))
        progress = progress.goBack()
        assertEquals(0, progress.currentIndex)
    }

    @Test
    fun unboundedNeverCompletes() {
        var progress = JesusPrayerProgress(target = JesusPrayerTarget.Unbounded)
        repeat(10_000) { progress = progress.goNext() }
        assertFalse(progress.isLastRep)
        assertNull(progress.targetCount)
        assertNull(progress.progressFraction)
    }

    @Test
    fun progressFraction() {
        val progress = JesusPrayerProgress(target = JesusPrayerTarget.Count(33))
        assertEquals(1.0f / 33.0f, progress.progressFraction!!, 0.0001f)
    }
}
