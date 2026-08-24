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
//  Patriarchate of Jerusalem overlay). The feast table reloads whenever the selection
//  changes; the calendar affects this row only, never the engine's season/mystery machinery.
//  A date/month outside the datasets returns nil and the row simply hides — regenerating the
//  JSON yearly is the only maintenance.
//

import Foundation

struct FeastDay: Decodable, Equatable {
  let title: String
  /// The calendar's own vocabulary: "Solemnity" / "Feast" / "Sunday" / "Memorial" /
  /// "Optional Memorial" (Roman), "1st Class" … "3rd Class" (1962). Display styling bolds
  /// "Solemnity" and "1st Class".
  let rank: String
}

struct PopeIntention: Decodable, Equatable {
  let title: String
  let text: String
}

/// One entry of calendars.json — a switchable feast calendar.
struct FeastCalendar: Decodable, Equatable, Identifiable {
  let id: String
  /// Basename of the calendar's dataset ("feasts", "feasts-roman", …).
  let file: String
  let name: String
  let nameByLanguage: [String: String]?

  /// The Settings picker label, resolved by UI language with the plain name as fallback.
  var displayName: String {
    let uiLanguage = Bundle.main.preferredLocalizations.first.map { String($0.prefix(2)) }
    return uiLanguage.flatMap { nameByLanguage?[$0] } ?? name
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

  private struct CalendarsFile: Decodable {
    let `default`: String
    let calendars: [FeastCalendar]
  }

  private static var feastsByDay: [String: FeastDay] = [:]
  private static var intentionsByMonth: [String: PopeIntention] = [:]
  private static var registry: CalendarsFile?
  private static var loadedCalendarId: String?

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
    let stored = UserDefaults.standard.string(forKey: calendarDefaultsKey)
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
}
