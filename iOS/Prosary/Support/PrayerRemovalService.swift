import Foundation

/// Removing a saved copy and removing downloaded content have different lifetimes.
/// A pack is eligible for removal only after its last saved reference is gone.
@MainActor
struct PrayerRemovalService {
  enum RemovalError: LocalizedError, Equatable {
    case downloadInUse, cleanupFailed, prayerRemoved

    var errorDescription: String? {
      switch self {
      case .downloadInUse:
        String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .cleanupFailed:
        String(localized: "removal.cleanupFailed", defaultValue: "The saved prayer was deleted, but its download could not be removed. Try again in Downloads.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .prayerRemoved:
        String(localized: "removal.prayerRemoved", defaultValue: "This saved prayer has been deleted.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      }
    }
  }

  private let store: PresetStore
  private let installedDevotionIDs: () -> [String]
  private let removeInstalledPack: (String) throws -> Void
  private let cancelReminders: (Prayer) -> Void
  private let cancelDownloadReminders: (String) -> Void

  init(store: PresetStore,
       installedDevotionIDs: (() -> [String])? = nil,
       removeInstalledPack: ((String) throws -> Void)? = nil,
       cancelReminders: ((Prayer) -> Void)? = nil,
       cancelDownloadReminders: ((String) -> Void)? = nil) {
    self.store = store
    self.installedDevotionIDs = installedDevotionIDs ?? { PrayerPackStore.installedBundleIds() }
    self.removeInstalledPack = removeInstalledPack ?? { try PrayerPackStore.removeInstalledPackFromDevice(id: $0) }
    // The pack's shared run may still be used on another device. Cancel local
    // notifications without clearing synchronized progress.
    self.cancelDownloadReminders = cancelDownloadReminders ?? { ReminderScheduler.removeSeries(devotionId: $0) }
    self.cancelReminders = cancelReminders ?? { prayer in
      ReminderScheduler.removeAll(for: prayer)
      #if os(macOS)
      if let id = Self.downloadID(for: prayer) {
        let runID = PrayerCopyProgressIdentity.devotionID(id, prayerID: prayer.id)
        ReminderScheduler.removeSeries(devotionId: id, runID: runID)
        MultiDayRuns.clear(runID)
      }
      #endif
    }
  }

  func willRemoveDownload(afterDeleting prayer: Prayer) async throws -> Bool {
    guard let id = Self.downloadID(for: prayer), installedDevotionIDs().contains(id) else { return false }
    let prayers = try await store.all()
    return !prayers.contains { $0.id != prayer.id && Self.downloadID(for: $0) == id }
  }

  func delete(_ prayer: Prayer) async throws {
    guard let current = try await store.get(id: prayer.id) else { return }
    // Nothing outside persistence is touched until the delete succeeds.
    try await store.delete(current)
    cancelReminders(current)
    NotificationCenter.default.post(name: .prayerConfigurationDidDelete, object: current.id)
    defer { NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil) }
    guard let id = Self.downloadID(for: current), installedDevotionIDs().contains(id) else { return }
    do {
      // Re-read after deletion: copies in another window may have changed meanwhile.
      let remaining = try await store.all()
      if !remaining.contains(where: { Self.downloadID(for: $0) == id }) {
        // Deletion has already succeeded. Even if file cleanup fails, this device
        // must not keep reminding the person to continue the deleted prayer.
        cancelDownloadReminders(id)
        try removeInstalledPack(id)
      }
    } catch { throw RemovalError.cleanupFailed }
  }

  func unusedDownloadIDs() async throws -> [String] {
    let prayers = try await store.all()
    let used = Set(prayers.compactMap { Self.downloadID(for: $0) })
    return installedDevotionIDs().filter { !used.contains($0) }
  }

  func removeDownload(bundleID: String) async throws {
    guard installedDevotionIDs().contains(bundleID) else { return }
    let prayers = try await store.all()
    guard !prayers.contains(where: { Self.downloadID(for: $0) == bundleID }) else {
      throw RemovalError.downloadInUse
    }
    try removeInstalledPack(bundleID)
    cancelDownloadReminders(bundleID)
    NotificationCenter.default.post(name: .prayerLibraryDidChange, object: nil)
  }

  static func downloadID(for prayer: Prayer) -> String? {
    switch prayer.kind {
    case .custom: prayer.customDevotionId
    case .rosary: "rosary"
    case .jesusPrayer: nil
    }
  }
}
