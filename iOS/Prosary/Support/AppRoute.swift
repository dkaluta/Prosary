//
//  AppRoute.swift
//  Prosary
//

import Foundation

enum AppRoute: Hashable {
  /// Launch any saved favorite by ID — ContentView dispatches to the right flow based on kind.
  case prayer(id: Prayer.ID)
  case favorites
  case about
  case jesusPrayerSetup
  case jesusPrayer(target: JesusPrayerTarget)
  /// Launches a generic (bundle-driven) devotion with no existing favorite — `devotionId` is the
  /// bundle id, e.g. `"angelus"`. See `PrayerKind.custom`.
  case custom(devotionId: String)
  /// The Rosary preset picker (Home → Rosary): default preset, "Pray any Rosary", then the
  /// remaining presets.
  case rosaryPicker
  /// An ad-hoc, unsaved Rosary session configured in the picker's quick-setup sheet.
  case rosaryQuickPray(prayer: Prayer)
}
