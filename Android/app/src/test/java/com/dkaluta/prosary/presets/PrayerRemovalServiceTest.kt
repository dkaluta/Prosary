package com.dkaluta.prosary.presets

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerReminder
import java.io.IOException
import kotlinx.coroutines.runBlocking
import org.junit.Assert.*
import org.junit.Test

class PrayerRemovalServiceTest {
    private fun prayer(id: String = "first", bundle: String = "repo.test.prayer") = Prayer(
        id = id, name = id, kind = PrayerKind.Custom, customDevotionId = bundle,
        reminders = listOf(PrayerReminder(hour = 12)),
    )

    private class Fixture(val store: PresetStore, val builtIns: Set<String> = emptySet()) {
        val installed = mutableSetOf("repo.test.prayer", "repo.test.other")
        val removed = mutableListOf<String>()
        val cancelled = mutableListOf<Prayer>()
        val cleaned = mutableListOf<String>()
        var failRemoval = false
        var failCleanup = false
        val service = PrayerRemovalService(
            store, isInstalled = { it in installed }, isBuiltIn = { it in builtIns },
            removePack = {
                if (failRemoval) throw IOException("File deletion failed")
                installed.remove(it)
                removed.add(it)
            },
            cancelReminders = { cancelled.add(it) },
            didRemovePack = {
                if (failCleanup) throw IOException("Audio cleanup failed")
                cleaned.add(it)
            },
        )
    }

    @Test
    fun lastSavedCopyRemovesOnlyItsDownloadAfterDeletingItsRow() = runBlocking {
        val selected = prayer()
        val unrelated = prayer("other", "repo.test.other")
        val store = MockPresetStore(listOf(selected, unrelated))
        val f = Fixture(store)
        assertTrue(f.service.plan(selected).removesDownload)
        f.service.deleteSaved(selected)
        assertNull(store.get(selected.id))
        assertEquals(listOf(selected), f.cancelled)
        assertEquals(listOf("repo.test.prayer"), f.removed)
        assertEquals(f.removed, f.cleaned)
        assertNotNull(store.get(unrelated.id))
        assertTrue("another download stays installed", "repo.test.other" in f.installed)
    }

    @Test
    fun deletingOneOfTwoKeepsDownloadAndOtherCopiesReminders() = runBlocking {
        val selected = prayer().copy(isDefault = true)
        val sibling = prayer("second")
        val store = MockPresetStore(listOf(selected, sibling))
        val f = Fixture(store)
        assertFalse(f.service.plan(selected).removesDownload)
        f.service.deleteSaved(selected)
        assertEquals(listOf(selected), f.cancelled)
        assertEquals(sibling.reminders, store.get(sibling.id)?.reminders)
        assertTrue(store.get(sibling.id)!!.isDefault)
        assertTrue(f.removed.isEmpty())
    }

    @Test
    fun builtInPackSurvivesEvenIfReportedAsInstalled() = runBlocking {
        val selected = prayer(bundle = "angelus")
        val f = Fixture(MockPresetStore(listOf(selected)), setOf("angelus"))
        f.installed.add("angelus")
        assertFalse(f.service.plan(selected).removesDownload)
        f.service.deleteSaved(selected)
        assertTrue(f.removed.isEmpty())
        assertTrue("angelus" in f.installed)
        assertEquals(listOf(selected), f.cancelled)
    }

    @Test
    fun databaseFailureLeavesDownloadAndRemindersUntouched() = runBlocking {
        val selected = prayer()
        val backing = MockPresetStore(listOf(selected))
        val store = object : PresetStore by backing {
            override suspend fun delete(prayer: Prayer) { throw IOException("Database write failed") }
        }
        val f = Fixture(store)
        val failure = runCatching { f.service.deleteSaved(selected) }.exceptionOrNull() as PrayerRemovalService.Failure
        assertFalse(failure.savedPrayerDeleted)
        assertNotNull(backing.get(selected.id))
        assertTrue(f.removed.isEmpty())
        assertTrue(f.cancelled.isEmpty())
    }

