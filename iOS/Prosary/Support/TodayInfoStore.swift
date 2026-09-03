//
//  TodayInfoStore.swift
//  Prosary
//
//  Backs the Pray tab's "Today" section: the day's feast per the selected liturgical
//  calendar, and the Pope's monthly prayer intention. Everything comes from bundled offline
//  datasets (Shared/data/, generated at dev time by Shared/tools/fetch-feasts.py — movable
//  feasts baked in per year, no computus in the app). calendars.json is the registry of
//  switchable calendars (2026-08, Erez's request): the app-wide "feastCalendarId" setting
//  picks one, defaulting — also for unknown ids — to the registry's default (the Latin
//  Patriarchate of Jerusalem overlay). Feast and reading tables reload whenever the selection
//  changes, so the Today card never leaks citations from the previously selected calendar.
//  A date/month outside the datasets returns nil and the row simply hides — regenerating the
//  JSON yearly is the only maintenance.
//

import Foundation

struct FeastDay: Decodable, Equatable {
  let title: String
  let titleByLanguage: [String: String]?
  /// The calendar's own vocabulary: "Solemnity" / "Feast" / "Sunday" / "Memorial" /
  /// "Optional Memorial" (Roman), "1st Class" … "3rd Class" (1962). Display styling bolds
  /// "Solemnity" and "1st Class".
  let rank: String

  func localizedTitle(_ language: String) -> String {
    HebrewDisplayText.unpointed(localizedValue(titleByLanguage, language: language) ?? title)
  }
}

struct PopeIntention: Decodable, Equatable {
  let title: String
  let text: String
  let titleByLanguage: [String: String]?
  let textByLanguage: [String: String]?

  func localizedTitle(_ language: String) -> String {
    HebrewDisplayText.unpointed(localizedValue(titleByLanguage, language: language) ?? title)
  }
  func localizedText(_ language: String) -> String {
    localizedValue(textByLanguage, language: language) ?? text
  }
}

struct ReadingCitation: Decodable, Equatable {
  let type: String
  let short: String
  let full: String
  let shortByLanguage: [String: String]?
  let fullByLanguage: [String: String]?

  /// Compatibility for the first readings dataset, which stored one Hebrew full citation in
  /// a dedicated field before citations became language-keyed alongside feast titles.
  private let legacyHebrew: String?

  private enum CodingKeys: String, CodingKey {
    case type, short, full, shortByLanguage, fullByLanguage, hebrew
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    type = try container.decode(String.self, forKey: .type)
    short = try container.decode(String.self, forKey: .short)
    full = try container.decode(String.self, forKey: .full)
    shortByLanguage = try container.decodeIfPresent([String: String].self, forKey: .shortByLanguage)
    fullByLanguage = try container.decodeIfPresent([String: String].self, forKey: .fullByLanguage)
    legacyHebrew = try container.decodeIfPresent(String.self, forKey: .hebrew)
  }

  func localizedShort(_ language: String) -> String {
    localizedValue(shortByLanguage, language: language) ?? short
  }

  func localizedFull(_ language: String) -> String {
    localizedValue(fullByLanguage, language: language)
      ?? ((LanguageCatalog.baseLanguage(of: language) ?? language) == "he" ? legacyHebrew : nil)
      ?? full
  }

  /// Kept for source compatibility with callers/tests written against the first schema.
  var hebrew: String { localizedFull("he") }
}

/// Language variants inherit display metadata from their base language. This intentionally
/// returns the authored value unchanged: unlike headings, Scripture citations and intention
/// prose must not be normalized a second time at runtime.
private func localizedValue(
  _ values: [String: String]?, language: String
) -> String? {
  values?[language] ?? LanguageCatalog.baseLanguage(of: language).flatMap { values?[$0] }
}

struct LiturgicalDayInfo: Equatable {
  let english: String
  let hebrew: String
}

