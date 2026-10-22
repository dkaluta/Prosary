import XCTest
@testable import Prosary

@MainActor
final class Version021PresentationTests: XCTestCase {
  func testPendingPhotoImportCannotCommitAfterRemovalOrReplaceANewerRequest() {
    var imports = HomeGraphicImportState()
    let first = imports.begin(.calendar)
    XCTAssertTrue(imports.canCommit(first, widgets: [.calendar]))
    imports.cancel(.calendar)
    XCTAssertFalse(imports.canCommit(first, widgets: [.calendar]), "Removing an image cancels the pending picker read")
    let replacement = imports.begin(.calendar)
    imports.finish(first)
    XCTAssertTrue(imports.canCommit(replacement, widgets: [.calendar]), "An old cancellation must not clear the new import")
    XCTAssertFalse(imports.canCommit(replacement, widgets: []), "Removing the target card prevents a commit before private files change")
    imports.cancel(.calendar)
    XCTAssertNil(imports.active)
  }

  func testSmallWidgetsPersistIndependentlyAndInvalidGraphicsCannotEscapePrivateStorage() {
    XCTAssertTrue(HomeWidgetDisplay.collapsed("").isEmpty)
    XCTAssertEqual(HomeWidgetDisplay.collapsed("calendar\nfuture\ncalendar\nreadings"), [.calendar, .readings])
    let selection: Set<HomeWidget> = [.scripture, .calendar]
    XCTAssertEqual(HomeWidgetDisplay.collapsed(HomeWidgetDisplay.encodeCollapsed(selection)), selection)
    let valid = HomePhotoStore.directory.appendingPathComponent("fixture.jpg").path
    let values: [HomeWidget: String] = [.calendar: valid, .scripture: "/private/tmp/unowned.jpg"]
    XCTAssertEqual(HomeWidgetDisplay.graphics(HomeWidgetDisplay.encodeGraphics(values)), [.calendar: valid])
    XCTAssertTrue(HomeWidgetDisplay.graphics("not JSON").isEmpty)
    XCTAssertTrue(HomeWidgetDisplay.graphics(#"{"unknown":"/tmp/x.jpg","readings":"/tmp/x.jpg"}"#).isEmpty)
  }

  func testCivilMonthStartsWithMondayAndRetainsLeapDay() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 15)))
    let cells = CalendarEventPresentation.monthCells(for: date, calendar: calendar)
    XCTAssertEqual(cells.prefix(3).compactMap { $0 }.count, 0, "February 2024 begins Thursday, after three Monday-first blanks")
    XCTAssertEqual(cells.compactMap { $0 }.count, 29)
    XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(cells[3])), 1)
    XCTAssertEqual(cells.count % 7, 0)
  }

  func testEveryAuthoredObservanceHasADistinctEventAndExactLanguageDescription() throws {
    let feast = try JSONDecoder().decode(FeastDay.self, from: Data(#"""
      {"title":"Day","rank":"Memorial","observances":[
        {"title":"First","identity":"same","descriptionByLanguage":{"en":"Exact source prose."}},
        {"title":"Second","identity":"same","descriptionByLanguage":{"he":"מקור"}}
      ]}
      """#.utf8))
    let events = CalendarEventPresentation.events(on: Date(), feast: feast)
    XCTAssertEqual(events.count, 2)
    XCTAssertNotEqual(events[0].id, events[1].id)
    XCTAssertEqual(events[0].description("en")?.text, "Exact source prose.")
    XCTAssertNil(events[1].description("en"), "Descriptions never borrow another language")
    XCTAssertEqual(events[1].description("he")?.text, "מקור")
    XCTAssertEqual(CalendarEventPresentation.events(on: Date(), feast: FeastDay(title: "Published weekday", rank: "Weekday")).count, 1)
    XCTAssertTrue(CalendarEventPresentation.events(on: Date(), feast: nil).isEmpty)
  }

  func testDailyScriptureUsesFirstGospelInSourceOrderOrFirstAppointment() throws {
    let readings = try JSONDecoder().decode([ReadingCitation].self, from: Data(#"""
      [{"type":"first","short":"first","full":"First source citation"},
       {"type":"gospel","short":"gospel","full":"First Gospel citation"},
       {"type":"gospel","short":"other","full":"Second Gospel citation"}]
      """#.utf8))
    XCTAssertEqual(TodayInfoStore.scriptureOfTheDay(in: readings)?.full, "First Gospel citation")
    XCTAssertEqual(TodayInfoStore.scriptureOfTheDay(in: Array(readings.prefix(1)))?.full, "First source citation")
    XCTAssertNil(TodayInfoStore.scriptureOfTheDay(in: []))
  }
}
