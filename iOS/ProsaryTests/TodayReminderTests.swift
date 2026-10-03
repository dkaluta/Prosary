import Foundation
import XCTest
@testable import Prosary

@MainActor
final class TodayReminderTests: XCTestCase {
  func testDateSpecificRemindersKeepLocalTimeAcrossDaylightSaving() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/New_York"))
    let before = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 9)))
    let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: before))
    let fire = try XCTUnwrap(TodayReminderScheduler.deliveryDate(on: nextDay, minutes: 540, after: before, calendar: calendar))
    XCTAssertEqual(calendar.component(.hour, from: fire), 9)
    XCTAssertEqual(fire.timeIntervalSince(before), 23 * 3600)
    XCTAssertNil(TodayReminderScheduler.deliveryDate(on: before, minutes: 540, after: before, calendar: calendar))
  }

  func testSaintNotificationRetainsSourceTextAndCreditWithoutLanguageFallback() throws {
    let feast = try JSONDecoder().decode(FeastDay.self, from: Data(#"""
      {"title":"Fixture feast","rank":"Feast","observances":[
        {"title":"Fixture saint","identity":"fixture","descriptionByLanguage":{"he":"Source paragraph."},
         "descriptionCreditByLanguage":{"he":"Source credit."}}
      ]}
      """#.utf8))
    let sourced = TodayReminderScheduler.saintBody(feast: feast, calendarID: "syriac", language: "he")
    XCTAssertTrue(sourced.contains("Source paragraph."))
    XCTAssertTrue(sourced.contains("Source credit."))
    for (calendar, language) in [("syriac", "en"), ("roman", "en")] {
      let fallback = TodayReminderScheduler.saintBody(feast: feast, calendarID: calendar, language: language)
      XCTAssertTrue(fallback.contains("Fixture feast"))
      XCTAssertFalse(fallback.contains("Source paragraph."))
    }
  }
}
