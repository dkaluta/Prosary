import SwiftData
import XCTest
@testable import Prosary

@MainActor
final class PrayerStoreStartupTests: XCTestCase {
  private enum StoreFailure: Error, Equatable { case blocked }

  func testUnavailableStoreThrowsTheStartupFailureForEveryOperation() async {
    let store: any PresetStore = UnavailablePresetStore(error: StoreFailure.blocked)
    let prayer = Prayer(name: "Must not become an empty replacement")
    let operations: [(String, () async throws -> Void)] = [
      ("all", { _ = try await store.all() }),
      ("get", { _ = try await store.get(id: prayer.id) }),
      ("defaultPreset", { _ = try await store.defaultPreset(kind: prayer.kind) }),
      ("save", { try await store.save(prayer) }),
      ("updateIfPresent", { _ = try await store.updateIfPresent(prayer) }),
      ("delete", { try await store.delete(prayer) }),
    ]
    for (name, operation) in operations {
      do {
        try await operation()
        XCTFail("\(name) must not report success while the library is unavailable")
      } catch {
        XCTAssertEqual(error as? StoreFailure, .blocked, "\(name) must preserve the startup failure")
      }
    }
  }

  func testHostedAppServicesUsesOnlyAnInMemoryContainer() {
    // Refuse to initialize AppServices if the test host was not detected: a failing
    // isolation test must not itself open or create the person's persistent store.
    guard ProsaryRuntimeEnvironment.isTesting else {
      XCTFail("The hosted test app must select storage isolation before AppServices initializes")
      return
    }
    let configurations = AppServices.modelContainer.configurations
    XCTAssertFalse(configurations.isEmpty)
    for configuration in configurations {
      XCTAssertTrue(configuration.isStoredInMemoryOnly)
      XCTAssertNil(configuration.cloudKitContainerIdentifier)
    }
    XCTAssertNil(AppServices.persistenceError)
    XCTAssertFalse(AppServices.shared.presetStore is UnavailablePresetStore)
  }
}
