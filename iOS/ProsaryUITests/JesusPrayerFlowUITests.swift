//
//  JesusPrayerFlowUITests.swift
//  ProsaryUITests
//
//  These tests use an isolated store with no Jesus Prayer default, so the local Search item
//  opens JesusPrayerSetupView instead of jumping straight to a saved flow. The target chooser
//  is two rows of plain buttons (counts on top, the
//  open-ended choices below) rather than one five-segment picker, so the segments are ordinary
//  buttons carrying the `.isSelected` trait on iOS. The counter flow advances
//  through its central "Pray" button — it passes a centralActionLabel, so PrayerStepFlowView
//  renders that instead of a footer Next — and since 0.7.3 no footer at all, so there is no
//  step-back control here either.
//

import XCTest

final class JesusPrayerFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    // The simulator remembers its orientation between runs, and landscape shortens every
    // list — rows fall below the fold and queries that assume a visible row fail for reasons
    // that have nothing to do with the app. Start upright, always.
    #if !os(macOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
    continueAfterFailure = false
  }

  /// The Jesus Prayer has no saved session on a clean store, so Search is its way in.
  private func openJesusPrayer(_ app: XCUIApplication) {
    let searchTab = app.tabBars.buttons["Search"]
    XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
    searchTab.tap()
    XCTAssertTrue(app.buttons["search.category.all"].waitForExistence(timeout: 5))
    // Local browsing is available without activating the system's searchable field. The
    // prayer's title may be in another language, so locate its stable discovery identifier.
    let row = app.buttons["search.local.jesusPrayer"].firstMatch
    for _ in 0..<8 {
      if row.exists && row.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(row.waitForExistence(timeout: 5) && row.isHittable, app.debugDescription)
    row.tap()
  }

  private func launchClean() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-defaultLanguageCode", "en",
                           "-autoAdvanceSeconds", "0"]
    app.launch()
    return app
  }

  @MainActor
  func testTargetChooserOffersBothRows() throws {
    let app = launchClean()
    openJesusPrayer(app)

    for target in ["33", "66", "99", "Unbounded", "Custom"] {
      XCTAssertTrue(app.buttons[target].waitForExistence(timeout: 5),
                    "\(target) should be offered")
    }
    // 33 is the default, and the two rows share one selection.
    XCTAssertTrue(app.buttons["33"].isSelected)

    // Tapped near the pill's edge, well away from the glyphs: the whole segment has to be
    // hit-testable, which is exactly what a missing contentShape breaks (an element-centre
    // tap would pass either way).
    app.buttons["99"].coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["99"].isSelected)
    XCTAssertFalse(app.buttons["33"].isSelected)

    app.buttons["Unbounded"].coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
    XCTAssertTrue(app.buttons["Unbounded"].isSelected)
  }

  @MainActor
  func testBoundedTargetDefaultsTo33AndTracksCount() throws {
    let app = launchClean()

    openJesusPrayer(app)
    XCTAssertTrue(app.buttons["33"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["33"].isSelected)

    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 33"].waitForExistence(timeout: 5))

    app.buttons["centralActionButton"].tap()
    app.buttons["centralActionButton"].tap()
    XCTAssertTrue(app.staticTexts["3 of 33"].waitForExistence(timeout: 5))

    // A counter flow offers no step-back control at all — the central Pray button is the
    // whole footer's worth of action.
    XCTAssertFalse(app.buttons["prayerFlowBackButton"].exists,
                   "The Jesus Prayer should not offer a step-back button")
  }

  @MainActor
  func testUnboundedTargetHasNoFixedTotalAndAlwaysOffersFinish() throws {
    let app = launchClean()

    openJesusPrayer(app)
    XCTAssertTrue(app.buttons["Unbounded"].waitForExistence(timeout: 5))
    app.buttons["Unbounded"].tap()
    app.buttons["Begin"].tap()

    XCTAssertTrue(app.staticTexts["1"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["1 of 33"].exists)

    app.buttons["centralActionButton"].tap()
    app.buttons["centralActionButton"].tap()
    XCTAssertTrue(app.staticTexts["3"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["prayerFlowNextButton"].exists,
                   "A counter flow replaces Next with the central Pray button")

    // An open-ended session never turns Next into Finish, so the toolbar offers it instead.
    let finishButton = app.buttons["Finish"]
    XCTAssertTrue(finishButton.exists)
    finishButton.tap()

    XCTAssertTrue(app.buttons["search.local.jesusPrayer"].firstMatch.waitForExistence(timeout: 5))
  }

  @MainActor
  func testCustomTargetRequiresAValidNumberBeforeBeginIsEnabled() throws {
    let app = launchClean()

    openJesusPrayer(app)
    XCTAssertTrue(app.buttons["Custom"].waitForExistence(timeout: 5))
    app.buttons["Custom"].tap()

    XCTAssertFalse(app.buttons["Begin"].isEnabled)

    let customCount = app.textFields["jesusPrayerCustomCount"]
    XCTAssertTrue(customCount.waitForExistence(timeout: 5))
    customCount.tap()
    customCount.typeText("12")

    XCTAssertTrue(app.buttons["Begin"].isEnabled)
    app.buttons["Begin"].tap()
    XCTAssertTrue(app.staticTexts["1 of 12"].waitForExistence(timeout: 5))
  }
}
