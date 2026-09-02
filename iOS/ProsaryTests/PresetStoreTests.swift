
//
//  PresetStoreTests.swift
//  ProsaryTests
//
//  Tests for MockPresetStore CRUD and per-kind default-promotion logic.
//

import XCTest
@testable import Prosary

final class PresetStoreTests: XCTestCase {

  // MARK: - Helpers

  private func makeStore(_ prayers: [Prayer] = []) -> MockPresetStore {
    MockPresetStore(configs: prayers)
  }

  // MARK: - PresetEntry column mapping

  /// The SwiftData row is the real persistence seam (MockPresetStore stores Prayer structs
  /// as-is) — the generic-devotion fields must survive the entry's encode/decode.
  func testPresetEntryRoundTripsGenericDevotionFields() {
    let prayer = Prayer(
      name: "Scriptural Stations", kind: .custom, customDevotionId: "stationsOfTheCross",
      variantId: "scriptural", customOptions: ["seventyTwoHailMarys": "false"])
    let restored = PresetEntry(prayer: prayer).toPrayer()
    XCTAssertEqual(restored.customDevotionId, "stationsOfTheCross")
    XCTAssertEqual(restored.variantId, "scriptural")
    XCTAssertEqual(restored.customOptions, ["seventyTwoHailMarys": "false"])
  }

  func testPresetEntryRoundTripsThePerRosaryAramaicCrossForm() {
    let prayer = Prayer(rosary: RosaryOptions(aramaicSignOfCrossForm: AramaicSignOfCrossForm.formB))
    XCTAssertEqual(PresetEntry(prayer: prayer).toPrayer().rosary.aramaicSignOfCrossForm,
                   AramaicSignOfCrossForm.formB)
  }

  // MARK: - all()

  func testAllReturnsSortedByName() async throws {
    let store = makeStore([
      Prayer(name: "Zebra", kind: .rosary),
      Prayer(name: "Apple", kind: .rosary),
      Prayer(name: "Mango", kind: .rosary),
    ])
    let prayers = try await store.all()
    XCTAssertEqual(prayers.map(\.name), ["Apple", "Mango", "Zebra"])
  }

  func testAllIncludesAllKinds() async throws {
    let store = makeStore([
      Prayer(name: "R", kind: .rosary),
      Prayer(name: "A", kind: .custom, customDevotionId: "angelus"),
      Prayer(name: "J", kind: .jesusPrayer),
    ])
    let prayers = try await store.all()
    XCTAssertEqual(prayers.count, 3)
    XCTAssertTrue(prayers.contains { $0.kind == .rosary })
    XCTAssertTrue(prayers.contains { $0.kind == .custom })
    XCTAssertTrue(prayers.contains { $0.kind == .jesusPrayer })
  }

  // MARK: - get(id:)

  func testGetReturnsMatchingPrayer() async throws {
    let prayer = Prayer(name: "Test", kind: .rosary)
    let store = makeStore([prayer])
    let found = try await store.get(id: prayer.id)
    XCTAssertEqual(found?.id, prayer.id)
  }

  func testGetReturnsNilForUnknownId() async throws {
    let store = makeStore([Prayer(name: "Test", kind: .rosary)])
    let found = try await store.get(id: UUID())
    XCTAssertNil(found)
  }

  // MARK: - save() — new prayer

  func testSaveAddsNewPrayer() async throws {
    let store = makeStore()
    let prayer = Prayer(name: "New", kind: .rosary)
    try await store.save(prayer)
    let all = try await store.all()
    XCTAssertTrue(all.contains { $0.id == prayer.id })
  }

  func testSaveUpdatesExistingPrayer() async throws {
    var prayer = Prayer(name: "Original", kind: .rosary)
    let store = makeStore([prayer])
    prayer.name = "Updated"
    try await store.save(prayer)
    let found = try await store.get(id: prayer.id)
    XCTAssertEqual(found?.name, "Updated")
  }

  // MARK: - save() — default promotion (per-kind)

  func testSavingDefaultClearsOtherDefaultsInSameKind() async throws {
    var first = Prayer(name: "A", kind: .rosary, isDefault: true)
    let second = Prayer(name: "B", kind: .rosary, isDefault: false)
    let store = makeStore([first, second])

    var promoted = second
    promoted.isDefault = true
    try await store.save(promoted)

    first = (try await store.get(id: first.id))!
    XCTAssertFalse(first.isDefault, "Old default should be cleared")
    let found = try await store.get(id: promoted.id)
    XCTAssertTrue(found?.isDefault == true)
  }

  func testSavingDefaultInOneKindDoesNotAffectOtherKinds() async throws {
    let rosary = Prayer(name: "R", kind: .rosary, isDefault: true)
    var angelus = Prayer(name: "A", kind: .custom, isDefault: false, customDevotionId: "angelus")
    let store = makeStore([rosary, angelus])

    angelus.isDefault = true
    try await store.save(angelus)

    let r = try await store.get(id: rosary.id)
    XCTAssertTrue(r?.isDefault == true, "Rosary default must not be affected by angelus default change")
  }

  // MARK: - delete()

  func testDeleteRemovesPrayer() async throws {
    let prayer = Prayer(name: "Delete me", kind: .rosary)
    let store = makeStore([prayer])
    try await store.delete(prayer)
    let all = try await store.all()
    XCTAssertFalse(all.contains { $0.id == prayer.id })
  }

  func testDeletePromotesNextPrayerToDefaultWhenDefaultIsDeleted() async throws {
    let defaultPrayer = Prayer(name: "Default", kind: .rosary, isDefault: true)
    let other = Prayer(name: "Other", kind: .rosary, isDefault: false)
    let store = makeStore([defaultPrayer, other])

    try await store.delete(defaultPrayer)
    let all = try await store.all()
    XCTAssertTrue(all.first?.isDefault == true, "Remaining prayer should become the default")
  }

  func testDeleteNonDefaultLeavesDefaultIntact() async throws {
    let defaultPrayer = Prayer(name: "Default", kind: .rosary, isDefault: true)
    let other = Prayer(name: "Other", kind: .rosary, isDefault: false)
    let store = makeStore([defaultPrayer, other])

    try await store.delete(other)
    let remaining = try await store.get(id: defaultPrayer.id)
    XCTAssertTrue(remaining?.isDefault == true)
  }

  func testDeleteAllowsDeletingLastPrayer() async throws {
    let prayer = Prayer(name: "Only", kind: .rosary, isDefault: true)
    let store = makeStore([prayer])
    try await store.delete(prayer)
    let all = try await store.all()
    XCTAssertTrue(all.isEmpty)
  }

  // MARK: - Reminders stored with Prayer

  func testSavePrayerWithReminders() async throws {
    var prayer = Prayer(name: "Angelus", kind: .custom, customDevotionId: "angelus")
    prayer.reminders = [PrayerReminder(hour: 6), PrayerReminder(hour: 12)]
    let store = makeStore()
    try await store.save(prayer)
    let loaded = try await store.get(id: prayer.id)
    XCTAssertEqual(loaded?.reminders.map(\.hour), [6, 12])
  }
}
