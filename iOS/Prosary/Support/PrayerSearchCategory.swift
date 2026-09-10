import Foundation

/// Local packs and community entries share manifest tags. An empty tag list remains
/// discoverable under Other, including when Search has no text query.
enum PrayerSearchCategory {
  static func tags(_ values: [String]) -> [String] {
    let normalized = Set(values.map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }.filter { !$0.isEmpty })
    return normalized.isEmpty ? ["other"] : normalized.sorted()
  }

  static func available(in groups: [[String]]) -> [String] {
    Array(Set(groups.flatMap(tags))).sorted()
  }

  static func matches(_ values: [String], selected: String?) -> Bool {
    guard let selected else { return true }
    return tags(values).contains(selected)
  }
}
