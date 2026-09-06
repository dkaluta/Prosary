import Foundation

enum BasicPrayerFavorites {
  // Keep the original preference key: previously starred prayers are now pinned to Home.
  static let idsKey = "favoriteBasicPrayerIds"
  static let moveToTopKey = "favoriteBasicPrayersFirst"

  static var ids: Set<String> { Set(CloudSyncedList.read(idsKey) ?? []) }

  static func contains(_ id: String) -> Bool { ids.contains(id) }

  static func homeRowID(_ id: String) -> String { "basic:\(id)" }

  static func prayerID(homeRowID: String) -> String? {
    guard homeRowID.hasPrefix("basic:") else { return nil }
    let id = String(homeRowID.dropFirst("basic:".count))
    return BasicPrayerCatalog.prayer(id: id) == nil ? nil : id
  }

  static func toggle(_ id: String) {
    var updated = ids
    if !updated.insert(id).inserted { updated.remove(id) }
    CloudSyncedList.write(BasicPrayerCatalog.all.map(\.id).filter(updated.contains), forKey: idsKey)
    // Home may stay alive underneath this list, or in another Mac window.
    CloudPreferencesGeneration.shared.bump()
  }

  static func apply(_ prayers: [BasicPrayer]) -> [BasicPrayer] {
    guard UserDefaults.standard.bool(forKey: moveToTopKey) else { return prayers }
    let favorites = ids
    return prayers.enumerated().sorted { lhs, rhs in
      let left = favorites.contains(lhs.element.id)
      let right = favorites.contains(rhs.element.id)
      return left == right ? lhs.offset < rhs.offset : left && !right
    }.map(\.element)
  }
}
