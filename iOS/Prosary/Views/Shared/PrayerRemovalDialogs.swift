import SwiftUI

/// Attach to the stable list, not an ephemeral context-menu button.
struct PrayerRemovalDialogs: ViewModifier {
  @Binding var prayer: Prayer?
  var onDeleted: () async -> Void = {}
  @Environment(\.appServices) private var services
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
      .alert(String(localized: "removal.deleteTitle", defaultValue: "Delete Saved Prayer?"),
             isPresented: Binding(get: { prayer != nil }, set: { if !$0 { prayer = nil } }),
             presenting: prayer) { selected in
        Button("favorites.delete", role: .destructive) {
          Task {
            do { try await PrayerRemovalService(store: services.presetStore).delete(selected) }
            catch { failure = error.localizedDescription }
            await onDeleted()
          }
        }
        Button("favoriteEditor.cancel", role: .cancel) { prayer = nil }
      } message: { selected in
        Text(selected.name + "\n\n" + String(localized: "removal.deleteDetail",
          defaultValue: "This deletes this saved copy and its reminders. If it is the last copy of a downloaded prayer, its download is also removed from this device."))
      }
      .alert(String(localized: "removal.failedTitle", defaultValue: "Could Not Remove Prayer"),
             isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
        Button("common.ok") { failure = nil }
      } message: { Text(failure ?? "") }
  }
}

struct PrayerDownloadRemovalDialogs: ViewModifier {
  @Binding var bundleID: String?
  var onRemoved: () async -> Void = {}
  @Environment(\.appServices) private var services
  @State private var failure: String?

  func body(content: Content) -> some View {
    content
      .alert(String(localized: "removal.removeDownloadTitle", defaultValue: "Remove Download?"),
             isPresented: Binding(get: { bundleID != nil }, set: { if !$0 { bundleID = nil } }),
             presenting: bundleID) { selected in
        Button(String(localized: "removal.remove", defaultValue: "Remove"), role: .destructive) {
          Task {
            do { try await PrayerRemovalService(store: services.presetStore).removeDownload(bundleID: selected) }
            catch { failure = error.localizedDescription }
            await onRemoved()
          }
        }
        Button("favoriteEditor.cancel", role: .cancel) { bundleID = nil }
      } message: { selected in
        Text((PrayerPackStore.info(for: selected)?.localizedDisplayName ?? selected) + "\n\n" +
          String(localized: "removal.removeDownloadDetail",
                 defaultValue: "This removes the downloaded prayer from this device. You can import or download it again."))
      }
      .alert(String(localized: "removal.failedTitle", defaultValue: "Could Not Remove Prayer"),
             isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
        Button("common.ok") { failure = nil }
      } message: { Text(failure ?? "") }
  }
}
