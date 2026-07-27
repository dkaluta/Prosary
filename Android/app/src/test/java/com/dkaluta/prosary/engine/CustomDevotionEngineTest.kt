package com.dkaluta.prosary.engine

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/** [PrayerEngine.buildCustomDevotionSteps] is the one generic builder behind every
 * PrayerKind.Custom devotion; these tests exercise it via the actual bundled
 * trisagion.prosaryprayer (produced by Shared/tools/make-prosaryprayer.sh from
 * Shared/content/trisagion) rather than a fixture, the same convention PrayerPackLoaderTest uses
 * for Rosary/Angelus. Mirrors iOS's CustomDevotionEngineTests.swift. */
class CustomDevotionEngineTest {
    companion object {
        @BeforeClass
        @JvmStatic
        fun loadPacks() {
            PrayerPackStore.initialize { packName ->
                val file = File("src/main/assets/$packName.prosaryprayer")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    @Test
    fun trisagionProducesTheSixStepSequence() {
        val engine = PrayerEngine()
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Custom, languageCode = "en", customDevotionId = "trisagion"))

        assertEquals(6, steps.size)
        assertEquals(
            listOf("Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"),
            steps.map { it.title },
        )
        assertTrue(steps[0].body.contains("Holy God, Holy Mighty One, Holy Immortal One"))
        assertTrue(steps[3].body.contains("Glory be to the Father"))
        assertTrue(steps[4].body.contains("Holy Immortal One, have mercy on us."))
        assertFalse(steps[4].body.contains("Holy Mighty One"))
    }

    @Test
    fun trisagionImagesMatchTheStepsJsonImageKeys() {
        val engine = PrayerEngine()
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Custom, languageCode = "en", customDevotionId = "trisagion"))

        assertEquals(
            listOf("jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait"),
            steps.map { it.imageKey },
        )
    }

    @Test
    fun missingCustomDevotionIdProducesNoSteps() {
        val engine = PrayerEngine()
        val steps = engine.buildSteps(Prayer(kind = PrayerKind.Custom, languageCode = "en"))
        assertTrue(steps.isEmpty())
    }
}
