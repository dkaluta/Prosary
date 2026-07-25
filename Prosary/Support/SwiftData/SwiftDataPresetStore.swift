//
//  SwiftDataPresetStore.swift
//  Prosary
//

import SwiftData
import Foundation

struct SwiftDataPresetStore: PresetStore {
  private let context: ModelContext

  init(context: ModelContext) {
    self.context = context
    seedIfEmpty()
  }

  private func seedIfEmpty() {
    guard let count = try? context.fetchCount(FetchDescriptor<PresetEntry>()),
          count == 0 else { return }
    context.insert(PresetEntry(prayer: Self.seedPrayer))
    try? context.save()
  }

  private static var seedPrayer: Prayer {
    Prayer(
      name: "Classic Rosary",
      kind: .rosary,
      isDefault: true,
      languageCode: LanguageCatalog.defaultSentinel,
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
    )
  }

  func all() async throws -> [Prayer] {
    let entries = try context.fetch(FetchDescriptor<PresetEntry>(
      sortBy: [SortDescriptor(\.name)]
    ))
    return entries.map { $0.toPrayer() }
  }

  func defaultPreset() async throws -> Prayer? {
    let all = try context.fetch(FetchDescriptor<PresetEntry>())
    let rosary = all.filter { $0.kind == PrayerKind.rosary.rawValue }
    guard let entry = rosary.first(where: { $0.isDefault }) ?? rosary.first else { return nil }
    return entry.toPrayer()
  }

  func get(id: Prayer.ID) async throws -> Prayer? {
    let all = try context.fetch(FetchDescriptor<PresetEntry>())
    return all.first { $0.id == id }?.toPrayer()
  }

  func save(_ prayer: Prayer) async throws {
    if prayer.isDefault {
      let all = try context.fetch(FetchDescriptor<PresetEntry>())
      for entry in all where entry.kind == prayer.kind.rawValue {
        entry.isDefault = false
      }
    }
    let existing = try context.fetch(FetchDescriptor<PresetEntry>()).first { $0.id == prayer.id }
    if let existing {
      existing.update(from: prayer)
    } else {
      context.insert(PresetEntry(prayer: prayer))
    }
    try context.save()
  }

  func delete(_ prayer: Prayer) async throws {
    let all = try context.fetch(FetchDescriptor<PresetEntry>())
    guard let entry = all.first(where: { $0.id == prayer.id }) else { return }
    let wasDefault = entry.isDefault
    let kindRaw = entry.kind
    context.delete(entry)
    if wasDefault {
      all.first { $0.id != prayer.id && $0.kind == kindRaw }?.isDefault = true
    }
    try context.save()
  }
}
