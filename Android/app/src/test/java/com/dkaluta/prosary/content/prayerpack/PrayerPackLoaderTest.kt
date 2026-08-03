package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.prayerTranslationsEnglish
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/** Proves the whole .prosaryprayer pipeline end-to-end against the actual bundled
 * .prosaryprayer files under app/src/main/assets/ (produced by
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
    fun angelusPackProvidesHebrewComposedBody() {
        val text = PrayerPackStore.resolveBodyText("angelus", "he", "angelusCollectBody")
        assertFalse(text.isEmpty())
        assertTrue(text.contains("נִתְפַּלְּלָה"))
    }

    /** The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
     * deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
     * from the hardcoded table even with both packs loaded. */
    @Test
    fun mainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
        val text = PrayerTranslations.get("en", PrayerKey.AveMaria)
        assertEquals(prayerTranslationsEnglish[PrayerKey.AveMaria], text)
    }

    /** A devotion converted to a bundle resolves entirely bundle-locally — its keys no longer
     * exist in the hardcoded tables at all. */
    @Test
    fun convertedDevotionKeyResolvesFromItsBundle() {
        val text = PrayerPackStore.resolveBodyText("stationsOfTheCross", "en", "stationsOpeningPrayer")
        assertTrue(text.startsWith("My Lord Jesus Christ, You made this journey"))
    }

    @Test
    fun rosaryPackProvidesImageDataForAMysteryKey() {
        val data = PrayerPackStore.imageData("joyful_01_annunciation")
        assertNotNull(data)
        assertTrue((data?.size ?: 0) > 0)
    }

    @Test
    fun franciscanCrownDeclaresItsOptions() {
        val options = PrayerPackStore.options("franciscanCrown")
        assertEquals(listOf("seventyTwoHailMarys", "popeIntentions"), options.map { it.key })
        assertTrue(options.all { it.kind == CustomDevotionOption.Kind.Toggle && it.defaultValue == "true" })
        assertEquals("Complete the 72 Hail Marys", options[0].name)
        assertTrue(PrayerPackStore.options("angelus").isEmpty())
    }

    // MARK: User-installed bundles

    /** Builds a minimal, valid .prosaryprayer in memory — the same shape a third-party author
     * would produce. */
    private fun makeExamplePack(id: String): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            fun put(name: String, text: String) {
                zip.putNextEntry(java.util.zip.ZipEntry(name))
                zip.write(text.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            put(
                "manifest.json",
                """{"schemaVersion": 1, "id": "$id", "kind": "$id", "displayName": "Example Devotion",
                    "languages": ["la", "en"], "hasCatalog": false, "images": []}""",
            )
            val content = """{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"""
            put("content/la.json", content)
            put("content/en.json", content)
            put(
                "devotion.json",
                """{"type": "steps", "steps": [
                    {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
                    {"title": "Example Prayer", "bodyKey": "exampleBody"}
                ]}""",
            )
        }
        return out.toByteArray()
    }

    @Test
    fun installRemoveRoundTripForAnImportedBundle() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val id = "example${(1000..9999).random()}"
        val installed = PrayerPackStore.installPack(makeExamplePack(id))
        assertEquals(id, installed)
        assertTrue(PrayerPackStore.customDevotionIds().contains(id))
        assertTrue(PrayerPackStore.installedBundleIds().contains(id))
        assertEquals("Example Devotion", PrayerPackStore.info(id)?.displayName)
        assertEquals("Kyrie eleison.", PrayerPackStore.resolveBodyText(id, "en", "exampleBody"))

        // A second install of the same id must be rejected, not silently replaced.
        assertTrue(runCatching { PrayerPackStore.installPack(makeExamplePack(id)) }.isFailure)
        // Garbage is rejected.
        assertTrue(runCatching { PrayerPackStore.installPack("not a zip".toByteArray()) }.isFailure)

        PrayerPackStore.removeInstalledPack(id)
        assertFalse(PrayerPackStore.customDevotionIds().contains(id))
        assertEquals(null, PrayerPackStore.definition(id))
    }

    /** A days-type (multi-day) bundle decodes, installs, and prays its first day — the
     * groundwork contract until per-favorite day progress ships (see ARCHITECTURE.md). */
    @Test
    fun daysTypeBundlePraysItsFirstDay() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val id = "novena${(1000..9999).random()}"
        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            fun put(name: String, text: String) {
                zip.putNextEntry(java.util.zip.ZipEntry(name))
                zip.write(text.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }
            put(
                "manifest.json",
                """{"schemaVersion": 1, "id": "$id", "kind": "$id", "displayName": "Example Novena",
                    "languages": ["la", "en"], "hasCatalog": false, "images": []}""",
            )
            val content = """{"prayers": {"day1Body": "Day one prayer.", "day2Body": "Day two prayer."}, "mysteries": {}}"""
            put("content/la.json", content)
            put("content/en.json", content)
            put(
                "devotion.json",
                """{"type": "days",
                    "opening": [{"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"}],
                    "days": [
                      {"name": "Day 1", "steps": [{"title": "Day 1", "bodyKey": "day1Body"}]},
                      {"name": "Day 2", "steps": [{"title": "Day 2", "bodyKey": "day2Body"}]}
                    ],
                    "closing": [{"title": "Glory Be", "bodyKey": "gloriaPatri", "imageKey": "glory_be"}]}""",
            )
        }
        PrayerPackStore.installPack(out.toByteArray())

        val steps = PrayerEngine().buildSteps(
            Prayer(kind = PrayerKind.Custom, languageCode = "en", customDevotionId = id),
        )
        assertEquals(listOf("Sign of the Cross", "Day 1", "Glory Be"), steps.map { it.title })
        assertEquals("Day one prayer.", steps[1].body)
        PrayerPackStore.removeInstalledPack(id)
    }

    /** An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.md's "Audio
     * (groundwork)") parses its track metadata and serves a declared file's bytes on demand;
     * undeclared files stay unreachable, and audio-less bundles report no tracks. */
    @Test
    fun audioBearingBundleParsesTracksAndServesDeclaredBytes() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val id = "audio${(1000..9999).random()}"
        // A minimal Ogg Opus signature (RFC 7845): an "OggS" page whose one-segment payload is
        // the "OpusHead" identification header at offset 28 — enough for the format's checks,
        // no real audio needed to prove the metadata/bytes plumbing.
        val opusBytes = "OggS".toByteArray() + ByteArray(24) + "OpusHead".toByteArray() + ByteArray(11)
        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            fun put(name: String, bytes: ByteArray) {
                zip.putNextEntry(java.util.zip.ZipEntry(name))
                zip.write(bytes)
                zip.closeEntry()
            }
            put(
                "manifest.json",
                """{"schemaVersion": 1, "id": "$id", "kind": "$id", "displayName": "Example Devotion",
                    "languages": ["la", "en"], "hasCatalog": false, "images": []}""".toByteArray(),
            )
            val content = """{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"""
            put("content/la.json", content.toByteArray())
            put("content/en.json", content.toByteArray())
            put(
                "devotion.json",
                """{"type": "steps", "steps": [
                    {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
                    {"title": "Example Prayer", "bodyKey": "exampleBody"}
                ]}""".toByteArray(),
            )
            put(
                "audio.json",
                """{"tracks": [
                    {"id": "en", "language": "en", "file": "audio/en.opus", "name": "Full recitation",
                     "chapters": [
                       {"start": 0, "title": "Sign of the Cross", "stepIndex": 0},
                       {"start": 12.5, "title": "Example Prayer", "stepIndex": 1}
                     ]}
                ]}""".toByteArray(),
            )
            put("audio/en.opus", opusBytes)
        }
        PrayerPackStore.installPack(out.toByteArray())

        val tracks = PrayerPackStore.audioTracks(id)
        assertEquals(listOf("en"), tracks.map { it.id })
        val track = tracks.single()
        assertEquals("en", track.language)
        assertEquals("audio/en.opus", track.file)
        assertNull(track.variantId)
        assertEquals("Full recitation", track.name)
        assertEquals(listOf(0.0, 12.5), track.chapters.map { it.start })
        assertEquals(listOf(0, 1), track.chapters.map { it.stepIndex })
        assertEquals("Sign of the Cross", track.chapters[0].title)

        assertArrayEquals(opusBytes, PrayerPackStore.audioData(id, "audio/en.opus"))
        assertNull(PrayerPackStore.audioData(id, "manifest.json"))
        assertTrue(PrayerPackStore.audioTracks("angelus").isEmpty())
        assertNull(PrayerPackStore.audioData("angelus", "audio/en.opus"))
        PrayerPackStore.removeInstalledPack(id)
    }

    @Test
    fun stationsPackProvidesItsImageData() {
        val data = PrayerPackStore.imageData("station_01_condemned_to_death")
        assertTrue((data?.size ?: 0) > 0)
        // The scriptural variant's own scenes ship in the same pack.
        assertTrue((PrayerPackStore.imageData("scriptural_02_kiss_of_judas")?.size ?: 0) > 0)
    }

    @Test
    fun packProvidesNoImageDataForAnUnknownKey() {
        assertNull(PrayerPackStore.imageData("no_such_image_key"))
    }

    // MARK: Generic (bundle-driven) devotions

    @Test
    fun bundledPacksExist() {
        for (pack in listOf(
            "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
            "divineMercyChaplet", "trisagion",
        )) {
            assertTrue("missing $pack.prosaryprayer", File("src/main/assets/$pack.prosaryprayer").exists())
        }
    }

    /** The Rosary's pack now ships a devotion.json (the engine builds the Rosary from it), but
     * its manifest's builtinKind keeps it off the generic-devotion list — it backs the
     * dedicated PrayerKind and must never appear as a Home/Favorites card twice. The six
     * generic devotions appear in pack-load order. */
    @Test
    fun customDevotionIdsAreTheSevenGenericDevotionsInLoadOrder() {
        assertEquals(
            listOf(
                "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
                "divineMercyChaplet", "trisagion",
            ),
            PrayerPackStore.customDevotionIds(),
        )
        assertNotNull(PrayerPackStore.definition("rosary"))
    }

    @Test
    fun trisagionInfoReadsFromItsManifest() {
        val info = PrayerPackStore.info("trisagion")
        assertEquals("Trisagion", info?.displayName)
        assertEquals("#00796B", info?.accentColorHex)
        assertEquals("triangle", info?.iconSystemName)
    }

    @Test
    fun trisagionDefinitionMatchesTheAuthoredSixStepSequence() {
        val definition = PrayerPackStore.definition("trisagion")
        assertEquals(CustomDevotionDefinition.DevotionType.Steps, definition?.type)
        val steps = definition?.steps.orEmpty()
        // Headings are translatable keys, not literals, so they read in the prayer's language.
        assertEquals(
            listOf(
                "trisagionAcclamationTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
                "gloriaPatriTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
            ),
            steps.map { it.titleKey },
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
