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
