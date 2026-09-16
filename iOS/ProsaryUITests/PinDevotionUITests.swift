//
//  PinDevotionUITests.swift
//  ProsaryUITests
//
//  A devotion with no presets is pinned to Pray by the star in its flow — that star is the only
//  pinning affordance those devotions have, so it is worth a test of its own.
//

import XCTest

final class PinDevotionUITests: XCTestCase {
  override func setUpWithError() throws {
    // The simulator remembers its orientation between runs, and landscape shortens every
    // list — rows fall below the fold and queries that assume a visible row fail for reasons
    // that have nothing to do with the app. Start upright, always.
    #if !os(macOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
    continueAfterFailure = false
  }

  @MainActor
  func testStarringADevotionPinsItToPray() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-defaultLanguageCode", "en",
                           "-autoAdvanceSeconds", "0"]
    app.launch()

    // Not pinned to begin with: a clean store seeds only the Rosary.
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["angelusCard"].exists)

    // Search retains category browsing and access to every local devotion.
    let searchTab = app.tabBars.buttons["Search"]
    XCTAssertTrue(searchTab.waitForExistence(timeout: 5))
    searchTab.tap()
    XCTAssertTrue(app.buttons["search.category.all"].waitForExistence(timeout: 5))
    let row = app.buttons["search.local.angelus"].firstMatch
    for _ in 0..<8 {
      if row.exists && row.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(row.waitForExistence(timeout: 5) && row.isHittable, app.debugDescription)
    row.tap()

    let star = app.buttons["pinDevotionButton"]
    XCTAssertTrue(star.waitForExistence(timeout: 10))
    star.tap()

    app.navigationBars.buttons.element(boundBy: 0).tap()
    let prayTab = app.tabBars.buttons["Pray"]
    XCTAssertTrue(prayTab.waitForExistence(timeout: 5))
    prayTab.tap()
    XCTAssertTrue(app.buttons["angelusCard"].waitForExistence(timeout: 10),
                  "Starring a devotion should pin it to Pray")
  }
}
