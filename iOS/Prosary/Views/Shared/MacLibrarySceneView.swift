#if os(macOS)
import SwiftUI

struct MacLibrarySceneView: View {
  @Environment(\.openWindow) private var openWindow
  private static let libraryDefaults = ProsaryRuntimeEnvironment.defaults
  @State private var model = MacPrayerLibraryModel(defaults: Self.libraryDefaults,
    installedDevotionIDs: { ProsaryRuntimeEnvironment.isTesting ? [] : PrayerPackStore.installedBundleIds() })

  var body: some View {
    MacPrayerLibraryView(model: model)
      .defaultAppStorage(Self.libraryDefaults)
      .modifier(MacSceneBridge())
      .onOpenURL { url in
        if let link = ProsaryWidgetLink(url: url) {
          switch link {
          case .today:
            NotificationCenter.default.post(name: .widgetNavigateLibrary, object: "today")
          case .library:
            NotificationCenter.default.post(name: .widgetNavigateLibrary, object: "library")
          case .prayer(let id):
            openWindow(id: "prayer", value: PrayerWindowRequest(route: .prayer(id: id)))
          case .rosary:
            Task {
              let saved = try? await AppServices.shared.presetStore.defaultPreset(kind: .rosary)
              let prayer = ProsaryWidgetLink.rosaryPrayer(from: saved)
              openWindow(id: "prayer", value: PrayerWindowRequest(route: .rosaryQuickPray(prayer: prayer)))
            }
          }
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
}
#endif
