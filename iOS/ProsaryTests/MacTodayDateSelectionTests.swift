#if os(macOS)
import Foundation
import XCTest
@testable import Prosary

final class MacTodayDateSelectionTests: XCTestCase {
  private let utc = TimeZone(secondsFromGMT: 0)!

  private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12, in timeZone: TimeZone) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
  }

  private func assertDay(_ selection: MacTodayDateSelection, _ year: Int, _ month: Int, _ day: Int,
                         file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(selection.day.year, year, file: file, line: line)
    XCTAssertEqual(selection.day.month, month, file: file, line: line)
    XCTAssertEqual(selection.day.day, day, file: file, line: line)
  }

  func testBrowsedCivilDaySurvivesTimezoneChangesInBothDirections() {
    let east = TimeZone(secondsFromGMT: 14 * 3600)!
    let west = TimeZone(secondsFromGMT: -10 * 3600)!
    for (origin, destination) in [(east, west), (west, east)] {
      let now = date(2026, 9, 8, in: origin)
      var selection = MacTodayDateSelection(now: now, timeZone: origin)
      selection.select(date(2026, 9, 5, hour: 0, in: origin), now: now, timeZone: origin)
      selection.refresh(now: now, timeZone: destination)
      assertDay(selection, 2026, 9, 5)
      XCTAssertFalse(selection.followsToday)
      var localCalendar = Calendar(identifier: .gregorian)
      localCalendar.timeZone = destination
      let components = localCalendar.dateComponents([.year, .month, .day], from: selection.localDate(in: destination))
      XCTAssertEqual(components.year, 2026)
      XCTAssertEqual(components.month, 9)
      XCTAssertEqual(components.day, 5)
    }
  }

  func testFollowingTodayTracksMidnightAndAChangedTimezoneButBrowsingDoesNot() {
    let beforeMidnight = date(2026, 9, 8, hour: 23, in: utc)
    let afterMidnight = date(2026, 9, 9, hour: 1, in: utc)
    var following = MacTodayDateSelection(now: beforeMidnight, timeZone: utc)
    following.refresh(now: afterMidnight, timeZone: utc)
    assertDay(following, 2026, 9, 9)
    let west = TimeZone(secondsFromGMT: -10 * 3600)!
    following.refresh(now: afterMidnight, timeZone: west)
    assertDay(following, 2026, 9, 8)

    following.select(date(2026, 9, 4, in: utc), now: afterMidnight, timeZone: utc)
    following.refresh(now: date(2026, 9, 10, in: utc), timeZone: utc)
    assertDay(following, 2026, 9, 4)
  }

  func testResetAndNavigationBackOntoTodayResumeTracking() {
    let now = date(2026, 9, 8, in: utc)
    var selection = MacTodayDateSelection(now: now, timeZone: utc)
    selection.move(by: -1, now: now, timeZone: utc)
    XCTAssertFalse(selection.followsToday)
    selection.move(by: 1, now: now, timeZone: utc)
    XCTAssertTrue(selection.followsToday)
    selection.refresh(now: date(2026, 9, 9, in: utc), timeZone: utc)
    assertDay(selection, 2026, 9, 9)
    selection.select(now, now: now, timeZone: utc)
    XCTAssertTrue(selection.isToday(now: now, timeZone: utc))
  }

  func testPickerAndNavigationClampToSameRangeAndKeepLeapDays() {
    let now = date(2026, 9, 8, in: utc)
    var selection = MacTodayDateSelection(now: now, timeZone: utc)
    selection.select(date(1800, 1, 1, in: utc), now: now, timeZone: utc)
    selection.move(by: -1, now: now, timeZone: utc)
    assertDay(selection, 1900, 1, 1)
    XCTAssertFalse(selection.canMoveBackward)
    XCTAssertTrue(MacTodayDateSelection.pickerRange(in: utc).contains(selection.localDate(in: utc)))
    selection.select(date(2200, 1, 1, in: utc), now: now, timeZone: utc)
    selection.move(by: 1, now: now, timeZone: utc)
    assertDay(selection, 2100, 12, 31)
    XCTAssertFalse(selection.canMoveForward)
    XCTAssertTrue(MacTodayDateSelection.pickerRange(in: utc).contains(selection.localDate(in: utc)))
    selection.select(date(2028, 2, 28, in: utc), now: now, timeZone: utc)
    selection.move(by: 1, now: now, timeZone: utc)
    assertDay(selection, 2028, 2, 29)
    selection.move(by: 1, now: now, timeZone: utc)
    assertDay(selection, 2028, 3, 1)
  }
}
#endif
