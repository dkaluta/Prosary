//
//  DevotionDirectory.swift
//  Prosary
//
//  One flat catalog of every launchable devotion — the Rosary, each loaded bundle, the Jesus
//  Prayer — with title/icon/accent/tags and the AppRoute that starts it. The Categories and
//  Search tabs both build from this so nothing devotion-specific is hardcoded in either.
//

import SwiftUI

struct DevotionListing: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  /// One grapheme (letter or emoji) drawn instead of `systemImage` when the author chose
  /// their own icon in Compose (v0.7, Gamaliel item 6).
  var iconGlyph: String? = nil
  let accentColor: Color
  /// Lowercase category labels from the manifest ("marian", "passion"). The Jesus Prayer,
  /// having no bundle, carries its tags here.
  let tags: [String]
  let route: AppRoute
}

enum DevotionDirectory {
  @MainActor
  static func all() -> [DevotionListing] {
    var listings: [DevotionListing] = []

    listings.append(DevotionListing(
      id: "rosary",
      title: PrayerKind.rosary.displayName,
      systemImage: PrayerKind.rosary.systemImage,
      accentColor: .brandPrimary,
      tags: PrayerPackStore.info(for: "rosary")?.tags ?? ["marian"],
      route: .rosaryQuickPray(prayer: Prayer(name: "", kind: .rosary, rosary: RosaryOptions()))))

    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let info = PrayerPackStore.info(for: bundleId) else { continue }
      let accent: Color
      if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
        accent = .adaptive(light: light, dark: dark)
      } else {
        accent = info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary
      }
      listings.append(DevotionListing(
        id: bundleId,
        title: info.localizedDisplayName,
        systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
        iconGlyph: info.iconGlyph,
        accentColor: accent,
        tags: info.tags,
        route: .custom(devotionId: bundleId)))
    }

    listings.append(DevotionListing(
      id: "jesusPrayer",
      title: PrayerKind.jesusPrayer.displayName,
      systemImage: PrayerKind.jesusPrayer.systemImage,
      accentColor: .adaptive(light: "#8B1A1A", dark: "#C62828"),
      tags: ["eastern", "meditative"],
      route: .jesusPrayerSetup))

    return listings
  }
}
