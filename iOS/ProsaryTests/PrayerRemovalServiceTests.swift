import XCTest
import SwiftData
@testable import Prosary

@MainActor
final class PrayerRemovalServiceTests: XCTestCase {
  func testDeletingOneOfTwoCopiesKeepsDownloadAndOtherReminders() async throws {
    let first = Prayer(name: "First", kind: .custom, customDevotionId: "download")
    let other = Prayer(name: "Other", kind: .custom, customDevotionId: "download")
    let store = MockPresetStore(configs: [first, other])
    var removed: [String] = []
    var canceled: [UUID] = []
    var canceledSeries: [String] = []
    let service = PrayerRemovalService(store: store, installedDevotionIDs: { ["download"] },
      removeInstalledPack: { removed.append($0) }, cancelReminders: { canceled.append($0.id) },
      cancelDownloadReminders: { canceledSeries.append($0) })
    let willRemove = try await service.willRemoveDownload(afterDeleting: first)
    XCTAssertFalse(willRemove)
    try await service.delete(first)
    XCTAssertTrue(removed.isEmpty)
    XCTAssertTrue(canceledSeries.isEmpty)
    XCTAssertEqual(canceled, [first.id])
    let remaining = try await store.all()
    XCTAssertEqual(remaining.map(\.id), [other.id])
    try await service.delete(other)
    XCTAssertEqual(removed, ["download"])
    XCTAssertEqual(canceledSeries, ["download"])
  }

  func testBuiltInCopyIsDeletedWithoutRemovingShippedPack() async throws {
    let prayer = Prayer(kind: .custom, customDevotionId: "angelus")
    let store = MockPresetStore(configs: [prayer])
    let service = PrayerRemovalService(store: store, installedDevotionIDs: { [] },
      removeInstalledPack: { _ in XCTFail("Built-in pack must stay") }, cancelReminders: { _ in })
    try await service.delete(prayer)
    let remaining = try await store.all()
    XCTAssertTrue(remaining.isEmpty)
  }

  func testDeleteFailureKeepsDownloadAndReminders() async throws {
    let prayer = Prayer(kind: .custom, customDevotionId: "download")
    let store = FailingDeleteStore(prayer: prayer)
    let service = PrayerRemovalService(store: store, installedDevotionIDs: { ["download"] },
      removeInstalledPack: { _ in XCTFail("No cleanup after failed delete") },
      cancelReminders: { _ in XCTFail("No canceled reminders after failed delete") })
    do { try await service.delete(prayer); XCTFail("Expected persistence failure") }
    catch { XCTAssertNotNil(error) }
    let remaining = try await store.all()
    XCTAssertEqual(remaining.count, 1)
  }

  func testCleanupFailureReportsPartialSuccessAndAllowsDownloadRetry() async throws {
    let prayer = Prayer(kind: .custom, customDevotionId: "download")
    let store = MockPresetStore(configs: [prayer])
    var shouldFail = true
    var removed = false
    var canceledSeries: [String] = []
    let service = PrayerRemovalService(store: store, installedDevotionIDs: { ["download"] },
      removeInstalledPack: { _ in
        if shouldFail { throw CocoaError(.fileWriteNoPermission) }
        removed = true
      }, cancelReminders: { _ in }, cancelDownloadReminders: { canceledSeries.append($0) })
    do { try await service.delete(prayer); XCTFail("Expected cleanup failure") }
    catch { XCTAssertEqual(error as? PrayerRemovalService.RemovalError, .cleanupFailed) }
    let remaining = try await store.all()
    XCTAssertTrue(remaining.isEmpty)
    XCTAssertEqual(canceledSeries, ["download"], "Deleted prayers must stop reminding even if file cleanup fails")
    shouldFail = false
    try await service.removeDownload(bundleID: "download")
    XCTAssertTrue(removed)
  }

  func testExplicitRemovalProtectsUsedDownloadsAndBuiltIns() async throws {
    let store = MockPresetStore(configs: [Prayer(kind: .custom, customDevotionId: "used")])
    var removed: [String] = []
    let service = PrayerRemovalService(store: store, installedDevotionIDs: { ["used", "unused"] },
      removeInstalledPack: { removed.append($0) }, cancelReminders: { _ in })
    let unused = try await service.unusedDownloadIDs()
    XCTAssertEqual(unused, ["unused"])
    do { try await service.removeDownload(bundleID: "used"); XCTFail("Expected in-use guard") }
    catch { XCTAssertEqual(error as? PrayerRemovalService.RemovalError, .downloadInUse) }
    try await service.removeDownload(bundleID: "rosary")
    XCTAssertTrue(removed.isEmpty)
    try await service.removeDownload(bundleID: "unused")
    XCTAssertEqual(removed, ["unused"])
  }

  func testPhoneStarterDoesNotReappearAfterDeletingLastSavedPrayer() async throws {
    let suite = "PrayerRemoval.Seed.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let container = try ModelContainer(for: PresetEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
    let store = SwiftDataPresetStore(context: container.mainContext, defaults: defaults)
    store.initializeStarterPrayerIfNeeded(defaults: defaults)
    let seeded = try await store.all()
    XCTAssertEqual(seeded.count, 1)
    try await store.delete(XCTUnwrap(seeded.first))
    let reopened = SwiftDataPresetStore(context: container.mainContext, defaults: defaults)
    reopened.initializeStarterPrayerIfNeeded(defaults: defaults)
    let remaining = try await reopened.all()
    XCTAssertTrue(remaining.isEmpty)
  }

  private final class FailingDeleteStore: PresetStore {
    let prayer: Prayer
    init(prayer: Prayer) { self.prayer = prayer }
    func all() async throws -> [Prayer] { [prayer] }
    func get(id: UUID) async throws -> Prayer? { prayer.id == id ? prayer : nil }
    func defaultPreset(kind: PrayerKind) async throws -> Prayer? { prayer }
    func save(_ prayer: Prayer) async throws {}
    func delete(_ prayer: Prayer) async throws { throw CocoaError(.fileWriteNoPermission) }
  }
}
