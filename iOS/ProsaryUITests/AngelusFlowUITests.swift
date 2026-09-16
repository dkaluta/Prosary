//
//  AngelusFlowUITests.swift
//  ProsaryUITests
//
//  The Pray tab lists saved sessions, so a devotion nobody has starred is reached through
//  Search. A devotion with no favorite prays in the
//  selected prayer language. The Latin fixtures explicitly select Latin; the English fixture
//  verifies that the step headings follow the prayer language independently of the interface.
//

import XCTest
#if os(iOS)
import UIKit
#endif

final class AngelusFlowUITests: XCTestCase {
  override func setUpWithError() throws {
    // The simulator remembers its orientation between runs, and landscape shortens every
    // list — rows fall below the fold and queries that assume a visible row fail for reasons
    // that have nothing to do with the app. Start upright, always.
    #if !os(macOS)
    XCUIDevice.shared.orientation = .portrait
    #endif
    continueAfterFailure = false
  }

  /// Search includes every local devotion, starred or not.
  private func openAngelus(_ app: XCUIApplication) {
    app.tabBars.buttons["Search"].tap()
    // Open the identified local row regardless of the native search-field placement.
    let row = app.buttons["search.local.angelus"].firstMatch
    for _ in 0..<8 where !row.isHittable { app.swipeUp() }
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertTrue(row.isHittable)
    row.tap()
  }

  @MainActor
  func testAngelusFlowFromHomeToFinish() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "", "-defaultLanguageCode", "la"]
    app.launch()

    openAngelus(app)

    // First step of the standard (non-Eastertide) form, headed in the praying language.
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))

    // Queried by identifier, not the "Next"/"Back" label text, since the system
    // navigation-bar back button also reads as plain "Back" and would otherwise collide.
    let nextButton = app.buttons["prayerFlowNextButton"]
    // 7 steps total: tapping Next 6 times reaches the last one, where the button becomes Finish.
    for _ in 0..<6 {
      XCTAssertTrue(nextButton.exists)
      XCTAssertEqual(nextButton.label, "Next")
      nextButton.tap()
    }

    XCTAssertTrue(nextButton.waitForExistence(timeout: 5))
    XCTAssertEqual(nextButton.label, "Finish")
    nextButton.tap()

    // Finishing returns to the list it was started from.
    XCTAssertTrue(app.buttons["search.local.angelus"].firstMatch.waitForExistence(timeout: 5))
  }

  @MainActor
  func testAngelusBackButtonReturnsToPreviousStep() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "", "-defaultLanguageCode", "la"]
    app.launch()

    openAngelus(app)
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowNextButton"].tap()
    // The second step is the first Hail Mary — "Ave Maria" while praying in Latin.
    XCTAssertTrue(app.staticTexts["Ave Maria"].waitForExistence(timeout: 5))

    app.buttons["prayerFlowBackButton"].tap()
    XCTAssertTrue(app.staticTexts["Angelus Domini"].waitForExistence(timeout: 5))
  }

  /// Headings follow the prayer, not the interface: the same devotion prayed in English heads
  /// its first step "The Annunciation". Covers titleKey resolution end to end.
  @MainActor
  func testHeadingsFollowThePrayerLanguage() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "", "-defaultLanguageCode", "en"]
    app.launch()

    openAngelus(app)
    XCTAssertTrue(app.staticTexts["The Annunciation"].waitForExistence(timeout: 5))
  }

  #if os(iOS)
  @MainActor
  func testActivePrayerKeepsItsStepAndReachableControlsThroughRotation() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "", "-defaultLanguageCode", "en"]
    app.launch()
    openAngelus(app)
    let progress = app.staticTexts["prayerProgressText"]
    XCTAssertTrue(progress.waitForExistence(timeout: 5))
    let next = app.buttons["prayerFlowNextButton"]
    next.tap()
    let currentProgress = progress.label

    for orientation in [UIDeviceOrientation.landscapeLeft, .landscapeRight, .portrait] {
      XCUIDevice.shared.orientation = orientation
      XCTAssertTrue(next.waitForExistence(timeout: 5))
      XCTAssertEqual(progress.label, currentProgress)
      XCTAssertTrue(next.isHittable)
      XCTAssertTrue(app.buttons["prayerFlowBackButton"].isHittable)
      XCTAssertTrue(app.buttons["autoAdvanceMenu"].isHittable)
      XCTAssertFalse(app.alerts.firstMatch.exists, "A layout change must not reopen the continuation prompt")
    }
  }
  #endif
}
