import XCTest
@testable import Prosary

final class RecentPrayerTests: XCTestCase {
  func testRecentPrayersPersistDeduplicateAndKeepTheNewestEight() throws {
    let suite = "RecentPrayerTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RecentPrayerStore(defaults: defaults)
    for count in 1...10 {
      store.record(.jesusPrayer(target: .count(count)), title: "Prayer \(count)", at: Date(timeIntervalSince1970: Double(count)))
    }
    XCTAssertEqual(store.entries.count, 8)
    XCTAssertEqual(store.entries.first?.title, "Prayer 10")
    XCTAssertEqual(store.entries.last?.title, "Prayer 3")
    store.record(.jesusPrayer(target: .count(3)), title: "Revisited", at: Date(timeIntervalSince1970: 20))
    let restored = RecentPrayerStore(defaults: defaults)
    XCTAssertEqual(restored.entries.count, 8)
    XCTAssertEqual(restored.entries.first?.title, "Revisited")
    XCTAssertEqual(restored.entries.filter { $0.route == .jesusPrayer(target: .count(3)) }.count, 1)
  }

  func testOnlyPlayableDestinationsEnterTheHistory() throws {
    let suite = "RecentPrayerTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RecentPrayerStore(defaults: defaults)
    for route in [AppRoute.about, .rosaryPresets, .jesusPrayerSetup, .basicPrayers] {
      store.record(route, title: "Not a prayer")
    }
    XCTAssertTrue(store.entries.isEmpty)
    for route in [AppRoute.prayer(id: UUID()), .custom(devotionId: "angelus"), .basicPrayer(id: "ourFather"),
                  .jesusPrayer(target: .unbounded), .rosaryQuickPray(prayer: Prayer())] {
      XCTAssertNotNil(RecentPrayerStore.identity(for: route))
    }
  }

  func testQuickRosaryDeduplicatesConfigurationInsteadOfTemporaryID() {
    let first = Prayer()
    var second = first
    second.id = UUID()
    XCTAssertEqual(RecentPrayerStore.identity(for: .rosaryQuickPray(prayer: first)),
                   RecentPrayerStore.identity(for: .rosaryQuickPray(prayer: second)))
    second.rosary.includeApostlesCreed.toggle()
    XCTAssertNotEqual(RecentPrayerStore.identity(for: .rosaryQuickPray(prayer: first)),
                      RecentPrayerStore.identity(for: .rosaryQuickPray(prayer: second)))
  }
}
