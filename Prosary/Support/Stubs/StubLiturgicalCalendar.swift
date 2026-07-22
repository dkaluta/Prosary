//
//  StubLiturgicalCalendar.swift
//  Prosary
//
//  Skeleton for the real liturgical-calendar implementation — fill in with your actual
//  weekday/season rules. Not wired into the app by default; see MockLiturgicalCalendar for a
//  fully-working version used to drive Previews and interactive testing today.
//

import SwiftUI

struct StubLiturgicalCalendar: LiturgicalCalendarProviding {
    func mysteryGroup(for date: Date) -> MysteryGroup {
        fatalError("StubLiturgicalCalendar.mysteryGroup(for:) not implemented")
    }

    func seasonColor(for date: Date) -> Color {
        fatalError("StubLiturgicalCalendar.seasonColor(for:) not implemented")
    }

    func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption {
        fatalError("StubLiturgicalCalendar.seasonalMarianAntiphon(for:) not implemented")
    }

    func isEasterSeason(for date: Date) -> Bool {
        fatalError("StubLiturgicalCalendar.isEasterSeason(for:) not implemented")
    }
}
