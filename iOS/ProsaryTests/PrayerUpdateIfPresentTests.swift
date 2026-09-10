import XCTest
import SwiftData
@testable import Prosary

@MainActor
final class PrayerUpdateIfPresentTests: XCTestCase {
  func testPersistentAutosaveCannotRecreateDeletedRosaryOrCustomPrayer() async throws {
    let container = try ModelContainer(for: PresetEntry.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let suite = "PrayerUpdateIfPresentTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: "hasInitializedPrayerPresets")
    let store = SwiftDataPresetStore(context: ModelContext(container), defaults: defaults)

    for prayer in [Prayer(name: "Rosary", kind: .rosary),
                   Prayer(name: "Custom", kind: .custom, customDevotionId: "angelus")] {
      try await store.save(prayer)
      let snapshot = try await store.get(id: prayer.id)
      var stale = try XCTUnwrap(snapshot)
      try await store.delete(prayer)
      stale.languageCode = "he"
      stale.dayIndex = 2
      stale.variantId = "evening"
      let updated = try await store.updateIfPresent(stale)
      XCTAssertFalse(updated, "An open flow's old value must never become a new saved copy")
      let reopened = SwiftDataPresetStore(context: ModelContext(container), defaults: defaults)
      let resurrected = try await reopened.get(id: prayer.id)
      XCTAssertNil(resurrected)
    }
  }

  func testPersistentUpdateKeepsPerDevotionDefaultRulesAndRejectedUpdateKeepsSurvivor() async throws {
    let container = try ModelContainer(for: PresetEntry.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let store = SwiftDataPresetStore(context: ModelContext(container))
    let first = Prayer(name: "First", kind: .custom, isDefault: true, customDevotionId: "angelus")
    var second = Prayer(name: "Second", kind: .custom, customDevotionId: "angelus")
    let other = Prayer(name: "Other", kind: .custom, isDefault: true, customDevotionId: "trisagion")
    for prayer in [first, second, other] { try await store.save(prayer) }
    second.isDefault = true
    second.languageCode = "uk"
    second.reminders = [PrayerReminder(hour: 18)]
    let changed = try await store.updateIfPresent(second)
    XCTAssertTrue(changed)
    let saved = try await store.get(id: second.id)
    XCTAssertEqual(saved?.languageCode, "uk")
    XCTAssertEqual(saved?.reminders.map(\.hour), [18])
    let oldDefault = try await store.get(id: first.id)
    let unrelated = try await store.get(id: other.id)
    XCTAssertEqual(oldDefault?.isDefault, false)
    XCTAssertEqual(unrelated?.isDefault, true)

    try await store.delete(second)
    let rejected = try await store.updateIfPresent(second)
    XCTAssertFalse(rejected)
    let promoted = try await store.get(id: first.id)
    XCTAssertEqual(promoted?.isDefault, true, "A stale Make Default must not demote a surviving copy")
  }

  func testMockConditionalUpdateAlsoRejectsDeletedCopies() async throws {
    let prayer = Prayer(name: "Saved", kind: .rosary)
    let store = MockPresetStore(configs: [prayer])
    var updated = prayer
    updated.languageCode = "ar"
    let changed = try await store.updateIfPresent(updated)
    XCTAssertTrue(changed)
    let saved = try await store.get(id: prayer.id)
    XCTAssertEqual(saved?.languageCode, "ar")
    try await store.delete(prayer)
    let rejected = try await store.updateIfPresent(updated)
    XCTAssertFalse(rejected)
    let remaining = try await store.all()
    XCTAssertTrue(remaining.isEmpty)
  }

  func testProtocolDefaultNeverFallsBackToAnUpsert() async throws {
    let store = UnsupportedUpdateStore()
    let changed = try await store.updateIfPresent(Prayer(name: "Stale"))
    XCTAssertFalse(changed)
    XCTAssertFalse(store.didSave)
  }

  private final class UnsupportedUpdateStore: PresetStore {
    var didSave = false
    func all() async throws -> [Prayer] { [] }
    func defaultPreset(kind: PrayerKind) async throws -> Prayer? { nil }
    func get(id: Prayer.ID) async throws -> Prayer? { Prayer(id: id) }
    func save(_ prayer: Prayer) async throws { didSave = true }
    func delete(_ prayer: Prayer) async throws {}
  }
}
