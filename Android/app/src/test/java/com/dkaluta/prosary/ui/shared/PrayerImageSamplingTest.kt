package com.dkaluta.prosary.ui.shared

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PrayerImageSamplingTest {
    @Test
    fun sampleSizeBoundsPortraitAndLandscapeImagesAt2048Pixels() {
        assertEquals(1, prayerImageSampleSize(2_048, 2_048))
        assertEquals(2, prayerImageSampleSize(2_049, 1_000))
        assertEquals(2, prayerImageSampleSize(1_000, 4_096))
        assertEquals(4, prayerImageSampleSize(4_097, 2_000))
        assertEquals(8, prayerImageSampleSize(12_000, 3_000))

        for ((width, height) in listOf(2_049 to 1_000, 1_000 to 4_096, 12_000 to 3_000)) {
            val sample = prayerImageSampleSize(width, height)
            assertTrue(maxOf(width, height).toLong() / sample <= PRAYER_IMAGE_MAX_DIMENSION)
        }
    }

    @Test
    fun invalidBoundsLeaveBitmapFactoryUnsampled() {
        assertEquals(1, prayerImageSampleSize(0, 4_000))
        assertEquals(1, prayerImageSampleSize(4_000, -1))
    }
}
