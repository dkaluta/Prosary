#if os(macOS)
import AppKit
import UniformTypeIdentifiers

/// File → Import remains usable when the last library window is closed or Settings is key.
enum MacDevotionImporter {
  static func open(onImport: @escaping (String) -> Void) {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.prosaryPrayer, .zip]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.begin { response in
      guard response == .OK, let url = panel.url else { return }
      do {
        onImport(try PrayerPackStore.installPack(fromUserSelected: url))
        NotificationCenter.default.post(name: .macShowGallery, object: nil)
      } catch {
        NSApp.presentError(error)
      }
    }
  }
}
#endif
