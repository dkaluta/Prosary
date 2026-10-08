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
    #if os(iOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
    continueAfterFailure = false
  }

  @MainActor
  private func openPrayTab(in app: XCUIApplication, title: String = "Pray") {
    #if !os(macOS)
    let tab = app.tabBars.buttons[title]
    if tab.waitForExistence(timeout: 5) {
      tab.tap()
    } else {
      let button = app.buttons[title].firstMatch
      if button.exists { button.tap() }
      else { app.cells[title].firstMatch.tap() }
    }
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10), "Pray contains the prayer library")
    #endif
  }

  @MainActor
  func testEveryTabOpensItsScreen() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", ""]
    app.launch()

    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10), "Pray lists the seeded favorite")

    // Full reading citations have their own tab; category browsing remains in Search.
    app.tabBars.buttons["Readings"].tap()
    XCTAssertTrue(app.navigationBars["Readings"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 5), app.debugDescription)

    app.tabBars.buttons["Search"].tap()
    XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["search.local.rosary"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.staticTexts["From the Community"].exists, "Browse owns installable prayers")
    XCTAssertFalse(app.buttons["Install"].exists)

    // Browse reaches the network; assert the screen, never the catalogue's contents.
    app.tabBars.buttons["Browse"].tap()
    XCTAssertTrue(app.navigationBars["Community Devotions"].waitForExistence(timeout: 5))

    app.tabBars.buttons["Pray"].tap()
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testUkrainianInterfaceLocalizesNavigationTodayAndSettings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-AppleLanguages", "(uk)", "-interfaceLanguageCode", "", "-AppleLocale", "uk_UA",
                           "-defaultLanguageCode", "uk", "-basicPrayersLanguageCode", "",
                           "-showPrayerNameInPrayerLanguage", "NO"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["Молитва"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.tabBars.buttons["Читання"].exists)
    XCTAssertTrue(app.tabBars.buttons["Пошук"].exists)
    XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "homeWidgets.date").firstMatch.exists)
    app.tabBars.buttons["Молитва"].tap()
    XCTAssertFalse(app.buttons["todayYesterdayButton"].exists)
    XCTAssertFalse(app.buttons["todayTomorrowButton"].exists)
    let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    home.name = "ukrainian-pray-without-today"
    home.lifetime = .keepAlways
    add(home)
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.navigationBars["Налаштування"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.switches["useJaffaHailMaryWording"].exists)
    let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    settings.name = "ukrainian-settings"
    settings.lifetime = .keepAlways
    add(settings)
    app.buttons["Готово"].tap()
    app.buttons["basicPrayersRow"].tap()
    let ourFather = app.buttons["basicPrayer-ourFather"]
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    XCTAssertTrue(ourFather.label.contains("Отче наш"))
    ourFather.tap()
    XCTAssertEqual(app.staticTexts["prayerFlowTitle"].label, "Отче наш")
    XCTAssertTrue(app.staticTexts["prayerBodyText"].label.contains("нехай святиться Ім’я Твоє"))
    let prayer = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    prayer.name = "ukrainian-sourced-basic-prayer"
    prayer.lifetime = .keepAlways
    add(prayer)
    app.terminate()
  }

  #if !os(macOS)
  @MainActor
  func testRetiredWordingPreferenceHasNoToggleAndPreservesTheSourcedPrayer() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-defaultLanguageCode", "arc", "-basicPrayersLanguageCode", "he",
                           "-useJaffaHailMaryWording", "YES", "-autoAdvanceSeconds", "0"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.switches["useJaffaHailMaryWording"].exists)
    app.buttons["Done"].tap()
    let basic = app.buttons["basicPrayersRow"]
    XCTAssertTrue(basic.waitForExistence(timeout: 5))
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    let hailMary = app.buttons["basicPrayer-hailMary"]
    XCTAssertTrue(hailMary.waitForExistence(timeout: 5))
    hailMary.tap()
    let body = app.staticTexts["prayerBodyText"]
    XCTAssertTrue(body.waitForExistence(timeout: 5))
    XCTAssertTrue(body.label.contains("מְלֵאַת הַחֶסֶד"))
    XCTAssertFalse(body.label.contains("בְּרוּכַת הַחֶסֶד"))
    app.terminate()
  }

  #if os(iOS)
  @MainActor
  func testPrayHasNoTodayViewAndReadingsRetainsItsBrowsedDate() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-readingsReminderEnabled", "NO"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["todayDateButton"].exists)
    XCTAssertFalse(app.otherElements["todaySection"].exists)
    openReadingsTab(in: app, title: "Readings")
    let initialDate = app.buttons["readings.chooseDate"].label
    app.buttons["readings.previousDay"].tap()
    let browsedDate = app.buttons["readings.chooseDate"].label
    XCTAssertNotEqual(browsedDate, initialDate)
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["todayDateButton"].exists)
    XCTAssertFalse(app.otherElements["todaySection"].exists)
    openReadingsTab(in: app, title: "Readings")
    XCTAssertEqual(app.buttons["readings.chooseDate"].label, browsedDate)
    app.buttons["readings.options"].tap()
    XCTAssertTrue(app.switches["readingsReminderEnabled"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.switches["readingsReminderEnabled"].value as? String, "0", "Opening Readings Settings does not enable a reminder")
    XCTAssertFalse(app.switches["saintReminderEnabled"].exists)
    XCTAssertTrue(app.switches["reverseReadingsOrderToggle"].exists)
    app.terminate()
  }

  @MainActor
  func testChapterHeadingsUseTheBibleLanguageEvenWhenTheInterfaceDiffers() throws {
    let app = XCUIApplication()
    for (interface, edition, tabTitle, pattern, name) in [
      ("en", "masoretic-delitzsch", "Readings", "פרק [א-ת׳״]+", "english-interface-hebrew-bible"),
      ("he", "douay-rheims-1899", "מקראות", "Chapter [0-9]+", "hebrew-interface-english-bible"),
    ] {
      app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(\(interface))",
                             "-interfaceLanguageCode", interface, "-defaultLanguageCode", "fr",
                             "-feastCalendarId", "roman", "-showTodayFeast", "NO",
                             "-expandReadingsByDefault", "YES", "-readingsEditionId", edition]
      app.launch()
      openReadingsTab(in: app, title: tabTitle)
      let heading = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", pattern)).firstMatch
      XCTAssertTrue(heading.waitForExistence(timeout: 15), app.debugDescription)
      XCTAssertTrue(NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: heading.label), heading.label)
      let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      screenshot.name = name
      screenshot.lifetime = .keepAlways
      add(screenshot)
      app.terminate()
    }
  }

  @MainActor
  private func moveReadingsDate(in app: XCUIApplication, to targetDate: String) throws {
    let date = app.buttons["readings.chooseDate"]
    let iso = DateFormatter()
    iso.locale = Locale(identifier: "en_US_POSIX")
    iso.dateFormat = "yyyy-MM-dd"
    let display = DateFormatter()
    display.locale = Locale(identifier: "en_US")
    display.dateStyle = .medium
    let target = try XCTUnwrap(iso.date(from: targetDate))
    let shown = try XCTUnwrap(display.date(from: date.label), date.label)
    let distance = try XCTUnwrap(Calendar(identifier: .gregorian).dateComponents([.day], from: shown, to: target).day)
    XCTAssertLessThanOrEqual(abs(distance), 366, "The sourced calendar fixture remains within one year")
    for _ in 0..<abs(distance) { app.buttons[distance < 0 ? "readings.previousDay" : "readings.nextDay"].tap() }
    XCTAssertEqual(date.label, display.string(from: target))
  }

  @MainActor
  func testGreekBibleCanBeChosenFromTheEditionMenu() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-feastCalendarId", "roman", "-showTodayFeast", "NO", "-expandReadingsByDefault", "YES"]
    app.launch()
    openReadingsTab(in: app, title: "Readings")
    try moveReadingsDate(in: app, to: "2026-09-27")
    let picker = app.buttons["readings.editionPicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    picker.tap()
    let option = app.buttons["Septuagint — Ἑβδομήκοντα (Brenton)"]
    XCTAssertTrue(option.waitForExistence(timeout: 5), app.debugDescription)
    option.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "Κεφάλαιο [0-9]+")).firstMatch.waitForExistence(timeout: 10))
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "greek-bible-selected-from-menu"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.terminate()
  }

  /// Seed the verified Peshitta archive in this disposable simulator before running.
  @MainActor
  func testDownloadedPeshittaJobDailyReadingUsesTheBibleLibrary() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-feastCalendarId", "lpj", "-showTodayFeast", "YES", "-expandReadingsByDefault", "YES",
                           "-readingsEditionId", "peshitta-1905", "-aramaicDefaultScript", "Hebr"]
    app.launch()
    openReadingsTab(in: app, title: "Readings")
    app.segmentedControls["readings.mode"].buttons["Bible"].tap()
    XCTAssertTrue(app.buttons["bible.remove"].waitForExistence(timeout: 10),
                  "The final verified Peshitta archive is installed in this disposable simulator")
    app.segmentedControls["readings.mode"].buttons["Daily Readings"].tap()
    try moveReadingsDate(in: app, to: "2026-10-03")
    XCTAssertTrue(app.staticTexts["וַענָא אִיוּב וְאמַר למָריָא."].waitForExistence(timeout: 15),
                  "The first appointed verse uses the source's Hebrew-script projection")
    let picker = app.segmentedControls.containing(.button, identifier: "Syriac Script").firstMatch
    let scroll = app.scrollViews.firstMatch
    for _ in 0..<3 where !picker.isHittable {
      scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
        .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
    }
    picker.buttons["Syriac Script"].tap()
    XCTAssertTrue(app.staticTexts["ܘܰܥ̣ܢܳܐ ܐܺܝܽܘܒ ܘܶܐܡܰܪ ܠܡܳܪܝܳܐ."].waitForExistence(timeout: 5))
    let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    capture.name = "peshitta-daily-job-october-3-syriac"; capture.lifetime = .keepAlways; add(capture)
    app.terminate()
  }

  @MainActor
  func testGreekAndArabicHeadingsUseAvailableSourcedReadings() throws {
    let app = XCUIApplication()
    for (edition, targetDate, headingText, name) in [
      ("brenton-lxx", "2026-09-27", "Κεφάλαιο 18", "greek-bible-chapter-heading"),
      ("jesuit-arabic-1897", "2026-09-15", "الفصل ١٩", "arabic-bible-chapter-heading"),
    ] {
      app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                             "-feastCalendarId", "roman", "-showTodayFeast", "NO",
                             "-expandReadingsByDefault", "YES", "-readingsEditionId", edition]
      app.launch()
      openReadingsTab(in: app, title: "Readings")
      try moveReadingsDate(in: app, to: targetDate)
      let heading = app.staticTexts[headingText].firstMatch
      XCTAssertTrue(heading.waitForExistence(timeout: 15), app.debugDescription)
      for _ in 0..<7 where !heading.isHittable { app.swipeUp() }
      XCTAssertTrue(heading.isHittable)
      let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      screenshot.name = name
      screenshot.lifetime = .keepAlways
      add(screenshot)
      app.terminate()
    }
  }

  @MainActor
  func testSyriacSaintDescriptionsStartClosedAndResetAfterBrowsing() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(he)", "-interfaceLanguageCode", "he",
                           "-feastCalendarId", "syriac", "-showTodayFeast", "YES",
                           "-expandReadingsByDefault", "NO"]
    app.launch()
    openReadingsTab(in: app, title: "מקראות")
    let disclosure = app.descendants(matching: .any)["today.saintDescriptions"].firstMatch
    // Coverage is source-dependent. Nearby saints can have prose when today's liturgical
    // observance does not, so browse through this week's actual supplied calendar entries.
    for _ in 0..<7 where !disclosure.waitForExistence(timeout: 1) {
      app.buttons["readings.nextDay"].tap()
    }
    XCTAssertTrue(disclosure.waitForExistence(timeout: 5), app.debugDescription)
    let description = app.staticTexts["today.saintDescription.0"]
    XCTAssertFalse(description.exists)
    disclosure.tap()
    XCTAssertTrue(description.waitForExistence(timeout: 5), app.debugDescription)
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "syriac-saint-description-hebrew"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["readings.nextDay"].tap()
    XCTAssertFalse(description.exists)
    app.buttons["readings.previousDay"].tap()
    XCTAssertTrue(disclosure.waitForExistence(timeout: 5))
    XCTAssertFalse(description.exists, "Returning to the same day leaves the prose closed")
    app.terminate()
  }

  @MainActor
  func testReadingsStartCollapsedAndTheSettingOpensChapterHeadings() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-feastCalendarId", "roman", "-expandReadingsByDefault", "NO", "-readingsEditionId", ""]
    app.launch()
    openReadingsTab(in: app, title: "Readings")
    let passage = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "readings.passage.daily.")).firstMatch
    XCTAssertTrue(passage.waitForExistence(timeout: 10))
    let chapter = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "Chapter [0-9]+")).firstMatch
    XCTAssertFalse(chapter.exists)
    // Launch-argument defaults take precedence over persisted values. Remove that override
    // before exercising a live Settings change, so the test does not lock the preference.
    app.terminate()
    app.launchArguments.removeLast(4)
    app.launch()
    openReadingsTab(in: app, title: "Readings")
    app.buttons["readings.options"].tap()
    let toggle = app.switches["expandReadingsByDefaultToggle"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 5))
    if (toggle.value as? String) != "1" {
      toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }
    XCTAssertEqual(toggle.value as? String, "1")
    app.buttons["Done"].tap()
    XCTAssertTrue(chapter.waitForExistence(timeout: 10), app.debugDescription)
    XCTAssertTrue(chapter.label.hasPrefix("Chapter "))
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+")).firstMatch.exists)
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "[0-9]+:[0-9]+")).firstMatch.exists)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "readings-chapters-and-verse-numbers"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
  }
  #endif

  @MainActor
  func testBasicPrayerNamesOfferBilingualDisplayWithoutChangingPrayerLanguage() throws {
    for (language, expectedTitle) in [("arc", "צלותא מרניתא"), ("he-x-gamliel", "תפילת האדון")] {
      for enabled in [false, true] {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-defaultLanguageCode", language,
                               "-basicPrayersLanguageCode", "", "-aramaicDefaultScript", "Hebr",
                               "-showPrayerNameInPrayerLanguage", enabled ? "YES" : "NO"]
        app.launch()
        openPrayTab(in: app)
        XCTAssertTrue(app.buttons["basicPrayersRow"].waitForExistence(timeout: 10))
        app.buttons["basicPrayersRow"].tap()
        let prayer = app.buttons["basicPrayer-ourFather"]
        XCTAssertTrue(prayer.waitForExistence(timeout: 5))
        XCTAssertTrue(prayer.label.contains(expectedTitle))
        XCTAssertEqual(prayer.label.contains("Our Father"), enabled)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "basic-prayer-\(language)-\(enabled ? "bilingual" : "prayer")-names"
        attachment.lifetime = .keepAlways
        add(attachment)
        prayer.tap()
        let heading = app.staticTexts["prayerFlowTitle"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, expectedTitle, "The shelf preference does not change the prayed title")
        app.terminate()
      }
    }
  }

  #if !os(macOS)
  @MainActor
  func testDateChoosersKeepCalendarAndControlsWithinBounds() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en"]
    app.launch()
    let readingsTab = app.buttons["Readings"].firstMatch
    if readingsTab.exists { readingsTab.tap() }
    else { app.cells["Readings"].firstMatch.tap() }
    let rows = [("readings.previousDay", "readings.chooseDate", "readings.nextDay", "readings.datePicker", "readings.dateDone")]
    for row in rows {
      let previous = app.buttons[row.0]
      let date = app.buttons[row.1]
      let next = app.buttons[row.2]
      XCTAssertTrue(date.waitForExistence(timeout: 10))
      let controls = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      controls.name = row.1 + "-unobscured-controls"
      controls.lifetime = .keepAlways
      add(controls)
      XCTAssertEqual(previous.frame.height, date.frame.height, accuracy: 1, "Previous and date buttons have equal visible height")
      XCTAssertEqual(next.frame.height, date.frame.height, accuracy: 1, "Next and date buttons have equal visible height")
      #if os(visionOS)
      XCTAssertGreaterThanOrEqual(date.frame.height, 60, "Spatial date controls retain native gaze targets")
      XCTAssertGreaterThanOrEqual(previous.frame.width, 60)
      XCTAssertGreaterThanOrEqual(next.frame.width, 60)
      #else
      // Native toolbar accessibility frames describe the system's visible platter, which
      // can be smaller than its touch target. Check reachability and bounds below instead.
      #endif
      #if os(iOS)
      checkReadingsToolbar(in: app, rightToLeft: false, screenshotName: "readings-toolbar-en")
      #endif
      let originalDate = date.label
      date.tap()
      let picker = app.datePickers[row.3]
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      let popover = app.descendants(matching: .any)[row.3 + ".popover"].firstMatch
      XCTAssertTrue(popover.exists)
      let calendar = picker.collectionViews.firstMatch
      XCTAssertTrue(calendar.waitForExistence(timeout: 5))
      XCTAssertGreaterThanOrEqual(calendar.frame.minX, popover.frame.minX - 1)
      XCTAssertLessThanOrEqual(calendar.frame.maxX, popover.frame.maxX + 1, "All seven calendar columns fit in the popover")
      let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      screenshot.name = row.3 + "-full-calendar"
      screenshot.lifetime = .keepAlways
      add(screenshot)
      app.buttons[row.4].tap()
      XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
      XCTAssertEqual(date.label, originalDate, "Done dismisses without changing the selected date")
    }
  }
  #endif

  #if os(iOS)
  @MainActor
  func testDateChoosersKeepCalendarAndControlsWithinBoundsInLandscape() throws {
    XCUIDevice.shared.orientation = .landscapeLeft
    try testDateChoosersKeepCalendarAndControlsWithinBounds()
  }

  @MainActor
  func testReadingsToolbarKeepsDateNavigationAndSettingsReachable() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en"]
    app.launch()
    openReadingsTab(in: app, title: "Readings")
    checkReadingsToolbar(in: app, rightToLeft: false, screenshotName: "readings-toolbar-en")
    checkReadingsDatePopover(in: app, screenshotName: "readings-calendar-en")
    app.terminate()
  }

  @MainActor
  func testReadingsToolbarKeepsDateNavigationAndSettingsReachableInLandscape() throws {
    XCUIDevice.shared.orientation = .landscapeLeft
    try testReadingsToolbarKeepsDateNavigationAndSettingsReachable()
  }

  @MainActor
  func testRTLReadingsToolbarKeepsDateNavigationAndSettingsReachable() throws {
    for (language, title) in [("he", "מקראות"), ("ar", "القراءات")] {
      let app = XCUIApplication()
      app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(\(language))",
                             "-interfaceLanguageCode", language]
      app.launch()
      openReadingsTab(in: app, title: title)
      checkReadingsToolbar(in: app, rightToLeft: true, screenshotName: "readings-toolbar-\(language)")
      checkReadingsDatePopover(in: app, screenshotName: "readings-calendar-\(language)")
      app.terminate()
    }
  }

  @MainActor
  private func openReadingsTab(in app: XCUIApplication, title: String) {
    let tab = app.buttons[title].firstMatch
    if tab.exists {
      tab.tap()
    } else {
      app.cells[title].firstMatch.tap()
    }
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 10))
  }

  @MainActor
  private func checkReadingsToolbar(in app: XCUIApplication, rightToLeft: Bool, screenshotName: String) {
    let identifiers = ["readings.previousDay", "readings.chooseDate", "readings.nextDay", "readings.options"]
    let previous = app.buttons[identifiers[0]]
    let date = app.buttons[identifiers[1]]
    let next = app.buttons[identifiers[2]]

    func checkLayout() {
      let bounds = app.frame
      let controls = identifiers.map { app.buttons[$0] }
      for (identifier, control) in zip(identifiers, controls) {
        XCTAssertEqual(app.buttons.matching(identifier: identifier).count, 1, "A toolbar action appears only once")
        XCTAssertTrue(control.isHittable, "\(identifier) stays reachable in the native toolbar")
        XCTAssertGreaterThanOrEqual(control.frame.minX, bounds.minX - 1)
        XCTAssertLessThanOrEqual(control.frame.maxX, bounds.maxX + 1)
        XCTAssertGreaterThanOrEqual(control.frame.minY, bounds.minY - 1)
        XCTAssertLessThanOrEqual(control.frame.maxY, bounds.maxY + 1)
      }
      for first in controls.indices {
        for second in controls.indices where second > first {
          let overlap = controls[first].frame.intersection(controls[second].frame)
          XCTAssertFalse(overlap.width > 1 && overlap.height > 1, "Native toolbar controls do not overlap")
        }
      }
      if rightToLeft {
        XCTAssertGreaterThan(previous.frame.midX, date.frame.midX)
        XCTAssertLessThan(next.frame.midX, date.frame.midX)
      } else {
        XCTAssertLessThan(previous.frame.midX, date.frame.midX)
        XCTAssertGreaterThan(next.frame.midX, date.frame.midX)
      }
    }

    func capture(_ suffix: String) {
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = screenshotName + suffix
      attachment.lifetime = .keepAlways
      add(attachment)
    }

    capture("-before-scrolling")
    checkLayout()
    let originalDate = date.label
    func waitForDate(matchesOriginal: Bool, message: String) {
      let predicate = NSPredicate(format: matchesOriginal ? "label == %@" : "label != %@", originalDate)
      let expectation = XCTNSPredicateExpectation(predicate: predicate, object: date)
      XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, message)
    }
    previous.tap()
    waitForDate(matchesOriginal: false, message: "Previous changes the selected reading date")
    next.tap()
    waitForDate(matchesOriginal: true, message: "Next returns to the original reading date")
    next.tap()
    waitForDate(matchesOriginal: false, message: "Next changes the selected reading date")
    previous.tap()
    waitForDate(matchesOriginal: true, message: "Previous returns to the original reading date")

    let readings = app.scrollViews.firstMatch
    XCTAssertTrue(readings.exists)
    readings.swipeUp()
    capture("-after-scrolling")
    checkLayout()
  }

  @MainActor
  private func checkReadingsDatePopover(in app: XCUIApplication, screenshotName: String) {
    let date = app.buttons["readings.chooseDate"]
    let originalDate = date.label
    date.tap()
    let picker = app.datePickers["readings.datePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5))
    let popover = app.descendants(matching: .any)["readings.datePicker.popover"].firstMatch
    XCTAssertTrue(popover.exists)
    let calendar = picker.collectionViews.firstMatch
    XCTAssertTrue(calendar.waitForExistence(timeout: 5))
    XCTAssertGreaterThanOrEqual(calendar.frame.minX, popover.frame.minX - 1)
    XCTAssertLessThanOrEqual(calendar.frame.maxX, popover.frame.maxX + 1, "All seven calendar columns fit in the popover")
    let done = app.buttons["readings.dateDone"]
    XCTAssertTrue(done.isHittable, "Done stays reachable in portrait and landscape")
    XCTAssertGreaterThanOrEqual(done.frame.minY, app.frame.minY - 1)
    XCTAssertLessThanOrEqual(done.frame.maxY, app.frame.maxY + 1)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = screenshotName
    attachment.lifetime = .keepAlways
    add(attachment)
    done.tap()
    XCTAssertTrue(picker.waitForNonExistence(timeout: 5))
    XCTAssertEqual(date.label, originalDate, "Done dismisses without changing the selected date")
  }
  #endif

  @MainActor
  func testTodayDateNavigationAndNativePicker() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en", "-showTodayTorahPortion", "YES"]
    app.launch()
    let readingsTab = app.buttons["Readings"].firstMatch
    if readingsTab.exists { readingsTab.tap() }
    else { app.cells["Readings"].firstMatch.tap() }
    let yesterday = app.buttons["readings.previousDay"]
    let tomorrow = app.buttons["readings.nextDay"]
    let dateButton = app.buttons["readings.chooseDate"]
    XCTAssertTrue(yesterday.waitForExistence(timeout: 10))
    let originalDate = dateButton.label
    yesterday.tap()
    XCTAssertNotEqual(dateButton.label, originalDate)
    tomorrow.tap()
    XCTAssertEqual(dateButton.label, originalDate)
    tomorrow.tap()
    XCTAssertNotEqual(dateButton.label, originalDate)
    dateButton.tap()
    let today = app.buttons["readings.reset"]
    XCTAssertTrue(today.waitForExistence(timeout: 5))
    XCTAssertTrue(today.isEnabled)
    today.tap()
    XCTAssertEqual(dateButton.label, originalDate)
    XCTAssertFalse(today.exists, "The reset belongs inside the date popover")
    let controls = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    controls.name = "readings-date-controls"
    controls.lifetime = .keepAlways
    add(controls)
    dateButton.tap()
    let picker = app.datePickers["readings.datePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5), "The popover contains a system DatePicker")
    XCTAssertFalse(today.isEnabled)
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "The native calendar opens")
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "readings-native-date-picker"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testRosaryTitleHasItsOwnLineAbovePhoneControls() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Dark",
                           "-defaultLanguageCode", "he"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    app.buttons["rosaryCard"].tap()
    let preset = app.buttons["prayDefaultPreset"].firstMatch
    XCTAssertTrue(preset.waitForExistence(timeout: 10))
    preset.tap()
    let title = app.staticTexts["prayerFlowTitle"]
    XCTAssertTrue(title.waitForExistence(timeout: 10))
    XCTAssertEqual(title.label, "Praying the Rosary")
    let language = app.buttons["languageMenu"]
    XCTAssertTrue(language.isHittable)
    XCTAssertGreaterThanOrEqual(language.frame.minY, title.frame.maxY)
    XCTAssertTrue(app.buttons["autoAdvanceMenu"].isHittable)
    XCTAssertTrue(app.buttons["nextMysteryButton"].isHittable)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "rosary-phone-title-and-controls"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testRTLPrayerControlsAndTodayFollowInterfaceLanguage() throws {
    for (language, prayTitle, readingsTitle, heading) in [("he", "תפילה", "מקראות", "המקראות"), ("ar", "صلّ", "القراءات", "القراءات")] {
      let app = XCUIApplication()
      app.launchArguments = ["-resetStore", "-AppleLanguages", "(\(language))", "-interfaceLanguageCode", "",
                             "-defaultLanguageCode", "en", "-todayLanguageCode", "it",
                             "-autoAdvanceSeconds", "0"]
      app.launch()
      let readingsTab = app.buttons[readingsTitle].firstMatch
      if readingsTab.exists { readingsTab.tap() }
      else { app.cells[readingsTitle].firstMatch.tap() }
      XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 10))
      XCTAssertFalse(app.buttons["todayLanguagePicker"].exists)
      XCTAssertTrue(app.staticTexts[heading].exists, "Readings follows the interface despite an old Italian override")
      XCTAssertLessThan(app.buttons["readings.nextDay"].frame.midX, app.buttons["readings.previousDay"].frame.midX)
      openPrayTab(in: app, title: prayTitle)
      XCTAssertFalse(app.buttons["todayDateButton"].exists)
      app.buttons["rosaryCard"].tap()
      let preset = app.buttons["prayDefaultPreset"].firstMatch
      XCTAssertTrue(preset.waitForExistence(timeout: 10))
      preset.tap()

      let body = app.staticTexts["prayerBodyText"]
      XCTAssertTrue(body.waitForExistence(timeout: 10))
      let firstBody = body.label
      let back = app.buttons["prayerFlowBackButton"]
      let next = app.buttons["prayerFlowNextButton"]
      let previousSection = app.buttons["previousMysteryButton"]
      let nextSection = app.buttons["nextMysteryButton"]
      XCTAssertLessThan(next.frame.midX, back.frame.midX)
      XCTAssertLessThan(nextSection.frame.midX, previousSection.frame.midX)
      XCTAssertFalse(back.isEnabled)
      XCTAssertFalse(previousSection.isEnabled)
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = "prayer-navigation-\(language)"
      attachment.lifetime = .keepAlways
      add(attachment)

      next.tap()
      XCTAssertTrue(back.isEnabled)
      XCTAssertNotEqual(body.label, firstBody)
      back.tap()
      XCTAssertEqual(body.label, firstBody)

      nextSection.tap()
      XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "label != %@", firstBody), object: body)], timeout: 5), .completed)
      let firstMystery = body.label
      nextSection.tap()
      XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "label != %@", firstMystery), object: body)], timeout: 5), .completed)
      previousSection.tap()
      XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "label == %@", firstMystery), object: body)], timeout: 5), .completed)
      app.terminate()
    }
  }

  @MainActor
  func testRosaryLitanyOptionKeepsHebrewAndFinishesWithoutAPopup() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-defaultLanguageCode", "he", "-autoAdvanceSeconds", "0"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["addFavoriteButton"].waitForExistence(timeout: 10))
    app.buttons["addFavoriteButton"].tap()
    app.buttons["Pray Any Rosary…"].tap()
    let litany = app.switches["litanyOfLoretoToggle"]
    for _ in 0..<7 where !litany.isHittable { app.swipeUp() }
    XCTAssertTrue(litany.waitForExistence(timeout: 5))
    let collect = app.switches["rosaryCollectToggle"]
    for _ in 0..<4 where !collect.isHittable || collect.frame.maxY > app.frame.maxY - 100 { app.swipeUp() }
    XCTAssertTrue(collect.isEnabled)
    collect.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "0"), object: collect)], timeout: 5), .completed, app.debugDescription)
    litany.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "1"), object: collect)], timeout: 5), .completed)
    XCTAssertFalse(collect.isEnabled)
    app.navigationBars.buttons["Pray"].tap()
    let nextSection = app.buttons["nextMysteryButton"]
    XCTAssertTrue(nextSection.waitForExistence(timeout: 10))
    for _ in 0..<6 where nextSection.isEnabled { nextSection.tap() }
    let next = app.buttons["prayerFlowNextButton"]
    let body = app.staticTexts["prayerBodyText"]
    for _ in 0..<20 where !body.label.contains("מָשִׁיחַ רַחֵם") { next.tap() }
    XCTAssertTrue(body.label.contains("מָשִׁיחַ רַחֵם"))
    XCTAssertFalse(app.alerts.firstMatch.exists)
    for _ in 0..<15 { next.tap() }
    XCTAssertTrue(app.staticTexts["נתפללה"].exists)
    XCTAssertFalse(body.label.contains("שִׂמְחָה בִּבְרִיאוּת"))
    let closing = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    closing.name = "hebrew-integrated-rosary-litany-collect"
    closing.lifetime = .keepAlways
    add(closing)
    next.tap()
    XCTAssertEqual(next.label, "Finish")
    next.tap()
    XCTAssertFalse(app.alerts.firstMatch.exists)
    XCTAssertTrue(app.buttons["addFavoriteButton"].waitForExistence(timeout: 5))
    app.tabBars.buttons["Search"].tap()
    let standalone = app.buttons["search.local.litanyOfLoreto"]
    for _ in 0..<5 where !standalone.isHittable { app.swipeUp() }
    XCTAssertTrue(standalone.waitForExistence(timeout: 5))
    standalone.tap()
    XCTAssertTrue(body.waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["variantMenu"].exists)
    for _ in 0..<15 { next.tap() }
    XCTAssertEqual(next.label, "Finish")
    XCTAssertTrue(body.label.contains("שִׂמְחָה בִּבְרִיאוּת"))
    next.tap()
    app.terminate()
  }

  @MainActor
  func testBasicPrayerTraditionAndHomePinStayConnected() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en",
                           "-showPrayerNameInPrayerLanguage", "YES"]
    app.launch()
    openPrayTab(in: app)
    let basic = app.buttons["basicPrayersRow"]
    XCTAssertTrue(basic.waitForExistence(timeout: 10))
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    app.buttons["languageMenu"].tap()
    XCTAssertFalse(app.buttons["basicPrayerLanguage-he-x-gamliel"].exists)
    app.buttons["basicPrayerLanguage-he"].tap()
    app.buttons["languageMenu"].tap()
    app.buttons["prayerTraditionMenu"].tap()
    app.buttons["Mission of St. Gamaliel"].tap()
    XCTAssertTrue(app.buttons["basicPrayer-holyGod"].label.contains("קדישת"))
    let pin = app.buttons["basicPrayerPin-holyGod"]
    if pin.label == "Remove from Pray" { pin.tap() }
    XCTAssertEqual(pin.label, "Pin to Pray")
    pin.tap()
    XCTAssertEqual(pin.label, "Remove from Pray")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let pinned = app.buttons["basic:holyGodCard"]
    XCTAssertTrue(pinned.waitForExistence(timeout: 5))
    XCTAssertTrue(pinned.label.contains("קדישת"))
    pinned.tap()
    XCTAssertTrue(app.staticTexts["prayerFlowTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["prayerFlowTitle"].label, "קדישת")
    app.buttons["prayerFlowNextButton"].tap()
    pinned.press(forDuration: 1)
    app.buttons["Remove from Pray"].tap()
    XCTAssertFalse(app.buttons["basic:holyGodCard"].exists)
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    XCTAssertTrue(app.buttons["basicPrayer-holyGod"].exists)
    XCTAssertEqual(app.buttons["basicPrayerPin-holyGod"].label, "Pin to Pray")
  }

  @MainActor
  func testAramaicRosaryHeadingsStayAramaicUnderEnglishInterface() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "arc"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    app.buttons["rosaryCard"].tap()
    let preset = app.buttons["prayDefaultPreset"].firstMatch
    XCTAssertTrue(preset.waitForExistence(timeout: 10))
    preset.tap()
    XCTAssertTrue(app.staticTexts["prayerBodyText"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.staticTexts["רושמא דצליבא"].exists)
    XCTAssertFalse(app.staticTexts["Sign of the Cross"].exists)
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "aramaic-rosary-heading"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.buttons["languageMenu"].tap()
    XCTAssertTrue(app.buttons["prayerLanguage-arc"].label.contains("ܐܪܡܐܝܬ / ארמית"))
  }

  @MainActor
  func testAlphabetChoiceIsCenteredAcrossPrayerSteps() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-defaultLanguageCode", "arc", "-aramaicDefaultScript", "Hebr", "-autoAdvanceSeconds", "0"]
    app.launch()
    openPrayTab(in: app)
    app.buttons["rosaryCard"].tap()
    let preset = app.buttons["prayDefaultPreset"].firstMatch
    XCTAssertTrue(preset.waitForExistence(timeout: 10))
    preset.tap()
    let body = app.staticTexts["prayerBodyText"]
    let syriac = app.buttons["transliterationToggle.Syrc"]
    let hebrew = app.buttons["transliterationToggle.Hebr"]
    XCTAssertTrue(body.waitForExistence(timeout: 10))
    XCTAssertTrue(syriac.waitForExistence(timeout: 5))
    XCTAssertEqual(syriac.label, "Syriac Script")
    XCTAssertEqual(hebrew.label, "Hebrew Script")
    let textColumnCenter = app.windows.firstMatch.frame.midX
    XCTAssertEqual(syriac.frame.union(hebrew.frame).midX, textColumnCenter, accuracy: 1)
    syriac.tap()
    let switched = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      body.label.unicodeScalars.contains { (0x0700...0x074F).contains($0.value) }
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [switched], timeout: 5), .completed)
    app.buttons["prayerFlowNextButton"].tap()
    XCTAssertTrue(body.waitForExistence(timeout: 5))
    XCTAssertEqual(syriac.frame.union(hebrew.frame).midX, textColumnCenter, accuracy: 1)
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "aramaic-centered-alphabet-shared-text-column"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  @MainActor
  func testBasicPrayerLanguagePickerUpdatesFlowAndList() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en",
                           "-aramaicDefaultScript", "Hebr"]
    app.launch()
    openPrayTab(in: app)
    let basic = app.buttons["basicPrayersRow"]
    XCTAssertTrue(basic.waitForExistence(timeout: 10))
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    app.buttons["languageMenu"].tap()
    app.buttons["basicPrayerLanguage-arc"].tap()
    let ourFather = app.buttons["basicPrayer-ourFather"]
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    XCTAssertTrue(ourFather.label.contains("צלותא מרניתא"))
    ourFather.tap()
    let syriacButton = app.buttons["transliterationToggle.Syrc"]
    XCTAssertTrue(syriacButton.waitForExistence(timeout: 5))
    XCTAssertEqual(syriacButton.label, "Syriac Script")
    XCTAssertEqual(app.buttons["transliterationToggle.Hebr"].label, "Hebrew Script")
    XCTAssertTrue(app.staticTexts["prayerStepTitle"].label.contains("צלותא"))
    syriacButton.tap()
    for identifier in ["prayerStepTitle", "prayerFlowTitle"] {
      let heading = app.staticTexts[identifier]
      let syriacHeading = NSPredicate { _, _ in
        heading.label.unicodeScalars.contains { (0x0700...0x074F).contains($0.value) }
      }
      XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: syriacHeading, object: nil)],
                                  timeout: 5), .completed)
    }
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "basic-prayer-aramaic-script-toggle"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.buttons["languageMenu"].tap()
    let appSetting = app.buttons["basicPrayerLanguage-default"]
    XCTAssertTrue(appSetting.waitForExistence(timeout: 5))
    XCTAssertEqual(appSetting.label, "App Setting")
    let languageMenu = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    languageMenu.name = "basic-prayer-default-language-menu"
    languageMenu.lifetime = .keepAlways
    add(languageMenu)
    appSetting.tap()
    let defaultHeading = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Our Father"), object: app.staticTexts["prayerFlowTitle"])
    XCTAssertEqual(XCTWaiter.wait(for: [defaultHeading], timeout: 5), .completed)
    XCTAssertFalse(app.buttons["transliterationToggle"].exists)
    XCTAssertFalse(app.buttons["transliterationToggle.Syrc"].exists)
    app.buttons["prayerFlowNextButton"].tap()
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    XCTAssertTrue(ourFather.label.contains("Our Father"))
  }

  @MainActor
  func testAramaicDefaultScriptAndSessionTogglePersistAcrossSteps() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "", "-defaultLanguageCode", "arc",
                           "-autoAdvanceSeconds", "0"]
    func openScriptSetting() -> XCUIElement {
      openPrayTab(in: app)
      XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
      app.buttons["settingsButton"].tap()
      // Expand the sheet using its header so the gesture does not also scroll
      // the form past Typography. Offscreen rows may already report hittable.
      let navigationBar = app.navigationBars["Settings"]
      XCTAssertTrue(navigationBar.waitForExistence(timeout: 5))
      navigationBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        .press(forDuration: 0.1, thenDragTo:
          app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)))
      let picker = app.buttons["aramaicDefaultScriptPicker"]
      for _ in 0..<8 where !picker.isHittable { app.swipeUp() }
      XCTAssertTrue(picker.isHittable)
      return picker
    }
    for (script, label) in [("Syrc", "Syriac Script"), ("Hebr", "Hebrew Script")] {
      app.launch()
      let picker = openScriptSetting()
      picker.staticTexts.firstMatch.tap()
      XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 5))
      app.buttons[label].tap()
      XCTAssertEqual(picker.staticTexts.firstMatch.label, label)
      app.buttons["Done"].tap()
      app.terminate()

      // The picker writes the real preference. No script launch argument can mask a
      // persistence failure.
      app.launch()
      XCTAssertEqual(openScriptSetting().staticTexts.firstMatch.label, label)
      app.buttons["Done"].tap()
      XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
      app.buttons["rosaryCard"].tap()
      let preset = app.buttons["prayDefaultPreset"].firstMatch
      XCTAssertTrue(preset.waitForExistence(timeout: 10))
      preset.tap()
      let body = app.staticTexts["prayerBodyText"]
      XCTAssertTrue(body.waitForExistence(timeout: 10))
      func expectScript(_ syriac: Bool) {
        let predicate = NSPredicate { _, _ in
          let heading = app.staticTexts["prayerStepTitle"]
          return body.label.unicodeScalars.contains { (0x0700...0x074F).contains($0.value) } == syriac
            && heading.exists
            && heading.label.unicodeScalars.contains { (0x0700...0x074F).contains($0.value) } == syriac
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 5), .completed)
        XCTAssertTrue(app.staticTexts["prayerProgressText"].label.contains(syriac ? "ܡܶܢ" : "מֶן"))
      }
      expectScript(script == "Syrc")
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = "aramaic-default-\(script)"
      attachment.lifetime = .keepAlways
      add(attachment)
      app.buttons["transliterationToggle.\(script == "Syrc" ? "Hebr" : "Syrc")"].tap()
      expectScript(script != "Syrc")
      app.buttons["prayerFlowNextButton"].tap()
      expectScript(script != "Syrc")
      app.terminate()
    }
  }
  #endif

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
    let backButton = app.buttons["chevron.backward"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 5))
    backButton.click()

    XCTAssertTrue(rosaryCard.waitForExistence(timeout: 5),
                  "A double-click must not push the Rosary presets screen twice")
    XCTAssertFalse(defaultPresetButton.exists)
  }

  @MainActor
  func testDoubleClickingBasicPrayerNeedsOnlyOneBackClick() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore"]
    app.launch()

    let basicPrayersRow = app.buttons["basicPrayersRow"]
    XCTAssertTrue(basicPrayersRow.waitForExistence(timeout: 10))
    basicPrayersRow.click()

    let signOfCross = app.buttons["basicPrayer-signOfCross"]
    XCTAssertTrue(signOfCross.waitForExistence(timeout: 5))
    signOfCross.doubleClick()

    let finishButton = app.buttons["prayerFlowNextButton"]
    XCTAssertTrue(finishButton.waitForExistence(timeout: 5))
    // The prayer flow also has its own step-level Back button. Target the native navigation
    // control explicitly so this verifies the stack rather than the prayer's step state.
    let backButton = app.buttons["chevron.backward"]
    XCTAssertTrue(backButton.waitForExistence(timeout: 5))
    backButton.click()

    XCTAssertTrue(signOfCross.waitForExistence(timeout: 5),
                  "A double-click must not push the same basic prayer twice")
    XCTAssertFalse(finishButton.exists)
  }

  @MainActor
  func testMenuLandingBackThenLocalNavigationKeepsEachStackHonest() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "-resetStore",
      "-AppleLanguages", "(en)",
      "-defaultLanguageCode", "en",
    ]
    app.launch()

    // Reproduce the real menu-tracking handoff: the Pray stack is inactive when the external
    // route arrives, then its native Back control must write all the way back to the one bound
    // path that Home's cards subsequently mutate.
    let searchTab = app.staticTexts["Search"].firstMatch
    XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
    searchTab.click()
    XCTAssertTrue(app.buttons["search.local.rosary"].waitForExistence(timeout: 5))

    let prayersMenu = app.menuBars.menuBarItems["Prayers"]
    XCTAssertTrue(prayersMenu.waitForExistence(timeout: 5))
    prayersMenu.click()
    let angelusMenuItem = app.menuItems["Angelus"]
    XCTAssertTrue(angelusMenuItem.waitForExistence(timeout: 5))
    angelusMenuItem.click()

    let prayerNext = app.buttons["prayerFlowNextButton"]
    XCTAssertTrue(prayerNext.waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["chevron.backward"].waitForExistence(timeout: 5))
    app.buttons["chevron.backward"].click()
    let rosaryCard = app.buttons["rosaryCard"]
    XCTAssertTrue(rosaryCard.waitForExistence(timeout: 5))

    rosaryCard.doubleClick()
    XCTAssertTrue(app.buttons["prayDefaultPreset"].waitForExistence(timeout: 5))
    app.buttons["chevron.backward"].click()
    XCTAssertTrue(rosaryCard.waitForExistence(timeout: 5),
                  "Rosary Back must return to Pray, not the externally landed Angelus")
    XCTAssertFalse(prayerNext.exists)

    app.buttons["basicPrayersRow"].click()
    let signOfCross = app.buttons["basicPrayer-signOfCross"]
    XCTAssertTrue(signOfCross.waitForExistence(timeout: 5))
    signOfCross.doubleClick()
    XCTAssertTrue(prayerNext.waitForExistence(timeout: 5))
    app.buttons["chevron.backward"].click()

    XCTAssertTrue(signOfCross.waitForExistence(timeout: 5),
                  "Basic-prayer Back must return to its list after earlier stack replacements")
    XCTAssertFalse(rosaryCard.exists, "Basic Prayers must remain the current stack destination")
  }
  #endif

  #if os(iOS)
  @MainActor
  func testAppColorOffersThePaletteAndPersistsWhiteWithGoldAccent() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en", "-AppleInterfaceStyle", "Dark"]
    app.launch()
    func openColorSettings() -> XCUIElement {
      XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
      app.buttons["settingsButton"].tap()
      let link = app.buttons["appearanceSettingsLink"]
      for _ in 0..<5 where !link.isHittable { app.swipeUp() }
      XCTAssertTrue(link.isHittable)
      return link
    }
    var link = openColorSettings()
    let settingsPosition = link.frame.midY
    link.tap()
    XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["appColorPicker"].exists)
    for name in ["Blue", "Green", "Red", "Purple", "Rose", "White", "Gold"] {
      let row = app.buttons["appColorOption-\(name.lowercased())"]
      for _ in 0..<3 where !row.isHittable { app.swipeUp() }
      XCTAssertTrue(row.isHittable, name)
      XCTAssertEqual(row.label, name)
      XCTAssertGreaterThanOrEqual(row.frame.height, 90, "Icon choices have comfortable full-size rows")
    }
    let white = app.buttons["appColorOption-white"]
    white.tap()
    XCTAssertTrue(white.isSelected)
    XCTAssertTrue(app.navigationBars["Appearance"].exists, "Choosing a color stays on Appearance")
    let settings = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    settings.name = "appearance-colors-white-selected"
    settings.lifetime = .keepAlways
    add(settings)
    app.navigationBars["Appearance"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    XCTAssertEqual(link.value as? String, "White")
    XCTAssertEqual(link.frame.midY, settingsPosition, accuracy: 3, "Back preserves the Settings scroll position")
    app.buttons["Done"].tap()
    let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    home.name = "white-palette-pray-accent"
    home.lifetime = .keepAlways
    add(home)
    app.terminate()
    app.launch()
    link = openColorSettings()
    XCTAssertEqual(link.value as? String, "White")
    link.tap()
    for _ in 0..<3 where !white.isHittable { app.swipeUp() }
    XCTAssertTrue(white.isSelected, "The selected color persists after relaunch")
    let blue = app.buttons["appColorOption-blue"]
    for _ in 0..<3 where !blue.isHittable { app.swipeDown() }
    blue.tap()
    XCTAssertTrue(blue.isSelected)
    let bluePage = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    bluePage.name = "appearance-colors-blue-selected"
    bluePage.lifetime = .keepAlways
    add(bluePage)
    app.navigationBars["Appearance"].buttons.element(boundBy: 0).tap()
    XCTAssertEqual(link.value as? String, "Blue")
    app.buttons["Done"].tap()
  }

  @MainActor
  func testAppearanceUsesNativeBackNavigationInHebrew() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(he)", "-interfaceLanguageCode", "he", "-AppleLocale", "he_IL"]
    app.launch()
    openPrayTab(in: app)
    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()
    let link = app.buttons["appearanceSettingsLink"]
    for _ in 0..<5 where !link.isHittable { app.swipeUp() }
    XCTAssertTrue(link.isHittable)
    link.tap()
    let bar = app.navigationBars["מראה"]
    XCTAssertTrue(bar.waitForExistence(timeout: 5))
    let blue = app.buttons["appColorOption-blue"]
    XCTAssertTrue(blue.isHittable)
    blue.tap()
    XCTAssertTrue(blue.isSelected)
    let back = bar.buttons.element(boundBy: 0)
    XCTAssertGreaterThan(back.frame.midX, bar.frame.midX, "The native back control follows RTL layout")
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "appearance-colors-hebrew"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    back.tap()
    XCTAssertTrue(app.navigationBars["הגדרות"].waitForExistence(timeout: 5))
    XCTAssertTrue(link.isHittable)
  }

  @MainActor
  func testAppearanceKeepsLargeTextChoicesReachable() throws {
    // Give the iPad toolbar room to show Settings; this test targets the Appearance
    // form, independently of the system overflow menu used by the Home toolbar.
    XCUIDevice.shared.orientation = .landscapeLeft
    defer { XCUIDevice.shared.orientation = .portrait }
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
                           "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
    app.launch()
    let settings = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@", "settingsButton", "Settings")).firstMatch
    if !settings.waitForExistence(timeout: 5) {
      // iPad's native toolbar moves secondary actions into More at large text sizes.
      let more = app.buttons["More"]
      XCTAssertTrue(more.waitForExistence(timeout: 5), app.debugDescription)
      more.tap()
    }
    XCTAssertTrue(settings.waitForExistence(timeout: 5))
    settings.tap()
    let link = app.buttons["appearanceSettingsLink"]
    for _ in 0..<12 where !link.isHittable { app.swipeUp() }
    XCTAssertTrue(link.isHittable)
    link.tap()
    XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 5))
    XCUIDevice.shared.orientation = .portrait
    for color in ["blue", "green", "red", "purple", "rose", "white", "gold"] {
      let row = app.buttons["appColorOption-\(color)"]
      for _ in 0..<4 where !row.isHittable { app.swipeUp() }
      XCTAssertTrue(row.isHittable, color)
      row.tap()
      XCTAssertTrue(row.isSelected, color)
    }
    let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    screenshot.name = "appearance-colors-large-text"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    let blue = app.buttons["appColorOption-blue"]
    for _ in 0..<8 where !blue.isHittable { app.swipeDown() }
    blue.tap()
    app.navigationBars["Appearance"].buttons.element(boundBy: 0).tap()
    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    XCTAssertTrue(link.isHittable)
  }

  @MainActor
  func testAppLanguageUpdatesInterfaceAndInheritedPrayersWhileKeepingExplicitChoices() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-defaultLanguageCode", ""]
    app.launch()
    openPrayTab(in: app)

    func chooseAppLanguage(_ name: String) {
      let picker = app.buttons["appLanguagePicker"]
      XCTAssertTrue(picker.waitForExistence(timeout: 5))
      picker.tap()
      let option = app.buttons[name]
      XCTAssertTrue(option.waitForExistence(timeout: 5))
      option.tap()
    }

    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()
    chooseAppLanguage("עברית")
    XCTAssertTrue(app.navigationBars["הגדרות"].waitForExistence(timeout: 5),
                  "The open settings sheet updates without being replaced")
    XCTAssertTrue(app.staticTexts["שפת היישומון"].exists)
    app.buttons["סיום"].tap()
    openReadingsTab(in: app, title: "מקראות")
    let rtlNavigation = NSPredicate { _, _ in
      app.buttons["readings.nextDay"].frame.midX < app.buttons["readings.previousDay"].frame.midX
    }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rtlNavigation, object: nil)],
                                timeout: 5), .completed)
    openPrayTab(in: app, title: "תפילה")
    XCTAssertFalse(app.buttons["todayDateButton"].exists)

    let basic = app.buttons["basicPrayersRow"]
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    app.buttons["languageMenu"].tap()
    app.buttons["basicPrayerLanguage-default"].tap()
    let ourFather = app.buttons["basicPrayer-ourFather"]
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    XCTAssertTrue(ourFather.label.contains("אבינו"),
                  "An inherited prayer follows the newly chosen app language")
    app.buttons["languageMenu"].tap()
    app.buttons["basicPrayerLanguage-en"].tap()
    XCTAssertTrue(ourFather.label.contains("Our Father"))
    app.navigationBars.buttons.element(boundBy: 0).tap()

    app.buttons["settingsButton"].tap()
    chooseAppLanguage("Français")
    XCTAssertTrue(app.navigationBars["Réglages"].waitForExistence(timeout: 5))
    app.buttons["Terminé"].tap()
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    XCTAssertTrue(ourFather.waitForExistence(timeout: 5))
    XCTAssertTrue(ourFather.label.contains("Our Father"),
                  "An explicit prayer language survives an interface change")
    app.buttons["languageMenu"].tap()
    app.buttons["basicPrayerLanguage-default"].tap()
    XCTAssertTrue(ourFather.label.contains("Notre Père"))
    app.navigationBars.buttons.element(boundBy: 0).tap()
    app.buttons["settingsButton"].tap()
    chooseAppLanguage("English")
    app.buttons["Done"].tap()
  }
  #endif

  @MainActor
  func testSettingsOpensFromHomeAndOffersItsSections() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", ""]
    app.launch()
    openPrayTab(in: app)

    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()

    XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    let removeDownloads = app.buttons["Remove Unused Downloads…"]
    for _ in 0..<8 where !removeDownloads.isHittable { app.swipeUp() }
    XCTAssertTrue(app.staticTexts["Downloads"].exists, "Downloads section should be present")
    XCTAssertTrue(removeDownloads.exists)
  }

  @MainActor
  func testHomeOrderEditorOpensFromTheToolbar() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)"]
    app.launch()
    openPrayTab(in: app)

    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["editOrderButton"].waitForExistence(timeout: 10))
    app.buttons["editOrderButton"].tap()

    XCTAssertTrue(app.navigationBars["Home Order"].waitForExistence(timeout: 5))
    app.buttons["Done"].tap()
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLanguageFallbackOrderUsesTheReorderEditor() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)"]
    app.launch()
    openPrayTab(in: app)

    XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.buttons["languageFallbackOrderButton"].waitForExistence(timeout: 5))
    app.buttons["languageFallbackOrderButton"].tap()

    XCTAssertTrue(app.navigationBars["Language Fallback Order"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["languageFallbackOrderList"].firstMatch.exists)
    XCTAssertTrue(app.staticTexts["languageFallbackOrder.en"].exists)
    XCTAssertTrue(app.buttons["languageFallbackOrderResetButton"].exists)
    app.navigationBars["Language Fallback Order"].buttons["Done"].tap()
  }
}
