import Foundation
import XCTest
@testable import Prosary

@MainActor
final class MissionCalendarTests: XCTestCase {
  private struct FeastFixture: Decodable { let days: [String: FeastDay] }
  private struct ReadingDayFixture: Decodable { let readings: [ReadingCitation] }
  private struct ReadingFixture: Decodable { let days: [String: ReadingDayFixture] }

  private func bundled<T: Decodable>(_ type: T.Type, resource: String) throws -> T {
    let url = try XCTUnwrap(Bundle.main.url(forResource: resource, withExtension: "json"))
    return try JSONDecoder().decode(type, from: Data(contentsOf: url))
  }

  private func date(_ value: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return try XCTUnwrap(formatter.date(from: value))
  }

  func testProvisionalCalendarReflectionsStaySourceBoundedAndLanguageExact() throws {
    let old = UserDefaults.standard.object(forKey: TodayInfoStore.calendarDefaultsKey)
    defer { UserDefaults.standard.set(old, forKey: TodayInfoStore.calendarDefaultsKey) }
    UserDefaults.standard.set("mission-provisional", forKey: TodayInfoStore.calendarDefaultsKey)
    let day = try date("2026-01-01")
    let feast = try XCTUnwrap(TodayInfoStore.feast(on: day))
    XCTAssertEqual(feast.reflections(language: "iw-IL").count, 3)
    XCTAssertTrue(feast.reflections(language: "en").isEmpty)
    XCTAssertTrue(feast.reflections(language: "fr").isEmpty)
    XCTAssertEqual(TodayInfoStore.readings(on: day).map(\.full),
      ["Galatians 5:1–12", "Luke 2:21–21; 4:14–22"], "Mission uses the published Syriac appointments")
    XCTAssertNil(TodayInfoStore.feast(on: try date("2027-01-01")), "RRULE cannot establish future dates")
    let observance = try XCTUnwrap(feast.observances?.first)
    XCTAssertEqual(observance.saintDescription(language: "iw-IL")?.sections.map(\.id),
      observance.sections?.map(\.id), "The supplied source sections must replace the matching flattened prose")
    XCTAssertTrue(try XCTUnwrap(feast.reflections(language: "he").first).sections.isEmpty)
    XCTAssertTrue(try XCTUnwrap(observance.sourceDescriptionByLanguage?["he"]).contains("נקודה לערעור:"))
    XCTAssertTrue(try XCTUnwrap(observance.descriptionByLanguage?["he"]).contains("נקודה להרהור:"))
    XCTAssertEqual(observance.sourceRecurrence, "FREQ=YEARLY")
    XCTAssertEqual(observance.categories, [])
    XCTAssertEqual(observance.reflectionByLanguage?["he"], observance.sections?.first { $0.id == "reflection" }?.textByLanguage["he"])
    XCTAssertTrue(try XCTUnwrap(feast.reflections(language: "he").first?.credit).contains("תקופת ניסיון"))
  }

  func testMissionKeepsItsOwnFeastsWhileLoadingTheSyriacReadingsTable() throws {
    let defaults = UserDefaults.standard
    let previousCalendar = defaults.object(forKey: TodayInfoStore.calendarDefaultsKey)
    defer {
      if let previousCalendar { defaults.set(previousCalendar, forKey: TodayInfoStore.calendarDefaultsKey) }
      else { defaults.removeObject(forKey: TodayInfoStore.calendarDefaultsKey) }
    }
    let key = "2026-10-08"
    let day = try date(key)
    let expectedFeast = try XCTUnwrap(bundled(FeastFixture.self, resource: "feasts-mission-provisional").days[key])
    let expectedReadings = try XCTUnwrap(bundled(ReadingFixture.self, resource: "readings-syriac").days[key]).readings.map { citation in
      var captured = citation
      captured.readingDatasetID = "syriac"
      return captured
    }
    XCTAssertFalse(expectedReadings.isEmpty, "The supplied SYE table covers the reported current date")
    let calendar = try XCTUnwrap(TodayInfoStore.calendars.first { $0.id == "mission-provisional" })
    XCTAssertEqual(calendar.file, "feasts-mission-provisional")
    XCTAssertEqual(calendar.readingsFile, "readings-syriac")

    // Loading another rite first catches accidental retention of its cached readings.
    defaults.set("roman", forKey: TodayInfoStore.calendarDefaultsKey)
    let romanReadings = TodayInfoStore.readings(on: day)
    XCTAssertNotEqual(romanReadings.map(\.full), expectedReadings.map(\.full))
    defaults.set("mission-provisional", forKey: TodayInfoStore.calendarDefaultsKey)
    XCTAssertEqual(TodayInfoStore.feast(on: day), expectedFeast)
    XCTAssertTrue(try XCTUnwrap(TodayInfoStore.feast(on: day)?.observances).allSatisfy { $0.identity.hasPrefix("mission:") })
    let missionReadings = TodayInfoStore.readings(on: day)
    XCTAssertEqual(missionReadings, expectedReadings)
    XCTAssertEqual(missionReadings.map(\.full), ["Ephesians 6:10–24", "John 15:12–24"])
    XCTAssertTrue(missionReadings.allSatisfy { $0.readingDatasetID == "syriac" },
                  "Bible passage lookup uses the actual shared Syriac dataset, not the feast calendar ID")

    defaults.set("syriac", forKey: TodayInfoStore.calendarDefaultsKey)
    XCTAssertEqual(TodayInfoStore.readings(on: day), missionReadings)
    defaults.set("mission-provisional", forKey: TodayInfoStore.calendarDefaultsKey)
    XCTAssertEqual(TodayInfoStore.feast(on: day), expectedFeast)
    XCTAssertEqual(TodayInfoStore.readings(on: day), expectedReadings)
    XCTAssertTrue(TodayInfoStore.readings(on: try date("2031-08-01")).isEmpty,
                  "An uncovered date must not borrow readings from another calendar or date")
  }
}
