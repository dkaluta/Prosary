#if os(iOS)
import XCTest

final class BibleUITests: XCTestCase {
  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-readingsEditionId", "douay-rheims-1899", "-homeWidgetOrder", "scripture\\ncalendar\\nreadings",
                           "-homeWidgetLayoutVersion", "1", "-homeWidgetCollapsedIds", "scripture\\ncalendar\\nreadings",
                           "-expandReadingsByDefault", "NO"]
    app.launch()
    selectSection("Readings", in: app)
    return app
  }

  @MainActor private func selectSection(_ title: String, in app: XCUIApplication) {
    let button = app.buttons[title].firstMatch
    if button.waitForExistence(timeout: 10) { button.tap() }
    else {
      let row = app.cells[title].firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      row.tap()
    }
  }

  @MainActor private func openHomeBible(_ app: XCUIApplication) {
    selectSection("Home", in: app)
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    for _ in 0..<4 where !open.isHittable { app.swipeUp() }
    open.tap()
    XCTAssertTrue(app.buttons["bible.book.GEN"].waitForExistence(timeout: 10))
  }

  @MainActor func testHomeBiblePreservesDailyDateAndReadingsHasNoReferenceModes() throws {
    let app = launch()
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    let previous = app.buttons["readings.previousDay"]
    XCTAssertTrue(previous.waitForExistence(timeout: 5))
    previous.tap()
    let date = app.buttons["readings.chooseDate"].label
    XCTAssertFalse(app.segmentedControls["readings.mode"].exists)
    XCTAssertFalse(app.buttons["calendar.list"].exists)
    openHomeBible(app)
    XCTAssertTrue(app.navigationBars["Bible"].staticTexts["Bible"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.segmentedControls["readings.mode"].exists)
    XCTAssertFalse(app.buttons["bible.scriptureDate"].exists)
    XCTAssertFalse(app.buttons["readings.chooseDate"].exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-edition-and-books"; capture.lifetime = .keepAlways; add(capture)
    app.buttons["homeReference.done"].tap()
    selectSection("Readings", in: app)
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["readings.chooseDate"].label, date)
    let dailyCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    dailyCapture.name = "daily-readings-restored-title"; dailyCapture.lifetime = .keepAlways; add(dailyCapture)
  }

  @MainActor func testCalendarOpensFromHomeOutsideReadings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-homeWidgetOrder", "calendar", "-homeWidgetLayoutVersion", "1", "-homeWidgetCollapsedIds", "calendar"]
    app.launch()
    selectSection("Home", in: app)
    let calendar = app.buttons["homeWidgets.open.calendar"]
    for _ in 0..<6 where !calendar.isHittable { app.swipeUp() }
    XCTAssertTrue(calendar.waitForExistence(timeout: 5), app.debugDescription)
    calendar.tap()
    XCTAssertTrue(app.navigationBars["Event Calendar"].waitForExistence(timeout: 5))
    app.buttons["homeReference.done"].tap()
    selectSection("Readings", in: app)
    XCTAssertTrue(app.navigationBars["Readings"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["calendar.list"].exists)
  }

  /// Before running locally, copy the verified catalog's Douay archive into the disposable
  /// simulator's Application Support/Prosary/Bibles/<edition>/<revision>.zip. Store tests
  /// validate all archive/install paths; this test never needs a public network or real account.
  @MainActor func testDownloadedBibleChapterVerseBackAndRemoval() throws {
    let app = launch()
    openHomeBible(app)
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
                           "-readingsEditionId", "peshitta-1905", "-aramaicDefaultScript", "Hebr",
                           "-homeWidgetOrder", "scripture"]
    app.launch()
    openHomeBible(app)
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
