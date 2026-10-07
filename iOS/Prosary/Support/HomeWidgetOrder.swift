import Foundation

/// Home widgets are independent of the saved-prayer ordering on Pray.
enum HomeWidget: String, CaseIterable, Identifiable {
  case readings, popeIntention, calendar, photo, reminders, scripture, reflection, feast
  var id: String { rawValue }
  var title: String { UILanguage.text("homeWidgets.\(rawValue)", language: UILanguage.current, fallback: rawValue) }
  var symbol: String {
    switch self {
    case .readings: "book.closed"
    case .popeIntention: "key.horizontal"
    case .calendar: "calendar"
    case .photo: "photo"
    case .reminders: "bell"
    case .scripture: "books.vertical"
    case .reflection: "quote.bubble"
    case .feast: "sun.max"
    }
  }
}

enum HomeWidgetOrder {
  static let key = "homeWidgetOrder"
  static let defaults: [HomeWidget] = [.readings, .popeIntention, .calendar, .reminders, .scripture, .feast]

  static func decode(_ stored: String?) -> [HomeWidget] {
    guard let stored else { return defaults }
    var seen = Set<HomeWidget>()
    return stored.components(separatedBy: "\n").compactMap { value in
      guard let widget = HomeWidget(rawValue: value), seen.insert(widget).inserted else { return nil }
      return widget
    }
  }

  static func encode(_ widgets: [HomeWidget]) -> String {
    var seen = Set<HomeWidget>()
    return widgets.filter { seen.insert($0).inserted }.map(\.rawValue).joined(separator: "\n")
  }
}
