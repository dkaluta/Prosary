import XCTest
@testable import Prosary

final class SystemCalendarMonthTests: XCTestCase {
  func testWeekStartChangesPaddingWithoutChangingCivilDates() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))
    calendar.firstWeekday = 1
    let sunday = CalendarEventPresentation.monthCells(for: date, calendar: calendar)
    calendar.firstWeekday = 2
    let monday = CalendarEventPresentation.monthCells(for: date, calendar: calendar)
    XCTAssertEqual(sunday.firstIndex(where: { $0 != nil }), 4)
    XCTAssertEqual(monday.firstIndex(where: { $0 != nil }), 3)
    XCTAssertEqual(sunday.compactMap { $0 }, monday.compactMap { $0 })
    XCTAssertEqual(sunday.compactMap { $0 }.count, 29)
  }

  func testHebrewLeapMonthsUseTheirOwnBoundariesAndRetainCivilIdentity() throws {
    var civil = Calendar(identifier: .gregorian)
    civil.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
    var hebrew = Calendar(identifier: .hebrew)
    hebrew.timeZone = civil.timeZone
    hebrew.firstWeekday = 1
    // Adar I and Adar II of 5784, rather than two fragments of Gregorian months.
    for (month, day, length) in [(2, 20, 30), (3, 20, 29)] {
      let date = try XCTUnwrap(civil.date(from: DateComponents(year: 2024, month: month, day: day, hour: 12)))
      let cells = CalendarEventPresentation.monthCells(for: date, calendar: hebrew)
      let days = cells.compactMap { $0 }
      XCTAssertEqual(days.count, length)
      XCTAssertEqual(hebrew.component(.day, from: try XCTUnwrap(days.first)), 1)
      XCTAssertEqual(Set(days.map { hebrew.component(.month, from: $0) }).count, 1)
      XCTAssertTrue(days.contains { civil.isDate($0, inSameDayAs: date) })
      XCTAssertEqual(cells.count % 7, 0)
    }
  }
}
