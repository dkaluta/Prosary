//
//  TodayInfoStore.swift
//  Prosary
//
//  Backs the Home screen's "Today" section: the day's feast per the Holy Land (Latin
//  Patriarchate of Jerusalem) calendar, and the Pope's monthly prayer intention. Both come from
//  bundled offline datasets (Shared/data/, generated at dev time — the General Roman Calendar
//  with the LPJ's documented propers overlaid, movable feasts baked in per year; and
//  popesprayer.va's published intentions). A date/month outside the datasets returns nil and the
//  row simply hides — regenerating the JSON yearly is the only maintenance.
//

import Foundation

struct FeastDay: Decodable, Equatable {
  let title: String
  /// "Solemnity" / "Feast" / "Sunday" / "Memorial" / "Optional Memorial".
  let rank: String
}

struct PopeIntention: Decodable, Equatable {
  let title: String
  let text: String
}

@MainActor
enum TodayInfoStore {
  private struct FeastsFile: Decodable {
    let days: [String: FeastDay]
  }

  private struct IntentionsFile: Decodable {
    let months: [String: PopeIntention]
  }

  private static var feastsByDay: [String: FeastDay] = [:]
  private static var intentionsByMonth: [String: PopeIntention] = [:]
  private static var didLoad = false

  static func feast(on date: Date = Date()) -> FeastDay? {
    ensureLoaded()
    return feastsByDay[key(for: date, format: "yyyy-MM-dd")]
  }

  static func intention(for date: Date = Date()) -> PopeIntention? {
    ensureLoaded()
    return intentionsByMonth[key(for: date, format: "yyyy-MM")]
  }

  private static func key(for date: Date, format: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = format
    return formatter.string(from: date)
  }

  private static func ensureLoaded() {
    guard !didLoad else { return }
    didLoad = true

    let decoder = JSONDecoder()
    if let url = Bundle.main.url(forResource: "feasts", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let file = try? decoder.decode(FeastsFile.self, from: data) {
      feastsByDay = file.days
    }
    if let url = Bundle.main.url(forResource: "pope-intentions", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let file = try? decoder.decode(IntentionsFile.self, from: data) {
      intentionsByMonth = file.months
    }
  }
}