    @Test
    fun failedPostDeleteQueryNeverGuessesThereAreNoSiblings() = runBlocking {
        val selected = prayer()
        val backing = MockPresetStore(listOf(selected, prayer("second")))
        val store = object : PresetStore by backing {
            override suspend fun all(): List<Prayer> { throw IOException("Database read failed") }
        }
        val f = Fixture(store)
        val failure = runCatching { f.service.deleteSaved(selected) }.exceptionOrNull() as PrayerRemovalService.Failure
        assertTrue(failure.savedPrayerDeleted)
        assertFalse(failure.downloadRemoved)
        assertTrue(f.removed.isEmpty())
        assertNotNull(backing.get("second"))
    }

    @Test
    fun siblingAddedAfterConfirmationProtectsDownload() = runBlocking {
        val selected = prayer()
        val store = MockPresetStore(listOf(selected))
        val f = Fixture(store)
        assertTrue(f.service.plan(selected).removesDownload)
        store.save(prayer("addedAfterConfirmation"))
        f.service.deleteSaved(selected)
        assertTrue(f.removed.isEmpty())
        assertNotNull(store.get("addedAfterConfirmation"))
    }

    @Test
    fun freshSiblingQueryAlsoSeesCopyAddedDuringDeletion() = runBlocking {
        val selected = prayer()
        val backing = MockPresetStore(listOf(selected))
        val store = object : PresetStore by backing {
            override suspend fun delete(prayer: Prayer) {
                backing.delete(prayer)
                backing.save(prayer("addedDuringDeletion"))
            }
        }
        val f = Fixture(store)
        f.service.deleteSaved(selected)
        assertTrue(f.removed.isEmpty())
        assertNotNull(backing.get("addedDuringDeletion"))
    }

    @Test
    fun packFileFailureReportsPartialDeletionAndKeepsCleanupPending() = runBlocking {
        val selected = prayer()
        val f = Fixture(MockPresetStore(listOf(selected)))
        f.failRemoval = true
        val failure = runCatching { f.service.deleteSaved(selected) }.exceptionOrNull() as PrayerRemovalService.Failure
        assertTrue(failure.savedPrayerDeleted)
        assertFalse(failure.downloadRemoved)
        assertTrue("repo.test.prayer" in f.installed)
        assertTrue(f.cleaned.isEmpty())
        assertEquals(listOf(selected), f.cancelled)
    }

    @Test
    fun audioFailureReportsThatDownloadWasAlreadyRemoved() = runBlocking {
        val f = Fixture(MockPresetStore(emptyList()))
        f.failCleanup = true
        val failure = runCatching { f.service.removeDownload("repo.test.prayer") }.exceptionOrNull() as PrayerRemovalService.Failure
        assertFalse(failure.savedPrayerDeleted)
        assertTrue(failure.downloadRemoved)
        assertFalse("repo.test.prayer" in f.installed)
        assertTrue("repo.test.other" in f.installed)
    }

    @Test
    fun removingDownloadRefusesAnySavedCopyAndNeverDeletesPresets() = runBlocking {
        val selected = prayer()
        val store = MockPresetStore(listOf(selected))
        val f = Fixture(store)
        val failure = runCatching { f.service.removeDownload("repo.test.prayer") }.exceptionOrNull() as PrayerRemovalService.Failure
        assertTrue(failure.downloadInUse)
        assertEquals(listOf(selected), store.all())
        assertTrue(f.removed.isEmpty())
        assertTrue(f.cancelled.isEmpty())
    }

    @Test
    fun unusedDownloadCanBeRemovedWithoutCreatingASavedPrayer() = runBlocking {
        val store = MockPresetStore(emptyList())
        val f = Fixture(store)
        f.service.removeDownload("repo.test.prayer")
        assertTrue(store.all().isEmpty())
        assertEquals(listOf("repo.test.prayer"), f.removed)
        assertTrue(f.cancelled.isEmpty())
    }

    @Test
    fun stalePrayerFlowAutosaveCannotResurrectDeletedCopy() = runBlocking {
        val selected = prayer()
        val store = MockPresetStore(listOf(selected))
        val stale = store.get(selected.id)!!
        Fixture(store).service.deleteSaved(selected)
        assertFalse(store.updateIfPresent(stale.copy(languageCode = "he", dayIndex = 3)))
        assertTrue(store.all().isEmpty())
    }
}
