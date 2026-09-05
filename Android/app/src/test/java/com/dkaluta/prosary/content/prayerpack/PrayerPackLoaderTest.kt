package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.prayerTranslationsEnglish
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipInputStream
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
    fun sharedAramaicPrayersKeepTheirHeadingsAndMatchingReadingAid() {
        assertEquals("שוּבחָא לַאבָא", PrayerPackStore.resolveBodyText("oAntiphons", "arc", "gloriaPatriTitle"))
        assertEquals(PrayerPackStore.resolveBodyText("trisagion", "arc", "gloriaPatri"),
            PrayerPackStore.resolveBodyText("oAntiphons", "arc", "gloriaPatri"))
        val readingAid = PrayerPackStore.transliteration("oAntiphons", "arc", "gloriaPatri")
        assertNotNull(readingAid)
        assertEquals(PrayerPackStore.transliteration("trisagion", "arc", "gloriaPatri"), readingAid)
        assertFalse(readingAid == PrayerPackStore.transliteration("rosary", "arc", "gloriaPatri"))
        assertNull(PrayerPackStore.transliteration("oAntiphons", "en", "gloriaPatri"))
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
     * deliberately absent from every bundle (see Shared/ARCHITECTURE.markdown) and must keep resolving
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

    /** Prayer artwork is packaged once, inside the portable bundles. This pins every shipped
     * image entry to the lazy pack index so removing the byte-identical drawable copies cannot
     * turn a later flow into the placeholder — including the cross-bundle images used by the
     * bundle-less Jesus Prayer and Basic Prayers screens. */
    @Test
    fun everyShippedArtworkKeyResolvesFromAPack() {
        val packedImageKeys = buildSet {
            val packs = File("src/main/assets").listFiles { file ->
                file.extension == "prosaryprayer"
            }.orEmpty()
            for (pack in packs) {
                ZipInputStream(pack.inputStream()).use { zip ->
                    var entry = zip.nextEntry
                    while (entry != null) {
                        if (!entry.isDirectory && entry.name.startsWith("images/")) {
                            add(entry.name.substringAfterLast('/').substringBeforeLast('.'))
                        }
                        zip.closeEntry()
                        entry = zip.nextEntry
                    }
                }
            }
        }

        assertTrue(packedImageKeys.isNotEmpty())
        assertTrue("Jesus Prayer artwork must remain pack-backed", "christ_pantocrator" in packedImageKeys)
        assertTrue("Basic Prayer artwork must remain pack-backed", "jesus_portrait" in packedImageKeys)
        for (imageKey in packedImageKeys) {
            assertTrue("$imageKey was not indexed from its pack", PrayerPackStore.hasImage(imageKey))
        }
        assertTrue((PrayerPackStore.imageData("christ_pantocrator")?.size ?: 0) > 0)
        assertTrue((PrayerPackStore.imageData("jesus_portrait")?.size ?: 0) > 0)
    }

    @Test
    fun prayerArtworkIsNotDuplicatedAsLooseDrawables() {
        val looseArtwork = File("src/main/res/drawable-nodpi").listFiles { file ->
            file.extension.lowercase() in setOf("jpg", "jpeg", "webp")
        }.orEmpty()
        assertTrue("pack-backed artwork should not also ship in drawable-nodpi", looseArtwork.isEmpty())
        assertTrue("launcher foreground remains a drawable", File("src/main/res/drawable-nodpi/ic_launcher_foreground.png").exists())
    }

    @Test
    fun removingAnInstalledImageOverrideRestoresTheBuiltInSource() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val imageKey = "joyful_01_annunciation"
        val originalRequest = requireNotNull(PrayerPackStore.imageRequest(imageKey))
        val originalBytes = requireNotNull(originalRequest.read())
        val overrideBytes = byteArrayOf(0xff.toByte(), 0xd8.toByte(), 1, 2, 3, 0xff.toByte(), 0xd9.toByte())
        val id = "imageOverride${(1000..9999).random()}"

        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            fun put(name: String, bytes: ByteArray) {
                zip.putNextEntry(java.util.zip.ZipEntry(name))
                zip.write(bytes)
                zip.closeEntry()
            }
            put(
                "manifest.json",
                """{"schemaVersion": 1, "id": "$id", "kind": "$id", "displayName": "Image Override",
                    "languages": ["en"], "hasCatalog": false, "images": ["$imageKey"]}""".toByteArray(),
            )
            put("content/en.json", """{"prayers": {"example": "Example"}, "mysteries": {}}""".toByteArray())
            put(
                "devotion.json",
                """{"type": "steps", "steps": [{"title": "Example", "bodyKey": "example", "imageKey": "$imageKey"}]}""".toByteArray(),
            )
            put("images/$imageKey.jpg", overrideBytes)
        }

        PrayerPackStore.installPack(out.toByteArray())
        val overrideRequest = requireNotNull(PrayerPackStore.imageRequest(imageKey))
        assertFalse("a new winner must get a new decoded-cache key", originalRequest.cacheKey == overrideRequest.cacheKey)
        assertArrayEquals(overrideBytes, overrideRequest.read())

        PrayerPackStore.removeInstalledPack(id)
        val restoredRequest = requireNotNull(PrayerPackStore.imageRequest(imageKey))
        assertFalse("restoring the built-in must invalidate the override cache key", overrideRequest.cacheKey == restoredRequest.cacheKey)
        assertArrayEquals(originalBytes, restoredRequest.read())
    }

    /** A sequential ZipInputStream has to process the corrupt first member before it can reach
     * metadata or a later image. Installed packs use the central-directory reader instead, so
     * neither operation touches that member; requesting the corrupt member itself still fails
     * its DEFLATE/CRC validation and proves the fixture is genuinely damaged. */
    @Test
    fun installedPackDoesNotInflateAnEarlierCorruptImageToLoadMetadataOrReadALaterImage() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val suffix = (1000..9999).random()
        val id = "seekable$suffix"
        val corruptKey = "corrupt_earlier_$suffix"
        val laterKey = "valid_later_$suffix"
        val corruptBytes = ByteArray(64 * 1024).also { java.util.Random(7).nextBytes(it) }
        val laterBytes = "later image bytes".toByteArray()

        val out = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(out).use { zip ->
            fun put(name: String, bytes: ByteArray) {
                zip.putNextEntry(java.util.zip.ZipEntry(name))
                zip.write(bytes)
                zip.closeEntry()
            }
            put("images/$corruptKey.jpg", corruptBytes)
            put(
                "manifest.json",
                """{"schemaVersion": 1, "id": "$id", "kind": "$id", "displayName": "Seekable Test",
                    "languages": ["en"], "hasCatalog": false, "images": ["$corruptKey", "$laterKey"]}""".toByteArray(),
            )
            put("content/en.json", """{"prayers": {"example": "Example"}, "mysteries": {}}""".toByteArray())
            put(
                "devotion.json",
                """{"type": "steps", "steps": [{"title": "Example", "bodyKey": "example", "imageKey": "$laterKey"}]}""".toByteArray(),
            )
            put("images/$laterKey.jpg", laterBytes)
        }

        val damagedPack = corruptCompressedEntry(out.toByteArray(), "images/$corruptKey.jpg")
        assertEquals(id, PrayerPackStore.installPack(damagedPack))
        assertEquals("Example", PrayerPackStore.resolveBodyText(id, "en", "example"))
        assertArrayEquals(laterBytes, PrayerPackStore.imageData(laterKey))
        assertNull("the damaged member must fail when directly requested", PrayerPackStore.imageData(corruptKey))
        PrayerPackStore.removeInstalledPack(id)
    }

    @Test
    fun seekableIndexRejectsUnsafeDuplicateAndDisagreeingRecords() {
        val unsafe = java.io.ByteArrayOutputStream().also { out ->
            java.util.zip.ZipOutputStream(out).use { zip ->
                zip.putNextEntry(java.util.zip.ZipEntry("../outside.json"))
                zip.write("{}".toByteArray())
                zip.closeEntry()
            }
        }.toByteArray()
        assertSeekableZipRejected(unsafe)

        val twoNames = java.io.ByteArrayOutputStream().also { out ->
            java.util.zip.ZipOutputStream(out).use { zip ->
                for (name in listOf("one", "two")) {
                    zip.putNextEntry(java.util.zip.ZipEntry(name))
                    zip.write(name.toByteArray())
                    zip.closeEntry()
                }
            }
        }.toByteArray()
        val duplicate = twoNames.copyOf()
        val secondCentral = findCentralRecord(duplicate, "two")
        val secondLocal = u32(duplicate, secondCentral + 42).toInt()
        "one".toByteArray().copyInto(duplicate, secondCentral + 46)
        "one".toByteArray().copyInto(duplicate, secondLocal + 30)
        assertSeekableZipRejected(duplicate)

        val localMismatch = makeExamplePack("mismatch${(1000..9999).random()}").copyOf()
        val manifestCentral = findCentralRecord(localMismatch, "manifest.json")
        val manifestLocal = u32(localMismatch, manifestCentral + 42).toInt()
        localMismatch[manifestLocal + 14] = (localMismatch[manifestLocal + 14].toInt() xor 1).toByte()
        assertSeekableZipRejected(localMismatch)
    }

    @Test
    fun seekableIndexRejectsDescriptorCentralSizeAndLocalOverlapTampering() {
        val descriptorMismatch = makeExamplePack("descriptor${(1000..9999).random()}").copyOf()
        val manifestCentral = findCentralRecord(descriptorMismatch, "manifest.json")
        val manifestLocal = u32(descriptorMismatch, manifestCentral + 42).toInt()
        val dataOffset = manifestLocal + 30 + u16(descriptorMismatch, manifestLocal + 26) +
            u16(descriptorMismatch, manifestLocal + 28)
        val descriptorOffset = dataOffset + u32(descriptorMismatch, manifestCentral + 20).toInt()
        val crcOffset = descriptorOffset + if (u32(descriptorMismatch, descriptorOffset) == 0x08074b50L) 4 else 0
        descriptorMismatch[crcOffset] = (descriptorMismatch[crcOffset].toInt() xor 1).toByte()
        assertSeekableZipRejected(descriptorMismatch)

        val wrongCentralSize = makeExamplePack("central${(1000..9999).random()}").copyOf()
        val eocd = wrongCentralSize.size - 22
        writeU32(u32(wrongCentralSize, eocd + 12).toInt() - 1, wrongCentralSize, eocd + 12)
        assertSeekableZipRejected(wrongCentralSize)

        val overlapping = storedEntries("a" to byteArrayOf(1), "b" to byteArrayOf(2))
        val firstCentral = findCentralRecord(overlapping, "a")
        val firstLocal = u32(overlapping, firstCentral + 42).toInt()
        writeU32(33, overlapping, firstLocal + 18)
        writeU32(33, overlapping, firstLocal + 22)
        writeU32(33, overlapping, firstCentral + 20)
        writeU32(33, overlapping, firstCentral + 24)
        assertSeekableZipRejected(overlapping)
    }

    @Test
    fun installByteCountIsRejectedBeforeAWholeArchiveAllocation() {
        PrayerPackStore.requireInstallByteCount(SeekableZipArchive.MAX_ARCHIVE_BYTES)
        assertTrue(runCatching {
            PrayerPackStore.requireInstallByteCount(SeekableZipArchive.MAX_ARCHIVE_BYTES + 1)
        }.exceptionOrNull() is PrayerPackStore.InstallException)
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

    /** Flips one byte in a named DEFLATE member while leaving its central-directory metadata
     * intact. This makes an eager/sequential reader fail but preserves all later ZIP offsets. */
    private fun corruptCompressedEntry(pack: ByteArray, entryName: String): ByteArray {
        val result = pack.copyOf()
        val wantedName = entryName.toByteArray(Charsets.UTF_8)
        var centralOffset = -1
        for (offset in 0..result.size - 46 - wantedName.size) {
            if (u32(result, offset) != 0x02014b50L) continue
            if (u16(result, offset + 28) != wantedName.size) continue
            if (result.copyOfRange(offset + 46, offset + 46 + wantedName.size).contentEquals(wantedName)) {
                centralOffset = offset
                break
            }
        }
        assertTrue("missing central-directory entry for $entryName", centralOffset >= 0)
        assertEquals("test fixture must use DEFLATE", 8, u16(result, centralOffset + 10))
        val compressedSize = u32(result, centralOffset + 20).toInt()
        val localOffset = u32(result, centralOffset + 42).toInt()
        assertEquals(0x04034b50L, u32(result, localOffset))
        val dataOffset = localOffset + 30 + u16(result, localOffset + 26) + u16(result, localOffset + 28)
        assertTrue("compressed fixture must contain data", compressedSize > 2)
        val damageOffset = dataOffset + compressedSize / 2
        result[damageOffset] = (result[damageOffset].toInt() xor 0x5a).toByte()
        return result
    }

    private fun u16(bytes: ByteArray, offset: Int): Int =
        (bytes[offset].toInt() and 0xff) or ((bytes[offset + 1].toInt() and 0xff) shl 8)

    private fun u32(bytes: ByteArray, offset: Int): Long =
        (u16(bytes, offset).toLong() or (u16(bytes, offset + 2).toLong() shl 16)) and 0xffff_ffffL

    private fun findCentralRecord(bytes: ByteArray, name: String): Int {
        val wanted = name.toByteArray(Charsets.UTF_8)
        for (offset in 0..bytes.size - 46 - wanted.size) {
            if (u32(bytes, offset) != 0x02014b50L || u16(bytes, offset + 28) != wanted.size) continue
            if (bytes.copyOfRange(offset + 46, offset + 46 + wanted.size).contentEquals(wanted)) {
                return offset
            }
        }
        error("missing central entry $name")
    }

    private fun writeU32(value: Int, bytes: ByteArray, offset: Int) {
        bytes[offset] = (value and 0xff).toByte()
        bytes[offset + 1] = ((value ushr 8) and 0xff).toByte()
        bytes[offset + 2] = ((value ushr 16) and 0xff).toByte()
        bytes[offset + 3] = ((value ushr 24) and 0xff).toByte()
    }

    private fun storedEntries(vararg files: Pair<String, ByteArray>): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        java.util.zip.ZipOutputStream(output).use { zip ->
            for ((name, bytes) in files) {
                val checksum = java.util.zip.CRC32().apply { update(bytes) }
                val entry = java.util.zip.ZipEntry(name).apply {
                    method = java.util.zip.ZipEntry.STORED
                    size = bytes.size.toLong()
                    compressedSize = bytes.size.toLong()
                    crc = checksum.value
                }
                zip.putNextEntry(entry)
                zip.write(bytes)
                zip.closeEntry()
            }
        }
        return output.toByteArray()
    }

    private fun assertSeekableZipRejected(bytes: ByteArray) {
        val file = File.createTempFile("prosary-malformed-", ".zip")
        try {
            file.writeBytes(bytes)
            assertTrue(runCatching { SeekableZipArchive.fromFile(file) }.isFailure)
        } finally {
            file.delete()
        }
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
        assertEquals("exampleBody", PrayerPackStore.resolveBodyText(id, "en", "exampleBody"))
    }

    @Test
    fun importedBundleIdCannotEscapeTheInstalledPackDirectory() {
        val installedDirectory = java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        PrayerPackStore.installedPacksDirectory = installedDirectory
        val escapedStem = "prosaryEscape${(1000..9999).random()}"
        val escapedFile = File(installedDirectory.parentFile, "$escapedStem.prosaryprayer")

        val failure = runCatching { PrayerPackStore.installPack(makeExamplePack("../$escapedStem")) }
        assertTrue(failure.exceptionOrNull() is PrayerPackStore.InstallException)
        assertFalse("an invalid bundle id must not write outside the pack directory", escapedFile.exists())
        assertTrue(
            "failed imports must clean their staged file",
            installedDirectory.listFiles().orEmpty().none { it.name.startsWith(".prosary-import-") },
        )
    }

    @Test
    fun dottedRepositoryStyleBundleIdRemainsValid() {
        PrayerPackStore.installedPacksDirectory =
            java.nio.file.Files.createTempDirectory("prosary-test-packs").toFile()
        val id = "example.test-${(1000..9999).random()}_v1"
        assertEquals(id, PrayerPackStore.installPack(makeExamplePack(id)))
        assertNotNull(PrayerPackStore.installedPackFile(id))
        PrayerPackStore.removeInstalledPack(id)
    }

    /** A days-type (multi-day) bundle decodes, installs, and prays its first day — the
     * groundwork contract until per-favorite day progress ships (see ARCHITECTURE.markdown). */
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

    /** An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.markdown's "Audio
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
        assertEquals("0b4c4a52-47", PrayerPackStore.audioCacheKey(id, "audio/en.opus"))
        assertNull(PrayerPackStore.audioCacheKey(id, "manifest.json"))
        assertNull(PrayerPackStore.audioData(id, "manifest.json"))
        assertTrue(PrayerPackStore.audioTracks("angelus").isEmpty())
        assertNull(PrayerPackStore.audioData("angelus", "audio/en.opus"))
        val extracted = ByteArrayOutputStream()
        assertTrue(PrayerPackStore.writeAudioTo(id, "audio/en.opus", extracted))
        assertArrayEquals(opusBytes, extracted.toByteArray())
        assertFalse(PrayerPackStore.writeAudioTo(id, "manifest.json", ByteArrayOutputStream()))
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
            "divineMercyChaplet", "trisagion", "oAntiphons",
        )) {
            assertTrue("missing $pack.prosaryprayer", File("src/main/assets/$pack.prosaryprayer").exists())
        }
    }

    /** The Rosary's pack now ships a devotion.json (the engine builds the Rosary from it), but
     * its manifest's builtinKind keeps it off the generic-devotion list — it backs the
     * dedicated PrayerKind and must never appear in the devotion directory twice. The generic
     * devotions appear in pack-load order. */
    @Test
    fun customDevotionIdsAreTheGenericDevotionsInLoadOrder() {
        assertEquals(
            listOf(
                "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
                "divineMercyChaplet", "trisagion", "oAntiphons",
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

    /** Android's Locale reports Hebrew by its pre-1989 code — getLanguage() gives "iw", never
     * "he" — so every UI-language lookup that fed it straight into a manifest's "he" keys fell
     * back to English for exactly the audience those keys were written for. The normalization
     * is a pure function so this can pin it without fighting the JVM's own Locale behavior. */
    @Test
    fun legacyLocaleCodesNormalizeToTheContentLayersSpelling() {
        assertEquals("he", LanguageCatalog.uiLanguageCode("iw"))
        assertEquals("he", LanguageCatalog.uiLanguageCode("he"))
        assertEquals("id", LanguageCatalog.uiLanguageCode("in"))
        assertEquals("en", LanguageCatalog.uiLanguageCode("en"))
    }

    /** A devotion's name follows the prayer language, rites included — Erez's ask: with his
     * rite as the default prayer language, the Trisagion card reads קדישת; plain Hebrew reads
     * טריסאגיון; a rite falls to its base when the bundle only names the base language. */
    @Test
    fun displayNameFollowsThePrayerLanguage() {
        val saved = AppSettings.defaultLanguageCode
        try {
            AppSettings.setDefaultLanguageCode("he-x-gamliel")
            assertEquals("קדישת", PrayerPackStore.info("trisagion")?.localizedDisplayName)
            assertEquals(
                PrayerPackStore.info("divineMercyChaplet")?.displayNameByLanguage?.get("he"),
                PrayerPackStore.info("divineMercyChaplet")?.localizedDisplayName,
            )

            AppSettings.setDefaultLanguageCode("he")
            assertEquals("טריסאגיון", PrayerPackStore.info("trisagion")?.localizedDisplayName)

            AppSettings.setDefaultLanguageCode("la")
            assertEquals("Trisagion", PrayerPackStore.info("trisagion")?.localizedDisplayName)
        } finally {
            AppSettings.setDefaultLanguageCode(saved)
        }
    }

    @Test
    fun trisagionDefinitionMatchesTheAuthoredSixStepSequence() {
        val definition = PrayerPackStore.definition("trisagion")
        assertEquals(CustomDevotionDefinition.DevotionType.Steps, definition?.type)
        // The bundle names its forms now (Byzantine first = the default, Syriac second); the
        // default form must remain the authored six steps, byte-identical.
        assertEquals(listOf("byzantine", "syriac"), definition?.variants?.map { it.id })
        val steps = definition?.resolvedSteps(null)?.first.orEmpty()
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
