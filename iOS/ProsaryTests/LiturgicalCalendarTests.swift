
//
//  LiturgicalCalendarTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class LiturgicalCalendarTests: XCTestCase {
  private let cal = StubLiturgicalCalendar()
  private let utc = TimeZone(identifier: "UTC")!

  // MARK: - Helpers

  private func date(year: Int, month: Int, day: Int) -> Date {
    var comps = DateComponents()
    comps.year = year; comps.month = month; comps.day = day
    comps.timeZone = utc
    return Calendar(identifier: .gregorian).date(from: comps)!
  }

  // MARK: - Easter algorithm (known reference dates)

  func testEasterSunday2024() {
    // Easter 2024 = March 31
    let easter = StubLiturgicalCalendar.computeEasterSunday(year: 2024)
    let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: easter)
    XCTAssertEqual(comps.month, 3)
    XCTAssertEqual(comps.day, 31)
  }

  func testEasterSunday2025() {
    // Easter 2025 = April 20
    let easter = StubLiturgicalCalendar.computeEasterSunday(year: 2025)
    let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: easter)
    XCTAssertEqual(comps.month, 4)
    XCTAssertEqual(comps.day, 20)
  }

  func testEasterSunday2026() {
    // Easter 2026 = April 5
    let easter = StubLiturgicalCalendar.computeEasterSunday(year: 2026)
    let comps = Calendar(identifier: .gregorian).dateComponents(in: utc, from: easter)
    XCTAssertEqual(comps.month, 4)
    XCTAssertEqual(comps.day, 5)
  }

  // MARK: - isEasterSeason

  func testEasterSundayIsEasterSeason() {
    let easterSunday = date(year: 2026, month: 4, day: 5)
    XCTAssertTrue(cal.isEasterSeason(for: easterSunday))
  }

  func testDayBeforeEasterIsNotEasterSeason() {
    let holySaturday = date(year: 2026, month: 4, day: 4)
    XCTAssertFalse(cal.isEasterSeason(for: holySaturday))
  }

  func testPentecostIsNotEasterSeason() {
    // Pentecost 2026 = May 24 (49 days after April 5)
    let pentecost = date(year: 2026, month: 5, day: 24)
    XCTAssertFalse(cal.isEasterSeason(for: pentecost))
  }

  func testDayBeforePentecostIsEasterSeason() {
    // May 23, 2026 — last day of Easter season
    let lastDay = date(year: 2026, month: 5, day: 23)
    XCTAssertTrue(cal.isEasterSeason(for: lastDay))
  }

  // MARK: - Season identification

  func testLentOnAshWednesday() {
    // Ash Wednesday 2026 = February 18 (46 days before April 5)
    let ashWed = date(year: 2026, month: 2, day: 18)
    XCTAssertEqual(cal.season(for: ashWed), .lent)
  }

  func testAdventInDecember() {
    // Advent 2025 starts Nov 30
    let adventDay = date(year: 2025, month: 12, day: 1)
    XCTAssertEqual(cal.season(for: adventDay), .advent)
  }

  func testChristmasDayIsChristmasSeason() {
    let christmas = date(year: 2025, month: 12, day: 25)
    XCTAssertEqual(cal.season(for: christmas), .christmas)
  }

  func testOrdinaryTimeInJune() {
    let june = date(year: 2026, month: 6, day: 15)
    XCTAssertEqual(cal.season(for: june), .other)
  }

  // MARK: - Mystery group by weekday (using a known Monday/Tuesday/etc.)

  func testMondayIsJoyful() {
    // 2026-07-20 is a Monday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 20)), .joyful)
  }

  func testTuesdayIsSorrowful() {
    // 2026-07-21 is a Tuesday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 21)), .sorrowful)
  }

  func testWednesdayIsGlorious() {
    // 2026-07-22 is a Wednesday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 22)), .glorious)
  }

  func testThursdayIsLuminous() {
    // 2026-07-23 is a Thursday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 23)), .luminous)
  }

  func testFridayIsSorrowful() {
    // 2026-07-24 is a Friday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 24)), .sorrowful)
  }

  func testSaturdayIsJoyful() {
    // 2026-07-25 is a Saturday
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 25)), .joyful)
  }

  func testSundayInOrdinaryTimeIsGlorious() {
    // 2026-07-26 is a Sunday in Ordinary Time
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 7, day: 26)), .glorious)
  }

  func testSundayInLentIsSorrowful() {
    // Palm Sunday 2026 = March 29
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2026, month: 3, day: 29)), .sorrowful)
  }

  func testSundayInAdventIsJoyful() {
    // First Sunday of Advent 2025 = Nov 30
    XCTAssertEqual(cal.mysteryGroup(for: date(year: 2025, month: 11, day: 30)), .joyful)
  }

  // MARK: - Seasonal Marian antiphon

  func testAntiphonInOrdinaryTimeIsSalveRegina() {
    XCTAssertEqual(cal.seasonalMarianAntiphon(for: date(year: 2026, month: 7, day: 24)), .salveRegina)
  }

  func testAntiphonInAdventIsAlmaRedemptorisMater() {
    XCTAssertEqual(cal.seasonalMarianAntiphon(for: date(year: 2025, month: 12, day: 1)), .almaRedemptorisMater)
  }

  func testAntiphonInLentIsAveReginaCaelorum() {
    XCTAssertEqual(cal.seasonalMarianAntiphon(for: date(year: 2026, month: 3, day: 1)), .aveReginaCaelorum)
  }

  func testAntiphonInEasterSeasonIsReginaCaeli() {
    let easterMonday = date(year: 2026, month: 4, day: 6)
    XCTAssertEqual(cal.seasonalMarianAntiphon(for: easterMonday), .reginaCaeli)
  }
}
