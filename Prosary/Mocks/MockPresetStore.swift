//
//  MockPresetStore.swift
//  Prosary
//
//  Fully-working in-memory PresetStore for Previews and interactive testing.
//  Nothing here survives a relaunch — see SwiftDataPresetStore for persistence.
//

import Foundation

final class MockPresetStore: PresetStore {
  private var favorites: [Prayer]

  init(configs: [Prayer]? = nil) {
    self.favorites = configs ?? Self.sampleFavorites
  }

  func all() async throws -> [Prayer] {
    favorites.sorted { $0.name < $1.name }
  }

  func defaultPreset() async throws -> Prayer? {
    let rosary = favorites.filter { $0.kind == .rosary }
    return rosary.first { $0.isDefault } ?? rosary.first
  }

  func get(id: Prayer.ID) async throws -> Prayer? {
    favorites.first { $0.id == id }
  }

  func save(_ prayer: Prayer) async throws {
    if prayer.isDefault {
      for index in favorites.indices where favorites[index].kind == prayer.kind {
        favorites[index].isDefault = false
      }
    }
    if let index = favorites.firstIndex(where: { $0.id == prayer.id }) {
      favorites[index] = prayer
    } else {
      favorites.append(prayer)
    }
  }

  func delete(_ prayer: Prayer) async throws {
    let kindBefore = prayer.kind
    let wasDefault = prayer.isDefault
    favorites.removeAll { $0.id == prayer.id }
    if wasDefault, let first = favorites.first(where: { $0.kind == kindBefore }) {
      let index = favorites.firstIndex(where: { $0.id == first.id })!
      favorites[index].isDefault = true
    }
  }

  private static let sampleFavorites: [Prayer] = [
    Prayer(
      name: "Classic Rosary",
      kind: .rosary,
      isDefault: true,
      languageCode: "la",
      rosary: RosaryOptions(
        mysterySelectionMode: .todaysMysteries,
        includeApostlesCreed: true,
        includeOpeningPrayers: true,
        includeFatimaPrayer: true,
        eternalRestForDeceased: .none,
        marianAntiphon: .seasonal,
        includeStMichaelPrayer: false,
        includeFinalSignOfCross: true
      )
    ),
    Prayer(
      name: "Evening Rosary for the Departed",
      kind: .rosary,
      isDefault: false,
      languageCode: "en",
      rosary: RosaryOptions(
        mysterySelectionMode: .specific,
        specificMysteryGroup: .sorrowful,
        includeApostlesCreed: true,
        includeOpeningPrayers: false,
        includeFatimaPrayer: true,
        eternalRestForDeceased: .afterEachDecade,
        marianAntiphon: .salveRegina,
        includeStMichaelPrayer: true,
        includeFinalSignOfCross: true
      )
    ),
    Prayer(
      name: "Angelus",
      kind: .angelus,
      isDefault: true,
      languageCode: "la"
    ),
    Prayer(
      name: "Jesus Prayer × 33",
      kind: .jesusPrayer,
      isDefault: true,
      languageCode: "la",
      jesusPrayer: JesusPrayerOptions(target: .count(33))
    ),
  ]
}
