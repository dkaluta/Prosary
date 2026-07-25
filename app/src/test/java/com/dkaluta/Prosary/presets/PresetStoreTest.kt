package com.dkaluta.Prosary.presets

import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.PrayerReminder
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Tests for [MockPresetStore] CRUD and per-kind default-promotion logic — mirrors iOS's
 * PresetStoreTests. */
class PresetStoreTest {

    private fun store(prayers: List<Prayer> = emptyList()) = MockPresetStore(prayers)

    // MARK: - all()

    @Test
    fun allReturnsSortedByName() = runBlocking {
        val s = store(
            listOf(
                Prayer(name = "Zebra", kind = PrayerKind.Rosary),
                Prayer(name = "Apple", kind = PrayerKind.Rosary),
                Prayer(name = "Mango", kind = PrayerKind.Rosary),
            ),
        )
        assertEquals(listOf("Apple", "Mango", "Zebra"), s.all().map { it.name })
    }

    @Test
    fun allIncludesAllKinds() = runBlocking {
        val s = store(
            listOf(
                Prayer(name = "R", kind = PrayerKind.Rosary),
                Prayer(name = "A", kind = PrayerKind.Angelus),
                Prayer(name = "J", kind = PrayerKind.JesusPrayer),
            ),
        )
        val prayers = s.all()
        assertEquals(3, prayers.size)
        assertTrue(prayers.any { it.kind == PrayerKind.Rosary })
        assertTrue(prayers.any { it.kind == PrayerKind.Angelus })
        assertTrue(prayers.any { it.kind == PrayerKind.JesusPrayer })
    }

    // MARK: - get(id)

    @Test
    fun getReturnsMatchingPrayer() = runBlocking {
        val prayer = Prayer(name = "Test", kind = PrayerKind.Rosary)
        val s = store(listOf(prayer))
        assertEquals(prayer.id, s.get(prayer.id)?.id)
    }

    @Test
    fun getReturnsNullForUnknownId() = runBlocking {
        val s = store(listOf(Prayer(name = "Test", kind = PrayerKind.Rosary)))
        assertNull(s.get("unknown-id"))
    }

    // MARK: - save() — new prayer

    @Test
    fun saveAddsNewPrayer() = runBlocking {
        val s = store()
        val prayer = Prayer(name = "New", kind = PrayerKind.Rosary)
        s.save(prayer)
        assertTrue(s.all().any { it.id == prayer.id })
    }

    @Test
    fun saveUpdatesExistingPrayer() = runBlocking {
        val prayer = Prayer(name = "Original", kind = PrayerKind.Rosary)
        val s = store(listOf(prayer))
        s.save(prayer.copy(name = "Updated"))
        assertEquals("Updated", s.get(prayer.id)?.name)
    }

    // MARK: - save() — default promotion (per-kind)

    @Test
    fun savingDefaultClearsOtherDefaultsInSameKind() = runBlocking {
        val first = Prayer(name = "A", kind = PrayerKind.Rosary, isDefault = true)
        val second = Prayer(name = "B", kind = PrayerKind.Rosary, isDefault = false)
        val s = store(listOf(first, second))

        s.save(second.copy(isDefault = true))

        assertFalse(s.get(first.id)?.isDefault ?: true)
        assertTrue(s.get(second.id)?.isDefault ?: false)
    }

    @Test
    fun savingDefaultInOneKindDoesNotAffectOtherKinds() = runBlocking {
        val rosary = Prayer(name = "R", kind = PrayerKind.Rosary, isDefault = true)
        val angelus = Prayer(name = "A", kind = PrayerKind.Angelus, isDefault = false)
        val s = store(listOf(rosary, angelus))

        s.save(angelus.copy(isDefault = true))

        assertTrue("Rosary default must not be affected by angelus default change", s.get(rosary.id)?.isDefault ?: false)
    }

    // MARK: - delete()

    @Test
    fun deleteRemovesPrayer() = runBlocking {
        val prayer = Prayer(name = "Delete me", kind = PrayerKind.Rosary)
        val s = store(listOf(prayer))
        s.delete(prayer)
        assertFalse(s.all().any { it.id == prayer.id })
    }

    @Test
    fun deletePromotesNextPrayerToDefaultWhenDefaultIsDeleted() = runBlocking {
        val defaultPrayer = Prayer(name = "Default", kind = PrayerKind.Rosary, isDefault = true)
        val other = Prayer(name = "Other", kind = PrayerKind.Rosary, isDefault = false)
        val s = store(listOf(defaultPrayer, other))

        s.delete(defaultPrayer)
        assertTrue("Remaining prayer should become the default", s.all().first().isDefault)
    }

    @Test
    fun deleteNonDefaultLeavesDefaultIntact() = runBlocking {
        val defaultPrayer = Prayer(name = "Default", kind = PrayerKind.Rosary, isDefault = true)
        val other = Prayer(name = "Other", kind = PrayerKind.Rosary, isDefault = false)
        val s = store(listOf(defaultPrayer, other))

        s.delete(other)
        assertTrue(s.get(defaultPrayer.id)?.isDefault ?: false)
    }

    @Test
    fun deleteAllowsDeletingLastPrayer() = runBlocking {
        val prayer = Prayer(name = "Only", kind = PrayerKind.Rosary, isDefault = true)
        val s = store(listOf(prayer))
        s.delete(prayer)
        assertTrue(s.all().isEmpty())
    }

    // MARK: - Reminders stored with Prayer

    @Test
    fun savePrayerWithReminders() = runBlocking {
        val prayer = Prayer(name = "Angelus", kind = PrayerKind.Angelus).copy(
            reminders = listOf(PrayerReminder(hour = 6), PrayerReminder(hour = 12)),
        )
        val s = store()
        s.save(prayer)
        assertEquals(listOf(6, 12), s.get(prayer.id)?.reminders?.map { it.hour })
    }
}
