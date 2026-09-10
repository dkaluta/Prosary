import Foundation

/// Reads the same copied canonical tables as Today without app-only state or SwiftData.
/// Unsupported/out-of-coverage dates remain empty; no rite borrows another rite's table.
nonisolated struct WidgetTodayContent: Equatable, Sendable {
  var feast: String?
  var readings: [String] = []
  var intention: String?
  var torah: String?
  var fullReadings: [String] = []
  var intentionText: String?
}

nonisolated struct WidgetTodayReader {
  private struct Registry: Decodable {
    var `default`: String
    var calendars: [CalendarEntry]
  }
  private struct CalendarEntry: Decodable {
    var id: String
    var file: String
    var readingsFile: String?
    var paschaVariants: [String: Variant]?
    var defaultPaschaStyle: String?
  }
  private struct Variant: Decodable { var file: String; var readingsFile: String? }
  private struct Titled: Decodable {
    var title: String
    var titleByLanguage: [String: String]?
    var text: String?
    var textByLanguage: [String: String]?
    func localizedText(_ language: String) -> String? {
      textByLanguage?[language].flatMap { $0.isEmpty ? nil : $0 } ?? text
    }
    func localized(_ language: String) -> String {
      let value = titleByLanguage?[language].flatMap { $0.isEmpty ? nil : $0 } ?? title
      // Match Today headings: Hebrew display titles do not carry vowel/cantillation marks.
      return String(value.unicodeScalars.filter { !(0x0591...0x05BD).contains($0.value)
        && $0.value != 0x05BF && !(0x05C1...0x05C2).contains($0.value)
        && !(0x05C4...0x05C5).contains($0.value) && $0.value != 0x05C7 })
    }
  }
  private struct Citation: Decodable {
    var short: String
    var shortByLanguage: [String: String]?
    var full: String?
    var fullByLanguage: [String: String]?
    var hebrew: String?
    func localizedFull(_ language: String) -> String {
      fullByLanguage?[language].flatMap { $0.isEmpty ? nil : $0 }
        ?? (language == "he" ? hebrew : nil) ?? full ?? localized(language)
    }
    func localized(_ language: String) -> String {
      shortByLanguage?[language].flatMap { $0.isEmpty ? nil : $0 } ?? short
    }
  }
  private struct Readings: Decodable { var readings: [Citation] }
  private struct Days<Value: Decodable>: Decodable { var days: [String: Value] }
  private struct Months: Decodable { var months: [String: Titled] }

  private var feasts: [String: Titled] = [:]
  private var readings: [String: Readings] = [:]
  private var intentions: [String: Titled] = [:]
  private var torah: [String: Titled] = [:]
  private let language: String

  init(settings: WidgetTodaySettings, bundle: Bundle = .main) {
    language = settings.normalizedLanguageCode
    func decode<T: Decodable>(_ type: T.Type, name: String) -> T? {
      guard let url = bundle.url(forResource: name, withExtension: "json")
        ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Data"),
            let data = try? Data(contentsOf: url) else { return nil }
      return try? JSONDecoder().decode(type, from: data)
    }
    if let registry = decode(Registry.self, name: "calendars") {
      let requested = settings.calendarID == "roman-he" ? "roman" : settings.calendarID
      let calendar = registry.calendars.first { $0.id == requested }
        ?? registry.calendars.first { $0.id == registry.default }
      if let calendar {
        let style = calendar.paschaVariants?[settings.easternPaschaStyle] != nil
          ? settings.easternPaschaStyle : calendar.defaultPaschaStyle ?? "julian"
        let variant = calendar.paschaVariants?[style]
        if settings.showFeast {
          feasts = decode(Days<Titled>.self, name: variant?.file ?? calendar.file)?.days ?? [:]
        }
        if let file = variant?.readingsFile ?? calendar.readingsFile {
          readings = decode(Days<Readings>.self, name: file)?.days ?? [:]
        }
      }
    }
    if settings.showIntention {
      intentions = decode(Months.self, name: "pope-intentions")?.months ?? [:]
    }
    if settings.showTorah {
      torah = decode(Days<Titled>.self, name: "torah-portions")?.days ?? [:]
    }
  }

  func content(on date: Date) -> WidgetTodayContent {
    let day = ProsaryWidgetSnapshot.localDateKey(date)
    return WidgetTodayContent(feast: feasts[day]?.localized(language),
                              readings: readings[day]?.readings.map { $0.localized(language) } ?? [],
                              intention: intentions[String(day.prefix(7))]?.localized(language),
                              torah: torah[day]?.localized(language),
                              fullReadings: readings[day]?.readings.map { $0.localizedFull(language) } ?? [],
                              intentionText: intentions[String(day.prefix(7))]?.localizedText(language))
  }
}
