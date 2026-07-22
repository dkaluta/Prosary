//
//  MockLiturgicalCalendar.swift
//  Prosary
//
//  A fully-working LiturgicalCalendarProviding used to drive Previews and interactive testing
//  today. Not the production implementation — see Support/Stubs/StubLiturgicalCalendar.swift for
//  the skeleton to replace this with your own rules.
//
//  Resolves "today's mysteries" per the traditional weekday assignment: Mon/Sat Joyful,
//  Tue/Fri Sorrowful, Wed Glorious, Thu Luminous, and on Sundays the mysteries proper to the
//  liturgical season (Joyful in Advent/Christmas, Sorrowful in Lent, Glorious otherwise).
//

import SwiftUI

struct MockLiturgicalCalendar: LiturgicalCalendarProviding {
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    func mysteryGroup(for date: Date) -> MysteryGroup {
        let weekday = Self.calendar.component(.weekday, from: date) // 1 = Sunday ... 7 = Saturday
        switch weekday {
        case 2, 7: return .joyful // Monday, Saturday
        case 3, 6: return .sorrowful // Tuesday, Friday
        case 4: return .glorious // Wednesday
        case 5: return .luminous // Thursday
        case 1: return mysteryGroupForSunday(date) // Sunday
        default: return .joyful
        }
    }

    /// The Marian antiphon traditionally used during the current liturgical season.
    func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption {
        switch season(for: date) {
        case .advent, .christmas: return .almaRedemptorisMater
        case .lent: return .aveReginaCaelorum
        case .easterSeason: return .reginaCaeli
        case .other: return .salveRegina
        }
    }

    func isEasterSeason(for date: Date) -> Bool {
        season(for: date) == .easterSeason
    }

    /// The traditional liturgical color for the day, for use as an accent/banner color.
    func seasonColor(for date: Date) -> Color {
        let easter = Self.computeEasterSunday(year: Self.calendar.component(.year, from: date))
        if let pentecost = Self.calendar.date(byAdding: .day, value: 49, to: easter),
           Self.calendar.isDate(date, inSameDayAs: pentecost) {
            return Color(hex: "#B22222") // Pentecost: red
        }

        switch season(for: date) {
        case .advent, .lent: return Color(hex: "#6A3E8E") // violet
        case .christmas, .easterSeason: return Color(hex: "#B8860B") // gold/white
        case .other: return Color(hex: "#2E7D32") // green: Ordinary Time
        }
    }

    private func mysteryGroupForSunday(_ date: Date) -> MysteryGroup {
        switch season(for: date) {
        case .advent, .christmas: return .joyful
        case .lent: return .sorrowful
        case .easterSeason, .other: return .glorious
        }
    }

    private enum LiturgicalSeason { case advent, christmas, lent, easterSeason, other }

    private func season(for date: Date) -> LiturgicalSeason {
        let cal = Self.calendar
        let date = cal.startOfDay(for: date)
        let year = cal.component(.year, from: date)
        let easter = Self.computeEasterSunday(year: year)
        let ashWednesday = cal.date(byAdding: .day, value: -46, to: easter)!

        if date >= ashWednesday && date < easter {
            return .lent
        }

        let pentecost = cal.date(byAdding: .day, value: 49, to: easter)!
        if date >= easter && date < pentecost {
            return .easterSeason
        }

        let adventStart = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year, month: 11, day: 27))!)
        let christmas = cal.date(from: DateComponents(year: year, month: 12, day: 25))!
        if date >= adventStart && date < christmas {
            return .advent
        }

        // Christmas season runs from Dec 25 through the Baptism of the Lord (approximated as the
        // first Sunday on/after Jan 7), spanning new year's day.
        let nextEpiphanySunday = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year + 1, month: 1, day: 7))!)
        if date >= christmas && date < nextEpiphanySunday {
            return .christmas
        }

        let previousChristmas = cal.date(from: DateComponents(year: year - 1, month: 12, day: 25))!
        let thisEpiphanySunday = Self.firstSunday(onOrAfter: cal.date(from: DateComponents(year: year, month: 1, day: 7))!)
        if date < christmas && date < thisEpiphanySunday && date >= previousChristmas {
            return .christmas
        }

        return .other
    }

    private static func firstSunday(onOrAfter date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        let offset = (1 - weekday + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: date)!
    }

    /// Anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    private static func computeEasterSunday(year: Int) -> Date {
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
