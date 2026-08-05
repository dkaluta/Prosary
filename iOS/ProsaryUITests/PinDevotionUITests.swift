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
    app.launchArguments = ["-resetStore"]
    app.launch()

    // Not pinned to begin with: a clean store seeds only the Rosary.
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["angelusCard"].exists)

    // A devotion under two tags appears twice in Categories, hence firstMatch.
    app.tabBars.buttons["Categories"].tap()
    let row = app.buttons["category.angelus"].firstMatch
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()

    let star = app.buttons["pinDevotionButton"]
    XCTAssertTrue(star.waitForExistence(timeout: 10))
    star.tap()

    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.tabBars.buttons["Pray"].tap()
    XCTAssertTrue(app.buttons["angelusCard"].waitForExistence(timeout: 10),
                  "Starring a devotion should pin it to Pray")
  }
}
