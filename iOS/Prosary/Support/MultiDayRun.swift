//
//  MultiDayRun.swift
//  Prosary
//
//  One run through a multi-day devotion — a novena's nine days, a triduum's three, a 33-day
//  consecration. The day count always comes from the bundle's own `days` array; nothing here
//  assumes nine.
//
//  Deliberately not part of `Prayer`: a Prayer is a saved configuration you keep, while a run
//  is where you are in something you started, and the two have different lifetimes (starting
//  over must not disturb your language or reminders). It records *which days were prayed*
//  rather than only how far you got, because a missed day and the day today's date calls for
//  are different answers — see `dueDay` and `missedDay`.
//

import Foundation

struct MultiDayRun: Codable, Equatable {
  let devotionId: String
  /// The calendar day the run began; day 1 belongs to this date, day 2 to the next, and so on.
  var startedOn: Date
  /// Zero-based day indices already prayed, so a skipped day stays visibly skipped.
  var prayedDays: [Int]
  var lastPrayedOn: Date?

  init(devotionId: String, startedOn: Date = Date(), prayedDays: [Int] = [], lastPrayedOn: Date? = nil) {
    self.devotionId = devotionId
    self.startedOn = startedOn
    self.prayedDays = prayedDays
    self.lastPrayedOn = lastPrayedOn
  }

  private static var calendar: Calendar { .current }

  /// Whole days between the start and `date`, so "which day should today be?" is a calendar
  /// question rather than a count of completions.
  private func elapsedDays(on date: Date) -> Int {
    let from = Self.calendar.startOfDay(for: startedOn)
    let to = Self.calendar.startOfDay(for: date)
    return Self.calendar.dateComponents([.day], from: from, to: to).day ?? 0
  }

  /// The day the calendar calls for today, clamped to the devotion's length.
  func dueDay(dayCount: Int, on date: Date = Date()) -> Int {
    min(max(elapsedDays(on: date), 0), max(dayCount - 1, 0))
  }

  /// The earliest day still unprayed — what "continue where I left off" means. Nil when the
  /// whole run is done.
  func nextUnprayedDay(dayCount: Int) -> Int? {
    (0..<dayCount).first { !prayedDays.contains($0) }
  }

  /// The day that should have been prayed but was not, when the calendar has moved past it.
  /// Nil when nothing was missed — which is what distinguishes "continue" from a real choice.
  func missedDay(dayCount: Int, on date: Date = Date()) -> Int? {
    guard let next = nextUnprayedDay(dayCount: dayCount) else { return nil }
    return next < dueDay(dayCount: dayCount, on: date) ? next : nil
  }

  func isComplete(dayCount: Int) -> Bool {
    nextUnprayedDay(dayCount: dayCount) == nil
  }

  /// True once today's day has been prayed: reopening the devotion the same day shows that day
  /// again rather than advancing, which is the point of counting calendar days.
  func hasPrayedToday(on date: Date = Date()) -> Bool {
    guard let last = lastPrayedOn else { return false }
    return Self.calendar.isDate(last, inSameDayAs: date)
  }

  mutating func recordPrayed(day: Int, on date: Date = Date()) {
    if !prayedDays.contains(day) { prayedDays.append(day) }
    lastPrayedOn = date
  }

  /// What opening the devotion should offer. `.resume` when there is only one sensible answer;
  /// `.choose` when a day was missed, since skipping it and taking it are both legitimate.
  enum Resumption: Equatable {
    case start
    case resume(day: Int)
    case choose(missed: Int, next: Int)
    case complete
  }

  func resumption(dayCount: Int, on date: Date = Date()) -> Resumption {
    guard dayCount > 1 else { return .start }
    guard let next = nextUnprayedDay(dayCount: dayCount) else { return .complete }
    if let missed = missedDay(dayCount: dayCount, on: date) {
      let due = dueDay(dayCount: dayCount, on: date)
      return missed == due ? .resume(day: missed) : .choose(missed: missed, next: due)
    }
    return .resume(day: next)
  }
}
