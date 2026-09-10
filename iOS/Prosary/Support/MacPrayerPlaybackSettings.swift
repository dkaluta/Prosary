#if os(macOS)
import Foundation

/// Local playback preferences belong to a named library copy. Reading an unconfigured copy
/// uses the app default; its first window saves that value so later defaults affect new copies.
struct MacPrayerPlaybackSettings {
  static let shared = MacPrayerPlaybackSettings()
  static let defaultsKey = "macPrayerPlaybackSettings"
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func autoAdvanceSeconds(for prayerID: UUID) -> Int {
    max(0, values[prayerID.uuidString] ?? defaults.integer(forKey: "autoAdvanceSeconds"))
  }

  func setAutoAdvanceSeconds(_ seconds: Int, for prayerID: UUID) {
    var updated = values
    updated[prayerID.uuidString] = max(0, seconds)
    save(updated)
  }

  /// Copy the effective choice even if the source still uses the app default. The new copy
  /// can then change its pace without changing the source or following future default edits.
  func copy(from sourceID: UUID, to destinationID: UUID) {
    setAutoAdvanceSeconds(autoAdvanceSeconds(for: sourceID), for: destinationID)
  }

  func remove(for prayerID: UUID) {
    var updated = values
    updated[prayerID.uuidString] = nil
    save(updated)
  }

  private var values: [String: Int] {
    guard let data = defaults.data(forKey: Self.defaultsKey),
          let decoded = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
    return decoded
  }

  private func save(_ values: [String: Int]) {
    guard !values.isEmpty else {
      defaults.removeObject(forKey: Self.defaultsKey)
      return
    }
    guard let data = try? JSONEncoder().encode(values) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }
}
#endif
