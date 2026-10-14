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

enum HomeWidgetDisplay {
  static let collapsedKey = "homeWidgetCollapsedIds"
  static let graphicsKey = "homeWidgetGraphicPaths"

  static func collapsed(_ stored: String) -> Set<HomeWidget> {
    Set(HomeWidgetOrder.decode(stored))
  }

  static func encodeCollapsed(_ widgets: Set<HomeWidget>) -> String {
    HomeWidgetOrder.encode(HomeWidget.allCases.filter { widgets.contains($0) })
  }

  static func graphics(_ stored: String) -> [HomeWidget: String] {
    guard let data = stored.data(using: .utf8),
          let values = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
    return Dictionary(uniqueKeysWithValues: values.compactMap { key, path in
      guard let widget = HomeWidget(rawValue: key), HomePhotoStore.ownedURL(path) != nil else { return nil }
      return (widget, path)
    })
  }

  static func encodeGraphics(_ values: [HomeWidget: String]) -> String {
    let active = Dictionary(uniqueKeysWithValues: values.compactMap { widget, path in
      HomePhotoStore.ownedURL(path).map { _ in (widget.rawValue, path) }
    })
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(active)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
  }
}

/// A removed card/image invalidates an outstanding picker read before private files change.
struct HomeGraphicImportState {
  struct Request: Equatable { let generation: Int; let widget: HomeWidget }
  private(set) var active: Request?
  private var generation = 0
  mutating func begin(_ widget: HomeWidget) -> Request {
    generation += 1
    let request = Request(generation: generation, widget: widget)
    active = request
    return request
  }
  mutating func cancel(_ widget: HomeWidget) {
    guard active?.widget == widget else { return }
    generation += 1; active = nil
  }
  func canCommit(_ request: Request, widgets: [HomeWidget]) -> Bool { active == request && widgets.contains(request.widget) }
  mutating func finish(_ request: Request) { if active == request { active = nil } }
}