/// The Today card initially follows the app's prayer language, including Hebrew variants.
/// Its translation button may then override this for the lifetime of the visible Home view.
enum TodayTranslationLanguage {
  static func defaultsToHebrew(_ languageCode: String) -> Bool {
    (LanguageCatalog.baseLanguage(of: languageCode) ?? languageCode) == "he"
  }
}

/// One entry of calendars.json — a switchable feast calendar.
struct FeastCalendar: Decodable, Equatable, Identifiable {
  let id: String
  /// Basename of the calendar's dataset ("feasts", "feasts-roman", …).
  let file: String
  /// Basename of this calendar's citation dataset. Calendars can share a lectionary file.
  let readingsFile: String?
  let name: String
  let nameByLanguage: [String: String]?

  /// The Settings picker label, resolved by UI language with the plain name as fallback.
  var displayName: String {
    let uiLanguage = Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) }
    return HebrewDisplayText.unpointed(uiLanguage.flatMap { nameByLanguage?[$0] } ?? name)
  }
}

@MainActor
enum TodayInfoStore {
  static let calendarDefaultsKey = "feastCalendarId"

  private struct FeastsFile: Decodable {
    let days: [String: FeastDay]
  }

  private struct IntentionsFile: Decodable {
    let months: [String: PopeIntention]
  }

  private struct ReadingDay: Decodable { let readings: [ReadingCitation] }
  private struct ReadingsFile: Decodable { let days: [String: ReadingDay] }

  private struct CalendarsFile: Decodable {
    let `default`: String
    let calendars: [FeastCalendar]
  }

  private static var feastsByDay: [String: FeastDay] = [:]
  private static var intentionsByMonth: [String: PopeIntention] = [:]
  private static var readingsByDay: [String: ReadingDay] = [:]
  private static var registry: CalendarsFile?
  private static var loadedCalendarId: String?
  private static var loadedReadingsCalendarId: String?

  /// The registry's calendars, in picker order.
  static var calendars: [FeastCalendar] {
    ensureRegistryLoaded()
    return registry?.calendars ?? []
  }

  /// The selected calendar id, resolved: an unset or unknown stored id reads as the
  /// registry's default, so a calendar removed from the registry can never dead-end the row.
  static var selectedCalendarId: String {
    ensureRegistryLoaded()
    guard let registry else { return "lpj" }
    let rawStored = UserDefaults.standard.string(forKey: calendarDefaultsKey)
    // The former Hebrew Roman picker was folded into General Roman once feast titles became
    // localizable. Migrate the old persisted id instead of unexpectedly sending those users
    // back to the LPJ default.
    let stored = rawStored == "roman-he" ? "roman" : rawStored
    if rawStored == "roman-he" { UserDefaults.standard.set("roman", forKey: calendarDefaultsKey) }
    if let stored, registry.calendars.contains(where: { $0.id == stored }) {
      return stored
    }
    return registry.default
  }

  static func feast(on date: Date = Date()) -> FeastDay? {
    ensureFeastsLoaded()
    return feastsByDay[key(for: date, format: "yyyy-MM-dd")]
  }

  static func intention(for date: Date = Date()) -> PopeIntention? {
    ensureIntentionsLoaded()
    return intentionsByMonth[key(for: date, format: "yyyy-MM")]
  }

  static func readings(on date: Date = Date()) -> [ReadingCitation] {
    ensureReadingsLoaded()
    return readingsByDay[key(for: date, format: "yyyy-MM-dd")]?.readings ?? []
  }

