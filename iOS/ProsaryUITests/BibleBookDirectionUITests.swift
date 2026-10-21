#if os(iOS)
import XCTest
import UIKit

final class BibleBookDirectionUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    executionTimeAllowance = 240
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor
  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: identifier).firstMatch
  }

  @MainActor
  private func visiblePage(_ slot: Int, in app: XCUIApplication) -> XCUIElement {
    let pages = app.descendants(matching: .any).matching(identifier: "bible.page.\(slot)")
    return pages.allElementsBoundByIndex.first { $0.isHittable } ?? pages.firstMatch
  }

  @MainActor
  private func waitForCount(_ count: String, on element: XCUIElement) {
    let expectation = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", count), object: element)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 15), .completed)
  }

  @MainActor
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  /// The verified Masoretic/Delitzsch archive must already be installed locally. The
  /// interface stays English so scripture, rather than interface language, owns the book.
  @MainActor
  func testHebrewFacingPagesAndGesturesFollowScriptureDirection() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-readingsEditionId", "masoretic-delitzsch",
                           "-homeWidgetOrder", "scripture"]
    app.launch()
    defer { app.terminate() }

    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 15))
    for _ in 0..<4 where !open.isHittable { app.swipeUp() }
    open.tap()
    let genesis = app.buttons["bible.book.GEN"]
    XCTAssertTrue(genesis.waitForExistence(timeout: 15))
    let installationResolved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      genesis.isEnabled || app.buttons["bible.download"].exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [installationResolved], timeout: 15), .completed)
    try XCTSkipUnless(genesis.isEnabled,
                      "Requires the verified local Masoretic/Delitzsch archive in the disposable simulator.")
    for _ in 0..<8 where !genesis.isHittable { app.swipeUp() }
    XCTAssertTrue(genesis.isHittable)
    genesis.tap()
    let chapter = app.buttons["bible.chapter.1"]
    XCTAssertTrue(chapter.waitForExistence(timeout: 15))
    chapter.tap()
    let reader = element("bible.bookReader", in: app)
    try XCTSkipUnless(reader.waitForExistence(timeout: 15),
                      "Facing-page direction requires iPad landscape or an open, wide Duo display.")

    let count = element("bible.pageCount", in: app)
    var previousCount = ""
    var unchangedSince = Date()
    let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      let current = count.label
      if current != previousCount {
        previousCount = current
        unchangedSince = Date()
        return false
      }
      return !current.isEmpty && Date().timeIntervalSince(unchangedSince) >= 0.5
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 15), .completed)
    let firstCount = count.label
    let firstPage = visiblePage(0, in: app)
    let secondPage = visiblePage(1, in: app)
    XCTAssertTrue(firstPage.exists && secondPage.exists)
    XCTAssertGreaterThan(firstPage.frame.midX, secondPage.frame.midX,
                         "The first Hebrew leaf is on the right despite the English interface")
    let next = app.buttons["bible.nextPage"]
    let previous = app.buttons["bible.previousPage"]
    XCTAssertTrue(next.isHittable && previous.isHittable)
    XCTAssertEqual(next.label, "Next Page")
    XCTAssertLessThan(next.frame.midX, previous.frame.midX,
                      "Forward Hebrew book navigation sits on the left")
    XCTAssertTrue(next.isEnabled)
    XCTAssertFalse(previous.isEnabled)
    capture("bible-hebrew-book-english-interface-first-spread")

    next.tap()
    let advanced = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label != %@", firstCount), object: count)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 15), .completed)
    let secondCount = count.label
    capture("bible-hebrew-book-next-spread")

    // In an RTL book, swiping toward inline-end (left) returns to the earlier spread;
    // swiping toward inline-start (right) advances again.
    reader.swipeLeft()
    waitForCount(firstCount, on: count)
    capture("bible-hebrew-book-swipe-left-previous")
    reader.swipeRight()
    waitForCount(secondCount, on: count)
    capture("bible-hebrew-book-swipe-right-next")
  }
}
#endif
