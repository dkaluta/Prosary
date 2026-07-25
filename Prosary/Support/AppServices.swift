//
//  AppServices.swift
//  Prosary
//
//  The backend, as the UI sees it — protocols injected once at the app root and read via
//  @Environment everywhere else. Wired to the Stub* implementations (Support/Stubs/) which
//  contain the full production logic; Mock* (Mocks/) are thin wrappers used only in Previews
//  and unit tests. Everything downstream only ever talks to the protocols.
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
  var rosaryEngine: RosaryEngine
  var angelusEngine: AngelusEngine
  var calendar: LiturgicalCalendarProviding

  static let modelContainer: ModelContainer = {
    // .automatic picks the CloudKit container declared in Prosary.entitlements
    // (iCloud.com.dkaluta.prosary) and syncs through the user's private database — saved
    // favorites (including reminders) follow them across every device signed into the same
    // iCloud account, the same way Reminders/Notes sync. Falls back to a local-only store (still
    // fully functional, just not synced) if iCloud is unavailable — signed out, disabled for this
    // app in Settings, or offline — rather than crashing the app on launch.
    let cloudKitConfiguration = ModelConfiguration(cloudKitDatabase: .automatic)
    if let container = try? ModelContainer(for: PresetEntry.self, configurations: cloudKitConfiguration) {
      return container
    }

    let localOnlyConfiguration = ModelConfiguration(cloudKitDatabase: .none)
    do {
      return try ModelContainer(for: PresetEntry.self, configurations: localOnlyConfiguration)
    } catch {
      fatalError("Failed to create ModelContainer: \(error)")
    }
  }()

  static let shared: AppServices = {
    let calendar = StubLiturgicalCalendar()
    let context = ModelContext(modelContainer)
    // Allow UI tests to start with a clean store so test-run order doesn't matter.
    if CommandLine.arguments.contains("-resetStore") {
      try? context.delete(model: PresetEntry.self)
      try? context.save()
    }
    return AppServices(
      presetStore: SwiftDataPresetStore(context: context),
      rosaryEngine: StubRosaryEngine(calendar: calendar),
      angelusEngine: StubAngelusEngine(calendar: calendar),
      calendar: calendar
    )
  }()
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