  static func liturgicalDayInfo(on date: Date = Date()) -> LiturgicalDayInfo {
    let calendar = Calendar(identifier: .gregorian)
    let start = calendar.startOfDay(for: date)
    let year = calendar.component(.year, from: start)
    let easter = StubLiturgicalCalendar.computeEasterSunday(year: year)
    let ashWednesday = calendar.date(byAdding: .day, value: -46, to: easter)!
    let pentecost = calendar.date(byAdding: .day, value: 49, to: easter)!
    let advent = StubLiturgicalCalendar.firstSunday(onOrAfter: calendar.date(
      from: DateComponents(year: year, month: 11, day: 27))!)
    let christmasThisYear = calendar.date(from: DateComponents(year: year, month: 12, day: 25))!
    let christmasStart = start < calendar.date(from: DateComponents(year: year, month: 2, day: 1))!
      ? calendar.date(from: DateComponents(year: year - 1, month: 12, day: 25))!
      : christmasThisYear
    let baptism = StubLiturgicalCalendar.firstSunday(onOrAfter: calendar.date(
      from: DateComponents(year: year, month: 1, day: 7))!)

    let season: (String, String, Int)
    if start >= ashWednesday && start < easter {
      season = ("Lent", "בצום", week(from: ashWednesday, to: start, calendar: calendar))
    } else if start >= easter && start <= pentecost {
      season = ("Easter Season", "בזמן הפסחא", week(from: easter, to: start, calendar: calendar))
    } else if start >= advent && start < christmasThisYear {
      season = ("Advent", "בזמן הציפייה", week(from: advent, to: start, calendar: calendar))
    } else if start >= christmasStart && (start < baptism || start >= christmasThisYear) {
      season = ("Christmas Season", "בזמן חג המולד", week(from: christmasStart, to: start, calendar: calendar))
    } else if start > pentecost && start < advent {
      let days = calendar.dateComponents([.day], from: start, to: advent).day ?? 0
      season = ("Ordinary Time", "בזמן הרגיל", max(1, 35 - Int(ceil(Double(days) / 7.0))))
    } else {
      let ordinaryStart = calendar.date(byAdding: .day, value: 1, to: baptism)!
      season = ("Ordinary Time", "בזמן הרגיל", week(from: ordinaryStart, to: start, calendar: calendar))
    }

    let enWeekday = weekday(start, locale: "en_US")
    let heWeekday = weekday(start, locale: "he_IL")
    return LiturgicalDayInfo(
      english: "\(enWeekday) · Week \(season.2) of \(season.0)",
      hebrew: "\(heWeekday) · השבוע ה־\(season.2) \(season.1)")
  }

  private static func week(from origin: Date, to date: Date, calendar: Calendar) -> Int {
    max(1, (calendar.dateComponents([.day], from: origin, to: date).day ?? 0) / 7 + 1)
  }

  private static func weekday(_ date: Date, locale: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: locale)
    formatter.dateFormat = "EEEE"
    return formatter.string(from: date)
  }

  private static func key(for date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private static func decode<T: Decodable>(_ type: T.Type, resource: String) -> T? {
    guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
          let data = try? Data(contentsOf: url) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }

  private static func ensureRegistryLoaded() {
    guard registry == nil else { return }
    registry = decode(CalendarsFile.self, resource: "calendars")
  }

  private static func ensureFeastsLoaded() {
    let selected = selectedCalendarId
    guard selected != loadedCalendarId else { return }
    loadedCalendarId = selected
    let file = registry?.calendars.first { $0.id == selected }?.file ?? "feasts"
    feastsByDay = decode(FeastsFile.self, resource: file)?.days ?? [:]
  }

  private static var didLoadIntentions = false
  private static func ensureIntentionsLoaded() {
    guard !didLoadIntentions else { return }
    didLoadIntentions = true
    intentionsByMonth = decode(IntentionsFile.self, resource: "pope-intentions")?.months ?? [:]
  }

  private static func ensureReadingsLoaded() {
    let selected = selectedCalendarId
    guard selected != loadedReadingsCalendarId else { return }
    loadedReadingsCalendarId = selected

    // Clearing before the decode is intentional. A missing/corrupt optional data file must
    // make this calendar's readings row disappear, never retain the last calendar's readings.
    readingsByDay = [:]
    guard let file = registry?.calendars.first(where: { $0.id == selected })?.readingsFile else {
      return
    }
    readingsByDay = decode(ReadingsFile.self, resource: file)?.days ?? [:]
  }
}
