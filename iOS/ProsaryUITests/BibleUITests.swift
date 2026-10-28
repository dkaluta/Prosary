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
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      app.otherElements["bible.bookReader"].exists || app.buttons["bible.download"].exists
        || app.buttons["bible.bookMenu"].exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 20), .completed)
  }

  @MainActor private func openDailyReadings(_ app: XCUIApplication) {
    selectSection("Home", in: app)
    let open = app.buttons["homeWidgets.open.readings"]
    XCTAssertTrue(open.waitForExistence(timeout: 5))
    for _ in 0..<4 where !open.isHittable { app.swipeUp() }
    open.tap()
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 5))
    let done = app.buttons["homeReference.done"]
    let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: done)
    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
  }

  @MainActor func testReadingsSheetPreservesDailyDateAcrossTheBibleTab() throws {
    let app = launch()
    openDailyReadings(app)
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    let previous = app.buttons["readings.previousDay"]
    XCTAssertTrue(previous.waitForExistence(timeout: 5))
    let before = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    before.name = "daily-readings-presented"; before.lifetime = .keepAlways; add(before)
    previous.tap()
    let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    after.name = "daily-readings-previous-day"; after.lifetime = .keepAlways; add(after)
    let date = app.buttons["readings.chooseDate"].label
    XCTAssertFalse(app.segmentedControls["readings.mode"].exists)
    XCTAssertFalse(app.buttons["calendar.list"].exists)
    app.buttons["homeReference.done"].tap()
    openHomeBible(app)
    XCTAssertTrue(app.buttons["bible.bookMenu"].exists || app.navigationBars["Bible"].exists)
    XCTAssertFalse(app.segmentedControls["readings.mode"].exists)
    XCTAssertFalse(app.buttons["bible.scriptureDate"].exists)
    XCTAssertFalse(app.buttons["readings.chooseDate"].exists)
    XCTAssertFalse(app.buttons["homeReference.done"].exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-edition-and-books"; capture.lifetime = .keepAlways; add(capture)
    openDailyReadings(app)
    XCTAssertTrue(app.navigationBars["Readings"].staticTexts["Readings"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.buttons["readings.chooseDate"].label, date)
    let dailyCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    dailyCapture.name = "daily-readings-restored-title"; dailyCapture.lifetime = .keepAlways; add(dailyCapture)
  }

  @MainActor func testCalendarEventReplacesItsSheetWithReadingsForTheSelectedDate() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-homeWidgetOrder", "calendar", "-homeWidgetLayoutVersion", "1", "-homeWidgetCollapsedIds", "calendar",
      "-calendarViewMode", "list", "-feastCalendarId", "roman"]
    app.launch()
    selectSection("Home", in: app)
    let calendar = app.buttons["homeWidgets.open.calendar"]
    for _ in 0..<6 where !calendar.isHittable { app.swipeUp() }
    XCTAssertTrue(calendar.waitForExistence(timeout: 5), app.debugDescription)
    calendar.tap()
    XCTAssertTrue(app.navigationBars["Event Calendar"].waitForExistence(timeout: 5))
    let events = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'calendar.listEvent.'"))
    XCTAssertTrue(events.firstMatch.waitForExistence(timeout: 5))
    let event = events.allElementsBoundByIndex.first { $0.isHittable } ?? events.firstMatch
    event.tap()
    let selectedDate = app.staticTexts["calendar.eventDate"]
    XCTAssertTrue(selectedDate.waitForExistence(timeout: 5))
    let date = selectedDate.label
    let readings = app.buttons["calendar.openReadings"]
    for _ in 0..<6 where !readings.isHittable { app.swipeUp() }
    XCTAssertTrue(readings.isHittable)
    readings.tap()
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 5))
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US")
    dateFormatter.dateStyle = .long
    let eventDay = try XCTUnwrap(dateFormatter.date(from: date))
    dateFormatter.dateStyle = .medium
    let readingsDay = try XCTUnwrap(dateFormatter.date(from: app.buttons["readings.chooseDate"].label))
    XCTAssertTrue(Calendar(identifier: .gregorian).isDate(eventDay, inSameDayAs: readingsDay))
    XCTAssertFalse(app.navigationBars["Event Details"].exists)
    app.buttons["homeReference.done"].tap()
    XCTAssertTrue(calendar.waitForExistence(timeout: 5), "One Done returns to Home")
  }

  @MainActor func testHolyScriptureShortcutSelectsTheFullWindowBibleTab() throws {
    let app = launch()
    openHomeBible(app)
    let bible = app.navigationBars.firstMatch
    let window = app.windows.firstMatch
    XCTAssertGreaterThan(bible.frame.width, window.frame.width * 0.9,
      "Holy Scripture must use the full window, including on iPad")
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-full-window"; capture.lifetime = .keepAlways; add(capture)
    XCTAssertFalse(app.buttons["homeReference.done"].exists)
    selectSection("Home", in: app)
    XCTAssertTrue(app.buttons["homeWidgets.open.scripture"].waitForExistence(timeout: 5))
    selectSection("Bible", in: app)
    XCTAssertTrue(app.buttons["bible.bookMenu"].exists || app.buttons["bible.download"].exists)
  }

  @MainActor func testCalendarWeekdayHeadersFollowSystemRegion() throws {
    for (region, first, last) in [("en_US", "Sunday", "Saturday"), ("en_GB", "Monday", "Sunday")] {
      let app = XCUIApplication()
      app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-AppleLocale", region,
        "-interfaceLanguageCode", "en", "-homeWidgetOrder", "calendar", "-homeWidgetLayoutVersion", "1",
        "-homeWidgetCollapsedIds", ""]
      app.launch()
      selectSection("Home", in: app)
      let grid = app.descendants(matching: .any).matching(identifier: "calendar.monthPicker").firstMatch
      XCTAssertTrue(grid.waitForExistence(timeout: 10))
      let firstDay = grid.staticTexts[first], lastDay = grid.staticTexts[last]
      XCTAssertTrue(firstDay.exists && lastDay.exists)
      XCTAssertLessThan(firstDay.frame.minX, lastDay.frame.minX, "Calendar week follows \(region), independently of English UI")
      app.terminate()
    }
  }

  /// Before running locally, copy the verified catalog's Douay archive into the disposable
  /// simulator's Application Support/Prosary/Bibles/<edition>/<revision>.zip. Store tests
  /// validate all archive/install paths; this test never needs a public network or real account.
  @MainActor func testDownloadedBibleChapterVerseBackAndRemoval() throws {
    let app = launch()
    openHomeBible(app)
    try XCTSkipUnless(app.buttons["bible.bookMenu"].exists,
      "Offline navigation requires the verified local archive in the disposable simulator.")
    XCTAssertTrue(app.buttons["bible.chapterMenu"].label.contains("1"))
    app.buttons["bible.nextChapter"].tap()
    XCTAssertTrue(app.buttons["bible.chapterMenu"].label.contains("2"))
    app.buttons["bible.verseMenu"].tap()
    app.buttons["3"].tap()
    XCTAssertTrue(app.webViews.firstMatch.exists)
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-offline-chapter-reader"; capture.lifetime = .keepAlways; add(capture)
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
    try XCTSkipUnless(app.buttons["bible.bookMenu"].exists,
      "Requires the verified Peshitta archive in the disposable simulator.")
    XCTAssertTrue(app.buttons["bible.chapterMenu"].label.contains("קפלאון א׳"))
    app.buttons["bible.scriptPicker.Syrc"].tap()
    XCTAssertTrue(app.buttons["bible.chapterMenu"].label.contains("ܩܦܠܐܘܢ ܐ"))
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "bible-partial-peshitta-syriac"; capture.lifetime = .keepAlways; add(capture)
  }
}
#endif
