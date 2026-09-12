#if os(macOS)
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerRemovalTests: XCTestCase {
  func testRemovingUnopenedBuiltinClearsMembershipButKeepsGallery() async throws {
    let fixture = Fixture()
    defer { fixture.cleanUp() }
    await fixture.model.reload()
    let item = try XCTUnwrap(fixture.model.galleryItems.first { $0.devotionID == "angelus" })
    fixture.model.addToLibrary(item)
    fixture.model.setTag(try XCTUnwrap(fixture.model.tags.first), on: item, enabled: true)
    let request = try await fixture.model.removalRequest(for: item)
    XCTAssertFalse(request.removesDownload)
    try await fixture.model.remove(request)
    XCTAssertTrue(fixture.model.items.isEmpty)
    XCTAssertTrue(fixture.model.galleryItems.contains { $0.devotionID == "angelus" })
    XCTAssertTrue(MacLibraryMembershipStore(defaults: fixture.defaults).devotionIDs.isEmpty)
    XCTAssertTrue(MacLibraryTagStore(defaults: fixture.defaults).tagIDs(for: item.id).isEmpty)
    let saved = try await fixture.store.all()
    XCTAssertTrue(saved.isEmpty)
  }

  func testDeletingLastBuiltinCopyDoesNotRevealItsOldTemplate() async throws {
    let prayer = Prayer(name: "My Angelus", kind: .custom, customDevotionId: "angelus")
    let fixture = Fixture(prayers: [prayer])
    defer { fixture.cleanUp() }
    MacLibraryMembershipStore(defaults: fixture.defaults).add("angelus")
    await fixture.model.reload()
    let item = try XCTUnwrap(fixture.model.items.first)
    try await fixture.model.remove(try await fixture.model.removalRequest(for: item))
    await fixture.model.reload()
    XCTAssertTrue(fixture.model.items.isEmpty)
    XCTAssertTrue(fixture.model.galleryItems.contains { $0.devotionID == "angelus" })
    XCTAssertTrue(fixture.packs.removed.isEmpty)
  }

  func testDeletingOneDownloadedCopyKeepsSiblingAndOnlyLastDeletionRemovesPack() async throws {
    let first = Prayer(name: "First Angelus", kind: .custom, customDevotionId: "angelus")
    let second = Prayer(name: "Second Angelus", kind: .custom, customDevotionId: "angelus")
    let fixture = Fixture(prayers: [first, second], downloaded: true)
    defer { fixture.cleanUp() }
    MacLibraryMembershipStore(defaults: fixture.defaults).add("angelus")
    await fixture.model.reload()
    let firstItem = try XCTUnwrap(fixture.model.items.first { $0.prayer?.id == first.id })
    let secondItem = try XCTUnwrap(fixture.model.items.first { $0.prayer?.id == second.id })
    fixture.model.setTag(try XCTUnwrap(fixture.model.tags.first), on: secondItem, enabled: true)
    let firstRequest = try await fixture.model.removalRequest(for: firstItem)
    XCTAssertFalse(firstRequest.removesDownload)
    try await fixture.model.remove(firstRequest)
    XCTAssertEqual(fixture.model.items.map(\.id), [second.id.uuidString])
    XCTAssertFalse(fixture.model.items[0].tagIDs.isEmpty)
    XCTAssertTrue(fixture.packs.removed.isEmpty)
    let lastRequest = try await fixture.model.removalRequest(for: secondItem)
    XCTAssertTrue(lastRequest.removesDownload)
    try await fixture.model.remove(lastRequest)
    XCTAssertEqual(fixture.packs.removed, ["angelus"])
    XCTAssertTrue(fixture.model.items.isEmpty)
    XCTAssertTrue(MacLibraryMembershipStore(defaults: fixture.defaults).devotionIDs.isEmpty)
  }

  func testUnusedDownloadCanBeRemovedDirectlyFromGallery() async throws {
    let fixture = Fixture(downloaded: true)
    defer { fixture.cleanUp() }
    await fixture.model.reload()
    let item = try XCTUnwrap(fixture.model.galleryItems.first { $0.devotionID == "angelus" })
    XCTAssertTrue(fixture.model.canRemoveDownload(item))
    let request = try await fixture.model.removalRequest(for: item, downloadOnly: true)
    try await fixture.model.remove(request)
    XCTAssertEqual(fixture.packs.removed, ["angelus"])
    XCTAssertFalse(fixture.model.downloadedDevotionIDs.contains("angelus"))
    XCTAssertTrue(fixture.model.items.isEmpty)
  }

  func testRemovingInUseDownloadPreservesItsCopiesAndMembership() async throws {
    let prayer = Prayer(name: "My Angelus", kind: .custom, customDevotionId: "angelus")
    let fixture = Fixture(prayers: [prayer], downloaded: true)
    defer { fixture.cleanUp() }
    MacLibraryMembershipStore(defaults: fixture.defaults).add("angelus")
    await fixture.model.reload()
    let item = try XCTUnwrap(fixture.model.galleryItems.first { $0.devotionID == "angelus" })
    XCTAssertFalse(fixture.model.canRemoveDownload(item))
    do {
      try await fixture.model.remove(try await fixture.model.removalRequest(for: item, downloadOnly: true))
      XCTFail("A stale gallery action must not remove an in-use download")
    } catch PrayerRemovalService.RemovalError.downloadInUse { }
    XCTAssertEqual(fixture.model.items.map(\.id), [prayer.id.uuidString])
    XCTAssertEqual(MacLibraryMembershipStore(defaults: fixture.defaults).devotionIDs, ["angelus"])
    XCTAssertTrue(fixture.packs.removed.isEmpty)
  }

  func testDownloadCleanupFailureCannotRestoreDeletedCopyAsTemplate() async throws {
    let prayer = Prayer(name: "My Angelus", kind: .custom, customDevotionId: "angelus")
    let fixture = Fixture(prayers: [prayer], downloaded: true)
    defer { fixture.cleanUp() }
    fixture.packs.failRemoval = true
    MacLibraryMembershipStore(defaults: fixture.defaults).add("angelus")
    await fixture.model.reload()
    let item = try XCTUnwrap(fixture.model.items.first)
    fixture.model.setTag(try XCTUnwrap(fixture.model.tags.first), on: item, enabled: true)
    do {
      try await fixture.model.remove(try await fixture.model.removalRequest(for: item))
      XCTFail("A failed file removal must be reported")
    } catch PrayerRemovalService.RemovalError.cleanupFailed { }
    let saved = try await fixture.store.get(id: prayer.id)
    XCTAssertNil(saved)
    XCTAssertTrue(fixture.model.items.isEmpty)
    XCTAssertTrue(fixture.model.downloadedDevotionIDs.contains("angelus"), "The remaining download can be retried")
    XCTAssertTrue(MacLibraryMembershipStore(defaults: fixture.defaults).devotionIDs.isEmpty)
    XCTAssertTrue(MacLibraryTagStore(defaults: fixture.defaults).tagIDs(for: prayer.id.uuidString).isEmpty)
  }

  @MainActor private final class PackState {
    var installed: [String]
    var removed: [String] = []
    var failRemoval = false
    init(downloaded: Bool) { installed = downloaded ? ["angelus"] : [] }
  }

  @MainActor private final class Fixture {
    let suite = "MacPrayerRemovalTests.\(UUID())"
    let defaults: UserDefaults
    let store: MockPresetStore
    let packs: PackState
    let model: MacPrayerLibraryModel

    init(prayers: [Prayer] = [], downloaded: Bool = false) {
      defaults = UserDefaults(suiteName: suite)!
      MacLibraryTagStore(defaults: defaults).create(named: "For Testing", colorID: "red")
      let store = MockPresetStore(configs: prayers)
      let packs = PackState(downloaded: downloaded)
      self.store = store
      self.packs = packs
      let removal = PrayerRemovalService(store: store, installedDevotionIDs: { packs.installed },
        removeInstalledPack: { id in
          if packs.failRemoval { throw CocoaError(.fileWriteNoPermission) }
          packs.removed.append(id)
          packs.installed.removeAll { $0 == id }
        }, cancelReminders: { _ in })
      model = MacPrayerLibraryModel(store: store, defaults: defaults,
        installedDevotionIDs: { packs.installed }, removalService: removal)
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }
  }
}
#endif
