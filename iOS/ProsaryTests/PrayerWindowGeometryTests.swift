#if os(macOS)
import AppKit
import XCTest
@testable import Prosary

final class PrayerWindowGeometryTests: XCTestCase {
  func testEachLibraryItemKeepsItsIdentityAndConcurrentWindowsUseSeparateSlots() {
    var slots = PrayerWindowFrameSlots()
    let original = slots.claim(persistenceID: "library-item-one")
    let concurrent = slots.claim(persistenceID: "library-item-one")
    let duplicate = slots.claim(persistenceID: "library-item-two")
    XCTAssertEqual(original.ordinal, 1)
    XCTAssertEqual(concurrent.ordinal, 2)
    XCTAssertEqual(duplicate.ordinal, 1)
    XCTAssertNotEqual(original.name, concurrent.name)
    XCTAssertNotEqual(original.name, duplicate.name)
    slots.release(original.name)
    XCTAssertEqual(slots.claim(persistenceID: "library-item-one"), original)
  }

  func testVisibleOrPartiallyOffscreenWindowRetainsItsPlacement() {
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 875)
    XCTAssertFalse(PrayerWindowFrameRecovery.needsRecovery(
      NSRect(x: 100, y: 100, width: 620, height: 700), visibleFrames: [screen]))
    XCTAssertFalse(PrayerWindowFrameRecovery.needsRecovery(
      NSRect(x: -120, y: 100, width: 620, height: 700), visibleFrames: [screen]))
  }

  func testDisconnectedScreenOrUnreachableTitleBarNeedsRecovery() {
    let screen = NSRect(x: 0, y: 0, width: 1440, height: 875)
    XCTAssertTrue(PrayerWindowFrameRecovery.needsRecovery(
      NSRect(x: 1800, y: 100, width: 620, height: 700), visibleFrames: [screen]))
    XCTAssertTrue(PrayerWindowFrameRecovery.needsRecovery(
      NSRect(x: 100, y: 600, width: 620, height: 700), visibleFrames: [screen]))
    XCTAssertFalse(PrayerWindowFrameRecovery.needsRecovery(
      NSRect(x: -1200, y: 100, width: 620, height: 700),
      visibleFrames: [screen, NSRect(x: -1440, y: 0, width: 1440, height: 875)]))
  }

  func testNoScreenDuringDisplayTransitionDoesNotForceAFrame() {
    XCTAssertFalse(PrayerWindowFrameRecovery.needsRecovery(.zero, visibleFrames: []))
  }
}
#endif
