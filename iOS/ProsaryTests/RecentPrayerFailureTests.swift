import XCTest
@testable import Prosary

@MainActor
final class RecentPrayerFailureTests: XCTestCase {
  private enum LookupFailure: Error { case unavailable }

  func testRefreshRetainsFailedLookupsWhilePruningDeletedCopiesAndUpdatingNames() async throws {
    let suite = "RecentPrayerFailureTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let unavailableID = UUID()
    let deletedID = UUID()
    let renamed = Prayer(name: "Renamed prayer", kind: .rosary)
    let stored = RecentPrayerStore(defaults: defaults)
    stored.record(.prayer(id: unavailableID), title: "Keep this title", at: Date(timeIntervalSince1970: 1))
    stored.record(.prayer(id: deletedID), title: "Deleted copy", at: Date(timeIntervalSince1970: 2))
    stored.record(.prayer(id: renamed.id), title: "Old title", at: Date(timeIntervalSince1970: 3))
    let history = RecentPrayers(defaults: defaults) { id in
      if id == unavailableID { throw LookupFailure.unavailable }
      return id == renamed.id ? renamed : nil
    }

    await history.refresh()

    XCTAssertEqual(history.entries.map(\.title), ["Renamed prayer", "Keep this title"])
    XCTAssertEqual(stored.entries, history.entries)
    XCTAssertEqual(history.entries.last?.lastPrayedAt, Date(timeIntervalSince1970: 1))
  }

  func testFailedOpenAndRecordLeaveSavedHistoryUnchanged() async throws {
    let suite = "RecentPrayerFailureTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let prayerID = UUID()
    let stored = RecentPrayerStore(defaults: defaults)
    stored.record(.prayer(id: prayerID), title: "Preserve me", at: Date(timeIntervalSince1970: 1))
    let before = stored.entries
    let history = RecentPrayers(defaults: defaults) { _ in throw LookupFailure.unavailable }

    let route = await history.routeForOpening(id: try XCTUnwrap(before.first?.id))
    await history.record(.prayer(id: prayerID))

    XCTAssertNil(route)
    XCTAssertEqual(history.entries, before)
    XCTAssertEqual(stored.entries, before)
  }
}
