
//
//  RosaryOptions.swift
//  Prosary
//
//  Configuration options specific to the Rosary. Lives inside a Prayer when kind == .rosary.
//

import Foundation

struct RosaryOptions: Hashable, Codable {
  var mysterySelectionMode: MysterySelectionMode = .todaysMysteries

  /// Used when `mysterySelectionMode` is `.specific` or `.singleMystery`.
  var specificMysteryGroup: MysteryGroup = .joyful

  /// 1-based index into `MysteryCatalog.forGroup(specificMysteryGroup)`. Used only when
  /// `mysterySelectionMode` is `.singleMystery`.
  var specificMysteryOrder: Int = 1

  var includeApostlesCreed: Bool = true

  /// The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be.
  var includeOpeningPrayers: Bool = true

  /// An optional Fatima Prayer immediately after the three virtue Hail Marys (before the
  /// opening Glory Be), independent of the usual after-each-decade Fatima Prayer setting.
  var includeOpeningFatimaPrayer: Bool = false

  /// The Fatima Prayer ("O my Jesus...") recited after the Glory Be of each decade.
  var includeFatimaPrayer: Bool = true

  var eternalRestForDeceased: EternalRestPlacement = .none

  var marianAntiphon: MarianAntiphonOption = .seasonal

  /// The customary closing intercessions right after the Marian antiphon — for the Pope's
  /// intentions and the needs of the Church and the nation, for the local ordinary and his
  /// intentions, and for the holy souls in purgatory — each unfolding into an Our Father,
  /// Hail Mary, and Glory Be. From the Mission of St. Gamaliel's prayer book.
  var includeClosingIntentions: Bool = false

  var includeStMichaelPrayer: Bool = false

  var includeFinalSignOfCross: Bool = true

  /// Per-Rosary Aramaic form. Used only when this Rosary explicitly selects Aramaic while the
  /// app default is another language; an Aramaic app default uses the system-wide setting.
  var aramaicSignOfCrossForm: String = AramaicSignOfCrossForm.formA

  /// Collapses each decade's 10 Hail Marys and Glory Be onto one combined screen — for someone
  /// leading a group aloud from memory who doesn't need to tap through 10 visually-identical
  /// screens. See `PrayerEngine.buildRosarySteps`.
  var presenterMode: Bool = false

  /// Which artwork set illustrates the mysteries during the session. Resolved by the engine
  /// into `RosaryStep.imageVariantKey`, never by rewriting `Mystery.imageKey`.
  var mysteryImageStyle: MysteryImageStyle = .classic

  var mysterySelectionSummary: String {
    switch mysterySelectionMode {
    case .specific:
      return String(localized: "rosaryOptions.summary.always", defaultValue: "Always \(specificMysteryGroup.displayName)")
    case .singleMystery:
      let chosen = MysteryCatalog.forGroup(specificMysteryGroup).first { $0.order == specificMysteryOrder }
      let title = chosen.map { HebrewDisplayText.unpointed(MysteryTranslations.get(
        languageCode: UILanguage.current,
        imageKey: $0.imageKey).title) } ?? specificMysteryGroup.displayName
      return String(localized: "rosaryOptions.summary.singleMystery", defaultValue: "Only \(title)")
    case .fifteenMystery:
      return String(localized: "rosaryOptions.summary.fifteenMystery", defaultValue: "The 15 Mysteries")
    case .twentyMystery:
      return String(localized: "rosaryOptions.summary.twentyMystery", defaultValue: "The 20 Mysteries")
    case .todaysMysteries:
      return String(localized: "mysterySelectionMode.todaysMysteries", defaultValue: "Today's Mysteries")
    }
  }
}
