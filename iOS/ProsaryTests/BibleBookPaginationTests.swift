import XCTest
@testable import Prosary

final class BibleBookPaginationTests: XCTestCase {
  func testPagesKeepAllSourceUnitsInOrderExactlyOnce() {
    let pages = BibleBookPagination.pages(heights: [30, 50, 90, 25, 300, 10], availableHeight: 140)
    XCTAssertEqual(pages.flatMap { Array($0) }, Array(0..<6))
    XCTAssertEqual(pages, [0..<2, 2..<4, 4..<5, 5..<6])
  }

  func testAnOversizeSourceUnitStaysWholeOnItsOwnPage() {
    XCTAssertEqual(BibleBookPagination.pages(heights: [800, 20, 20], availableHeight: 100), [0..<1, 1..<3])
  }

  func testReflowFindsTheSpreadContainingTheSameSourceAnchor() {
    let large = BibleBookPagination.pages(heights: Array(repeating: 30, count: 20), availableHeight: 130)
    let small = BibleBookPagination.pages(heights: Array(repeating: 50, count: 20), availableHeight: 100)
    for anchor in 0..<20 {
      for pages in [large, small] {
        let spread = BibleBookPagination.spread(containing: anchor, pages: pages)
        XCTAssertTrue(pages[spread * 2].contains(anchor)
          || (pages.indices.contains(spread * 2 + 1) && pages[spread * 2 + 1].contains(anchor)))
      }
    }
  }

  func testEmptyAndTransientViewportSizesRemainBounded() {
    XCTAssertTrue(BibleBookPagination.pages(heights: [], availableHeight: 0).isEmpty)
    XCTAssertEqual(BibleBookPagination.pages(heights: [0, .infinity, 10], availableHeight: 0), [0..<1, 1..<2, 2..<3])
  }
}
