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
  func testEveryTabOpensItsScreen() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", ""]
    app.launch()

    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10), "Pray lists the seeded favorite")

    // Full reading citations have their own tab; category browsing remains in Search.
    app.tabBars.buttons["Readings"].tap()
    XCTAssertTrue(app.navigationBars["Readings"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.buttons["readings.chooseDate"].waitForExistence(timeout: 5), app.debugDescription)

    app.tabBars.buttons["Search"].tap()
    XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5))

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
    XCTAssertEqual(app.buttons["todayYesterdayButton"].label, "Попередній день")
    XCTAssertEqual(app.buttons["todayTomorrowButton"].label, "Наступний день")
    let home = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    home.name = "ukrainian-pray-and-today"
    home.lifetime = .keepAlways
    add(home)
    app.buttons["settingsButton"].tap()
    XCTAssertTrue(app.navigationBars["Налаштування"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.switches["useJaffaHailMaryWording"].label.contains("Альтернативний текст «Радуйся, Маріє»"))
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
  func testJaffaWordingToggleIsAvailableToFallbackUsersAndRestoresThePrayer() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "arc",
                           "-basicPrayersLanguageCode", "he", "-autoAdvanceSeconds", "0"]
    for enabled in [false, true, false] {
      app.launch()
      XCTAssertTrue(app.buttons["settingsButton"].waitForExistence(timeout: 10))
      app.buttons["settingsButton"].tap()
      let toggle = app.switches["useJaffaHailMaryWording"]
      XCTAssertTrue(toggle.waitForExistence(timeout: 5), "The option is available even with Aramaic selected")
      let expectedValue = enabled ? "1" : "0"
      if (toggle.value as? String) != expectedValue {
        // SwiftUI exposes the whole labelled row as the switch's accessibility frame.
        // The English interface places the native switch at its trailing edge.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      }
      let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expectedValue),
                                              object: toggle)
      XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
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
      XCTAssertTrue(body.label.contains(enabled ? "בְּרוּכַת הַחֶסֶד" : "מְלֵאַת הַחֶסֶד"))
      XCTAssertFalse(body.label.contains(enabled ? "מְלֵאַת הַחֶסֶד" : "בְּרוּכַת הַחֶסֶד"))
      if enabled {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "jaffa-hail-mary-wording"
        attachment.lifetime = .keepAlways
        add(attachment)
      }
      app.terminate()
      app.launchArguments.removeAll { $0 == "-resetStore" }
    }
  }

  @MainActor
  func testBasicPrayerNamesOfferBilingualDisplayWithoutChangingPrayerLanguage() throws {
    for (language, expectedTitle) in [("arc", "צלותא מרניתא"), ("he-x-gamliel", "תפילת האדון")] {
      for enabled in [false, true] {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-defaultLanguageCode", language,
                               "-basicPrayersLanguageCode", "", "-aramaicDefaultScript", "Hebr",
                               "-showPrayerNameInPrayerLanguage", enabled ? "YES" : "NO"]
        app.launch()
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
    let rows = [("todayYesterdayButton", "todayDateButton", "todayTomorrowButton", "todayDatePicker", "todayDateDoneButton"),
                ("readings.previousDay", "readings.chooseDate", "readings.nextDay", "readings.datePicker", "readings.dateDone")]
    for (index, row) in rows.enumerated() {
      if index == 1 {
        let readingsTab = app.buttons["Readings"].firstMatch
        if readingsTab.exists {
          readingsTab.tap()
        } else {
          // Wide iPad windows expose the adaptive tab sidebar as list cells.
          app.cells["Readings"].firstMatch.tap()
        }
      }
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
      if index == 0 {
        XCTAssertGreaterThanOrEqual(date.frame.height, 44, "Detached date controls retain touch targets")
        XCTAssertGreaterThanOrEqual(previous.frame.width, 44)
        XCTAssertGreaterThanOrEqual(next.frame.width, 44)
      }
      // Native toolbar accessibility frames describe the system's visible platter, which
      // can be smaller than its touch target. Check reachability and bounds below instead.
      #endif
      #if os(iOS)
      if index == 1 {
        checkReadingsToolbar(in: app, rightToLeft: false, screenshotName: "readings-toolbar-en")
      }
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
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
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
      XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
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
    app.launchArguments = ["-AppleLanguages", "(en)", "-showTodayTorahPortion", "YES"]
    app.launch()
    let yesterday = app.buttons["todayYesterdayButton"]
    let tomorrow = app.buttons["todayTomorrowButton"]
    let dateButton = app.buttons["todayDateButton"]
    XCTAssertTrue(yesterday.waitForExistence(timeout: 10))
    let originalDate = dateButton.label
    yesterday.tap()
    XCTAssertNotEqual(dateButton.label, originalDate)
    tomorrow.tap()
    XCTAssertEqual(dateButton.label, originalDate)
    tomorrow.tap()
    XCTAssertNotEqual(dateButton.label, originalDate)
    dateButton.tap()
    let today = app.buttons["todayResetButton"]
    XCTAssertTrue(today.waitForExistence(timeout: 5))
    XCTAssertTrue(today.isEnabled)
    today.tap()
    XCTAssertEqual(dateButton.label, originalDate)
    XCTAssertFalse(today.exists, "The reset belongs inside the date popover")
    let controls = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    controls.name = "today-liquid-glass-controls"
    controls.lifetime = .keepAlways
    add(controls)
    dateButton.tap()
    let picker = app.datePickers["todayDatePicker"]
    XCTAssertTrue(picker.waitForExistence(timeout: 5), "The popover contains a system DatePicker")
    XCTAssertFalse(today.isEnabled)
    XCTAssertTrue(app.collectionViews.firstMatch.waitForExistence(timeout: 5), "The native calendar opens")
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "today-native-date-picker"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testRosaryTitleHasItsOwnLineAbovePhoneControls() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-AppleInterfaceStyle", "Dark",
                           "-defaultLanguageCode", "he"]
    app.launch()
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
    for (language, heading) in [("he", "המקרא היומי"), ("ar", "قراءات اليوم")] {
      let app = XCUIApplication()
      app.launchArguments = ["-resetStore", "-AppleLanguages", "(\(language))", "-interfaceLanguageCode", "",
                             "-defaultLanguageCode", "en", "-todayLanguageCode", "it",
                             "-autoAdvanceSeconds", "0"]
      app.launch()
      XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
      XCTAssertFalse(app.buttons["todayLanguagePicker"].exists)
      XCTAssertTrue(app.staticTexts[heading].exists, "Today follows the interface despite an old Italian override")
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
  func testRosaryLitanyHandoffKeepsHebrewAndUsesOnlyItsOwnEnding() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "he", "-autoAdvanceSeconds", "0"]
    app.launch()
    XCTAssertTrue(app.buttons["rosaryCard"].waitForExistence(timeout: 10))
    app.buttons["rosaryCard"].tap()
    app.buttons["prayDefaultPreset"].firstMatch.tap()
    let nextSection = app.buttons["nextMysteryButton"]
    XCTAssertTrue(nextSection.waitForExistence(timeout: 10))
    for _ in 0..<6 where nextSection.isEnabled { nextSection.tap() }
    let next = app.buttons["prayerFlowNextButton"]
    for _ in 0..<20 where next.label != "Finish" { next.tap() }
    XCTAssertEqual(next.label, "Finish")
    next.tap()
    let offer = app.buttons["prayLitanyButton"].firstMatch
    XCTAssertTrue(offer.waitForExistence(timeout: 5))
    offer.tap()
    let body = app.staticTexts["prayerBodyText"]
    XCTAssertTrue(body.waitForExistence(timeout: 5))
    XCTAssertTrue(body.label.contains("מָשִׁיחַ רַחֵם"))
    XCTAssertFalse(app.buttons["variantMenu"].exists)
    for _ in 0..<15 { next.tap() }
    XCTAssertEqual(next.label, "Finish")
    XCTAssertTrue(body.label.contains("אֱלֹהִים, אֲשֶׁר בִּנְךָ הַיָּחִיד"))
    XCTAssertFalse(body.label.contains("שִׂמְחָה בִּבְרִיאוּת"))
    let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    after.name = "hebrew-litany-after-rosary-ending"
    after.lifetime = .keepAlways
    add(after)
    next.tap()
    XCTAssertTrue(app.buttons["prayDefaultPreset"].firstMatch.waitForExistence(timeout: 5))
    app.navigationBars.buttons.element(boundBy: 0).tap()
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
    XCTAssertFalse(body.label.contains("אֱלֹהִים, אֲשֶׁר בִּנְךָ הַיָּחִיד"))
    let standard = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    standard.name = "hebrew-litany-standalone-ending"
    standard.lifetime = .keepAlways
    add(standard)
    next.tap()
  }

  @MainActor
  func testBasicPrayerTraditionAndHomePinStayConnected() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en",
                           "-showPrayerNameInPrayerLanguage", "YES"]
    app.launch()
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
  func testBasicPrayerLanguagePickerUpdatesFlowAndList() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en",
                           "-aramaicDefaultScript", "Hebr"]
    app.launch()
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
    XCTAssertTrue(app.buttons["transliterationToggle"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["prayerStepTitle"].label.contains("צלותא"))
    app.buttons["transliterationToggle"].tap()
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
    app.buttons["basicPrayerLanguage-default"].tap()
    XCTAssertEqual(app.staticTexts["prayerFlowTitle"].label, "Our Father")
    XCTAssertFalse(app.buttons["transliterationToggle"].exists)
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
      app.buttons["transliterationToggle"].tap()
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
  func testAppLanguageUpdatesInterfaceAndInheritedPrayersWhileKeepingExplicitChoices() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-defaultLanguageCode", ""]
    app.launch()

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
    let rtlNavigation = NSPredicate { _, _ in
      app.buttons["todayTomorrowButton"].frame.midX < app.buttons["todayYesterdayButton"].frame.midX
    }
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: rtlNavigation, object: nil)],
                                timeout: 5), .completed)

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
