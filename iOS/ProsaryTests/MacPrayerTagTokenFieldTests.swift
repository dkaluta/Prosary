#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerTagTokenFieldTests: XCTestCase {
  func testRepeatedTokenConversionHasStableObjectiveCEquality() {
    let first = MacPrayerTagTokenField.TagToken("At Home")
    let second = MacPrayerTagTokenField.TagToken("At Home")
    XCTAssertFalse(first === second)
    XCTAssertTrue(first.isEqual(second))
    XCTAssertEqual(first.hash, second.hash)
    XCTAssertTrue(NSArray(object: first).isEqual(to: [second]),
      "AppKit must not treat every intrinsic-size validation as a changed token array")
    XCTAssertFalse(first.isEqual(MacPrayerTagTokenField.TagToken("Evening")))
  }

  func testSizingValidationDoesNotCommitAnyPartOfANewName() throws {
    let harness = Harness()
    for draft in ["A", "At", "At H", "At Ho", "At Home"] {
      let represented = try XCTUnwrap(harness.coordinator.tokenField(
        harness.field, representedObjectForEditing: draft))
      XCTAssertEqual(represented as? String, draft)
      harness.field.objectValue = [represented]
      for _ in 0..<4 {
        harness.field.updateConstraints()
        XCTAssertEqual(harness.coordinator.names(in: harness.field), [])
      }
    }
    XCTAssertTrue(harness.state.commits.isEmpty)
    XCTAssertEqual(harness.coordinator.names(in: harness.field, committingDraft: true), ["At Home"])
  }

  func testAcceptedCustomTokenIsCommittedAsOneCompleteName() {
    let harness = Harness()
    let accepted = harness.coordinator.tokenField(harness.field, shouldAdd: ["  At Home  "], at: 0)
    XCTAssertEqual(accepted.count, 1)
    XCTAssertEqual((accepted.first as? MacPrayerTagTokenField.TagToken)?.title, "At Home")
    harness.field.objectValue = accepted
    harness.coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification,
                                                             object: harness.field))
    XCTAssertEqual(harness.state.names, ["At Home"])
    XCTAssertEqual(harness.state.commits, [["At Home"]])
  }

  func testReturnKeepsExistingTagsAndCommitsUnterminatedDraft() {
    let harness = Harness(names: ["Red"])
    harness.field.objectValue = [MacPrayerTagTokenField.TagToken("Red"), "At Home"]
    harness.coordinator.finish(harness.field)
    XCTAssertEqual(harness.state.names, ["Red", "At Home"])
    XCTAssertEqual(harness.state.commits, [["Red", "At Home"]])
    XCTAssertEqual(harness.state.finishCount, 1)
  }

  func testRemovingTokensPublishesAnEmptyAssignment() {
    let harness = Harness(names: ["At Home"])
    harness.field.objectValue = []
    harness.coordinator.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification,
                                                             object: harness.field))
    XCTAssertEqual(harness.state.names, [])
    XCTAssertEqual(harness.state.commits, [[]])
  }

  func testDismantlingCommitsDraftOnceAndInvalidatesQueuedCallbacks() async throws {
    let harness = Harness(names: ["Red"])
    harness.field.objectValue = [MacPrayerTagTokenField.TagToken("Red"), "At Home"]
    harness.coordinator.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification,
                                                        object: harness.field))
    MacPrayerTagTokenField.dismantleNSView(harness.field, coordinator: harness.coordinator)
    try await Task.sleep(for: .milliseconds(20))
    XCTAssertEqual(harness.state.commits, [["Red", "At Home"]])
    XCTAssertFalse(harness.coordinator.isActive)
    XCTAssertNil(harness.field.delegate)
    XCTAssertNil(harness.field.target)
  }

  @MainActor private final class State {
    var names: [String]
    var commits: [[String]] = []
    var finishCount = 0
    init(names: [String]) { self.names = names }
  }

  @MainActor private final class Harness {
    let state: State
    let field: MacPrayerTagTokenField.FocusedTagTokenField
    let coordinator: MacPrayerTagTokenField.Coordinator

    init(names: [String] = []) {
      let state = State(names: names)
      self.state = state
      let representable = MacPrayerTagTokenField(
        names: Binding(get: { state.names }, set: { state.names = $0 }),
        suggestions: ["Red", "Blue"],
        onChange: { state.commits.append($0) }, onFinish: { state.finishCount += 1 })
      coordinator = representable.makeCoordinator()
      coordinator.publishedNames = names
      field = MacPrayerTagTokenField.FocusedTagTokenField(frame: NSRect(x: 0, y: 0, width: 278, height: 48))
      field.delegate = coordinator
      field.objectValue = names.map { MacPrayerTagTokenField.TagToken($0) }
    }
  }
}
#endif
