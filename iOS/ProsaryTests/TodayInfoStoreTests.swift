//
//  TodayInfoStoreTests.swift
//  ProsaryTests
//
//  Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
//  movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
//  Roman Calendar), the Pope's monthly intention, and the graceful out-of-range nil that hides
//  the row.
//

import XCTest
@testable import Prosary

@MainActor
final class TodayInfoStoreTests: XCTestCase {
  private func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: string)!
  }

  func testFixedSolemnityResolves() {
    let feast = TodayInfoStore.feast(on: date("2026-12-25"))
    XCTAssertEqual(feast?.title, "Christmas")
    XCTAssertEqual(feast?.rank, "Solemnity")
  }

  func testMovableFeastIsBakedInPerYear() {
    // Easter falls on April 5 in 2026 and March 28 in 2027 — both must resolve.
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-04-05"))?.rank, "Solemnity")
    XCTAssertNotNil(TodayInfoStore.feast(on: date("2027-03-26")))  // Good Friday 2027
  }

  /// The Holy Land calendar's own principal feast overlays the General Roman Calendar — in 2026
  /// October 25 is a Sunday of Ordinary Time in the GRC, but the diocese's patronal solemnity
  /// takes precedence.
  func testLatinPatriarchatePropersOverlayTheGeneralCalendar() {
    let feast = TodayInfoStore.feast(on: date("2026-10-25"))
    XCTAssertEqual(feast?.title, "Our Lady, Queen of Palestine and of the Holy Land")
    XCTAssertEqual(feast?.rank, "Solemnity")

    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-07-15"))?.title,
      "Dedication of the Basilica of the Holy Sepulchre")
  }

  func testFerialDayHasNoFeast() {
    // An ordinary weekday with no memorial in either calendar.
    XCTAssertNil(TodayInfoStore.feast(on: date("2026-07-27")))
  }

  func testDateOutsideTheGeneratedYearsHasNoFeast() {
    XCTAssertNil(TodayInfoStore.feast(on: date("2031-12-25")))
  }

  func testMonthIntentionResolves() {
    let intention = TodayInfoStore.intention(for: date("2026-07-27"))
    XCTAssertEqual(intention?.title, "For respect for human life")
    XCTAssertTrue(intention?.text.contains("human life in all its stages") ?? false)
  }

  func testMonthOutsideThePublishedListHasNoIntention() {
    XCTAssertNil(TodayInfoStore.intention(for: date("2031-05-01")))
  }
}
