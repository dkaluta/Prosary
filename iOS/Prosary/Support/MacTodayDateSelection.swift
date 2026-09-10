import Foundation

/// A browsed day is a civil identity, not an instant that can move into yesterday
/// when the device changes time zones. Convert to local noon only at the native API boundary.
struct MacTodayDateSelection: Equatable {
  struct CivilDay: Equatable, Comparable {
    let year: Int
    let month: Int
    let day: Int

    fileprivate init(year: Int, month: Int, day: Int) {
      self.year = year
      self.month = month
      self.day = day
    }

    fileprivate init(_ date: Date, timeZone: TimeZone) {
      let components = Self.calendar(in: timeZone).dateComponents([.year, .month, .day], from: date)
      year = components.year!
      month = components.month!
      day = components.day!
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
      (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    fileprivate func date(in timeZone: TimeZone) -> Date {
      Self.calendar(in: timeZone).date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    fileprivate static func calendar(in timeZone: TimeZone) -> Calendar {
      var calendar = Calendar(identifier: .gregorian)
      calendar.timeZone = timeZone
      return calendar
    }
  }

  static let minimumDay = CivilDay(year: 1900, month: 1, day: 1)
  static let maximumDay = CivilDay(year: 2100, month: 12, day: 31)
  private(set) var day: CivilDay
  private(set) var followsToday = true

  init(now: Date = Date(), timeZone: TimeZone = .current) {
    day = Self.clamped(CivilDay(now, timeZone: timeZone))
  }

  var canMoveBackward: Bool { day > Self.minimumDay }
  var canMoveForward: Bool { day < Self.maximumDay }

  func localDate(in timeZone: TimeZone = .current) -> Date { day.date(in: timeZone) }

  func isToday(now: Date = Date(), timeZone: TimeZone = .current) -> Bool {
    day == CivilDay(now, timeZone: timeZone)
  }

  static func pickerRange(in timeZone: TimeZone = .current) -> ClosedRange<Date> {
    let calendar = CivilDay.calendar(in: timeZone)
    let first = calendar.startOfDay(for: minimumDay.date(in: timeZone))
    let last = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: maximumDay.date(in: timeZone))!
    return first...last
  }

  mutating func select(_ date: Date, now: Date = Date(), timeZone: TimeZone = .current) {
    day = Self.clamped(CivilDay(date, timeZone: timeZone))
    followsToday = day == Self.clamped(CivilDay(now, timeZone: timeZone))
  }

  mutating func move(by days: Int, now: Date = Date(), timeZone: TimeZone = .current) {
    // UTC carries Gregorian day arithmetic only. It never becomes a displayed local instant.
    let utc = TimeZone(secondsFromGMT: 0)!
    let calendar = CivilDay.calendar(in: utc)
    guard let moved = calendar.date(byAdding: .day, value: days, to: day.date(in: utc)) else { return }
    day = Self.clamped(CivilDay(moved, timeZone: utc))
    followsToday = day == Self.clamped(CivilDay(now, timeZone: timeZone))
  }

  mutating func refresh(now: Date = Date(), timeZone: TimeZone = .current) {
    if followsToday { day = Self.clamped(CivilDay(now, timeZone: timeZone)) }
  }

  private static func clamped(_ value: CivilDay) -> CivilDay {
    min(max(value, minimumDay), maximumDay)
  }
}
