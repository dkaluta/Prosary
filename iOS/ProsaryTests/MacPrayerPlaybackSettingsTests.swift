#if os(macOS)
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerPlaybackSettingsTests: XCTestCase {
  func testRememberedCopiesKeepTheirPaceWhenAnotherCopyOrTheDefaultChanges() throws {
    let suiteName = "MacPrayerPlaybackSettingsTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = MacPrayerPlaybackSettings(defaults: defaults)
    let first = UUID()
    let second = UUID()
    defaults.set(5, forKey: "autoAdvanceSeconds")
    XCTAssertEqual(settings.autoAdvanceSeconds(for: first), 5)

    settings.setAutoAdvanceSeconds(settings.autoAdvanceSeconds(for: first), for: first)
    settings.copy(from: first, to: second)
    settings.setAutoAdvanceSeconds(15, for: second)
    defaults.set(10, forKey: "autoAdvanceSeconds")

    let reopened = MacPrayerPlaybackSettings(defaults: defaults)
    XCTAssertEqual(reopened.autoAdvanceSeconds(for: first), 5)
    XCTAssertEqual(reopened.autoAdvanceSeconds(for: second), 15)
    XCTAssertEqual(reopened.autoAdvanceSeconds(for: UUID()), 10)
    settings.setAutoAdvanceSeconds(0, for: first)
    XCTAssertEqual(reopened.autoAdvanceSeconds(for: first), 0, "Off is an explicit per-copy choice")
    XCTAssertEqual(reopened.autoAdvanceSeconds(for: second), 15)
    XCTAssertEqual(defaults.integer(forKey: "autoAdvanceSeconds"), 10)
  }

  func testDuplicatingAnUnopenedCopyFreezesItsEffectiveDefaultAndRemovalIsIndependent() throws {
    let suiteName = "MacPrayerPlaybackSettingsTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let settings = MacPrayerPlaybackSettings(defaults: defaults)
    let source = UUID()
    let copy = UUID()
    defaults.set(3, forKey: "autoAdvanceSeconds")
    settings.copy(from: source, to: copy)
    defaults.set(15, forKey: "autoAdvanceSeconds")
    XCTAssertEqual(settings.autoAdvanceSeconds(for: copy), 3)
    XCTAssertEqual(settings.autoAdvanceSeconds(for: source), 15)
    settings.setAutoAdvanceSeconds(5, for: source)
    settings.remove(for: copy)
    XCTAssertEqual(settings.autoAdvanceSeconds(for: copy), 15)
    XCTAssertEqual(settings.autoAdvanceSeconds(for: source), 5)
  }
}
#endif
