import XCTest
@testable import Prosary

final class RecentPrayerTests: XCTestCase {
  func testRetirementRemovesOldStandaloneRoutesAndRejectsNewHistoryEntries() throws {
    let suite = "RecentPrayerTests.Retired.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = RecentPrayerStore(defaults: defaults)
    let id = RetiredPrayerBundles.loretoStandaloneID
    let old = RecentPrayer(id: "custom:\(id):", route: .custom(devotionId: id),
      title: "Old standalone", lastPrayedAt: Date())
    let builtin = RecentPrayer(id: "custom:litanyOfLoreto:", route: .custom(devotionId: "litanyOfLoreto"),
      title: "Built-in Loreto", lastPrayedAt: Date())
    defaults.set(try JSONEncoder().encode([old, builtin]), forKey: RecentPrayerStore.defaultsKey)
    XCTAssertEqual(store.entries, [builtin])
    store.record(.custom(devotionId: id), title: "Retired standalone")
    XCTAssertEqual(store.entries, [builtin])
    XCTAssertNil(RecentPrayerStore.identity(for: .custom(devotionId: id)))
    XCTAssertNotNil(RecentPrayerStore.identity(for: .custom(devotionId: "repo.stgamliel-il.otherPrayer")))
  }

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
