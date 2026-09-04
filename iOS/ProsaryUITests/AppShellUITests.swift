//
//  AppShellUITests.swift
//  ProsaryUITests
//
//  The tab shell and the two surfaces reachable from Home's toolbar. Replaces the Xcode
//  template's empty testExample, which asserted nothing.
//

import XCTest

final class AppShellUITests: XCTestCase {
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
  func testEveryTabOpensItsScreen() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10), "Pray lists the seeded favorite")

    // Categories groups every devotion by tag — the discovery surface Pray no longer duplicates.
    app.tabBars.buttons["Categories"].tap()
    XCTAssertTrue(app.navigationBars["Categories"].waitForExistence(timeout: 5))

    app.tabBars.buttons["Search"].tap()
    XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))

    // Browse reaches the network; assert the screen, never the catalogue's contents.
    app.tabBars.buttons["Browse"].tap()
    XCTAssertTrue(app.navigationBars["Community Devotions"].waitForExistence(timeout: 5))

    app.tabBars.buttons["Pray"].tap()
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  #if os(macOS)
  @MainActor
  func testDoubleClickingRosaryCardNeedsOnlyOneBackClick() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore"]
    app.launch()

    let rosaryCard = app.buttons["rosaryCard"]
    XCTAssertTrue(rosaryCard.waitForExistence(timeout: 10))
    rosaryCard.doubleClick()

    let defaultPresetButton = app.buttons["prayDefaultPreset"]
    XCTAssertTrue(defaultPresetButton.waitForExistence(timeout: 5))
    let backButton = app.buttons["Back"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 5))
    backButton.click()

    XCTAssertTrue(rosaryCard.waitForExistence(timeout: 5),
                  "A double-click must not push the Rosary presets screen twice")
    XCTAssertFalse(defaultPresetButton.exists)
  }
  #endif

  @MainActor
  func testSettingsOpensFromHomeAndOffersItsSections() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Downloads"].exists, "Downloads section should be present")
    XCTAssertTrue(app.buttons["Remove All Downloaded Devotions…"].exists)
  }

  @MainActor
  func testHomeOrderEditorOpensFromTheToolbar() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["editOrderButton"].waitForExistence(timeout: 10))
    app.buttons["editOrderButton"].tap()

    XCTAssertTrue(app.navigationBars["Home Order"].waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLanguageFallbackOrderUsesTheReorderEditor() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.buttons["languageFallbackOrderButton"].waitForExistence(timeout: 5))
    app.buttons["languageFallbackOrderButton"].tap()

    XCTAssertTrue(app.navigationBars["Language fallback order"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.otherElements["languageFallbackOrderList"].exists
      || app.tables["languageFallbackOrderList"].exists)
    app.buttons["Done"].tap()
  }
}
