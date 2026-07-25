package com.dkaluta.prosary.presets

import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions

/** A fully-working, in-memory [PresetStore] for previews/tests. Nothing here survives a process
 * restart — see [com.dkaluta.prosary.persistence.RoomPresetStore] for persistence. */
class MockPresetStore(initialFavorites: List<Prayer>? = null) : PresetStore {
    private val favorites: MutableList<Prayer> = (initialFavorites ?: sampleFavorites).toMutableList()

    override suspend fun all(): List<Prayer> = favorites.sortedBy { it.name }

    override suspend fun defaultPreset(): Prayer? {
        val rosary = favorites.filter { it.kind == PrayerKind.Rosary }
        return rosary.firstOrNull { it.isDefault } ?: rosary.firstOrNull()
    }

    override suspend fun get(id: String): Prayer? = favorites.firstOrNull { it.id == id }

    override suspend fun save(prayer: Prayer) {
        if (prayer.isDefault) {
            for (i in favorites.indices) {
                if (favorites[i].kind == prayer.kind) {
                    favorites[i] = favorites[i].copy(isDefault = false)
                }
            }
        }

        val index = favorites.indexOfFirst { it.id == prayer.id }
        if (index >= 0) {
            favorites[index] = prayer
        } else {
            favorites.add(prayer)
        }
    }

    override suspend fun delete(prayer: Prayer) {
        val wasDefault = prayer.isDefault
        favorites.removeAll { it.id == prayer.id }

        if (wasDefault) {
            val nextIndex = favorites.indexOfFirst { it.kind == prayer.kind }
            if (nextIndex >= 0) {
                favorites[nextIndex] = favorites[nextIndex].copy(isDefault = true)
            }
        }
    }

    companion object {
        private val sampleFavorites: List<Prayer> = listOf(
            Prayer(
                name = "Classic Rosary",
                kind = PrayerKind.Rosary,
                isDefault = true,
                languageCode = "la",
                rosary = RosaryOptions(
                    mysterySelectionMode = MysterySelectionMode.TodaysMysteries,
                    includeApostlesCreed = true,
                    includeOpeningPrayers = true,
                    includeFatimaPrayer = true,
                    eternalRestForDeceased = EternalRestPlacement.None,
                    marianAntiphon = MarianAntiphonOption.Seasonal,
                    includeStMichaelPrayer = false,
                    includeFinalSignOfCross = true,
                ),
            ),
            Prayer(
                name = "Evening Rosary for the Departed",
                kind = PrayerKind.Rosary,
                isDefault = false,
                languageCode = "en",
                rosary = RosaryOptions(
                    mysterySelectionMode = MysterySelectionMode.Specific,
                    specificMysteryGroup = MysteryGroup.Sorrowful,
                    includeApostlesCreed = true,
                    includeOpeningPrayers = false,
                    includeFatimaPrayer = true,
                    eternalRestForDeceased = EternalRestPlacement.AfterEachDecade,
                    marianAntiphon = MarianAntiphonOption.SalveRegina,
                    includeStMichaelPrayer = true,
                    includeFinalSignOfCross = true,
                ),
            ),
            Prayer(
                name = "Angelus",
                kind = PrayerKind.Angelus,
                isDefault = true,
                languageCode = "la",
            ),
            Prayer(
                name = "Jesus Prayer × 33",
                kind = PrayerKind.JesusPrayer,
                isDefault = true,
                languageCode = "la",
                jesusPrayer = JesusPrayerOptions(target = JesusPrayerTarget.Count(33)),
            ),
        )
    }
}
