import XCTest
@testable import Prosary

final class HomeDashboardLayoutTests: XCTestCase {
  func testNarrowPanesKeepOneReadableColumn() {
    for width in [CGFloat(0), 280, 375, 430, 720] {
      XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: width), 1)
    }
  }

  func testColumnsFollowAvailablePaneWidth() {
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 760), 2)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1024), 2)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1200), 3)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 2000), 3)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 1024 / 2), 1)
  }

  func testSavedOrderRunsAcrossColumnsWithoutSharingRowHeights() {
    let frames = HomeDashboardLayout.cardFrames(heights: [100, 300, 50, 60, 70, 80, 90],
      contentWidth: 1052, columnCount: 3)
    XCTAssertEqual(frames.map(\.minX), [0, 356, 712, 0, 356, 712, 0])
    XCTAssertEqual(frames.map(\.width), Array(repeating: 340, count: 7))
    XCTAssertEqual(frames.map(\.minY), [0, 0, 0, 116, 316, 66, 192])
    XCTAssertLessThan(frames[3].minY, frames[1].maxY, "A tall neighboring card does not delay the next card")
    XCTAssertEqual(frames.map(\.maxY).max(), 386)
  }

  func testOneColumnKeepsNaturalHeightsAndEmptyLayoutsStayEmpty() {
    let frames = HomeDashboardLayout.cardFrames(heights: [70, 180, 44], contentWidth: 335, columnCount: 1)
    XCTAssertEqual(frames.map(\.minX), [0, 0, 0])
    XCTAssertEqual(frames.map(\.minY), [0, 86, 282])
    XCTAssertEqual(frames.map(\.width), [335, 335, 335])
    XCTAssertTrue(HomeDashboardLayout.cardFrames(heights: [], contentWidth: 720, columnCount: 2).isEmpty)
  }

  func testSideBySidePartialFoldAlternatesSavedCardsAcrossPanes() {
    let ordered = ["readings", "torah", "popeIntention", "calendar", "reminders", "scripture", "feast"]
    XCTAssertEqual(HomeDashboardLayout.paneItems(ordered, paneIndex: 0, isHorizontal: true),
      ["readings", "popeIntention", "reminders", "feast"])
    XCTAssertEqual(HomeDashboardLayout.paneItems(ordered, paneIndex: 1, isHorizontal: true),
      ["torah", "calendar", "scripture"])
    XCTAssertEqual(ordered, ["readings", "torah", "popeIntention", "calendar", "reminders", "scripture", "feast"])
    XCTAssertTrue(HomeDashboardLayout.paneItems([String](), paneIndex: 0, isHorizontal: true).isEmpty)
    XCTAssertEqual(HomeDashboardLayout.columnCount(availableWidth: 2000, isHorizontalPane: true), 1,
      "Each side-by-side physical pane remains one logical card column")
  }

  func testStackedPartialFoldKeepsSavedOrderFromTopPaneToBottomPane() {
    let ordered = [0, 1, 2, 3, 4]
    let top = HomeDashboardLayout.paneItems(ordered, paneIndex: 0, isHorizontal: false)
    let bottom = HomeDashboardLayout.paneItems(ordered, paneIndex: 1, isHorizontal: false)
    XCTAssertEqual(top, [0, 1, 2])
    XCTAssertEqual(bottom, [3, 4])
    XCTAssertEqual(top + bottom, ordered)
  }
}
