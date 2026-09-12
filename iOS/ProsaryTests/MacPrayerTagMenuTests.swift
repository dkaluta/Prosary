#if os(macOS)
import AppKit
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerTagMenuTests: XCTestCase {
  func testFreshLibraryMenuHasOnlyClearAndTagsEditorAndCreatesNothing() throws {
    let fixture = Fixture()
    defer { fixture.close() }
    XCTAssertTrue(fixture.store.tags.isEmpty)
    let row = MacPrayerTagMenuRow(tags: fixture.store.tags, selectedIDs: [],
      onToggle: { _ in XCTFail("There are no stored tags") }, onClear: {}, onEdit: {})
    let buttons = row.subviews.compactMap { $0 as? NSButton }
    XCTAssertEqual(buttons.compactMap { $0.identifier?.rawValue },
      ["macLibrary.tagSwatch.clear", "macLibrary.editTags"])
    XCTAssertFalse(try XCTUnwrap(buttons.first).isEnabled)
    XCTAssertTrue(try XCTUnwrap(buttons.last).isEnabled)
    XCTAssertTrue(fixture.store.tags.isEmpty)
    XCTAssertTrue(MacLibraryTagStore(defaults: fixture.defaults).tags.isEmpty)
  }

  func testMigrationRemovesOnlyUntouchedUnusedSeeds() throws {
    let fixture = Fixture()
    defer { fixture.close() }
    var tags = MacPrayerTag.colors.map { id, _, name in ["id": id, "name": name, "colorID": id] }
    tags[1]["name"] = "Evening"
    tags[2]["colorID"] = "purple"
    tags.append(["id": "a-personal-tag", "name": "Red", "colorID": "red"])
    let value: [String: Any] = ["version": 2, "tags": tags, "assignments": ["prayer": ["blue"]]]
    fixture.defaults.set(try JSONSerialization.data(withJSONObject: value), forKey: MacLibraryTagStore.defaultsKey)
    XCTAssertEqual(fixture.store.tags.map(\.id), ["orange", "yellow", "blue", "a-personal-tag"])
    XCTAssertEqual(fixture.store.tagIDs(for: "prayer"), ["blue"])
    XCTAssertEqual(fixture.store.tags.first { $0.id == "orange" }?.title, "Evening")
    XCTAssertEqual(fixture.store.tags.first { $0.id == "yellow" }?.colorID, "purple")
    fixture.store.set("blue", on: "prayer", enabled: false)
    XCTAssertNotNil(MacLibraryTagStore(defaults: fixture.defaults).tags.first { $0.id == "blue" },
      "Once migrated, removing the last assignment must not delete a retained tag")
  }

  func testLegacyNamesAndAssignmentsArePreservedWithoutSeedingUnusedColors() throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let value: [String: Any] = ["names": ["red": "Morning"], "assignments": ["prayer": ["blue"]]]
    fixture.defaults.set(try JSONSerialization.data(withJSONObject: value), forKey: MacLibraryTagStore.defaultsKey)
    XCTAssertEqual(fixture.store.tags.map(\.id), ["red", "blue"])
    XCTAssertEqual(fixture.store.tags.first?.title, "Morning")
    XCTAssertEqual(fixture.store.tagIDs(for: "prayer"), ["blue"])
  }

  func testAssigningAndClearingExistingTagsNeverCreatesOrDeletesTags() throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let red = try XCTUnwrap(fixture.store.create(named: "Evening", colorID: "red"))
    fixture.store.set(red.id, on: "first", enabled: true)
    XCTAssertEqual(fixture.store.tags.count, 1)
    XCTAssertEqual(red.colorID, "red")
    XCTAssertEqual(fixture.store.tagIDs(for: "first"), [red.id])
    fixture.store.set(red.id, on: "second", enabled: true)
    XCTAssertEqual(fixture.store.tags.map(\.id), [red.id])
    XCTAssertEqual(fixture.store.tagIDs(for: "second"), [red.id])
    fixture.store.setTags(named: [], on: "first")
    XCTAssertTrue(fixture.store.tagIDs(for: "first").isEmpty)
    XCTAssertEqual(fixture.store.tags.map(\.id), [red.id], "Clear removes assignments, not the person's tag")
  }

  func testMenuKeepsEveryStoredIDInOrderIncludingSameColorAndUncoloredTags() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let first = try XCTUnwrap(fixture.store.create(named: "Morning", colorID: "red"))
    let neutral = try XCTUnwrap(fixture.store.create(named: "At Home", colorID: nil))
    let last = try XCTUnwrap(fixture.store.create(named: "Evening", colorID: "red"))
    var toggled: [String] = []
    let row = MacPrayerTagMenuRow(tags: fixture.store.tags, selectedIDs: [first.id, last.id],
      onToggle: { toggled.append($0.id) }, onClear: {}, onEdit: {})
    let buttons = row.subviews.compactMap { $0 as? NSButton }.filter { $0.identifier?.rawValue != "macLibrary.editTags" }
    XCTAssertEqual(buttons.compactMap { $0.identifier?.rawValue },
      ["clear", first.id, neutral.id, last.id].map { "macLibrary.tagSwatch.\($0)" })
    XCTAssertEqual(buttons.map(\.state), [.off, .on, .off, .on])
    XCTAssertEqual(buttons[1].accessibilityLabel(), "Remove “Morning”")
    XCTAssertEqual(buttons[2].accessibilityLabel(), "Add “At Home”")
    XCTAssertEqual(buttons[3].accessibilityLabel(), "Remove “Evening”")
    for button in buttons.dropFirst() { button.performClick(nil) }
    await nextMainQueueTurn()
    XCTAssertEqual(toggled, [first.id, neutral.id, last.id])
    XCTAssertEqual(fixture.store.tags.map(\.id), [first.id, neutral.id, last.id])
  }

  func testNativeTagControlsHaveOneTargetPerSavedTagAndDeferredActions() async throws {
    let selected = MacPrayerTag(id: "evening", title: "Evening", colorID: "red")
    var actions: [String] = []
    let row = MacPrayerTagMenuRow(tags: [selected], selectedIDs: [selected.id],
      onToggle: { actions.append($0.id) }, onClear: { actions.append("clear") },
      onEdit: { actions.append("edit") })
    let menu = NSMenu()
    let item = NSMenuItem()
    item.view = row
    menu.addItem(item)
    let buttons = row.subviews.compactMap { $0 as? NSButton }
    XCTAssertEqual(buttons.count, 3)
    XCTAssertTrue(buttons.allSatisfy { row.bounds.contains($0.frame) })
    let red = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "macLibrary.tagSwatch.evening" })
    XCTAssertEqual(red.state, .on)
    let edit = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "macLibrary.editTags" })
    edit.performClick(nil)
    XCTAssertTrue(actions.isEmpty, "Library updates must wait until native menu tracking has ended")
    await nextMainQueueTurn()
    XCTAssertEqual(actions, ["edit"])
    red.performClick(nil)
    await nextMainQueueTurn()
    XCTAssertEqual(actions.last, selected.id)
    let clear = try XCTUnwrap(buttons.first { $0.identifier?.rawValue == "macLibrary.tagSwatch.clear" })
    clear.performClick(nil)
    await nextMainQueueTurn()
    XCTAssertEqual(actions.last, "clear")
  }

  func testManyTagsWrapWithoutOverlapAndRemainKeyboardAccessible() async throws {
    let tags = (0..<25).map { MacPrayerTag(id: "tag-\($0)", title: "Tag \($0)", colorID: nil) }
    var selected: String?
    let row = MacPrayerTagMenuRow(tags: tags, selectedIDs: [],
      onToggle: { selected = $0.id }, onClear: { XCTFail("Nothing to clear") }, onEdit: {})
    let buttons = row.subviews.compactMap { $0 as? NSButton }
    XCTAssertEqual(buttons.count, tags.count + 2)
    XCTAssertTrue(buttons.allSatisfy { row.bounds.contains($0.frame) })
    for (index, button) in buttons.enumerated() {
      XCTAssertTrue(buttons.dropFirst(index + 1).allSatisfy { !button.frame.intersects($0.frame) })
    }
    XCTAssertGreaterThan(buttons[9].frame.minY, buttons[1].frame.maxY)
    row.keyDown(with: key(124)) // The disabled Clear is skipped.
    row.keyDown(with: key(125))
    row.keyDown(with: key(125))
    row.keyDown(with: key(125)) // Reach the final stored tag in the fourth row.
    row.keyDown(with: key(36))
    await nextMainQueueTurn()
    XCTAssertEqual(selected, "tag-24")
    row.keyDown(with: key(126))
    row.keyDown(with: key(36))
    await nextMainQueueTurn()
    XCTAssertEqual(selected, "tag-16")
    for _ in 0..<16 { row.keyDown(with: key(123)) }
    row.keyDown(with: key(36))
    await nextMainQueueTurn()
    XCTAssertEqual(selected, "tag-0")
  }

  func testDisabledTagControlsCannotChangeTags() throws {
    let row = MacPrayerTagMenuRow(tags: [], selectedIDs: [], isEnabled: false,
      onToggle: { _ in XCTFail("Disabled tags") }, onClear: { XCTFail("Disabled clear") },
      onEdit: { XCTFail("Disabled editor") })
    XCTAssertTrue(row.subviews.compactMap { $0 as? NSButton }.allSatisfy { !$0.isEnabled })
    row.keyDown(with: key(124))
    row.keyDown(with: key(125))
  }

  private func key(_ code: UInt16) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
      timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "",
      isARepeat: false, keyCode: code)!
  }

  private func nextMainQueueTurn() async {
    await withCheckedContinuation { continuation in DispatchQueue.main.async { continuation.resume() } }
  }

  @MainActor private final class Fixture {
    let suite = "MacPrayerTagMenuTests.\(UUID())"
    let defaults: UserDefaults
    let store: MacLibraryTagStore
    init() {
      defaults = UserDefaults(suiteName: suite)!
      store = MacLibraryTagStore(defaults: defaults)
    }
    func close() { defaults.removePersistentDomain(forName: suite) }
  }
}
#endif
