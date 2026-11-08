#if os(iOS)
import XCTest

final class BibleEditionUITests: XCTestCase {
  @MainActor func testBookPagesTurnAcrossBooksAndExposeEachBooksLastPage() throws {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-useInMemoryStore", "-AppleLanguages", "(en)", "-interfaceLanguageCode", "en",
      "-readingsEditionId", "douay-rheims-1899", "-homeWidgetOrder", "scripture"]
    app.launch()
    defer { app.terminate() }
    let open = app.buttons["homeWidgets.open.scripture"]
    XCTAssertTrue(open.waitForExistence(timeout: 10)); open.tap()
    let count = app.buttons["bible.pageCount"]
    func numbers() -> [Int] {
      guard count.exists else { return [] }
      return count.label.replacingOccurrences(of: ",", with: "").split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
    }
    let prepared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().last.map { $0 > 20 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [prepared], timeout: 30), .completed)
    let initial = numbers()
    XCTAssertNotNil(initial.last)
    XCTAssertTrue(app.webViews.firstMatch.exists)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    let text = app.webViews.firstMatch
    text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    let hidden = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      !count.exists && !app.buttons["bible.bookMenu"].exists
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed)
    let focused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    focused.name = "bible-chrome-hidden"; focused.lifetime = .keepAlways; add(focused)
    text.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    XCTAssertTrue(count.waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["bible.bookMenu"].isHittable)
    let restored = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    restored.name = "bible-native-glass-restored"; restored.lifetime = .keepAlways; add(restored)
    // Reflow can change the book's total when the bars reclaim their space.
    let restoredTotal = try XCTUnwrap(numbers().last)
    app.buttons["bible.nextPage"].tap()
    let advanced = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 > 1 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [advanced], timeout: 10), .completed)
    XCTAssertEqual(numbers().last, restoredTotal)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
    app.buttons["bible.bookMenu"].tap(); app.buttons["Exodus"].tap()
    XCTAssertTrue(app.navigationBars["Exodus"].waitForExistence(timeout: 10))
    let exodusOpened = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in numbers().first == 1 }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [exodusOpened], timeout: 10), .completed, count.label)
    // Each book is its own document: Genesis' pages are not counted in Exodus.
    XCTAssertNotEqual(numbers().last, restoredTotal)
    app.buttons["bible.previousChapter"].tap()
    XCTAssertTrue(app.navigationBars["Genesis"].waitForExistence(timeout: 10))
    let genesisEnd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 > 10 } == true && numbers().last == restoredTotal
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [genesisEnd], timeout: 10), .completed, count.label)
    app.buttons["bible.verseMenu"].tap(); app.buttons["3"].tap()
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "book-pages-and-verse-lookup"; attachment.lifetime = .keepAlways; add(attachment)
    // The page count opens the book's chapters.
    XCTAssertFalse(app.sliders["bible.pageSlider"].exists)
    count.tap(); app.buttons["Chapter 50"].tap()
    let nearEnd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      numbers().first.map { $0 > restoredTotal * 90 / 100 } == true
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [nearEnd], timeout: 10), .completed, count.label)
    // Genesis 50 can begin a few pages before the book's last page.
    for _ in 0..<40 where numbers().first.map({ $0 < restoredTotal - 1 }) == true {
      app.buttons["bible.nextPage"].tap()
    }
    // The last page of Genesis turns into the first page of Exodus.
    XCTAssertTrue(app.buttons["bible.nextPage"].isEnabled)
    app.buttons["bible.nextPage"].tap()
    XCTAssertTrue(app.navigationBars["Exodus"].waitForExistence(timeout: 10))
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in numbers().first == 1 }, object: nil)], timeout: 10), .completed, count.label)
    // And back again to the last page of Genesis.
    app.buttons["bible.previousPage"].tap()
    XCTAssertTrue(app.navigationBars["Genesis"].waitForExistence(timeout: 10))
    let backAtEnd = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
      guard let first = numbers().first, let last = numbers().last else { return false }
      return first >= last - 1
    }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [backAtEnd], timeout: 10), .completed, count.label)
    XCTAssertFalse(app.progressIndicators["bible.preparingEdition"].exists)
  }
}
#endif
