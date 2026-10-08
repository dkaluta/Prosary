#if os(iOS)
import XCTest

final class BibleUITests: XCTestCase {
  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-readingsEditionId", "douay-rheims-1899"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Readings"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Readings"].tap()
    return app
  }

  @MainActor func testBibleScopePreservesDailyDate() throws {
    let app = launch()
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    let previous = app.buttons["readings.previousDay"]
    XCTAssertTrue(previous.waitForExistence(timeout: 5))
    previous.tap()
    let date = app.buttons["readings.chooseDate"].label
    let scope = app.segmentedControls["readings.mode"]
    XCTAssertGreaterThanOrEqual(scope.frame.minY,
      app.navigationBars["Readings"].staticTexts["Readings"].frame.maxY,
      "The Daily/Bible selector must remain below the large navigation title")
    scope.buttons["Bible"].tap()
    XCTAssertTrue(app.buttons["bible.book.GEN"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.navigationBars["Bible"].staticTexts["Bible"].waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(scope.frame.minY,
      app.navigationBars["Bible"].staticTexts["Bible"].frame.maxY,
      "The selector must not obscure the Bible title")
    XCTAssertFalse(app.buttons["readings.chooseDate"].exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-edition-and-books"; capture.lifetime = .keepAlways; add(capture)
    scope.buttons["Daily Readings"].tap()
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["readings.chooseDate"].label, date)
    let dailyCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    dailyCapture.name = "daily-readings-restored-title"; dailyCapture.lifetime = .keepAlways; add(dailyCapture)
  }

  @MainActor func testFeastListOpensTheSelectedDaysReadings() throws {
    let app = launch()
    app.buttons["calendar.list"].tap()
    XCTAssertTrue(app.navigationBars["Feasts and Solemnities"].waitForExistence(timeout: 5))
    let feast = app.buttons.containing(.staticText, identifier: "Solemnity").firstMatch
    XCTAssertTrue(feast.waitForExistence(timeout: 5))
    if !feast.isHittable { app.swipeUp() }
    XCTAssertTrue(feast.isHittable)
    let selectedTitle = feast.staticTexts.element(boundBy: 1).label
    feast.tap()
    XCTAssertTrue(app.navigationBars["Readings"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[selectedTitle].waitForExistence(timeout: 5))
    XCTAssertFalse(app.navigationBars["Feasts and Solemnities"].exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "feast-selected-daily-readings"; capture.lifetime = .keepAlways; add(capture)
  }

  /// Before running locally, copy the verified catalog's Douay archive into the disposable
  /// simulator's Application Support/Prosary/Bibles/<edition>/<revision>.zip. Store tests
  /// validate all archive/install paths; this test never needs a public network or real account.
  @MainActor func testDownloadedBibleChapterVerseBackAndRemoval() throws {
    let app = launch()
    app.segmentedControls["readings.mode"].buttons["Bible"].tap()
    let genesis = app.buttons["bible.book.GEN"]
    XCTAssertTrue(genesis.waitForExistence(timeout: 10))
    try XCTSkipUnless(genesis.isEnabled, "Offline navigation requires the verified local archive in the disposable simulator.")
    genesis.tap()
    app.buttons["bible.chapter.1"].tap()
    XCTAssertTrue(app.staticTexts["readings.chapter.1"].waitForExistence(timeout: 5))
    app.buttons["bible.nextChapter"].tap()
    XCTAssertTrue(app.staticTexts["readings.chapter.2"].waitForExistence(timeout: 5))
    app.buttons["bible.verseMenu"].tap()
    app.buttons["3"].tap()
    XCTAssertTrue(app.otherElements["bible.verse.3"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "seventh day")).firstMatch.exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-offline-chapter-reader"; capture.lifetime = .keepAlways; add(capture)
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.buttons["bible.chapter.1"].waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let remove = app.buttons["bible.remove"]
    XCTAssertTrue(remove.waitForExistence(timeout: 5))
    remove.tap()
    app.sheets.buttons["Remove Download"].tap()
    XCTAssertTrue(app.buttons["bible.download"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["bible.book.GEN"].isEnabled)
  }

  @MainActor func testPartialBibleChapterKeepsItsPairedScripts() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-readingsEditionId", "peshitta-1905", "-aramaicDefaultScript", "Hebr"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Readings"].waitForExistence(timeout: 10))
    app.tabBars.buttons["Readings"].tap()
    app.segmentedControls["readings.mode"].buttons["Bible"].tap()
    let genesis = app.buttons["bible.book.GEN"]
    XCTAssertTrue(genesis.waitForExistence(timeout: 10))
    try XCTSkipUnless(genesis.isEnabled, "Requires the verified Peshitta archive in the disposable simulator.")
    genesis.tap()
    app.buttons["bible.chapter.1"].tap()
    XCTAssertTrue(app.staticTexts["bible.partial"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["readings.chapter.1"].label, "קפלאון א׳")
    app.buttons["bible.scriptPicker.Syrc"].tap()
    XCTAssertEqual(app.staticTexts["readings.chapter.1"].label, "ܩܦܠܐܘܢ ܐ")
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-partial-peshitta-syriac"; capture.lifetime = .keepAlways; add(capture)
  }
}
#endif
