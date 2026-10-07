#if os(macOS)
import SwiftUI

struct MacLibrarySceneView: View {
  @Environment(\.openWindow) private var openWindow
  @State private var reminderActivation = ReminderActivation.shared
  @State private var scriptingNavigation = MacScriptingNavigation.shared
  private static let libraryDefaults = ProsaryRuntimeEnvironment.defaults
  @State private var model = MacPrayerLibraryModel(defaults: Self.libraryDefaults,
    installedDevotionIDs: { ProsaryRuntimeEnvironment.isTesting ? [] : PrayerPackStore.installedBundleIds() })

  var body: some View {
    MacPrayerLibraryView(model: model)
      .defaultAppStorage(Self.libraryDefaults)
      .modifier(MacSceneBridge())
      .onChange(of: scriptingNavigation.pendingLibraryDestination) { _, _ in consumeScriptingDestination() }
      .task { consumeScriptingDestination() }
      .onChange(of: reminderActivation.pendingURL) { _, _ in
        guard let url = reminderActivation.pendingURL, let link = ProsaryWidgetLink(url: url) else { return }
        reminderActivation.pendingURL = nil
        openWindow(id: "main")
        open(link)
      }
      .task {
        if let url = reminderActivation.pendingURL, let link = ProsaryWidgetLink(url: url) {
          reminderActivation.pendingURL = nil
          open(link)
        }
      }
      .onOpenURL { url in
        if let link = ProsaryWidgetLink(url: url) {
          open(link)
          return
        }
        guard url.isFileURL, url.pathExtension.lowercased() == "prosaryprayer" else { return }
        Task {
          if await model.importFiles([url]) {
            NotificationCenter.default.post(name: .macShowGallery, object: nil)
          }
        }
      }
  }

  private func open(_ link: ProsaryWidgetLink) {
    switch link {
    case .today, .library, .calendar, .readings:
      let destination: String
      switch link {
      case .today: destination = "today"
      case .library: destination = "library"
      case .calendar: destination = "calendar"
      default: destination = "readings"
      }
      NotificationCenter.default.post(name: .widgetNavigateLibrary, object: destination)
    case .prayer(let id):
      openWindow(id: "prayer", value: PrayerWindowRequest(route: .prayer(id: id)))
    case .rosary:
      Task {
        let saved = try? await AppServices.shared.presetStore.defaultPreset(kind: .rosary)
        let prayer = ProsaryWidgetLink.rosaryPrayer(from: saved)
        openWindow(id: "prayer", value: PrayerWindowRequest(route: .rosaryQuickPray(prayer: prayer)))
      }
    }
  }

  private func consumeScriptingDestination() {
    guard let destination = scriptingNavigation.pendingLibraryDestination else { return }
    scriptingNavigation.pendingLibraryDestination = nil
    NotificationCenter.default.post(name: .widgetNavigateLibrary, object: destination)
  }
}
#endif
