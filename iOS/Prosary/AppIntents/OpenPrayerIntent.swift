import AppIntents
import Foundation

/// Stable saved-copy identities span every prayer kind. Entity resolution always reads
/// the app's authoritative library, so a removed shortcut selection cannot open another copy.
struct SavedPrayerEntity: AppEntity {
  let id: Prayer.ID
  let name: String

  init(_ prayer: Prayer) { id = prayer.id; name = prayer.name }

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("appIntents.savedPrayer.typeName", defaultValue: "Saved Prayer"))
  static var defaultQuery = SavedPrayerEntityQuery()
  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

  static func entities(from prayers: [Prayer], identifiers: [Prayer.ID]? = nil) -> [Self] {
    if let identifiers {
      return identifiers.compactMap { id in prayers.first(where: { $0.id == id }).map(Self.init) }
    }
    return prayers.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }.map(Self.init)
  }
}

struct SavedPrayerEntityQuery: EntityQuery {
  func entities(for identifiers: [Prayer.ID]) async throws -> [SavedPrayerEntity] {
    SavedPrayerEntity.entities(from: try await AppServices.shared.presetStore.all(), identifiers: identifiers)
  }

  func suggestedEntities() async throws -> [SavedPrayerEntity] {
    SavedPrayerEntity.entities(from: try await AppServices.shared.presetStore.all())
  }
}

struct OpenPrayerIntent: AppIntent {
  static var title = LocalizedStringResource("appIntents.openPrayer.title", defaultValue: "Open Prayer")
  static var description = IntentDescription(LocalizedStringResource(
    "appIntents.openPrayer.description", defaultValue: "Opens a saved prayer with its settings and progress."))
  // Retain support for iOS 17 and macOS 14, where supportedModes is unavailable.
  static var openAppWhenRun = true

  @Parameter(title: LocalizedStringResource("appIntents.openPrayer.prayer", defaultValue: "Prayer"))
  var prayer: SavedPrayerEntity

  @MainActor
  func perform() async throws -> some IntentResult {
    let route = try await Self.route(for: prayer.id, in: AppServices.shared.presetStore)
    NavigationCoordinator.shared.pendingRoute = route
    return .result()
  }

  @MainActor
  static func route(for id: Prayer.ID, in store: any PresetStore) async throws -> AppRoute {
    guard let saved = try await store.get(id: id) else { throw SavedPrayerUnavailableError() }
    return .prayer(id: saved.id)
  }
}

struct SavedPrayerUnavailableError: LocalizedError {
  var errorDescription: String? {
    String(localized: "appIntents.openPrayer.unavailable", defaultValue: "This saved prayer is no longer available. Choose another prayer in the shortcut.")
  }
}
