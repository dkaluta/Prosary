import Foundation

struct CalendarEvent: Identifiable {
  let date: Date
  let feast: FeastDay
  let observance: FeastObservance?
  let index: Int
  var id: String { "\(PrayerRunProgress.localDateString(for: date, calendar: Calendar(identifier: .gregorian)))|\(observance?.identity ?? "day")|\(index)" }

  func title(_ language: String) -> String {
    guard let observance else { return feast.localizedTitle(language) }
    return HebrewDisplayText.unpointed(observance.titleByLanguage?[UILanguage.normalized(language)] ?? observance.title)
  }

  func description(_ language: String) -> FeastSaintDescription? {
    observance?.saintDescription(language: language) ?? observance?.reflection(language: language)
  }
}

enum CalendarEventPresentation {
  static func dateLabel(_ date: Date, template: String = "yMMMMd") -> String {
    let formatter = DateFormatter(); formatter.locale = UILanguage.locale
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.setLocalizedDateFormatFromTemplate(template)
    return formatter.string(from: date)
  }

  static func events(on date: Date, feast: FeastDay?) -> [CalendarEvent] {
    guard let feast else { return [] }
    guard let observances = feast.observances, !observances.isEmpty else {
      return [CalendarEvent(date: date, feast: feast, observance: nil, index: 0)]
    }
    return observances.enumerated().map { CalendarEvent(date: date, feast: feast, observance: $0.element, index: $0.offset) }
  }

  /// Monday-first Gregorian civil dates, independent of the selected feast calendar/RTL.
  static func monthCells(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> [Date?] {
    guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
          let range = calendar.range(of: .day, in: .month, for: date) else { return [] }
    let leading = (calendar.component(.weekday, from: start) + 5) % 7
    var cells = Array<Date?>(repeating: nil, count: leading)
    cells += range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }.map { Optional($0) }
    while cells.count % 7 != 0 { cells.append(nil) }
    return cells
  }
}
