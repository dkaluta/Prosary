//
//  SwiftDataPresetStore.swift
//  Prosary
//

import SwiftData
import Foundation

struct SwiftDataPresetStore: PresetStore {
  private let context: ModelContext
  private let defaults: UserDefaults

  init(context: ModelContext, defaults: UserDefaults = .standard) {
    self.context = context
    self.defaults = defaults
    // Mac users choose their starting prayers from the gallery. Existing saved rows
    // remain intact; only a new, empty store skips the phone's starter preset.
    #if !os(macOS)
    initializeStarterPrayerIfNeeded(defaults: defaults)
    #endif
  }

  func initializeStarterPrayerIfNeeded(defaults: UserDefaults) {
    let key = "hasInitializedPrayerPresets"
    guard !defaults.bool(forKey: key),
          let count = try? context.fetchCount(FetchDescriptor<PresetEntry>()) else { return }
    if count == 0 {
      context.insert(PresetEntry(prayer: Self.seedPrayer))
      do { try context.save() }
      catch { context.rollback(); return }
    }
    // An intentionally empty library must stay empty on subsequent launches.
    defaults.set(true, forKey: key)
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
    let entries = try activeEntries(sortedByName: true)
    return entries.map { $0.toPrayer() }
  }

  func defaultPreset(kind: PrayerKind) async throws -> Prayer? {
    let all = try activeEntries()
    let matching = all.filter { $0.resolvedKind.kind == kind }
    guard let entry = matching.first(where: { $0.isDefault }) ?? matching.first else { return nil }
    return entry.toPrayer()
  }

  func get(id: Prayer.ID) async throws -> Prayer? {
    let all = try activeEntries()
    return all.first { $0.id == id }?.toPrayer()
  }

  func save(_ prayer: Prayer) async throws {
    let all = try activeEntries()
    guard prayer.kind != .custom || !RetiredPrayerBundles.contains(prayer.customDevotionId) else {
      throw PrayerPackStore.InstallError.notADevotion
    }
    if prayer.isDefault {
      // "One default per kind" is scoped per devotion: (kind, customDevotionId), compared via
      // the resolved identity so legacy-kind rows ("angelus") and their migrated .custom
      // equivalents share one default slot.
      for entry in all {
        let resolved = entry.resolvedKind
        if resolved.kind == prayer.kind && resolved.customDevotionId == prayer.customDevotionId {
          entry.isDefault = false
        }
      }
    }
    let existing = all.first { $0.id == prayer.id }
    if let existing {
      existing.update(from: prayer)
    } else {
      context.insert(PresetEntry(prayer: prayer))
    }
    do { try context.save() }
    catch { context.rollback(); throw error }
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  @discardableResult
  func updateIfPresent(_ prayer: Prayer) async throws -> Bool {
    // This method never suspends between lookup and save, and has no insert path.
    let all = try activeEntries()
    guard prayer.kind != .custom || !RetiredPrayerBundles.contains(prayer.customDevotionId) else { return false }
    guard let existing = all.first(where: { $0.id == prayer.id }) else { return false }
    if prayer.isDefault {
      for entry in all {
        let resolved = entry.resolvedKind
        if resolved.kind == prayer.kind && resolved.customDevotionId == prayer.customDevotionId {
          entry.isDefault = false
        }
      }
    }
    existing.update(from: prayer)
    do { try context.save() }
    catch { context.rollback(); throw error }
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
    return true
  }

  func delete(_ prayer: Prayer) async throws {
    let all = try activeEntries()
    guard let entry = all.first(where: { $0.id == prayer.id }) else { return }
    let wasDefault = entry.isDefault
    let identity = entry.resolvedKind
    context.delete(entry)
    if wasDefault {
      all.first {
        $0.id != prayer.id && $0.resolvedKind == identity
      }?.isDefault = true
    }
    do { try context.save() }
    catch { context.rollback(); throw error }
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  /// Repeat on every access because CloudKit may deliver an old copy after launch.
  /// Saving the deletion propagates it to the user's other Apple devices.
  private func activeEntries(sortedByName: Bool = false) throws -> [PresetEntry] {
    let entries = try context.fetch(FetchDescriptor<PresetEntry>(
      sortBy: sortedByName ? [SortDescriptor(\.name)] : []))
    let retired = entries.filter {
      $0.resolvedKind.kind == .custom && RetiredPrayerBundles.contains($0.resolvedKind.customDevotionId)
    }
    guard !retired.isEmpty else { return entries }
    let active = entries.filter {
      $0.resolvedKind.kind != .custom || !RetiredPrayerBundles.contains($0.resolvedKind.customDevotionId)
    }
    let prayers = retired.map { $0.toPrayer() }
    for entry in retired { context.delete(entry) }
    do { try context.save() }
    catch { context.rollback(); throw error }
    for prayer in prayers {
      if !ProsaryRuntimeEnvironment.isTesting {
        ReminderScheduler.removeAll(for: prayer)
        ReminderScheduler.removeSeries(devotionId: RetiredPrayerBundles.loretoStandaloneID,
          runID: PrayerCopyProgressIdentity.devotionID(RetiredPrayerBundles.loretoStandaloneID, prayerID: prayer.id))
      }
      RecentPrayerStore(defaults: defaults).remove(prayerID: prayer.id)
      MultiDayRuns.clear(RetiredPrayerBundles.loretoStandaloneID)
      MultiDayRuns.clear(PrayerCopyProgressIdentity.devotionID(RetiredPrayerBundles.loretoStandaloneID, prayerID: prayer.id))
      _ = PrayerRunProgressStore(defaults: defaults).progress(for:
        PrayerRunKey.custom(RetiredPrayerBundles.loretoStandaloneID, variantId: nil, dayIndex: 0))
      #if os(macOS)
      MacPrayerPlaybackSettings(defaults: defaults).remove(for: prayer.id)
      MacLibraryMembershipStore(defaults: defaults).remove(RetiredPrayerBundles.loretoStandaloneID)
      let tags = MacLibraryTagStore(defaults: defaults)
      tags.removeAssignments(for: prayer.id.uuidString)
      tags.removeAssignments(for: "devotion:\(RetiredPrayerBundles.loretoStandaloneID)")
      #endif
    }
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
    return active
  }
}
