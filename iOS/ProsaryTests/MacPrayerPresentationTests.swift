#if os(macOS)
import XCTest
@testable import Prosary

final class MacPrayerPresentationTests: XCTestCase {
  func testPresenterPreferencesPersistAndCopiesCanChangeIndependently() throws {
    let suite = "MacPrayerPresentationTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MacPrayerPresentationStore(defaults: defaults)
    let original = UUID(), copy = UUID()
    store.save(MacPrayerPresentation(isPresenting: true, textSize: 64), for: original)
    store.copy(from: original, to: copy)
    XCTAssertEqual(store.settings(for: copy), store.settings(for: original))
    store.save(MacPrayerPresentation(isPresenting: false, textSize: 32), for: copy)
    let reopened = MacPrayerPresentationStore(defaults: defaults)
    XCTAssertEqual(reopened.settings(for: original), MacPrayerPresentation(isPresenting: true, textSize: 64))
    XCTAssertEqual(reopened.settings(for: copy), MacPrayerPresentation(isPresenting: false, textSize: 32))
  }

  func testTextSizeIsAlwaysReadableAndFinite() throws {
    let suite = "MacPrayerPresentationTests.\(UUID())"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = MacPrayerPresentationStore(defaults: defaults)
    let id = UUID()
    store.save(MacPrayerPresentation(textSize: 2), for: id)
    XCTAssertEqual(store.settings(for: id).textSize, 24)
    store.save(MacPrayerPresentation(textSize: 1000), for: id)
    XCTAssertEqual(store.settings(for: id).textSize, 96)
    store.save(MacPrayerPresentation(textSize: .infinity), for: id)
    XCTAssertEqual(store.settings(for: id).textSize, 44)
  }
}
#endif
