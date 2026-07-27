package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.prayerTranslationsEnglish
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/** Proves the whole .prosaryprayer pipeline end-to-end against the actual bundled
 * rosary.prosaryprayer/angelus.prosaryprayer files under app/src/main/assets/ (produced by
 * Shared/tools/make-prosaryprayer.sh from Shared/content/) — mirrors iOS's
 * PrayerPackLoaderTests.swift. Plain JVM test, no Android Context/AssetManager needed:
 * [PrayerPackStore.initialize] takes a generic byte-source function, fed here from a plain File. */
class PrayerPackLoaderTest {
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
    fun rosaryPackProvidedKeyOverridesEnglishText() {
        val text = PrayerTranslations.get("en", PrayerKey.OratioFatimae)
        assertEquals(
            "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those who are in most need of Thy mercy.",
            text,
        )
    }

    @Test
    fun rosaryPackProvidedMysteryOverridesLatinTitle() {
        val text = MysteryTranslations.get("la", "joyful_01_annunciation")
        assertEquals("Nuntiatio", text.title)
        assertEquals("Humilitas", text.fruit)
    }

    @Test
    fun angelusPackProvidedKeyOverridesHebrewText() {
        val text = PrayerTranslations.get("he", PrayerKey.CollectaAngelus)
        assertFalse(text.isEmpty())
        assertTrue(text.startsWith("נִתְפַּלְּלָה"))
    }

    /** The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
     * deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
     * from the hardcoded table even with both packs loaded. */
    @Test
    fun mainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
        val text = PrayerTranslations.get("en", PrayerKey.AveMaria)
        assertEquals(prayerTranslationsEnglish[PrayerKey.AveMaria], text)
    }

    /** A devotion with no shipped pack at all (Stations) must be completely unaffected. */
    @Test
    fun unmigratedDevotionKeyStillResolvesFromHardcodedTable() {
        val text = PrayerTranslations.get("en", PrayerKey.StationsOpeningPrayer)
        assertEquals(prayerTranslationsEnglish[PrayerKey.StationsOpeningPrayer], text)
    }

    @Test
    fun rosaryPackProvidesImageDataForAMysteryKey() {
        val data = PrayerPackStore.imageData("joyful_01_annunciation")
        assertNotNull(data)
        assertTrue((data?.size ?: 0) > 0)
    }

    @Test
    fun packProvidesNoImageDataForAnUnrelatedKey() {
        assertNull(PrayerPackStore.imageData("station_01_condemned_to_death"))
    }

    // MARK: Generic (bundle-driven) devotions

    @Test
    fun trisagionIsDiscoveredAsACustomDevotion() {
        assertTrue(PrayerPackStore.customDevotionIds().contains("trisagion"))
    }

    /** A devotion with no steps.json at all (Rosary/Angelus) is never mistaken for a generic
     * one. */
    @Test
    fun packsWithNoStepsJsonAreNotCustomDevotions() {
        assertFalse(PrayerPackStore.customDevotionIds().contains("rosary"))
        assertFalse(PrayerPackStore.customDevotionIds().contains("angelus"))
    }

    @Test
    fun trisagionInfoReadsFromItsManifest() {
        val info = PrayerPackStore.info("trisagion")
        assertEquals("Trisagion", info?.displayName)
        assertEquals("#00796B", info?.accentColorHex)
        assertEquals("triangle", info?.iconSystemName)
    }

    @Test
    fun trisagionStepsMatchTheAuthoredSixStepSequence() {
        val steps = PrayerPackStore.steps("trisagion")
        assertEquals(
            listOf("Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"),
            steps.map { it.title },
        )
        assertEquals(
            listOf(
                "trisagionAcclamation", "trisagionAcclamation", "trisagionAcclamation",
                "gloriaPatri", "trisagionShortAcclamation", "trisagionAcclamation",
            ),
            steps.map { it.bodyKey },
        )
    }

    /** [PrayerPackStore.resolveBodyText] step 1 — a bundle-local-only key (never a [PrayerKey]
     * case) resolves from the bundle's own raw content. */
    @Test
    fun resolveBodyTextResolvesABundleLocalKey() {
        val text = PrayerPackStore.resolveBodyText("trisagion", "en", "trisagionAcclamation")
        assertEquals("Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.", text)
    }

    /** [PrayerPackStore.resolveBodyText] step 2 — a key matching an existing [PrayerKey] case
     * (here, "gloriaPatri", a "main" prayer deliberately absent from every bundle) falls through
     * to the ordinary hardcoded table. */
    @Test
    fun resolveBodyTextFallsThroughToASharedPrayerKey() {
        val text = PrayerPackStore.resolveBodyText("trisagion", "en", "gloriaPatri")
        assertEquals(PrayerTranslations.get("en", PrayerKey.GloriaPatri), text)
    }

    /** [PrayerPackStore.resolveBodyText] step 3 — an unresolvable key returns itself, matching
     * [PrayerTranslations.get]'s own last-resort fallback. */
    @Test
    fun resolveBodyTextFallsBackToTheRawKey() {
        val text = PrayerPackStore.resolveBodyText("trisagion", "en", "notARealKey")
        assertEquals("notARealKey", text)
    }
}
