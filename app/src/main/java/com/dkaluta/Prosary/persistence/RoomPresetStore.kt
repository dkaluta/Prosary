package com.dkaluta.Prosary.persistence

import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.RosaryOptions
import com.dkaluta.Prosary.presets.PresetStore

/** A [PresetStore] backed by Room — the production implementation, replacing the in-memory-only
 * [com.dkaluta.Prosary.presets.MockPresetStore]. Mirrors iOS's `SwiftDataPresetStore`: seeds
 * exactly one favorite (Classic Rosary) the first time the table is empty; `save`/`delete` only
 * ever touch the default flag of favorites of the **same kind**. */
class RoomPresetStore(private val dao: PresetDao) : PresetStore {

    suspend fun seedIfEmpty() {
        if (dao.count() == 0) {
            dao.upsert(PresetEntity.from(seedPrayer))
        }
    }

    override suspend fun all(): List<Prayer> = dao.getAll().map { it.toPrayer() }

    override suspend fun defaultPreset(): Prayer? {
        val rosaryEntries = dao.getAll().filter { it.kind == PrayerKind.Rosary.name }
        val entry = rosaryEntries.firstOrNull { it.isDefault } ?: rosaryEntries.firstOrNull()
        return entry?.toPrayer()
    }

    override suspend fun get(id: String): Prayer? = dao.getById(id)?.toPrayer()

    override suspend fun save(prayer: Prayer) {
        if (prayer.isDefault) {
            val sameKindDefaults = dao.getAll().filter { it.kind == prayer.kind.name && it.id != prayer.id && it.isDefault }
            for (entry in sameKindDefaults) {
                dao.upsert(entry.copy(isDefault = false))
            }
        }
        dao.upsert(PresetEntity.from(prayer))
    }

    override suspend fun delete(prayer: Prayer) {
        val entity = dao.getById(prayer.id) ?: return
        val wasDefault = entity.isDefault
        val kind = entity.kind
        dao.delete(entity)
        if (wasDefault) {
            val next = dao.getAll().firstOrNull { it.kind == kind }
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
