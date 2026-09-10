//
//  AppServices.swift
//  Prosary
//
//  The backend, as the UI sees it — injected once at the app root and read via @Environment
//  everywhere else. `engine` is the single PrayerEngine used for every devotion (see
//  Support/PrayerEngine.swift); `presetStore`/`calendar` are still protocol-typed since they
//  have real alternate implementations (SwiftData vs. in-memory, real calendar vs. fixed).
//
//  `shared` is the single instance used both as the environment default (SwiftUI) and directly
//  by App Intents (AppIntents/), which run outside the view hierarchy and can't read @Environment
//  — using the same instance from both keeps SwiftData state consistent whichever entry point
//  touched it.
//

import SwiftUI
import SwiftData

struct AppServices {
  var presetStore: PresetStore
  var engine: PrayerEngine
  var calendar: LiturgicalCalendarProviding

  private static let persistence: (container: ModelContainer, error: Error?) = {
    if ProsaryRuntimeEnvironment.isTesting { return (isolatedContainer(), nil) }
    // .automatic picks the CloudKit container declared in Prosary.entitlements
    // (iCloud.com.dkaluta.prosary) and syncs through the user's private database — saved
    // favorites (including reminders) follow them across every device signed into the same
    // iCloud account, the same way Reminders/Notes sync. Falls back to a local-only store (still
    // fully functional, just not synced) if iCloud is unavailable — signed out, disabled for this
    // app in Settings, or offline — rather than crashing the app on launch.
    do {
      #if os(macOS)
      let url = try MacPrayerStoreLocation.prepare()
      let cloudKitConfiguration = ModelConfiguration(url: url, cloudKitDatabase: .automatic)
      let localOnlyConfiguration = ModelConfiguration(url: url, cloudKitDatabase: .none)
      #else
      let cloudKitConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)
      let localOnlyConfiguration = ModelConfiguration(cloudKitDatabase: .none)
      #endif
      if let container = try? ModelContainer(for: PresetEntry.self, configurations: cloudKitConfiguration) {
        return (container, nil)
      }
      return (try ModelContainer(for: PresetEntry.self, configurations: localOnlyConfiguration), nil)
    } catch {
      // This container only hosts the error screen. The service below rejects all data
      // access, so a failed library never becomes a silently empty, writable replacement.
      return (isolatedContainer(), error)
    }
  }()

  static var modelContainer: ModelContainer { persistence.container }
  static var persistenceError: Error? { persistence.error }

  private static func isolatedContainer() -> ModelContainer {
    try! ModelContainer(for: PresetEntry.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
  }

  static let shared: AppServices = {
    let calendar = StubLiturgicalCalendar()
    // Legacy -resetStore is now an isolated-test flag; never delete the person's library
    // or iCloud preferences from an app launch argument.
    let store: PresetStore = if let error = persistenceError {
      UnavailablePresetStore(error: error)
    } else {
      SwiftDataPresetStore(context: ModelContext(modelContainer), defaults: ProsaryRuntimeEnvironment.defaults)
    }
    return AppServices(
      presetStore: store,
      engine: PrayerEngine(calendar: calendar),
      calendar: calendar
    )
  }()
}

struct UnavailablePresetStore: PresetStore {
  let error: Error
  func all() async throws -> [Prayer] { throw error }
  func get(id: Prayer.ID) async throws -> Prayer? { throw error }
  func defaultPreset(kind: PrayerKind) async throws -> Prayer? { throw error }
  func save(_ prayer: Prayer) async throws { throw error }
  func updateIfPresent(_ prayer: Prayer) async throws -> Bool { throw error }
  func delete(_ prayer: Prayer) async throws { throw error }
}

private struct AppServicesKey: EnvironmentKey {
  static let defaultValue = AppServices.shared
}

extension EnvironmentValues {
  var appServices: AppServices {
    get { self[AppServicesKey.self] }
    set { self[AppServicesKey.self] = newValue }
  }
}
