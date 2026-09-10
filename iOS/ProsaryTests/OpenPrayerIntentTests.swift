import XCTest
@testable import Prosary

@MainActor
final class OpenPrayerIntentTests: XCTestCase {
  func testEntitiesIncludeEverySavedKindAndResolveStableIdentifiers() {
    let prayers = [Prayer(name: "Rosary", kind: .rosary),
                   Prayer(name: "Jesus Prayer", kind: .jesusPrayer),
                   Prayer(name: "Angelus", kind: .custom, customDevotionId: "angelus")]
    let entities = SavedPrayerEntity.entities(from: prayers)
    XCTAssertEqual(Set(entities.map(\.id)), Set(prayers.map(\.id)))
    let resolved = SavedPrayerEntity.entities(from: prayers, identifiers: [prayers[2].id, UUID(), prayers[0].id])
    XCTAssertEqual(resolved.map(\.id), [prayers[2].id, prayers[0].id])
    XCTAssertEqual(resolved.map(\.name), ["Angelus", "Rosary"])
  }

  func testOpeningUsesSelectedSavedCopyAndDeletionNeverFallsBack() async throws {
    let selected = Prayer(name: "Evening", kind: .jesusPrayer)
    let fallback = Prayer(name: "Default", isDefault: true)
    let store = MockPresetStore(configs: [selected, fallback])
    let route = try await OpenPrayerIntent.route(for: selected.id, in: store)
    XCTAssertEqual(route, .prayer(id: selected.id))
    try await store.delete(selected)
    do {
      _ = try await OpenPrayerIntent.route(for: selected.id, in: store)
      XCTFail("A deleted saved selection must report an error")
    } catch {
      XCTAssertTrue(error is SavedPrayerUnavailableError)
    }
  }
}
