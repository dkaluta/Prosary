import Foundation

enum BasicPrayerFavorites {
  static let idsKey = "favoriteBasicPrayerIds"
  static let moveToTopKey = "favoriteBasicPrayersFirst"

  static var ids: Set<String> { Set(CloudSyncedList.read(idsKey) ?? []) }

  static func contains(_ id: String) -> Bool { ids.contains(id) }

  static func toggle(_ id: String) {
    var updated = ids
    if !updated.insert(id).inserted { updated.remove(id) }
    CloudSyncedList.write(BasicPrayerCatalog.all.map(\.id).filter(updated.contains), forKey: idsKey)
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
