import Foundation
import XCTest
@testable import Prosary

@MainActor
final class WidgetDataReaderTests: XCTestCase {
  private let registry = #"""
    {"default":"lpj","calendars":[
      {"id":"lpj","file":"feasts","readingsFile":"readings-roman"},
      {"id":"roman","file":"feasts-roman","readingsFile":"readings-roman"},
      {"id":"other","file":"feasts-other","readingsFile":"missing-readings"},
      {"id":"ugcc","file":"feasts-julian","readingsFile":"readings-julian",
       "defaultPaschaStyle":"julian","paschaVariants":{
         "julian":{"file":"feasts-julian","readingsFile":"readings-julian"},
         "gregorian":{"file":"feasts-gregorian","readingsFile":"readings-gregorian"}
       }}
    ]}
    """#

  private var day: Date {
    Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 12))!
  }

  private func withBundle(_ files: [String: String], perform: (Bundle) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("WidgetDataReaderTests-\(UUID().uuidString).bundle", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let info: [String: Any] = [
      "CFBundleIdentifier": "com.dkaluta.prosary.widget-test.\(UUID().uuidString)",
      "CFBundleName": "Widget test data", "CFBundlePackageType": "BNDL",
    ]
    let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
    try plist.write(to: directory.appendingPathComponent("Info.plist"))
    for (name, contents) in files {
      try Data(contents.utf8).write(to: directory.appendingPathComponent("\(name).json"))
    }
    try perform(XCTUnwrap(Bundle(url: directory)))
  }

  private func titles(_ value: String) -> String {
    #"{"days":{"2026-09-10":{"title":"\#(value)"}}}"#
  }

  private func citations(_ value: String) -> String {
    #"{"days":{"2026-09-10":{"readings":[{"short":"\#(value)"}]}}}"#
  }

  func testCalendarSelectionNeverBorrowsMissingReadingsFromTheDefaultRite() throws {
    try withBundle([
      "calendars": registry,
      "feasts": titles("Default calendar fixture"),
      "readings-roman": citations("Default reading fixture"),
      "feasts-other": titles("Other calendar fixture"),
    ]) { bundle in
      let standard = WidgetTodayReader(settings: .init(), bundle: bundle).content(on: day)
      XCTAssertEqual(standard.readings, ["Default reading fixture"])

      let selected = WidgetTodayReader(settings: .init(calendarID: "other"), bundle: bundle).content(on: day)
      XCTAssertEqual(selected.feast, "Other calendar fixture")
      XCTAssertEqual(selected.readings, [])
    }
  }

  func testPaschaStyleSelectsBothFeastsAndReadingsTogether() throws {
    try withBundle([
      "calendars": registry,
      "feasts-julian": titles("Julian fixture"), "readings-julian": citations("Julian reading fixture"),
      "feasts-gregorian": titles("Gregorian fixture"), "readings-gregorian": citations("Gregorian reading fixture"),
    ]) { bundle in
      for (style, expected) in [("julian", "Julian"), ("gregorian", "Gregorian"), ("invalid", "Julian")] {
        let content = WidgetTodayReader(
          settings: .init(calendarID: "ugcc", easternPaschaStyle: style), bundle: bundle).content(on: day)
        XCTAssertEqual(content.feast, "\(expected) fixture", style)
        XCTAssertEqual(content.readings, ["\(expected) reading fixture"], style)
      }
    }
  }

  func testHidingFeastKeepsReadingsAndHonorsOtherIndependentVisibilityFlags() throws {
    try withBundle([
      "calendars": registry, "feasts": titles("Feast fixture"),
      "readings-roman": citations("Reading fixture"),
      "pope-intentions": #"{"months":{"2026-09":{"title":"Intention fixture"}}}"#,
      "torah-portions": titles("Torah fixture"),
    ]) { bundle in
      let hidden = WidgetTodayReader(settings: .init(showFeast: false, showIntention: false, showTorah: false),
                                     bundle: bundle).content(on: day)
      XCTAssertNil(hidden.feast)
      XCTAssertEqual(hidden.readings, ["Reading fixture"])
      XCTAssertNil(hidden.intention)
      XCTAssertNil(hidden.torah)

      let enabled = WidgetTodayReader(settings: .init(showFeast: false, showIntention: true, showTorah: true),
                                      bundle: bundle).content(on: day)
      XCTAssertNil(enabled.feast)
      XCTAssertEqual(enabled.readings, ["Reading fixture"])
      XCTAssertEqual(enabled.intention, "Intention fixture")
      XCTAssertEqual(enabled.torah, "Torah fixture")
    }
  }

  func testLanguageAliasesAndSourceFallbackDoNotChangeCalendarIdentity() throws {
    try withBundle([
      "calendars": registry,
      "feasts": #"{"days":{"2026-09-10":{"title":"Source fixture","titleByLanguage":{"he":"שָׁלוֹם","tl":"Filipino fixture","ar":"Arabic fixture","ru":"Russian fixture","fr":"French fixture","it":"Italian fixture","uk":"Ukrainian fixture"}}}}"#,
      "readings-roman": #"{"days":{"2026-09-10":{"readings":[{"short":"Source citation","shortByLanguage":{"he":"שָׁלוֹם","tl":"Filipino citation"}}]}}}"#,
    ]) { bundle in
      for (language, expectedTitle, expectedCitation, rtl) in [
        ("iw-IL", "שלום", "שָׁלוֹם", true),
        ("fil_PH", "Filipino fixture", "Filipino citation", false),
        ("ar", "Arabic fixture", "Source citation", true),
        ("ru", "Russian fixture", "Source citation", false),
        ("fr", "French fixture", "Source citation", false),
        ("it", "Italian fixture", "Source citation", false),
        ("uk", "Ukrainian fixture", "Source citation", false),
        ("en", "Source fixture", "Source citation", false),
        ("unsupported", "Source fixture", "Source citation", false),
      ] {
        let settings = WidgetTodaySettings(languageCode: language)
        let content = WidgetTodayReader(settings: settings, bundle: bundle).content(on: day)
        XCTAssertEqual(content.feast, expectedTitle, language)
        XCTAssertEqual(content.readings, [expectedCitation], language)
        XCTAssertEqual(settings.isRightToLeft, rtl, language)
      }
    }
  }

  func testLegacyCalendarAliasAndUnknownCalendarUseTheCorrectRegistryEntry() throws {
    try withBundle([
      "calendars": registry,
      "feasts": titles("Default fixture"), "feasts-roman": titles("Roman fixture"),
      "readings-roman": citations("Reading fixture"),
    ]) { bundle in
      XCTAssertEqual(WidgetTodayReader(settings: .init(calendarID: "roman-he"), bundle: bundle)
        .content(on: day).feast, "Roman fixture")
      XCTAssertEqual(WidgetTodayReader(settings: .init(calendarID: "removed-calendar"), bundle: bundle)
        .content(on: day).feast, "Default fixture")
    }
  }

  func testMissingDatesAndCorruptReadingsAreEmptyWithoutDiscardingAvailableFeasts() throws {
    try withBundle([
      "calendars": registry, "feasts": titles("Feast fixture"), "readings-roman": "not valid JSON",
    ]) { bundle in
      let reader = WidgetTodayReader(settings: .init(), bundle: bundle)
      XCTAssertEqual(reader.content(on: day).feast, "Feast fixture")
      XCTAssertEqual(reader.content(on: day).readings, [])
      let nextDay = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: day)!
      XCTAssertNil(reader.content(on: nextDay).feast)
      XCTAssertEqual(reader.content(on: nextDay).readings, [])
    }
    try withBundle([
      "calendars": "not valid JSON", "feasts": titles("Must not leak"),
      "pope-intentions": #"{"months":{"2026-09":{"title":"Independent intention"}}}"#,
    ]) { bundle in
      let content = WidgetTodayReader(settings: .init(), bundle: bundle).content(on: day)
      XCTAssertNil(content.feast)
      XCTAssertEqual(content.readings, [])
      XCTAssertEqual(content.intention, "Independent intention")
    }
  }

  func testLocalDateKeyUsesTheRequestedTimeZoneRatherThanTheUTCDate() throws {
    let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-09-10T22:30:00Z"))
    XCTAssertEqual(ProsaryWidgetSnapshot.localDateKey(instant, timeZone: try XCTUnwrap(TimeZone(identifier: "Asia/Jerusalem"))),
                   "2026-09-11")
    XCTAssertEqual(ProsaryWidgetSnapshot.localDateKey(instant, timeZone: try XCTUnwrap(TimeZone(identifier: "America/New_York"))),
                   "2026-09-10")
  }
}
