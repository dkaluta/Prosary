package com.dkaluta.prosary.persistence

import com.dkaluta.prosary.models.PrayerKind
import org.junit.Assert.assertEquals
import org.junit.Test

/** Rows written before the generic-devotion migration store deleted per-devotion enum names
 * ("Angelus", "StationsOfTheCross", ...). [PresetEntity.resolvedKind] must map them to
 * Custom + the matching bundle id (the camelCased enum name) — permanently at read time (not
 * one-shot), because a cloud backup restore can bring rows from old app versions in at any time.
 * Mirrors iOS's LegacyKindMigrationTests.swift. */
class LegacyKindMigrationTest {
    // Constructed directly, not via PresetEntity.from(): `from` serializes reminders through
    // org.json, whose android.jar stubs throw in plain JVM unit tests.
    private fun legacyEntity(kind: String, customDevotionId: String? = null): PresetEntity =
        PresetEntity(
            id = "legacy", name = "Legacy", isDefault = false, languageCode = "",
            kind = kind, customDevotionId = customDevotionId,
        )

    @Test
    fun everyLegacyKindMapsToItsBundleId() {
        val legacyKinds = mapOf(
            "Angelus" to "angelus",
            "StationsOfTheCross" to "stationsOfTheCross",
            "FranciscanCrown" to "franciscanCrown",
            "SevenSorrows" to "sevenSorrows",
            "DivineMercyChaplet" to "divineMercyChaplet",
        )
        for ((legacy, bundleId) in legacyKinds) {
            val prayer = legacyEntity(legacy).toPrayer()
            assertEquals("$legacy should migrate to Custom", PrayerKind.Custom, prayer.kind)
            assertEquals("$legacy's camelCased name doubles as its bundle id", bundleId, prayer.customDevotionId)
        }
    }

    @Test
    fun currentKindsPassThroughUnchanged() {
        for (kind in PrayerKind.entries) {
            val entity = legacyEntity(kind.name)
            assertEquals(kind, entity.toPrayer().kind)
        }
    }

    @Test
    fun existingCustomDevotionIdWinsOverTheLegacyRawValue() {
        val entity = legacyEntity("Custom", customDevotionId = "trisagion")
        val prayer = entity.toPrayer()
        assertEquals(PrayerKind.Custom, prayer.kind)
        assertEquals("trisagion", prayer.customDevotionId)
    }

    /** A migrated legacy row and a freshly created Custom favorite must share one default slot. */
    @Test
    fun defaultScopingTreatsLegacyAndMigratedRowsAsTheSameDevotion() {
        val legacy = legacyEntity("Angelus")
        assertEquals(PrayerKind.Custom to "angelus", legacy.resolvedKind)

        val fresh = legacyEntity(PrayerKind.Custom.name, customDevotionId = "angelus")
        assertEquals(
            "legacy and migrated rows must resolve to the same (kind, devotionId) identity",
            fresh.resolvedKind, legacy.resolvedKind,
        )
    }
}
