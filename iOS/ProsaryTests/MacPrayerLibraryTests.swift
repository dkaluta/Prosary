#if os(macOS)
import XCTest
import SwiftUI
@testable import Prosary

@MainActor
final class MacPrayerLibraryTests: XCTestCase {
  func testBrowsingDoesNotCreatePresetsAndOpeningTwiceKeepsOneIdentity() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MockPresetStore(configs: [])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    let empty = try await store.all()
    XCTAssertTrue(empty.isEmpty)
    XCTAssertTrue(model.items.isEmpty)
    let template = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "angelus" })
    model.addToLibrary(template)
    let red = try XCTUnwrap(model.tags.first { $0.id == "red" })
    model.setTag(red, on: template, enabled: true)
    let first = try await model.prayer(for: template)
    let second = try await model.prayer(for: template)
    XCTAssertEqual(first.id, second.id)
    let saved = try await store.all()
    XCTAssertEqual(saved.count, 1)
    XCTAssertEqual(model.items.first { $0.prayer?.id == first.id }?.tagIDs, ["red"])
    XCTAssertTrue(MacLibraryTagStore(defaults: defaults).tagIDs(for: template.id).isEmpty)
  }

  func testDuplicatePreservesSettingsAndTagsWithFreshIdentityAndProgress() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let original = Prayer(name: "Evening", kind: .custom, isDefault: true,
      languageCode: "he", customDevotionId: "angelus", variantId: "alternate",
      dayIndex: 3, customOptions: ["responses": "true"], reminders: [PrayerReminder(hour: 19)])
    let store = MockPresetStore(configs: [original])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    let item = try XCTUnwrap(model.items.first { $0.prayer?.id == original.id })
    model.setTag(try XCTUnwrap(model.tags.first), on: item, enabled: true)
    let named = try XCTUnwrap(model.createTag(named: "Evening prayers", colorID: nil))
    model.setTag(named, on: item, enabled: true)
    let copy = try await model.duplicate(item)
    XCTAssertNotEqual(copy.id, original.id)
    XCTAssertEqual(copy.languageCode, original.languageCode)
    XCTAssertEqual(copy.variantId, original.variantId)
    XCTAssertEqual(copy.customOptions, original.customOptions)
    XCTAssertFalse(copy.isDefault)
    XCTAssertNil(copy.dayIndex)
    XCTAssertEqual(copy.reminders.first?.hour, 19)
    XCTAssertEqual(copy.reminders.first?.isEnabled, false)
    XCTAssertNotEqual(copy.reminders.first?.id, original.reminders.first?.id)
    XCTAssertEqual(model.items.first { $0.prayer?.id == copy.id }?.tagIDs, ["red", named.id])
    XCTAssertNil(model.tags.first { $0.id == named.id }?.colorID)
    let unchanged = try await store.get(id: original.id)
    XCTAssertEqual(unchanged, original)
    let second = try await model.duplicate(item)
    XCTAssertNotEqual(second.name, copy.name)
  }

  func testTagsCanBeRenamedAndPersistAcrossIndependentWindows() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = MacLibraryTagStore(defaults: defaults)
    let second = MacLibraryTagStore(defaults: defaults)
    first.set("red", on: "copy-a", enabled: true)
    second.set("blue", on: "copy-a", enabled: true)
    second.set("purple", on: "copy-b", enabled: true)
    first.rename("red", to: "Morning")
    XCTAssertEqual(second.tags.first { $0.id == "red" }?.title, "Morning")
    XCTAssertEqual(first.tagIDs(for: "copy-a"), ["red", "blue"])
    XCTAssertEqual(first.tagIDs(for: "copy-b"), ["purple"])
    first.set("red", on: "copy-a", enabled: false)
    XCTAssertEqual(second.tagIDs(for: "copy-a"), ["blue"])
    first.set("unknown", on: "copy-a", enabled: true)
    XCTAssertEqual(second.tagIDs(for: "copy-a"), ["blue"])
  }

  func testTemplateTagsMergeWhenASavedCopyArrivesFromAnotherDevice() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MockPresetStore(configs: [])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    let template = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "angelus" })
    model.addToLibrary(template)
    model.setTag(try XCTUnwrap(model.tags.first { $0.id == "red" }), on: template, enabled: true)
    let named = try XCTUnwrap(model.createTag(named: "At home", colorID: "green"))
    model.setTag(named, on: template, enabled: true)
    let synced = Prayer(name: "Morning", kind: .custom, customDevotionId: "angelus")
    let tagStore = MacLibraryTagStore(defaults: defaults)
    tagStore.set("blue", on: synced.id.uuidString, enabled: true)
    try await store.save(synced)
    await model.reload()
    XCTAssertEqual(model.items.first { $0.prayer?.id == synced.id }?.tagIDs, ["red", "blue", named.id])
    XCTAssertTrue(tagStore.tagIDs(for: template.id).isEmpty)
  }

  func testLegacyColorTagsMigrateWithEveryIdentityNameAndAssignmentIntact() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let colorIDs = MacPrayerTag.colors.map(\.0)
    let legacy: [String: Any] = [
      "names": ["red": "Morning", "blue": "Evening", "green": "Morning"],
      "assignments": ["copy-a": colorIDs, "devotion:angelus": ["blue", "red"], "copy-b": ["gray"]]
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: MacLibraryTagStore.defaultsKey)
    let store = MacLibraryTagStore(defaults: defaults)
    XCTAssertEqual(store.tags.map(\.id), colorIDs)
    XCTAssertEqual(store.tags.map(\.colorID), colorIDs.map(Optional.some))
    XCTAssertEqual(store.tags.first { $0.id == "red" }?.title, "Morning")
    XCTAssertEqual(store.tags.first { $0.id == "blue" }?.title, "Evening")
    XCTAssertEqual(store.tags.first { $0.id == "green" }?.title, "Morning",
                   "Legacy duplicate names must not merge distinct tag identities")
    XCTAssertEqual(store.tagIDs(for: "copy-a"), Set(colorIDs))
    XCTAssertEqual(store.tagIDs(for: "devotion:angelus"), ["red", "blue"])
    let migrated = try XCTUnwrap(JSONSerialization.jsonObject(with: try XCTUnwrap(defaults.data(forKey: MacLibraryTagStore.defaultsKey))) as? [String: Any])
    XCTAssertEqual(migrated["version"] as? Int, 3)
    XCTAssertNil(migrated["names"])
    let reopened = MacLibraryTagStore(defaults: defaults)
    XCTAssertEqual(reopened.tags.map(\.id), colorIDs)
    XCTAssertEqual(reopened.tagIDs(for: "copy-b"), ["gray"])
  }

  func testNamedTagsReuseCaseInsensitiveNamesAndColorsRemainIndependent() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MacLibraryTagStore(defaults: defaults)
    let first = try XCTUnwrap(store.create(named: "  At Home\n", colorID: "blue"))
    XCTAssertNotNil(UUID(uuidString: first.id))
    XCTAssertEqual(first.title, "At Home")
    XCTAssertEqual(first.colorID, "blue")
    let reused = try XCTUnwrap(store.create(named: "AT HOME", colorID: "red"))
    XCTAssertEqual(reused.id, first.id)
    XCTAssertEqual(reused.title, first.title)
    XCTAssertEqual(reused.colorID, "blue", "Entering an existing name must not recolor it")
    XCTAssertEqual(store.tags.count, 8)
    store.set(first.id, on: "copy", enabled: true)
    store.setColor(first.id, colorID: "purple")
    XCTAssertEqual(store.tags.first { $0.id == first.id }?.colorID, "purple")
    XCTAssertEqual(store.tags.first { $0.id == first.id }?.title, "At Home")
    store.setColor(first.id, colorID: nil)
    XCTAssertNil(store.tags.first { $0.id == first.id }?.colorID)
    XCTAssertEqual(store.tagIDs(for: "copy"), [first.id])
    store.setColor("red", colorID: "green")
    XCTAssertEqual(store.tags.first { $0.id == "red" }?.colorID, "green")
    XCTAssertEqual(store.tags.first { $0.id == "red" }?.title, MacPrayerTag.colors.first?.2)
    let neutral = try XCTUnwrap(store.create(named: "No Color", colorID: "future-color"))
    XCTAssertNil(neutral.colorID)
    XCTAssertNil(store.create(named: " \n ", colorID: nil))
    XCTAssertNil(MacLibraryTagStore(defaults: defaults).tags.first { $0.id == first.id }?.colorID)
  }

  func testEditingOtherTokensPreservesAssignedLegacyDuplicateNameIdentities() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let legacy: [String: Any] = [
      "names": ["red": "Morning", "green": "Morning"],
      "assignments": ["green-only": ["green"], "both": ["red", "green"], "untouched": ["red"]]
    ]
    defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: MacLibraryTagStore.defaultsKey)
    let store = MacLibraryTagStore(defaults: defaults)
    store.setTags(named: ["Morning", "At Home"], on: "green-only")
    let home = try XCTUnwrap(store.tags.first { $0.title == "At Home" })
    XCTAssertEqual(store.tagIDs(for: "green-only"), ["green", home.id],
                   "An unrelated token edit must not replace green with the first same-named red tag")
    store.setTags(named: ["MORNING", "at home"], on: "both")
    XCTAssertEqual(store.tagIDs(for: "both"), ["red", "green", home.id],
                   "A shared name retains both old assignments when both were already selected")
    XCTAssertEqual(store.tagIDs(for: "untouched"), ["red"])
    store.setTags(named: ["At Home"], on: "green-only")
    XCTAssertEqual(store.tagIDs(for: "green-only"), [home.id], "Removing the shared-name token removes its assignment")
    store.setTags(named: ["Morning"], on: "new-item")
    XCTAssertEqual(store.tagIDs(for: "new-item"), ["red"], "A newly typed ambiguous name uses stored order consistently")
    let reopened = MacLibraryTagStore(defaults: defaults)
    XCTAssertEqual(reopened.tagIDs(for: "both"), ["red", "green", home.id])
  }

  func testRenameCollisionsFailWithoutMergingAssignmentsOrChangingColor() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let model = MacPrayerLibraryModel(store: MockPresetStore(configs: []), defaults: defaults, installedDevotionIDs: { [] })
    let first = try XCTUnwrap(model.createTag(named: "Morning", colorID: "red"))
    let second = try XCTUnwrap(model.createTag(named: "Evening", colorID: "blue"))
    let store = MacLibraryTagStore(defaults: defaults)
    store.set(first.id, on: "copy-a", enabled: true)
    store.set(second.id, on: "copy-b", enabled: true)
    XCTAssertFalse(model.renameTag(first, to: " evening "))
    XCTAssertNotNil(model.error)
    XCTAssertEqual(store.tags.first { $0.id == first.id }?.title, "Morning")
    XCTAssertEqual(store.tags.first { $0.id == first.id }?.colorID, "red")
    XCTAssertEqual(store.tagIDs(for: "copy-a"), [first.id])
    XCTAssertEqual(store.tagIDs(for: "copy-b"), [second.id])
    XCTAssertFalse(model.renameTag(first, to: "\n"))
    XCTAssertTrue(model.renameTag(first, to: "MORNING"), "Changing only capitalization keeps the same identity")
    XCTAssertEqual(store.tags.first { $0.id == first.id }?.title, "MORNING")
  }

  func testTypedTagNamesReplaceMembershipTogetherWithoutDeletingSharedTags() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MacLibraryTagStore(defaults: defaults)
    let existing = try XCTUnwrap(store.create(named: "Morning", colorID: "orange"))
    store.set("blue", on: "copy-a", enabled: true)
    store.set("blue", on: "copy-b", enabled: true)
    store.setTags(named: [" Morning ", "MORNING", "At Home", "at home", "\n"], on: "copy-a")
    let created = try XCTUnwrap(store.tags.first { $0.title == "At Home" })
    XCTAssertEqual(store.tagIDs(for: "copy-a"), [existing.id, created.id])
    XCTAssertEqual(store.tagIDs(for: "copy-b"), ["blue"])
    XCTAssertEqual(store.tags.count, 9)
    XCTAssertNil(created.colorID)
    XCTAssertEqual(store.tags.first { $0.id == existing.id }?.colorID, "orange")
    let reopened = MacLibraryTagStore(defaults: defaults)
    XCTAssertEqual(reopened.tagIDs(for: "copy-a"), [existing.id, created.id])
    reopened.setTags(named: [], on: "copy-a")
    XCTAssertTrue(store.tagIDs(for: "copy-a").isEmpty)
    XCTAssertNotNil(store.tags.first { $0.id == created.id }, "Removing membership keeps the named tag available elsewhere")
    XCTAssertEqual(store.tagIDs(for: "copy-b"), ["blue"])
  }

  func testDeletingTagsRemovesAllAssignmentsAndNeverRecreatesDeletedDefaults() throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MacLibraryTagStore(defaults: defaults)
    let custom = try XCTUnwrap(store.create(named: "Morning", colorID: nil))
    for item in ["copy-a", "devotion:angelus"] {
      store.set(custom.id, on: item, enabled: true)
      store.set("red", on: item, enabled: true)
    }
    store.delete(custom.id)
    XCTAssertNil(store.tags.first { $0.id == custom.id })
    XCTAssertEqual(store.tagIDs(for: "copy-a"), ["red"])
    XCTAssertEqual(store.tagIDs(for: "devotion:angelus"), ["red"])
    for id in MacPrayerTag.colors.map(\.0) { store.delete(id) }
    let reopened = MacLibraryTagStore(defaults: defaults)
    XCTAssertTrue(reopened.tags.isEmpty)
    XCTAssertTrue(reopened.tagIDs(for: "copy-a").isEmpty)
    XCTAssertTrue(reopened.tagIDs(for: "devotion:angelus").isEmpty)
    let new = try XCTUnwrap(reopened.create(named: "New", colorID: nil))
    XCTAssertEqual(store.tags.map(\.id), [new.id])
  }

  func testGalleryMembershipPersistsWithoutCreatingPresetsAndSavedPrayersStayVisible() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MockPresetStore(configs: [])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    XCTAssertTrue(model.items.isEmpty)
    XCTAssertFalse(model.galleryItems.isEmpty)
    let gallery = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "angelus" })
    XCTAssertFalse(model.isInLibrary(gallery))
    model.addToLibrary(gallery)
    model.addToLibrary(gallery)
    XCTAssertTrue(model.isInLibrary(gallery))
    XCTAssertEqual(model.items.map(\.devotionID), ["angelus"])
    let prayers = try await store.all()
    XCTAssertTrue(prayers.isEmpty)
    XCTAssertEqual(defaults.stringArray(forKey: MacLibraryMembershipStore.defaultsKey), ["angelus"])
    let reopened = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await reopened.reload()
    XCTAssertEqual(reopened.items.map(\.devotionID), ["angelus"])
    let saved = Prayer(name: "Saved Rosary", kind: .rosary)
    let orphan = Prayer(name: "Temporarily Missing Pack", kind: .custom, customDevotionId: "missing.pack")
    try await store.save(saved)
    try await store.save(orphan)
    await reopened.reload()
    XCTAssertEqual(Set(reopened.items.map(\.devotionID)), ["angelus", "rosary", "missing.pack"])
    XCTAssertEqual(reopened.items.first { $0.prayer?.id == orphan.id }?.title, orphan.name)
  }

  func testInstalledPacksBeginInGalleryWithoutLibraryMembership() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MockPresetStore(configs: [])
    // Inject only pack-source discovery, avoiding changes to the user's installed files.
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { ["angelus"] })
    await model.reload()
    XCTAssertTrue(model.items.isEmpty)
    XCTAssertTrue(model.galleryItems.contains { $0.devotionID == "angelus" })
    XCTAssertEqual(model.downloadedDevotionIDs, ["angelus"])
    XCTAssertTrue(MacLibraryMembershipStore(defaults: defaults).devotionIDs.isEmpty)
    let saved = try await store.all()
    XCTAssertTrue(saved.isEmpty)
  }

  func testBatchGalleryAdditionKeepsExistingCopiesAndAddsOnlyMissingMembership() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let saved = Prayer(name: "My Rosary", kind: .rosary)
    let store = MockPresetStore(configs: [saved])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    let rosary = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "rosary" })
    let angelus = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "angelus" })
    let trisagion = try XCTUnwrap(model.galleryItems.first { $0.devotionID == "trisagion" })
    model.addToLibrary(angelus)

    let changed = expectation(description: "One library reload notification for a batch")
    changed.assertForOverFulfill = true
    let observer = NotificationCenter.default.addObserver(forName: .prayerLibraryDidChange, object: nil, queue: nil) { _ in
      changed.fulfill()
    }
    defer { NotificationCenter.default.removeObserver(observer) }
    model.addToLibrary([rosary, angelus, trisagion, trisagion])
    model.addToLibrary([rosary, angelus, trisagion]) // no write or notification for a repeated batch
    await fulfillment(of: [changed], timeout: 1)

    XCTAssertEqual(Set(model.items.map(\.devotionID)), ["rosary", "angelus", "trisagion"])
    XCTAssertEqual(model.items.count, 3)
    XCTAssertEqual(defaults.stringArray(forKey: MacLibraryMembershipStore.defaultsKey), ["angelus", "trisagion"])
    let savedAfterAdding = try await store.all()
    XCTAssertEqual(savedAfterAdding, [saved], "Batch addition must never create or rewrite saved prayers")
    let reopened = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await reopened.reload()
    XCTAssertEqual(Set(reopened.items.map(\.devotionID)), ["rosary", "angelus", "trisagion"])
  }

  func testBatchGalleryAdditionIgnoresUnavailableIDsAndKeepsAnEmptyPresetStore() async throws {
    let suite = "MacPrayerLibraryTests.\(UUID())"
    let defaults = try tagFixtureDefaults(suite: suite)
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MockPresetStore(configs: [])
    let model = MacPrayerLibraryModel(store: store, defaults: defaults, installedDevotionIDs: { [] })
    await model.reload()
    let candidates = Array(model.galleryItems.prefix(3))
    XCTAssertEqual(candidates.count, 3)
    let unavailable = MacPrayerLibraryItem(id: "devotion:missing", title: "Missing", subtitle: "",
      systemImage: "book", iconGlyph: nil, color: .blue, prayer: nil, devotionID: "missing", tagIDs: [])
    model.addToLibrary(candidates + [unavailable])
    XCTAssertEqual(Set(model.items.map(\.devotionID)), Set(candidates.map(\.devotionID)))
    XCTAssertEqual(MacLibraryMembershipStore(defaults: defaults).devotionIDs, Set(candidates.map(\.devotionID)))
    let saved = try await store.all()
    XCTAssertTrue(saved.isEmpty)
  }

  func testGallerySelectionDropsHiddenItemsBeforeComputingItsAddAction() {
    let visible = [selectionItem("angelus"), selectionItem("trisagion")]
    let hidden = selectionItem("rosary")
    let ids = Set(visible.map(\.id) + [hidden.id, "stale-gallery-id"])
    let selection = MacPrayerGallerySelection(visibleItems: visible, selectedIDs: ids,
      includedDevotionIDs: [visible[0].devotionID])
    XCTAssertEqual(selection.retainedIDs, Set(visible.map(\.id)))
    XCTAssertEqual(selection.items.map(\.id), visible.map(\.id))
    XCTAssertEqual(selection.additions.map(\.id), [visible[1].id])
    XCTAssertNil(selection.showTarget, "A mixed selection offers Add, not Show")
    XCTAssertNil(selection.singleItem, "Download removal stays a single-item action")
  }

  func testGalleryShowTargetUsesVisibleOrderAndEmptySelectionHasNoAction() {
    let visible = [selectionItem("trisagion"), selectionItem("rosary"), selectionItem("angelus")]
    let selection = MacPrayerGallerySelection(visibleItems: visible, selectedIDs: Set(visible.map(\.id)),
      includedDevotionIDs: Set(visible.map(\.devotionID)))
    XCTAssertTrue(selection.additions.isEmpty)
    XCTAssertEqual(selection.showTarget?.id, visible.first?.id)
    let empty = MacPrayerGallerySelection(visibleItems: visible, selectedIDs: [], includedDevotionIDs: [])
    XCTAssertTrue(empty.items.isEmpty)
    XCTAssertTrue(empty.additions.isEmpty)
    XCTAssertNil(empty.showTarget)
  }

  /// These existing-state tests explicitly provide named tags; the app no longer seeds them.
  private func tagFixtureDefaults(suite: String) throws -> UserDefaults {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    let tags = MacPrayerTag.colors.map { id, _, title in
      ["id": id, "name": title, "colorID": id]
    }
    let value: [String: Any] = ["version": 3, "tags": tags, "assignments": [:] as [String: [String]]]
    defaults.set(try JSONSerialization.data(withJSONObject: value), forKey: MacLibraryTagStore.defaultsKey)
    return defaults
  }

  private func selectionItem(_ devotionID: String) -> MacPrayerLibraryItem {
    MacPrayerLibraryItem(id: "devotion:\(devotionID)", title: devotionID, subtitle: "",
      systemImage: "book", iconGlyph: nil, color: .blue, prayer: nil, devotionID: devotionID, tagIDs: [])
  }

  func testOrdinaryOpeningReusesCopyWindowAndExplicitNewWindowIsIndependent() throws {
    let id = UUID()
    let first = PrayerWindowRequest(route: .prayer(id: id))
    let reopen = PrayerWindowRequest(route: .prayer(id: id))
    let additional = PrayerWindowRequest(route: .prayer(id: id), newWindow: true)
    XCTAssertEqual(first, reopen)
    XCTAssertNotEqual(first, additional)
    XCTAssertEqual(first.id, id)
    let restored = try JSONDecoder().decode(PrayerWindowRequest.self, from: JSONEncoder().encode(first))
    XCTAssertEqual(first, restored)
  }
}
#endif
