//
//  MultiDayStatus.swift
//  Prosary
//
//  What a multi-day devotion should say about itself on the Pray row: how far through a run you
//  are, or — for a series that has not begun — when it traditionally starts, so a pinned novena
//  announces itself ahead of its first day rather than sitting there mute until you remember.
//

import Foundation

enum MultiDayStatus {
  /// Nil for anything that is not a tracked series, so single-day devotions and free day-sets
  /// keep their ordinary subtitle.
  static func subtitle(for devotionId: String, on date: Date = Date()) -> String? {
    guard let definition = PrayerPackStore.definition(for: devotionId),
          let days = definition.days, days.count > 1,
          (definition.dayProgression ?? .series) == .series else { return nil }

    if let run = MultiDayRuns.run(for: devotionId) {
      if run.isComplete(dayCount: days.count) {
        return String(localized: "multiDay.complete", defaultValue: "Complete")
      }
      let day = (run.nextUnprayedDay(dayCount: days.count) ?? 0) + 1
      return String(localized: "multiDay.dayOf", defaultValue: "Day \(day) of \(days.count)")
    }

    guard let start = startDate(definition.suggestedStart, on: date) else { return nil }
    let calendar = Calendar.current
    if calendar.isDate(start, inSameDayAs: date) {
      return String(localized: "multiDay.startsToday", defaultValue: "Starts today")
    }
    return String(
      localized: "multiDay.startsOn",
      defaultValue: "Starts \(start.formatted(.dateTime.day().month(.wide)))")
  }

  /// The next occurrence of an annual "MM-DD" — this year's if it is still ahead, otherwise
  /// next year's, so a devotion whose date has passed announces the coming one.
  static func startDate(_ suggestedStart: String?, on date: Date = Date()) -> Date? {
    guard let suggestedStart else { return nil }
    let parts = suggestedStart.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 2 else { return nil }

    let calendar = Calendar.current
    let today = calendar.startOfDay(for: date)
    var components = calendar.dateComponents([.year], from: today)
    components.month = parts[0]
    components.day = parts[1]
    guard let thisYear = calendar.date(from: components) else { return nil }
    if thisYear >= today { return thisYear }
    components.year = (components.year ?? 0) + 1
    return calendar.date(from: components)
  }

  /// The devotion to offer when a run finishes, or nil. A bundle may point at something this
  /// device has never installed — a hand-written series naming its author's other work, say —
  /// so an unresolvable suggestion is simply not offered rather than shown as a dead end.
  static func suggestedNext(after devotionId: String) -> (id: String, name: String)? {
    guard let suggestion = PrayerPackStore.definition(for: devotionId)?.suggestedNext,
          let info = PrayerPackStore.info(for: suggestion) else { return nil }
    return (suggestion, info.localizedDisplayName)
  }
}
