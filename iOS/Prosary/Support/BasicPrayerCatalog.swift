//
//  BasicPrayerCatalog.swift
//  Prosary
//
//  The handful of prayers worth praying on their own, outside any devotion — tester-requested
//  (Erez, 2026-08-07): the Sign of the Cross, the Our Father, the Hail Mary, the Glory Be, and
//  the Trisagion's Holy God. Nothing here carries text: each entry names the same keys the
//  devotions already resolve, so a basic prayer reads in the prayer language with every chain
//  the flows use — rites included. In the Mission of St. Gamaliel's rite the list itself shows
//  his headings (קדישת over his own acclamation), with no per-rite code anywhere below.
//
//  Titles resolve through the rosary bundle (which carries the four classic title keys in all
//  six languages) and the Holy God through the trisagion bundle — the acclamation deliberately
//  stays bundle-local rather than becoming a PrayerKey, because promotion would demand
//  hardcoded tables for a text the bundle already ships everywhere.
//

import Foundation

struct BasicPrayer: Identifiable {
  let id: String
  /// The bundle whose content resolves this prayer's keys (its own chain falls through to the
  /// shared tables for `PrayerKey`-backed bodies like `paterNoster`).
  let bundleId: String
  let titleKey: String
  let bodyKey: String
  /// The prayer's traditional illustration — the same override keys the devotions use.
  let imageKey: String
}

enum BasicPrayerCatalog {
  static let languageDefaultsKey = "basicPrayersLanguageCode"

  static let all: [BasicPrayer] = [
    BasicPrayer(id: "signOfCross", bundleId: "rosary",
                titleKey: "signumCrucisTitle", bodyKey: "signumCrucis", imageKey: "crucifix"),
    BasicPrayer(id: "ourFather", bundleId: "rosary",
                titleKey: "paterNosterTitle", bodyKey: "paterNoster", imageKey: "our_father"),
    BasicPrayer(id: "hailMary", bundleId: "rosary",
                titleKey: "aveMariaTitle", bodyKey: "aveMaria", imageKey: "madonna_and_child"),
    BasicPrayer(id: "gloryBe", bundleId: "rosary",
                titleKey: "gloriaPatriTitle", bodyKey: "gloriaPatri", imageKey: "glory_be"),
    // "The Creed" resolves per community, not per catalog: the shared tables carry the
    // Apostles' Creed, and the Mission of St. Gamaliel's overlay replaces it with the Nicene —
    // exactly as their Rosary prays it (Erez, 2026-08-08).
    BasicPrayer(id: "creed", bundleId: "rosary",
                titleKey: "symbolumApostolorumTitle", bodyKey: "symbolumApostolorum",
                imageKey: "crucifix"),
    BasicPrayer(id: "holyGod", bundleId: "trisagion",
                titleKey: "trisagionAcclamationTitle", bodyKey: "trisagionAcclamation",
                imageKey: "jesus_portrait"),
  ]

  static func prayer(id: String) -> BasicPrayer? {
    all.first { $0.id == id }
  }

  /// The prayer as one step, in the selected or app-default prayer language — the same
  /// `RosaryStep` the flows render, so typography, RTL, the ✠ mark and the transliteration
  /// toggle all come along without any new machinery.
  @MainActor
  static func step(for prayer: BasicPrayer, languageCode: String? = nil) -> RosaryStep {
    let language = LanguageCatalog.resolve(languageCode).code
    return RosaryStep(
      title: PrayerPackStore.resolveBodyText(
        bundleId: prayer.bundleId, languageCode: language, key: prayer.titleKey),
      body: PrayerPackStore.resolveBodyText(
        bundleId: prayer.bundleId, languageCode: language, key: prayer.bodyKey),
      transliteratedBody: PrayerPackStore.transliteration(
        bundleId: prayer.bundleId, languageCode: language, key: prayer.bodyKey),
      imageOverrideKey: prayer.imageKey)
  }
}
