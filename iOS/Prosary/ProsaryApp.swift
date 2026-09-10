import SwiftUI
import SwiftData

@main
struct ProsaryApp: App {
  #if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif
  private let presetsMenuState = PresetsMenuState()

  init() {
    let defaults = ProsaryRuntimeEnvironment.defaults
    // Font registration is process-scoped and also needed by isolated UI test hosts.
    FontRegistration.registerBundledFontsIfNeeded()
    defaults.register(defaults: ["defaultLanguageCode": LanguageCatalog.defaultCode])
    if !ProsaryRuntimeEnvironment.isTesting { CloudSyncedList.startSyncing() }
  }

  var body: some Scene {
    #if os(macOS)
    Window(String(localized: "macLibrary.title", defaultValue: "Library"), id: "main") {
      MacLibrarySceneView()
        .modifier(WidgetSnapshotLifecycle())
        .frame(minWidth: 700, minHeight: 480)
        .modifier(PrayerStoreStartupGuard())
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .task { await presetsMenuState.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
          Task { await presetsMenuState.reload() }
        }
    }
    .defaultSize(width: 1000, height: 750)
    .modelContainer(AppServices.modelContainer)
    .handlesExternalEvents(matching: ["*"])
    .commands {
      MacLibraryCommands()
      SidebarCommands()
    }

    WindowGroup(id: "prayer", for: PrayerWindowRequest.self) { $request in
      if let request {
      MacPrayerWindowView(request: request)
        .modifier(WidgetSnapshotLifecycle())
        .frame(minWidth: 380, minHeight: 560)
        .modifier(PrayerStoreStartupGuard())
        // Finder imports belong in the library window, not an ongoing prayer session.
        .handlesExternalEvents(preferring: [], allowing: [])
        .task { await presetsMenuState.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
          Task { await presetsMenuState.reload() }
        }
      }
    }
    .defaultSize(width: 620, height: 750)
    .modelContainer(AppServices.modelContainer)
    .handlesExternalEvents(matching: [])

    Window("about.navigationTitle", id: "about") {
      NavigationStack { AboutView() }
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 520, height: 640)
    .commandsRemoved()

    Settings { SettingsView() }
      .windowResizability(.contentSize)
    #else
    WindowGroup {
      ContentView()
        .modifier(WidgetSnapshotLifecycle())
        .modifier(PrayerStoreStartupGuard())
        #if os(visionOS)
        .frame(minWidth: 560, minHeight: 560)
        #endif
        .task { await presetsMenuState.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
          Task { await presetsMenuState.reload() }
        }
    }
    .modelContainer(AppServices.modelContainer)
    .commands { PrayersCommands(presetsState: presetsMenuState) }
    #endif
  }
}
