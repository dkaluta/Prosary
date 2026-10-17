import SwiftUI
import SwiftData
import UserNotifications

@main
struct ProsaryApp: App {
  #if os(macOS)
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  #endif
  private let presetsMenuState = PresetsMenuState()

  init() {
    let defaults = ProsaryRuntimeEnvironment.defaults
    if ProsaryRuntimeEnvironment.isTesting { Self.seedHomeLayoutForTesting(in: defaults) }
    // Font registration is process-scoped and also needed by isolated UI test hosts.
    FontRegistration.registerBundledFontsIfNeeded()
    defaults.register(defaults: [UILanguage.defaultsKey: "", LanguageCatalog.defaultsKey: ""])
    if !ProsaryRuntimeEnvironment.isTesting { CloudSyncedList.startSyncing() }
    if !ProsaryRuntimeEnvironment.isTesting { UNUserNotificationCenter.current().delegate = ReminderActivation.shared }
  }

  /// Seed the isolated UI host once, then allow real preference edits to beat its fixture.
  /// Launch arguments otherwise outrank writes to UserDefaults for the entire process.
  private static func seedHomeLayoutForTesting(in defaults: UserDefaults) {
    let arguments = CommandLine.arguments
    let keys = [HomeWidgetOrder.key, HomeWidgetOrder.layoutVersionKey,
      HomeWidgetDisplay.collapsedKey, HomeWidgetDisplay.colorsKey]
    var argumentDomain = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
    var seededValues: [String: String] = [:]
    for key in keys {
      guard let index = arguments.firstIndex(of: "-" + key), arguments.indices.contains(index + 1) else { continue }
      let value = arguments[index + 1]
      // XCUITest launch transport can split literal newlines; list fixtures may escape them.
      seededValues[key] = key == HomeWidgetOrder.key || key == HomeWidgetDisplay.collapsedKey
        ? value.replacingOccurrences(of: "\\n", with: "\n") : value
      argumentDomain.removeValue(forKey: key)
    }
    if seededValues[HomeWidgetOrder.key] != nil {
      defaults.removeObject(forKey: HomeLayoutCloud.key)
      argumentDomain.removeValue(forKey: HomeLayoutCloud.key)
    }
    defaults.setVolatileDomain(argumentDomain, forName: UserDefaults.argumentDomain)
    for (key, value) in seededValues { defaults.set(value, forKey: key) }
  }

  var body: some Scene {
    #if os(macOS)
    Window(String(localized: "macLibrary.title", defaultValue: "Library", bundle: UILanguage.bundle, locale: UILanguage.locale), id: "main") {
      MacLibrarySceneView()
        .modifier(WidgetSnapshotLifecycle())
        .modifier(ReminderLifecycle())
        .frame(minWidth: 700, minHeight: 480)
        .modifier(PrayerStoreStartupGuard())
        .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        .task { await presetsMenuState.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
          Task { await presetsMenuState.reload() }
        }
        .appInterfaceLanguage()
    }
    .defaultSize(width: 1000, height: 750)
    .modelContainer(AppServices.modelContainer)
    .handlesExternalEvents(matching: ["*"])
    .commands {
      MacLibraryCommands()
      SidebarCommands()
    }
    .appInterfaceLanguage()

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
        .appInterfaceLanguage()
      }
    }
    .defaultSize(width: 620, height: 750)
    .modelContainer(AppServices.modelContainer)
    .handlesExternalEvents(matching: [])
    .appInterfaceLanguage()

    Window("about.navigationTitle", id: "about") {
      NavigationStack { AboutView() }.appInterfaceLanguage()
    }
    .windowResizability(.contentSize)
    .defaultSize(width: 520, height: 640)
    .commandsRemoved()
    .appInterfaceLanguage()

    Settings {
      SettingsView()
        .defaultAppStorage(ProsaryRuntimeEnvironment.defaults)
        .appInterfaceLanguage()
    }
      .windowResizability(.contentSize)
      .appInterfaceLanguage()
    #else
    WindowGroup {
      ContentView()
        .defaultAppStorage(ProsaryRuntimeEnvironment.defaults)
        .modifier(WidgetSnapshotLifecycle())
        .modifier(ReminderLifecycle())
        .modifier(PrayerStoreStartupGuard())
        #if os(visionOS)
        .frame(minWidth: 560, minHeight: 560)
        #endif
        .task { await presetsMenuState.reload() }
        .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
          Task { await presetsMenuState.reload() }
        }
        .appInterfaceLanguage()
    }
    .modelContainer(AppServices.modelContainer)
    .commands { PrayersCommands(presetsState: presetsMenuState) }
    .appInterfaceLanguage()
    #endif
  }
}
