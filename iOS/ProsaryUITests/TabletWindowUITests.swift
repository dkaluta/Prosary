#if os(iOS)
import XCTest
import UIKit

final class TabletWindowUITests: XCTestCase {
  @MainActor func testCalendarActionsStayReachableAfterResizingTabletWindow() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
    defer { XCUIDevice.shared.orientation = .portrait }
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-homeWidgetOrder", "calendar", "-homeWidgetLayoutVersion", "1"]
    app.launch()
    defer { app.terminate() }
    let date = app.buttons["homeWidgets.date"]
    XCTAssertTrue(date.waitForExistence(timeout: 10))
    let window = app.windows.firstMatch
    if window.frame.width < 900 {
      // iPad remembers floating-window geometry between launches. Start from full screen
      // using the native title-bar gesture, rather than depending on a fresh simulator.
      window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
        .withOffset(CGVector(dx: 0, dy: 6)).doubleTap()
      let expanded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in window.frame.width >= 900 }, object: nil)
      _ = XCTWaiter.wait(for: [expanded], timeout: 5)
    }
    let original = window.frame
    try XCTSkipIf(original.width < 900, "Requires a tablet in landscape with native window resizing enabled")
    defer {
      if window.frame.width < original.width - 100 || window.frame.height < original.height - 100 {
        window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0))
          .withOffset(CGVector(dx: 0, dy: 6)).doubleTap()
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
          window.frame.width >= original.width - 10 && window.frame.height >= original.height - 10
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 5), .completed,
          "Restore the native window geometry for subsequent tests")
      }
    }
    let handle = window.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
      .withOffset(CGVector(dx: -5, dy: -5))
    handle.press(forDuration: 0.3, thenDragTo: window.coordinate(withNormalizedOffset: CGVector(dx: 0.55, dy: 0.55)))
    let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      window.frame.width < original.width - 100 || window.frame.height < original.height - 100
    }, object: nil)
    try XCTSkipUnless(XCTWaiter.wait(for: [resized], timeout: 5) == .completed,
      "This simulator has not enabled native iPad window resizing")
    date.tap()
    let done = app.buttons["homeWidgets.dateDone"]
    XCTAssertTrue(done.waitForExistence(timeout: 5) && done.isHittable)
    XCTAssertTrue(app.buttons["homeWidgets.dateToday"].isHittable)
    let picker = app.descendants(matching: .any).matching(identifier: "homeWidgets.datePicker").firstMatch
    XCTAssertGreaterThanOrEqual(picker.frame.minX, window.frame.minX - 1)
    XCTAssertLessThanOrEqual(picker.frame.maxX, window.frame.maxX + 1)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "tablet-resized-calendar"; capture.lifetime = .keepAlways; add(capture)
    done.tap()
    XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
    XCTAssertTrue(date.isHittable)
  }
}
#endif
