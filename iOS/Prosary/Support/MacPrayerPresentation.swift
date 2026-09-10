#if os(macOS)
import SwiftUI

struct MacPrayerPresentation: Codable, Equatable {
  var isPresenting = false
  var textSize = 44.0
}

struct MacPrayerPresentationStore {
  static let shared = MacPrayerPresentationStore()
  static let defaultsKey = "macPrayerPresentation"
  let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }

  func settings(for id: UUID) -> MacPrayerPresentation {
    var value = values[id.uuidString] ?? MacPrayerPresentation()
    value.textSize = min(96, max(24, value.textSize.isFinite ? value.textSize : 44))
    return value
  }

  func save(_ value: MacPrayerPresentation, for id: UUID) {
    var updated = values
    var safe = value
    safe.textSize = min(96, max(24, value.textSize.isFinite ? value.textSize : 44))
    updated[id.uuidString] = safe
    guard let data = try? JSONEncoder().encode(updated) else { return }
    defaults.set(data, forKey: Self.defaultsKey)
  }

  func copy(from sourceID: UUID, to destinationID: UUID) { save(settings(for: sourceID), for: destinationID) }

  private var values: [String: MacPrayerPresentation] {
    guard let data = defaults.data(forKey: Self.defaultsKey) else { return [:] }
    return (try? JSONDecoder().decode([String: MacPrayerPresentation].self, from: data)) ?? [:]
  }
}

struct MacPrayerPresentationActions {
  let isPresenting: Bool
  let textSize: Binding<Double>
  let toggle: () -> Void
  let exit: () -> Void
}

private struct MacPrayerPresentationKey: FocusedValueKey {
  typealias Value = MacPrayerPresentationActions
}

private struct MacPrayerPresentationEnvironmentKey: EnvironmentKey {
  static let defaultValue: MacPrayerPresentationActions? = nil
}

extension FocusedValues {
  var macPrayerPresentation: MacPrayerPresentationActions? {
    get { self[MacPrayerPresentationKey.self] }
    set { self[MacPrayerPresentationKey.self] = newValue }
  }
}

extension EnvironmentValues {
  var macPrayerPresentation: MacPrayerPresentationActions? {
    get { self[MacPrayerPresentationEnvironmentKey.self] }
    set { self[MacPrayerPresentationEnvironmentKey.self] = newValue }
  }
}
#endif
