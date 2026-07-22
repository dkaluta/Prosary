package com.dkaluta.Prosary.presets

import com.dkaluta.Prosary.models.EternalRestPlacement
import com.dkaluta.Prosary.models.MarianAntiphonOption
import com.dkaluta.Prosary.models.MysteryGroup
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.RosaryConfig

/** A fully-working, in-memory [PresetStore] used to drive the app today. Not the production
 * implementation — nothing here survives a process restart. */
class MockPresetStore(initialConfigs: List<RosaryConfig>? = null) : PresetStore {
    private val configs: MutableList<RosaryConfig> = (initialConfigs ?: sampleConfigs).toMutableList()

    override suspend fun all(): List<RosaryConfig> = configs.sortedBy { it.name }

    override suspend fun defaultPreset(): RosaryConfig = configs.firstOrNull { it.isDefault } ?: configs[0]

    override suspend fun get(id: String): RosaryConfig? = configs.firstOrNull { it.id == id }

    override suspend fun save(config: RosaryConfig) {
        if (config.isDefault) {
            for (i in configs.indices) {
                configs[i] = configs[i].copy(isDefault = false)
            }
        }

        val index = configs.indexOfFirst { it.id == config.id }
        if (index >= 0) {
            configs[index] = config
        } else {
            configs.add(config)
        }
    }

    override suspend fun delete(config: RosaryConfig) {
        configs.removeAll { it.id == config.id }

        if (configs.isNotEmpty() && configs.none { it.isDefault }) {
            configs[0] = configs[0].copy(isDefault = true)
        }
    }

    companion object {
        private val sampleConfigs: List<RosaryConfig> = listOf(
            RosaryConfig(
                name = "Classic Rosary",
                isDefault = true,
                mysterySelectionMode = MysterySelectionMode.TodaysMysteries,
                includeApostlesCreed = true,
                includeOpeningPrayers = true,
                includeFatimaPrayer = true,
                eternalRestForDeceased = EternalRestPlacement.None,
                marianAntiphon = MarianAntiphonOption.Seasonal,
                includeStMichaelPrayer = false,
                includeFinalSignOfCross = true,
                languageCode = "la",
            ),
            RosaryConfig(
                name = "Evening Rosary for the Departed",
                isDefault = false,
                mysterySelectionMode = MysterySelectionMode.Specific,
                specificMysteryGroup = MysteryGroup.Sorrowful,
                includeApostlesCreed = true,
                includeOpeningPrayers = false,
                includeFatimaPrayer = true,
                eternalRestForDeceased = EternalRestPlacement.AfterEachDecade,
                marianAntiphon = MarianAntiphonOption.SalveRegina,
                includeStMichaelPrayer = true,
                includeFinalSignOfCross = true,
                languageCode = "en",
            ),
        )
    }
}
