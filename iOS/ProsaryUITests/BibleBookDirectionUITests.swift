#if os(iOS)
import XCTest
import UIKit

final class BibleBookDirectionUITests: XCTestCase {
  @MainActor func testHebrewFacingPagesAndGesturesFollowScriptureDirection() throws {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
    defer { XCUIDevice.shared.orientation = .portrait }
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-readingsEditionId", "masoretic-delitzsch", "-homeWidgetOrder", "scripture"]
    app.launch(); defer { app.terminate() }
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
    let counter = app.staticTexts["bible.pageCount"]
    func values() -> [Int] { counter.exists ? counter.label.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) } : [] }
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in values().last.map { $0 > 500 } == true }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 90), .completed)
    let initial = counter.label
    let total = values().last
    let next = app.buttons["bible.nextPage"], previous = app.buttons["bible.previousPage"]
    XCTAssertLessThan(next.frame.midX, previous.frame.midX)
    XCTAssertFalse(previous.isEnabled)
    next.tap()
    let advanced = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label != %@", initial), object: counter)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 10), .completed)
    let second = counter.label
    app.webViews.firstMatch.swipeLeft()
    let returned = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", initial), object: counter)
    XCTAssertEqual(XCTWaiter.wait(for: [returned], timeout: 10), .completed)
    app.webViews.firstMatch.swipeRight()
    let restored = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", second), object: counter)
    XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 10), .completed)
    XCTAssertEqual(values().last, total)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); image.name = "continuous-edition-hebrew"; image.lifetime = .keepAlways; add(image)
  }
}
#endif
