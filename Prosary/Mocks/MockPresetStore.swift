//
//  MockPresetStore.swift
//  Prosary
//
//  A fully-working, in-memory PresetStore used to drive Previews and interactive testing today.
//  Not the production implementation — see Support/Stubs/StubPresetStore.swift for the skeleton
//  to replace this with your own persistence (nothing here survives an app relaunch).
//

import Foundation

final class MockPresetStore: PresetStore {
    private var configs: [RosaryConfig]

    init(configs: [RosaryConfig]? = nil) {
        self.configs = configs ?? Self.sampleConfigs
    }

    func all() async throws -> [RosaryConfig] {
        configs.sorted { $0.name < $1.name }
    }

    func defaultPreset() async throws -> RosaryConfig {
        configs.first { $0.isDefault } ?? configs[0]
    }

    func get(id: RosaryConfig.ID) async throws -> RosaryConfig? {
        configs.first { $0.id == id }
    }

    func save(_ config: RosaryConfig) async throws {
        if config.isDefault {
            for index in configs.indices {
                configs[index].isDefault = false
            }
        }

        if let index = configs.firstIndex(where: { $0.id == config.id }) {
            configs[index] = config
        } else {
            configs.append(config)
        }
    }

    func delete(_ config: RosaryConfig) async throws {
        configs.removeAll { $0.id == config.id }

        if !configs.isEmpty && !configs.contains(where: { $0.isDefault }) {
            configs[0].isDefault = true
        }
    }

    private static let sampleConfigs: [RosaryConfig] = [
        RosaryConfig(
            name: "Classic Rosary",
            isDefault: true,
            mysterySelectionMode: .todaysMysteries,
            includeApostlesCreed: true,
            includeOpeningPrayers: true,
            includeFatimaPrayer: true,
            eternalRestForDeceased: .none,
            marianAntiphon: .seasonal,
            includeStMichaelPrayer: false,
            includeFinalSignOfCross: true,
            languageCode: "la"),
        RosaryConfig(
            name: "Evening Rosary for the Departed",
            isDefault: false,
            mysterySelectionMode: .specific,
            specificMysteryGroup: .sorrowful,
            includeApostlesCreed: true,
            includeOpeningPrayers: false,
            includeFatimaPrayer: true,
            eternalRestForDeceased: .afterEachDecade,
            marianAntiphon: .salveRegina,
            includeStMichaelPrayer: true,
            includeFinalSignOfCross: true,
            languageCode: "en"),
    ]
}
