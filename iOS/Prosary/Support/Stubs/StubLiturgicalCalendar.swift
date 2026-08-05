
//
//  StubLiturgicalCalendar.swift
//  Prosary
//
//  Production liturgical calendar — resolves today's mystery group, seasonal Marian antiphon,
//  season accent color, and Easter season flag. Uses the traditional weekday assignment and the
//  Meeus/Jones/Butcher algorithm for Easter. Used by AppServices.shared; MockLiturgicalCalendar
//  delegates here so previews and tests run the same logic.
//
//  Weekday assignment: Mon/Sat → Joyful, Tue/Fri → Sorrowful, Wed → Glorious, Thu → Luminous,
//  Sunday → depends on liturgical season.
//

import SwiftUI

struct StubLiturgicalCalendar: LiturgicalCalendarProviding {
  static let calendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
  }()

  func mysteryGroup(for date: Date) -> MysteryGroup {
    let weekday = Self.calendar.component(.weekday, from: date)
    switch weekday {
    case 2, 7: return .joyful      // Monday, Saturday
    case 3, 6: return .sorrowful   // Tuesday, Friday
    case 4:    return .glorious    // Wednesday
    case 5:    return .luminous    // Thursday
    case 1:    return mysteryGroupForSunday(date) // Sunday
    default:   return .joyful
    }
  }

  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption {
    switch season(for: date) {
    case .advent, .christmas: return .almaRedemptorisMater
    case .lent:               return .aveReginaCaelorum
    case .easterSeason:       return .reginaCaeli
    case .other:              return .salveRegina
    }
  }

  func isEasterSeason(for date: Date) -> Bool {
    season(for: date) == .easterSeason
  }

  func isLent(for date: Date) -> Bool { season(for: date) == .lent }

  func seasonColor(for date: Date) -> Color {
    let easter = Self.computeEasterSunday(year: Self.calendar.component(.year, from: date))
    if let pentecost = Self.calendar.date(byAdding: .day, value: 49, to: easter),
       Self.calendar.isDate(date, inSameDayAs: pentecost) {
      return .adaptive(light: "#B22222", dark: "#E53935") // Pentecost: red
    }

    switch season(for: date) {
    case .advent, .lent:            return .adaptive(light: "#6A3E8E", dark: "#8E54B8") // violet
    case .christmas, .easterSeason: return .adaptive(light: "#9E7A0A", dark: "#C49B0D") // gold
    case .other:                    return .adaptive(light: "#2E7D32", dark: "#43A047") // green
    }
  }

  // MARK: - Internal season logic (internal visibility for unit tests via @testable import)

  enum LiturgicalSeason { case advent, christmas, lent, easterSeason, other }

  func mysteryGroupForSunday(_ date: Date) -> MysteryGroup {
    switch season(for: date) {
    case .advent, .christmas:    return .joyful
    case .lent:                  return .sorrowful
    case .easterSeason, .other:  return .glorious
    }
  }

  func season(for date: Date) -> LiturgicalSeason {
    let cal = Self.calendar
    let date = cal.startOfDay(for: date)
    let year = cal.component(.year, from: date)
    let easter = Self.computeEasterSunday(year: year)
    let ashWednesday = cal.date(byAdding: .day, value: -46, to: easter)!

    if date >= ashWednesday && date < easter { return .lent }

    let pentecost = cal.date(byAdding: .day, value: 49, to: easter)!
    if date >= easter && date < pentecost { return .easterSeason }

    let adventStart = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year, month: 11, day: 27))!)
    let christmas = cal.date(from: DateComponents(year: year, month: 12, day: 25))!
    if date >= adventStart && date < christmas { return .advent }

    let nextEpiphanySunday = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year + 1, month: 1, day: 7))!)
    if date >= christmas && date < nextEpiphanySunday { return .christmas }

    let previousChristmas = cal.date(from: DateComponents(year: year - 1, month: 12, day: 25))!
    let thisEpiphanySunday = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year, month: 1, day: 7))!)
    if date < christmas && date < thisEpiphanySunday && date >= previousChristmas { return .christmas }

    return .other
  }

  static func firstSunday(onOrAfter date: Date) -> Date {
    let weekday = calendar.component(.weekday, from: date)
    let offset = (1 - weekday + 7) % 7
    return calendar.date(byAdding: .day, value: offset, to: date)!
  }

  /// Meeus/Jones/Butcher algorithm for Easter Sunday.
  static func computeEasterSunday(year: Int) -> Date {
    let a = year % 19
    let b = year / 100
    let c = year % 100
    let d = b / 4
    let e = b % 4
    let f = (b + 8) / 25
    let g = (b - f + 1) / 3
    let h = (19 * a + b - d - g + 15) % 30
    let i = c / 4
    let k = c % 4
    let l = (32 + 2 * e + 2 * i - h - k) % 7
    let m = (a + 11 * h + 22 * l) / 451
    let month = (h + l - 7 * m + 114) / 31
    let day = (h + l - 7 * m + 114) % 31 + 1
    return calendar.date(from: DateComponents(year: year, month: month, day: day))!
  }
}
