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

  #if !os(macOS)
  @MainActor
  func testBasicPrayerNamesOfferBilingualDisplayWithoutChangingPrayerLanguage() throws {
    for enabled in [false, true] {
      let app = XCUIApplication()
      app.launchArguments = ["-AppleLanguages", "(en)", "-defaultLanguageCode", "arc",
                             "-basicPrayersLanguageCode", "arc", "-aramaicDefaultScript", "Hebr",
                             "-showPrayerNameInPrayerLanguage", enabled ? "YES" : "NO"]
      app.launch()
      XCTAssertTrue(app.buttons["basicPrayersRow"].waitForExistence(timeout: 10))
      app.buttons["basicPrayersRow"].tap()
      let prayer = app.buttons["basicPrayer-ourFather"]
      XCTAssertTrue(prayer.waitForExistence(timeout: 5))
      XCTAssertTrue(prayer.label.contains("Our Father"))
      XCTAssertEqual(prayer.label.contains("צלותא מרניתא"), enabled)
      let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
      attachment.name = enabled ? "basic-prayer-bilingual-names" : "basic-prayer-interface-names"
      attachment.lifetime = .keepAlways
      add(attachment)
      prayer.tap()
      let heading = app.staticTexts["prayerFlowTitle"]
      XCTAssertTrue(heading.waitForExistence(timeout: 5))
      XCTAssertEqual(heading.label, "צלותא מרניתא", "The shelf preference does not change the prayed title")
      app.terminate()
    }
  }

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
      app.launchArguments = ["-resetStore", "-AppleLanguages", "(\(language))",
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
      let firstMystery = body.label
      XCTAssertNotEqual(firstMystery, firstBody)
      nextSection.tap()
      XCTAssertNotEqual(body.label, firstMystery)
      previousSection.tap()
      XCTAssertEqual(body.label, firstMystery)
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
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en"]
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
    app.buttons["prayerTradition-he-x-gamliel"].tap()
    XCTAssertTrue(app.buttons["basicPrayer-holyGod"].label.contains("קדישת"))
    let pin = app.buttons["basicPrayerPin-holyGod"]
    XCTAssertEqual(pin.label, "Pin to home")
    pin.tap()
    XCTAssertEqual(pin.label, "Unpin from home")
    app.navigationBars.buttons.element(boundBy: 0).tap()
    let pinned = app.buttons["basic:holyGodCard"]
    XCTAssertTrue(pinned.waitForExistence(timeout: 5))
    XCTAssertTrue(pinned.label.contains("קדישת"))
    pinned.tap()
    XCTAssertTrue(app.staticTexts["prayerFlowTitle"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["prayerFlowTitle"].label, "קדישת")
    app.buttons["prayerFlowNextButton"].tap()
    for _ in 0..<4 where !basic.isHittable { app.swipeUp() }
    basic.tap()
    app.buttons["basicPrayerPin-holyGod"].tap()
    app.navigationBars.buttons.element(boundBy: 0).tap()
    XCTAssertFalse(app.buttons["basic:holyGodCard"].exists)
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
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "en"]
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
    app.buttons["transliterationToggle"].tap()
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
    app.launchArguments = ["-resetStore", "-AppleLanguages", "(en)", "-defaultLanguageCode", "arc",
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
      XCTAssertTrue(picker.isHittable)
      return picker
    }
    for (script, label) in [("Syrc", "Syriac script"), ("Hebr", "Hebrew script")] {
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
      app.launchArguments.removeAll { $0 == "-resetStore" }
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
          body.label.unicodeScalars.contains { (0x0700...0x074F).contains($0.value) } == syriac
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
