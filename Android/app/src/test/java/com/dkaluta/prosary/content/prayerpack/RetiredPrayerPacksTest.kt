package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.persistence.PresetDao
import com.dkaluta.prosary.persistence.PresetEntity
import com.dkaluta.prosary.persistence.RoomPresetStore
import com.dkaluta.prosary.presets.MockPresetStore
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.file.Files
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class RetiredPrayerPacksTest {
    private val retiredId = "repo.stgamliel-il.litanyOfMaryTheBlessedEverVirgin"
    private lateinit var directory: File

    @Before
    fun prepare() {
        PrayerPackStore.resetForTesting()
        directory = Files.createTempDirectory("prosary-retired-packs").toFile()
        PrayerPackStore.installedPacksDirectory = directory
    }

    @After
    fun restoreBuiltIns() {
        directory.deleteRecursively()
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf { it.exists() }?.inputStream() }
    }

    @Test
    fun startupPurgesCanonicalAndRenamedDownloadsWhileKeepingOtherPrayers() {
        val retired = File(directory, "$retiredId.prosaryprayer").apply { writeBytes(pack(retiredId)) }
        val renamed = File(directory, "renamed.prosaryprayer").apply { writeBytes(pack(retiredId)) }
        val retainedId = "repo.stgamliel-il.otherPrayer"
        val retained = File(directory, "$retainedId.prosaryprayer").apply { writeBytes(pack(retainedId)) }
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf { it.exists() }?.inputStream() }

        assertFalse(retired.exists())
        assertFalse(renamed.exists())
        assertTrue(retained.exists())
        assertEquals(listOf(retainedId), PrayerPackStore.installedBundleIds())
        assertNull(PrayerPackStore.definition(retiredId))
        assertNotNull(PrayerPackStore.definition("litanyOfLoreto"))
        assertNotNull(PrayerPackStore.definition("rosary"))
    }

    @Test
    fun filenameAloneRetiresACorruptedOldDownload() {
        val retired = File(directory, "$retiredId.prosaryprayer").apply { writeText("corrupted old download") }
        PrayerPackStore.initialize { null }
        assertFalse(retired.exists())
        assertTrue(PrayerPackStore.installedBundleIds().isEmpty())
    }

    @Test
    fun fileImportCannotRestoreTheWithdrawnManifest() {
        PrayerPackStore.initialize { null }
        assertTrue(runCatching { PrayerPackStore.installPack(pack(retiredId)) }.exceptionOrNull() is PrayerPackStore.InstallException)
        assertTrue(directory.listFiles().orEmpty().isEmpty())
        assertNull(PrayerPackStore.info(retiredId))
        val retainedId = "repo.stgamliel-il.otherPrayer"
        assertEquals(retainedId, PrayerPackStore.installPack(pack(retainedId)))
    }

    @Test
    fun evenAnUnexpectedBuiltinSourceCannotLoadTheWithdrawnManifest() {
        PrayerPackStore.initialize { pack(retiredId).inputStream() }
        assertNull(PrayerPackStore.info(retiredId))
        assertTrue(PrayerPackStore.customDevotionIds().isEmpty())
    }

    @Test
    fun migrationCancelsAndDeletesEverySavedCopyAndStaysNarrowAndIdempotent() = runBlocking {
        val first = Prayer(name = "Old standalone", kind = PrayerKind.Custom, customDevotionId = retiredId,
            isDefault = true, reminders = listOf(PrayerReminder(hour = 7)))
        val second = first.copy(id = "another-copy", isDefault = false)
        val rosary = Prayer(name = "Rosary", kind = PrayerKind.Rosary)
        val builtIn = Prayer(name = "Loreto", kind = PrayerKind.Custom, customDevotionId = "litanyOfLoreto")
        val sameAuthor = Prayer(name = "Other", kind = PrayerKind.Custom, customDevotionId = "repo.stgamliel-il.otherPrayer")
        val store = MockPresetStore(listOf(first, second, rosary, builtIn, sameAuthor))
        val cancelled = mutableListOf<Prayer>()
        RetiredPrayerPacks.removeSavedPrayers(store) { cancelled += it }
        RetiredPrayerPacks.removeSavedPrayers(store) { cancelled += it }

        assertEquals(setOf(first.id, second.id), cancelled.map { it.id }.toSet())
        assertEquals(2, cancelled.size)
        assertEquals(first.reminders, cancelled.first { it.id == first.id }.reminders)
        assertEquals(setOf(rosary.id, builtIn.id, sameAuthor.id), store.all().map { it.id }.toSet())
        assertTrue(runCatching { store.save(first) }.isFailure)
        assertFalse(store.updateIfPresent(first))
    }

    @Test
    fun failedReminderCancellationPreservesTheSavedCopyForRetry() = runBlocking {
        val prayer = Prayer(name = "Old standalone", kind = PrayerKind.Custom, customDevotionId = retiredId)
        val store = MockPresetStore(listOf(prayer))
        assertTrue(runCatching {
            RetiredPrayerPacks.removeSavedPrayers(store) { throw java.io.IOException("Retry cleanup") }
        }.isFailure)
        assertEquals(prayer.id, store.get(prayer.id)?.id)
    }

    @Test
    fun productionStoreCannotRecreateAWithdrawnCopyFromAStaleEditor() = runBlocking {
        val dao = object : PresetDao {
            override suspend fun getAll(): List<PresetEntity> = error("Must not access persistence")
            override suspend fun getById(id: String): PresetEntity? = error("Must not access persistence")
            override suspend fun count(): Int = error("Must not access persistence")
            override suspend fun upsert(entity: PresetEntity): Unit = error("Must not access persistence")
            override suspend fun update(entity: PresetEntity): Int = error("Must not access persistence")
            override suspend fun delete(entity: PresetEntity): Unit = error("Must not access persistence")
        }
        val store = RoomPresetStore(dao)
        val retired = Prayer(name = "Old standalone", kind = PrayerKind.Custom, customDevotionId = retiredId)
        assertTrue(runCatching { store.save(retired) }.exceptionOrNull() is IllegalArgumentException)
        assertFalse(store.updateIfPresent(retired))
    }

    private fun pack(id: String): ByteArray {
        val output = ByteArrayOutputStream()
        ZipOutputStream(output).use { zip ->
            fun put(name: String, text: String) {
                zip.putNextEntry(ZipEntry(name))
                zip.write(text.toByteArray())
                zip.closeEntry()
            }
            put("manifest.json", """{"schemaVersion":1,"id":"$id","kind":"$id","displayName":"Example",
                "languages":["en"],"hasCatalog":false,"images":[]}""")
            put("devotion.json", """{"type":"steps","steps":[{"title":"Example","bodyKey":"example"}]}""")
            put("content/en.json", """{"prayers":{"example":"Kyrie eleison."},"mysteries":{}}""")
        }
        return output.toByteArray()
    }
}
