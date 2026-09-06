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

  /// Captions follow the Today language selection, independently of the app UI language.
  /// Roman rank terms follow the Saint James Vicariate's 2025–2026 calendar, pp. 4, 6–7:
  /// https://s3-eu-west-1.amazonaws.com/catholic.co.il/12147_SJVLiturgicalCalendar202526.pdf
  /// Other entries are ordinary UI descriptions; canonical ranks remain unchanged.
  func localizedRank(_ language: String) -> String {
    let hebrewFallback: String
    switch rank {
    case "Solemnity": hebrewFallback = "מועד"
    case "Feast": hebrewFallback = "חג"
    case "Memorial": hebrewFallback = "זיכרון"
    case "Optional Memorial": hebrewFallback = "זיכרון רשות"
    case "Sunday": hebrewFallback = "יום ראשון"
    case "Great Feast": hebrewFallback = "חג גדול"
    case "Holy Week": hebrewFallback = "השבוע הקדוש"
    case "Fast": hebrewFallback = "צום"
    case "1st Class": hebrewFallback = "דרגה ראשונה"
    case "2nd Class": hebrewFallback = "דרגה שנייה"
    case "3rd Class": hebrewFallback = "דרגה שלישית"
    default: return rank
    }
    let displayLanguage = UILanguage.resolve(language)
    let fallback = displayLanguage == "he" ? hebrewFallback : rank
    let key = "home.today.rank.\(rank.lowercased().replacingOccurrences(of: " ", with: "_"))"
    return UILanguage.text(key, language: displayLanguage, fallback: fallback)
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
      ?? (UILanguage.normalized(language) == "he" ? legacyHebrew : nil)
      ?? full
  }

  /// Kept for source compatibility with callers/tests written against the first schema.
  var hebrew: String { localizedFull("he") }
}

struct TorahPortion: Decodable, Equatable {
  let saturday: String
  let title: String
  let titleByLanguage: [String: String]?
  let isHoliday: Bool
  let readings: [ReadingCitation]
  let sourceUrl: String

  func localizedTitle(_ language: String) -> String {
    HebrewDisplayText.unpointed(localizedValue(titleByLanguage, language: language) ?? title)
  }
}

/// Language variants inherit display metadata from their base language. This intentionally
/// returns the authored value unchanged: unlike headings, Scripture citations and intention
/// prose must not be normalized a second time at runtime.
private func localizedValue(
  _ values: [String: String]?, language: String
) -> String? {
  for code in [language, UILanguage.normalized(language)] {
    if let value = values?[code], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return value
    }
  }
  return nil
}

struct LiturgicalDayInfo: Equatable {
  let english: String
  let hebrew: String
  let date: Date
  let season: String
  let week: Int
  var usesCivilDate = false

  func localized(_ language: String) -> String {
    let code = UILanguage.resolve(language)
    if usesCivilDate {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: code)
      formatter.calendar = Calendar(identifier: .gregorian)
      formatter.dateFormat = "MMMM"
      let day = Calendar(identifier: .gregorian).component(.day, from: date)
      return String(format: UILanguage.text("home.today.civilDay", language: code,
                                            fallback: "Day %lld of %@"),
                    locale: Locale(identifier: code), day, formatter.string(from: date))
    }
    if code == "he" { return hebrew }
    if code == "en" { return english }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: code)
    formatter.dateFormat = "EEEE"
    let seasonKey = season.lowercased().replacingOccurrences(of: " ", with: "_")
    let seasonName = UILanguage.text("home.today.season.\(seasonKey)", language: code, fallback: season)
    let format = UILanguage.text("home.today.week", language: code, fallback: "%@ · Week %lld of %@")
    return String(format: format, locale: Locale(identifier: code), formatter.string(from: date), week, seasonName)
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
    HebrewDisplayText.unpointed(localizedValue(nameByLanguage, language: UILanguage.current) ?? name)
  }
}

@MainActor
enum TodayInfoStore {
  static let calendarDefaultsKey = "feastCalendarId"
  static let paschaStyleDefaultsKey = "easternPaschaStyle"

  static var selectedPaschaStyle: String {
    UserDefaults.standard.string(forKey: paschaStyleDefaultsKey) == "gregorian" ? "gregorian" : "julian"
  }

  private struct FeastsFile: Decodable {
    let days: [String: FeastDay]
  }

  private struct IntentionsFile: Decodable {
    let months: [String: PopeIntention]
  }

  private struct ReadingDay: Decodable { let readings: [ReadingCitation] }
  private struct ReadingsFile: Decodable { let days: [String: ReadingDay] }
  private struct TorahPortionsFile: Decodable { let days: [String: TorahPortion] }

  private struct CalendarsFile: Decodable {
    let `default`: String
    let calendars: [FeastCalendar]
  }

  private static var feastsByDay: [String: FeastDay] = [:]
  private static var intentionsByMonth: [String: PopeIntention] = [:]
  private static var readingsByDay: [String: ReadingDay] = [:]
  private static var torahPortionsByDay: [String: TorahPortion]?
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

  static func torahPortion(on date: Date = Date()) -> TorahPortion? {
    if torahPortionsByDay == nil {
      torahPortionsByDay = decode(TorahPortionsFile.self, resource: "torah-portions")?.days ?? [:]
    }
    return torahPortionsByDay?[key(for: date, format: "yyyy-MM-dd")]
  }

  /// Only modern Roman calendars use the computed Latin season heading. Other rites retain
  /// their own sourced feast/Sunday names and show a neutral civil date on weekdays.
  static func displayDayInfo(on date: Date = Date(), calendarId: String? = nil) -> LiturgicalDayInfo? {
    let calendar = Calendar(identifier: .gregorian)
    guard calendar.component(.weekday, from: date) != 1 else { return nil }
    if ["lpj", "roman"].contains(calendarId ?? selectedCalendarId) {
      return liturgicalDayInfo(on: date)
    }
    return LiturgicalDayInfo(english: "", hebrew: "", date: calendar.startOfDay(for: date),
                             season: "", week: 0, usesCivilDate: true)
  }

  static func dateByMoving(_ days: Int, from date: Date) -> Date {
    let calendar = Calendar(identifier: .gregorian)
    return calendar.date(byAdding: .day, value: days, to: date) ?? date
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
      hebrew: "\(heWeekday) · השבוע ה־\(season.2) \(season.1)",
      date: start, season: season.0, week: season.2)
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
    formatter.calendar = Calendar(identifier: .gregorian)
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
    let variant = selected == "ugcc" && selectedPaschaStyle == "gregorian"
    let cacheId = variant ? "ugcc-gregorian" : selected
    guard cacheId != loadedCalendarId else { return }
    loadedCalendarId = cacheId
    let file = variant ? "feasts-ugcc-gregorian"
      : registry?.calendars.first { $0.id == selected }?.file ?? "feasts"
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
    let variant = selected == "ugcc" && selectedPaschaStyle == "gregorian"
    let cacheId = variant ? "ugcc-gregorian" : selected
    guard cacheId != loadedReadingsCalendarId else { return }
    loadedReadingsCalendarId = cacheId

    // Clearing before the decode is intentional. A missing/corrupt optional data file must
    // make this calendar's readings row disappear, never retain the last calendar's readings.
    readingsByDay = [:]
    guard let file = variant ? "readings-ugcc-gregorian"
      : registry?.calendars.first(where: { $0.id == selected })?.readingsFile else {
      return
    }
    readingsByDay = decode(ReadingsFile.self, resource: file)?.days ?? [:]
  }
}
