import AppIntents
import Foundation

/// Catalog identities do not depend on display names or create saved prayer copies.
/// Imported packs appear automatically through the same directory used by Browse/Search.
struct CatalogPrayerEntity: AppEntity {
  var id: String
  var name: String

  static var typeDisplayRepresentation = TypeDisplayRepresentation(
    name: LocalizedStringResource("appIntents.catalogPrayer.typeName", defaultValue: "Prayer"))
  static var defaultQuery = CatalogPrayerEntityQuery()
  var displayRepresentation: DisplayRepresentation { .init(title: "\(name)") }

  @MainActor
  static func available() -> [Self] {
    let devotions = DevotionDirectory.all().map { Self(id: "devotion:\($0.id)", name: $0.title) }
    let basics = BasicPrayerCatalog.all.map { prayer in
      Self(id: "basic:\(prayer.id)", name: BasicPrayerCatalog.step(for: prayer).title)
    }
    return (devotions + basics).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
  }

  @MainActor
  static func route(for id: String) -> AppRoute? {
    if id.hasPrefix("basic:"), let basic = BasicPrayerCatalog.prayer(id: String(id.dropFirst(6))) {
      return .basicPrayer(id: basic.id)
    }
    if id.hasPrefix("devotion:") {
      return DevotionDirectory.all().first { $0.id == String(id.dropFirst(9)) }?.route
    }
    return nil
  }
}

struct CatalogPrayerEntityQuery: EntityStringQuery {
  func entities(for identifiers: [String]) async throws -> [CatalogPrayerEntity] {
    let available = await CatalogPrayerEntity.available()
    return identifiers.compactMap { id in available.first { $0.id == id } }
  }
  func suggestedEntities() async throws -> [CatalogPrayerEntity] {
    await CatalogPrayerEntity.available()
  }
  func entities(matching string: String) async throws -> [CatalogPrayerEntity] {
    await CatalogPrayerEntity.available().filter { $0.name.localizedStandardContains(string) }
  }
}

struct OpenCatalogPrayerIntent: AppIntent {
  static var title = LocalizedStringResource("appIntents.catalogPrayer.title", defaultValue: "Open a Prayer Template")
  static var description = IntentDescription(LocalizedStringResource(
    "appIntents.catalogPrayer.description", defaultValue: "Open any installed devotion or basic prayer. Use Open Prayer for a saved configuration."))
  static var openAppWhenRun = true

  @Parameter(title: LocalizedStringResource("appIntents.catalogPrayer.typeName", defaultValue: "Prayer"))
  var prayer: CatalogPrayerEntity

  @MainActor
  func perform() async throws -> some IntentResult {
    guard let route = CatalogPrayerEntity.route(for: prayer.id) else { throw CatalogPrayerUnavailableError() }
    NavigationCoordinator.shared.pendingRoute = route
    return .result()
  }
}

struct CatalogPrayerUnavailableError: LocalizedError {
  var errorDescription: String? {
    String(localized: "appIntents.catalogPrayer.unavailable", defaultValue: "This prayer is no longer installed. Choose another prayer in the shortcut.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
  }
}
