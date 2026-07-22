//
//  LiturgicalCalendarProviding.swift
//  Prosary
//
//  What the UI needs from the backend to know "today's" mystery group, season accent color, and
//  seasonal Marian antiphon. This is the liturgical-calendar boundary — implement
//  `StubLiturgicalCalendar` (see Support/Stubs/StubLiturgicalCalendar.swift) with your real
//  season/date logic. The UI only ever consumes the `Color` this returns; it doesn't compute it.
//

import SwiftUI

protocol LiturgicalCalendarProviding {
    func mysteryGroup(for date: Date) -> MysteryGroup
    func seasonColor(for date: Date) -> Color
    /// The Marian antiphon traditionally used during the current liturgical season.
    func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption
    /// True from Easter Sunday through the day before Pentecost, inclusive — the window in which
    /// the Angelus is traditionally replaced by the Regina Caeli.
    func isEasterSeason(for date: Date) -> Bool
}

extension LiturgicalCalendarProviding {
    func mysteryGroupToday() -> MysteryGroup { mysteryGroup(for: Date()) }
    func seasonColorToday() -> Color { seasonColor(for: Date()) }
    func seasonalMarianAntiphonToday() -> MarianAntiphonOption { seasonalMarianAntiphon(for: Date()) }
    func isEasterSeasonToday() -> Bool { isEasterSeason(for: Date()) }
}
