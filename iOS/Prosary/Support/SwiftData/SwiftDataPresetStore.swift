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

  func defaultPreset(kind: PrayerKind) async throws -> Prayer? {
    let all = try context.fetch(FetchDescriptor<PresetEntry>())
    let matching = all.filter { $0.resolvedKind.kind == kind }
    guard let entry = matching.first(where: { $0.isDefault }) ?? matching.first else { return nil }
    return entry.toPrayer()
  }

  func get(id: Prayer.ID) async throws -> Prayer? {
    let all = try context.fetch(FetchDescriptor<PresetEntry>())
    return all.first { $0.id == id }?.toPrayer()
  }

  func save(_ prayer: Prayer) async throws {
    if prayer.isDefault {
      // "One default per kind" is scoped per devotion: (kind, customDevotionId), compared via
      // the resolved identity so legacy-kind rows ("angelus") and their migrated .custom
      // equivalents share one default slot.
      let all = try context.fetch(FetchDescriptor<PresetEntry>())
      for entry in all {
        let resolved = entry.resolvedKind
        if resolved.kind == prayer.kind && resolved.customDevotionId == prayer.customDevotionId {
          entry.isDefault = false
        }
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
    let identity = entry.resolvedKind
    context.delete(entry)
    if wasDefault {
      all.first {
        $0.id != prayer.id && $0.resolvedKind == identity
      }?.isDefault = true
    }
    try context.save()
  }
}
