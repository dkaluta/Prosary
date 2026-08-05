//
//  MultiDayRunTests.swift
//  ProsaryTests
//
//  The rules that make a multi-day devotion behave like a calendar rather than a counter.
//

import XCTest
@testable import Prosary

final class MultiDayRunTests: XCTestCase {
  private let nine = 9
  private func day(_ offset: Int, from start: Date) -> Date {
    Calendar.current.date(byAdding: .day, value: offset, to: start)!
  }

  func testPrayingTwiceInOneDayDoesNotAdvance() {
    let start = Date()
    var run = MultiDayRun(devotionId: "novena", startedOn: start)
    run.recordPrayed(day: 0, on: start)

    XCTAssertTrue(run.hasPrayedToday(on: start))
    // Same calendar day: the next unprayed day exists, but today's is already done.
    XCTAssertEqual(run.dueDay(dayCount: nine, on: start), 0)
    XCTAssertEqual(run.nextUnprayedDay(dayCount: nine), 1)
  }

  func testTheNextCalendarDayOffersTheNextDay() {
    let start = Date()
    var run = MultiDayRun(devotionId: "novena", startedOn: start)
    run.recordPrayed(day: 0, on: start)

    let tomorrow = day(1, from: start)
    XCTAssertFalse(run.hasPrayedToday(on: tomorrow))
    XCTAssertEqual(run.resumption(dayCount: nine, on: tomorrow), .resume(day: 1))
    XCTAssertNil(run.missedDay(dayCount: nine, on: tomorrow))
  }

  func testAMissedDayOffersBothItAndTheCalendarDay() {
    let start = Date()
    var run = MultiDayRun(devotionId: "novena", startedOn: start)
    run.recordPrayed(day: 0, on: start)

    // Day 2 (index 1) was due yesterday and never prayed; today the calendar wants index 2.
    let dayAfterNext = day(2, from: start)
    XCTAssertEqual(run.missedDay(dayCount: nine, on: dayAfterNext), 1)
    XCTAssertEqual(run.dueDay(dayCount: nine, on: dayAfterNext), 2)
    XCTAssertEqual(run.resumption(dayCount: nine, on: dayAfterNext), .choose(missed: 1, next: 2))
  }

  func testTheDayCountComesFromTheDevotion() {
    let start = Date()
    var triduum = MultiDayRun(devotionId: "triduum", startedOn: start)
    triduum.recordPrayed(day: 0, on: start)
    triduum.recordPrayed(day: 1, on: day(1, from: start))
    XCTAssertFalse(triduum.isComplete(dayCount: 3))

    triduum.recordPrayed(day: 2, on: day(2, from: start))
    XCTAssertTrue(triduum.isComplete(dayCount: 3))
    XCTAssertEqual(triduum.resumption(dayCount: 3, on: day(2, from: start)), .complete)
    // The same run is nowhere near done if the devotion is longer.
    XCTAssertFalse(triduum.isComplete(dayCount: 33))
  }

  func testDueDayNeverRunsPastTheLastDay() {
    let start = Date()
    let run = MultiDayRun(devotionId: "novena", startedOn: start)
    XCTAssertEqual(run.dueDay(dayCount: nine, on: day(400, from: start)), 8)
  }
}

/// The announcement a pinned series makes before it has begun.
final class MultiDayStartDateTests: XCTestCase {
  private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
  }

  func testAnUpcomingDateResolvesToThisYear() {
    let start = MultiDayStatus.startDate("11-29", on: date(2026, 8, 5))
    XCTAssertEqual(start, date(2026, 11, 29))
  }

  func testAPassedDateResolvesToNextYear() {
    // The Immaculate Conception novena has already run this year; announce the coming one.
    let start = MultiDayStatus.startDate("11-29", on: date(2026, 12, 20))
    XCTAssertEqual(start, date(2027, 11, 29))
  }

  func testTodayCountsAsUpcoming() {
    let start = MultiDayStatus.startDate("11-29", on: date(2026, 11, 29))
    XCTAssertEqual(start, date(2026, 11, 29))
  }

  func testNoDeclarationMeansNoAnnouncement() {
    XCTAssertNil(MultiDayStatus.startDate(nil, on: date(2026, 8, 5)))
    XCTAssertNil(MultiDayStatus.startDate("not-a-date", on: date(2026, 8, 5)))
  }
}
