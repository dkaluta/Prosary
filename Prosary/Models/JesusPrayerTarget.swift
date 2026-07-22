//
//  JesusPrayerTarget.swift
//  Prosary
//
//  How many times the Jesus Prayer is prayed in a session. "Custom" is a setup-screen-only
//  concept (see JesusPrayerSetupView) — by the time a session starts it has already collapsed
//  into a plain `.count`, so this type only ever distinguishes a fixed target from no target
//  at all.
//

import Foundation

enum JesusPrayerTarget: Hashable {
    case count(Int)
    case unbounded
}
