import Combine
import XCTest
@testable import Prosary

@MainActor
final class PrayerLanguageMonitorTests: XCTestCase {
  func testInitialSnapshotUsesInjectedPreferencesAndResolvedFallbackOrder() throws {
    let suite = "PrayerLanguageMonitorTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set(true, forKey: PrayerNamePresentation.defaultsKey)
    defaults.set(true, forKey: JaffaHailMaryWording.defaultsKey)
    let monitor = PrayerLanguageMonitor(defaults: defaults, notificationCenter: NotificationCenter(),
      resolveCode: { "ar" }, resolveFallbackOrder: { ["he-x-gamliel", "he", "en", "la"] })

    XCTAssertEqual(monitor.code, "ar")
    XCTAssertEqual(monitor.fallbackOrder, ["he-x-gamliel", "he", "en", "la"])
    XCTAssertTrue(monitor.showsPrayerNameInPrayerLanguage)
    XCTAssertTrue(monitor.usesJaffaHailMaryWording)
  }

  func testFallbackOnlyChangePublishesAfterTheMainRunLoopWithoutChangingSelectedLanguage() async throws {
    let suite = "PrayerLanguageMonitorTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let notifications = NotificationCenter()
    let original = ["he", "en", "la"]
    let reordered = ["en", "he", "la"]
    defaults.set(original, forKey: LanguageCatalog.fallbackOrderKey)
    let monitor = PrayerLanguageMonitor(defaults: defaults, notificationCenter: notifications,
      resolveCode: { "ar" },
      resolveFallbackOrder: { defaults.stringArray(forKey: LanguageCatalog.fallbackOrderKey) ?? [] })
    let changed = expectation(description: "Fallback-only changes invalidate language-dependent labels")
    let observer = monitor.$fallbackOrder.dropFirst().sink { order in
      if order == reordered { changed.fulfill() }
    }
    defer { observer.cancel() }

    defaults.set(reordered, forKey: LanguageCatalog.fallbackOrderKey)
    notifications.post(name: UserDefaults.didChangeNotification, object: defaults)
    XCTAssertEqual(monitor.fallbackOrder, original, "Delivery must stay deferred until the menu's tracking loop ends")
    await fulfillment(of: [changed], timeout: 2)

    XCTAssertEqual(monitor.fallbackOrder, reordered)
    XCTAssertEqual(monitor.code, "ar")
    XCTAssertFalse(monitor.showsPrayerNameInPrayerLanguage)
  }
}
