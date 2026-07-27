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
  case angelus
  case stationsOfTheCross
  case franciscanCrown
  case sevenSorrows
  case divineMercyChaplet
  case jesusPrayerSetup
  case jesusPrayer(target: JesusPrayerTarget)
  /// Launches a generic (bundle-driven) devotion with no existing favorite — `devotionId` is the
  /// bundle id, e.g. `"trisagion"`. See `PrayerKind.custom`.
  case custom(devotionId: String)
}
