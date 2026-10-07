import Foundation
import XCTest
@testable import Prosary

@MainActor
final class MissionCalendarTests: XCTestCase {
  func testProvisionalCalendarReflectionsStaySourceBoundedAndLanguageExact() throws {
    let old = UserDefaults.standard.object(forKey: TodayInfoStore.calendarDefaultsKey)
    defer { UserDefaults.standard.set(old, forKey: TodayInfoStore.calendarDefaultsKey) }
    UserDefaults.standard.set("mission-provisional", forKey: TodayInfoStore.calendarDefaultsKey)
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    let day = try XCTUnwrap(formatter.date(from: "2026-01-01"))
    let feast = try XCTUnwrap(TodayInfoStore.feast(on: day))
    XCTAssertEqual(feast.reflections(language: "iw-IL").count, 3)
    XCTAssertTrue(feast.reflections(language: "en").isEmpty)
    XCTAssertTrue(feast.reflections(language: "fr").isEmpty)
    XCTAssertTrue(TodayInfoStore.readings(on: day).isEmpty, "No readings were supplied for the provisional calendar")
    XCTAssertNil(TodayInfoStore.feast(on: try XCTUnwrap(formatter.date(from: "2027-01-01"))), "RRULE cannot establish future dates")
    let observance = try XCTUnwrap(feast.observances?.first)
    XCTAssertTrue(try XCTUnwrap(observance.sourceDescriptionByLanguage?["he"]).contains("נקודה לערעור:"))
    XCTAssertTrue(try XCTUnwrap(observance.descriptionByLanguage?["he"]).contains("נקודה להרהור:"))
    XCTAssertEqual(observance.sourceRecurrence, "FREQ=YEARLY")
    XCTAssertEqual(observance.categories, [])
    XCTAssertEqual(observance.reflectionByLanguage?["he"], observance.sections?.first { $0.id == "reflection" }?.textByLanguage["he"])
    XCTAssertTrue(try XCTUnwrap(feast.reflections(language: "he").first?.credit).contains("תקופת ניסיון"))
  }
}
