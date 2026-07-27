package com.dkaluta.prosary.persistence

import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.presets.PresetStore

/** A [PresetStore] backed by Room — the production implementation, replacing the in-memory-only
 * [com.dkaluta.prosary.presets.MockPresetStore]. Mirrors iOS's `SwiftDataPresetStore`: seeds
 * exactly one favorite (Classic Rosary) the first time the table is empty; `save`/`delete` only
 * ever touch the default flag of favorites of the **same kind**. */
class RoomPresetStore(private val dao: PresetDao) : PresetStore {

    suspend fun seedIfEmpty() {
        if (dao.count() == 0) {
            dao.upsert(PresetEntity.from(seedPrayer))
        }
    }

    override suspend fun all(): List<Prayer> = dao.getAll().map { it.toPrayer() }

    override suspend fun defaultPreset(kind: PrayerKind): Prayer? {
        val matchingEntries = dao.getAll().filter { it.resolvedKind.first == kind }
        val entry = matchingEntries.firstOrNull { it.isDefault } ?: matchingEntries.firstOrNull()
        return entry?.toPrayer()
    }

    override suspend fun get(id: String): Prayer? = dao.getById(id)?.toPrayer()

    override suspend fun save(prayer: Prayer) {
        if (prayer.isDefault) {
            // "One default per kind" is scoped per devotion: (kind, customDevotionId), compared
            // via the resolved identity so legacy-kind rows ("Angelus") and their migrated
            // Custom equivalents share one default slot.
            val identity = prayer.kind to prayer.customDevotionId
            val sameKindDefaults = dao.getAll().filter { it.resolvedKind == identity && it.id != prayer.id && it.isDefault }
            for (entry in sameKindDefaults) {
                dao.upsert(entry.copy(isDefault = false))
            }
        }
        dao.upsert(PresetEntity.from(prayer))
    }

    override suspend fun delete(prayer: Prayer) {
        val entity = dao.getById(prayer.id) ?: return
        val wasDefault = entity.isDefault
        val identity = entity.resolvedKind
        dao.delete(entity)
        if (wasDefault) {
            val next = dao.getAll().firstOrNull { it.resolvedKind == identity }
            if (next != null) dao.upsert(next.copy(isDefault = true))
        }
    }

    companion object {
        private val seedPrayer = Prayer(
            name = "Classic Rosary",
            kind = PrayerKind.Rosary,
            isDefault = true,
            languageCode = LanguageCatalog.defaultSentinel,
            rosary = RosaryOptions(mysterySelectionMode = MysterySelectionMode.TodaysMysteries),
        )
    }
}
