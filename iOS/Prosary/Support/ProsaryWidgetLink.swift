import Foundation

/// Widget URLs name destinations only. A URL cannot change a saved prayer or its bookmark.
enum ProsaryWidgetLink: Equatable {
  case today
  case rosary
  case library
  case prayer(UUID)

  init?(url: URL) {
    guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
          parts.scheme?.lowercased() == "prosary",
          parts.user == nil, parts.password == nil, parts.port == nil,
          parts.query == nil, parts.fragment == nil else { return nil }
    switch parts.host?.lowercased() {
    case "today" where parts.path.isEmpty || parts.path == "/": self = .today
    case "rosary" where parts.path.isEmpty || parts.path == "/": self = .rosary
    case "library" where parts.path.isEmpty || parts.path == "/": self = .library
    case "prayer":
      let path = parts.path
      guard path.hasPrefix("/"), let id = UUID(uuidString: String(path.dropFirst())) else { return nil }
      self = .prayer(id)
    default: return nil
    }
  }

  /// Starting today's Rosary uses the person's preferred options without editing that copy.
  static func rosaryPrayer(from saved: Prayer?) -> Prayer {
    var prayer = saved ?? Prayer(name: String(localized: "prayerKind.rosary", defaultValue: "Rosary"))
    prayer.id = UUID()
    prayer.kind = .rosary
    prayer.isDefault = false
    prayer.reminders = []
    prayer.rosary.mysterySelectionMode = .todaysMysteries
    return prayer
  }
}

extension Notification.Name {
  static let widgetNavigateLibrary = Notification.Name("Prosary.widgetNavigateLibrary")
}
