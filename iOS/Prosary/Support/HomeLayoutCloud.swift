import Foundation

/// One atomic preference follows the person through the existing iCloud key-value store.
/// Photos, civil dates and responsive column counts belong to the device and never enter it.
enum HomeLayoutCloud {
  static let key = "homeWidgetLayout"

  struct Snapshot: Codable, Equatable {
    let version: Int
    let order: String
    let collapsed: String
    let colors: String
  }

  static func normalized(order: String, collapsed: String, colors: String) -> Snapshot {
    Snapshot(version: 1,
      order: HomeWidgetOrder.encode(HomeWidgetOrder.decode(order)),
      collapsed: HomeWidgetDisplay.encodeCollapsed(HomeWidgetDisplay.collapsed(collapsed)),
      colors: HomeWidgetDisplay.encodeColors(HomeWidgetDisplay.colors(colors)))
  }

  static func decode(_ data: Data) -> Snapshot? {
    guard data.count <= 16_384, let value = try? JSONDecoder().decode(Snapshot.self, from: data),
          value.version == 1 else { return nil }
    return normalized(order: value.order, collapsed: value.collapsed, colors: value.colors)
  }

  static func read() -> Snapshot? {
    CloudSyncedList.readData(key).flatMap(decode)
  }

  /// Called only for an explicit layout edit. A newly opened device must not publish its
  /// defaults while the existing account's layout may still be arriving from iCloud.
  static func write(order: String, collapsed: String, colors: String) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(normalized(order: order, collapsed: collapsed, colors: colors)) else { return }
    CloudSyncedList.writeData(data, forKey: key)
  }
}
