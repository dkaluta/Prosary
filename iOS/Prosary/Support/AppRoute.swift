//
//  AppRoute.swift
//  Prosary
//

import Foundation

enum AppRoute: Hashable {
  /// Launch any saved favorite by ID — ContentView dispatches to the right flow based on kind.
  case prayer(id: Prayer.ID)
  case about
  /// A devotion's saved presets, reached from the disclosure on its Pray row.
  case rosaryPresets
  case jesusPrayerSetup
  case jesusPrayer(target: JesusPrayerTarget)
  /// Launches a generic (bundle-driven) devotion with no existing favorite — `devotionId` is the
  /// bundle id, e.g. `"angelus"`. See `PrayerKind.custom`.
  case custom(devotionId: String)
  /// An ad-hoc, unsaved Rosary session configured in the picker's quick-setup sheet.
  case rosaryQuickPray(prayer: Prayer)
  /// The basic prayers on their own (Erez, 2026-08-07) — the list, and one prayer as a
  /// single-step flow. `id` is a BasicPrayerCatalog id, not a bundle id.
  case basicPrayers
  case basicPrayer(id: String)
}
