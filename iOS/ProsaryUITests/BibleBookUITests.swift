#if os(iOS)
import XCTest
import UIKit

final class BibleBookUITests: XCTestCase {
  override func setUpWithError() throws {
    continueAfterFailure = false
    executionTimeAllowance = 240
    XCUIDevice.shared.orientation = .landscapeLeft
  }

  override func tearDownWithError() throws {
    XCUIDevice.shared.orientation = .portrait
  }

  @MainActor
  private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
    let matches = app.descendants(matching: .any).matching(identifier: identifier)
    // A native paging container may retain its neighboring spreads. Read the visible leaf
    // when those retained spreads expose the same stable slot identifiers.
    if identifier.hasPrefix("bible.page.") {
      return matches.allElementsBoundByIndex.first { $0.isHittable } ?? matches.firstMatch
    }
    return matches.firstMatch
  }

  @MainActor
  private func selectSection(_ title: String, in app: XCUIApplication) {
    let button = app.buttons[title].firstMatch
    if button.exists { button.tap() }
    else {
      let row = app.cells[title].firstMatch
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      row.tap()
    }
  }

  /// Seed the verified Douay archive in the disposable simulator before running. These
  /// tests browse that local installation and never download or remove a Bible.
  @MainActor
  private func openGenesis() throws -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)",
                           "-interfaceLanguageCode", "en", "-readingsEditionId", "douay-rheims-1899",
                           "-homeWidgetOrder", "scripture"]
    app.launch()
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 10))
    for _ in 0..<4 where !open.isHittable { app.swipeUp() }
    open.tap()
    let genesis = app.buttons["bible.book.GEN"]
    XCTAssertTrue(genesis.waitForExistence(timeout: 10))
    let installationResolved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      genesis.isEnabled || app.buttons["bible.download"].exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [installationResolved], timeout: 10), .completed)
    guard genesis.isEnabled else {
      app.terminate()
      throw XCTSkip("Requires the verified local Douay archive in the disposable simulator.")
    }
    for _ in 0..<8 where !genesis.isHittable { app.swipeUp() }
    XCTAssertTrue(genesis.isHittable)
    genesis.tap()
    let chapter = app.buttons["bible.chapter.1"]
    XCTAssertTrue(chapter.waitForExistence(timeout: 5))
    chapter.tap()
    guard element("bible.bookReader", in: app).waitForExistence(timeout: 10) else {
      app.terminate()
      throw XCTSkip("Facing pages require a wide display; run on iPad landscape or an open Duo.")
    }
    waitForSettledSpread(in: app)
    return app
  }

  @MainActor
  private func spreadText(in app: XCUIApplication) -> [String] {
    (0...1).map { slot in
      let page = element("bible.page.\(slot)", in: app)
      // The book uses selectable native paragraphs. Read one representative source unit,
      // rather than fetching a remote accessibility snapshot for every verse in a chapter.
      let paragraph = page.textViews.firstMatch
      if paragraph.exists { return (paragraph.value as? String) ?? paragraph.label }
      let fallback = page.staticTexts.firstMatch
      return fallback.exists ? fallback.label : ""
    }
  }

  @MainActor
  private func waitForSpread(_ text: [String], in app: XCUIApplication) {
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.spreadText(in: app) == text
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 10), .completed)
  }

  @MainActor
  private func waitForSettledSpread(in app: XCUIApplication) {
    var previousText: [String] = []
    var previousCount = ""
    var unchangedSince = Date()
    let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      let text = self.spreadText(in: app)
      let count = self.element("bible.pageCount", in: app).label
      if text != previousText || count != previousCount {
        previousText = text
        previousCount = count
        unchangedSince = Date()
        return false
      }
      return text.allSatisfy { !$0.isEmpty } && !count.isEmpty
        && Date().timeIntervalSince(unchangedSince) >= 0.5
    }, object: nil)
    let result = XCTWaiter.wait(for: [expectation], timeout: 15)
    XCTAssertEqual(result, .completed,
                   "Wait for source-row measurement to settle before checking pagination. \(result == .completed ? "" : app.debugDescription)")
  }

  @MainActor
  private func capture(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testFacingPagesAdvanceRestoreAndJumpToTheContainingPage() throws {
    let app = try openGenesis()
    defer { app.terminate() }
    let initialText = spreadText(in: app)
    XCTAssertTrue(initialText.allSatisfy { !$0.isEmpty }, "Both facing pages contain source text")
    let pageCount = element("bible.pageCount", in: app)
    XCTAssertTrue(pageCount.exists)
    let initialCount = pageCount.label
    let next = app.buttons["bible.nextPage"]
    let previous = app.buttons["bible.previousPage"]
    XCTAssertTrue(next.isHittable && next.isEnabled)
    XCTAssertFalse(previous.isEnabled)
    capture("bible-book-first-spread")

    next.tap()
    let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.spreadText(in: app) != initialText && pageCount.label != initialCount
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
    let secondText = spreadText(in: app)
    XCTAssertTrue(previous.isHittable && previous.isEnabled)
    capture("bible-book-next-spread")

    previous.tap()
    waitForSpread(initialText, in: app)
    XCTAssertEqual(pageCount.label, initialCount)
    next.tap()
    waitForSpread(secondText, in: app)

    let verseMenus = app.buttons.matching(NSPredicate(format: "identifier == %@ OR label == %@",
      "bible.verseMenu", "Go to Verse"))
    if !verseMenus.allElementsBoundByIndex.contains(where: { $0.isHittable }) {
      let more = app.buttons["More"].firstMatch
      XCTAssertTrue(more.waitForExistence(timeout: 5))
      more.tap()
    }
    let verseMenu = verseMenus.allElementsBoundByIndex.first { $0.isHittable } ?? verseMenus.firstMatch
    XCTAssertTrue(verseMenu.waitForExistence(timeout: 15) && verseMenu.isHittable)
    verseMenu.tap()
    let firstVerse = app.buttons["1"].firstMatch
    XCTAssertTrue(firstVerse.waitForExistence(timeout: 5))
    firstVerse.tap()
    waitForSpread(initialText, in: app)
    XCTAssertEqual(pageCount.label, initialCount, "A verse jump selects the spread containing that source block")
    XCTAssertTrue(element("bible.page.0", in: app).textViews.firstMatch.isHittable,
                  "The containing spread exposes the selected source paragraph")
    capture("bible-book-verse-jump")
    // Bible's native stack returns to its library and Home remains a primary section.
    for _ in 0..<3 where !app.buttons["bible.book.GEN"].isHittable {
      let back = app.navigationBars.buttons.element(boundBy: 0)
      XCTAssertTrue(back.isHittable)
      back.tap()
    }
    selectSection("Home", in: app)
    XCTAssertTrue(app.buttons["homeWidgets.open.scripture"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testBibleTabRetainsTheCurrentSourceBlockAfterVisitingHome() throws {
    let app = try openGenesis()
    defer { app.terminate() }
    let initial = spreadText(in: app)
    let next = app.buttons["bible.nextPage"]
    XCTAssertTrue(next.isHittable && next.isEnabled)
    next.tap()
    let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.spreadText(in: app) != initial
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
    waitForSettledSpread(in: app)
    let retainedText = spreadText(in: app)
    let retainedCount = element("bible.pageCount", in: app).label
    selectSection("Home", in: app)
    XCTAssertTrue(app.buttons["homeWidgets.open.scripture"].waitForExistence(timeout: 5))
    selectSection("Bible", in: app)
    XCTAssertTrue(element("bible.bookReader", in: app).waitForExistence(timeout: 10))
    waitForSettledSpread(in: app)
    waitForSpread(retainedText, in: app)
    XCTAssertEqual(element("bible.pageCount", in: app).label, retainedCount)
    capture("bible-tab-retained-source-block")
  }

  @MainActor
  func testCurrentSourceBlockSurvivesWideAndNarrowReaderChanges() throws {
    let app = try openGenesis()
    defer { app.terminate() }
    let initialText = spreadText(in: app)
    let next = app.buttons["bible.nextPage"]
    XCTAssertTrue(next.isHittable && next.isEnabled)
    next.tap()
    let changed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      self.spreadText(in: app) != initialText
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 10), .completed)
    let firstPage = element("bible.page.0", in: app)
    let block = firstPage.descendants(matching: .any)
      .matching(NSPredicate(format: "identifier BEGINSWITH %@", "bible.block.")).firstMatch
    XCTAssertTrue(block.exists, "A page preserves the source block's stable identity")
    let blockIdentifier = block.identifier
    capture("bible-book-before-narrowing")

    XCUIDevice.shared.orientation = .portrait
    try XCTSkipUnless(element("bible.bookReader", in: app).waitForNonExistence(timeout: 5),
                      "This device remains wide in portrait; use a display that crosses the reader's narrow threshold.")
    let retained = element(blockIdentifier, in: app)
    let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      retained.exists && retained.isHittable
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 10), .completed,
                   "The narrow reader keeps the current source block in view")
    capture("bible-book-retained-source-block-narrow")

    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(element("bible.bookReader", in: app).waitForExistence(timeout: 10))
    XCTAssertTrue(retained.exists && retained.isHittable,
                  "Returning to facing pages keeps the same source block")
    capture("bible-book-retained-source-block-wide")
  }
}
#endif
