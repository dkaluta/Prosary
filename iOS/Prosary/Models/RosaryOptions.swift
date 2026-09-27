
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
  /// Omit the fifth decade of each full set; explicit single-mystery choices remain intact.
  var skipFifthDecade: Bool = false

  var includeApostlesCreed: Bool = true

  /// The opening Our Father + 3 Hail Marys (for faith, hope, and charity) + Glory Be.
  var includeOpeningPrayers: Bool = true

  /// An optional Fatima Prayer after the opening Glory Be, independent of the usual
  /// after-each-decade Fatima Prayer setting.
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
  // Retained for configurations saved while the three intentions had separate controls.
  var includeClosingPopeIntention: Bool? = nil
  var includeClosingBishopIntention: Bool? = nil
  var includeClosingDepartedIntention: Bool? = nil

  var effectiveClosingIntentions: Bool {
    get {
      (includeClosingPopeIntention ?? includeClosingIntentions)
        || (includeClosingBishopIntention ?? includeClosingIntentions)
        || (includeClosingDepartedIntention ?? includeClosingIntentions)
    }
    set {
      includeClosingIntentions = newValue
      includeClosingPopeIntention = nil
      includeClosingBishopIntention = nil
      includeClosingDepartedIntention = nil
    }
  }

  // Older packs can still reference the group keys; every group now follows one setting.
  var effectiveClosingPopeIntention: Bool { effectiveClosingIntentions }
  var effectiveClosingBishopIntention: Bool { effectiveClosingIntentions }
  var effectiveClosingDepartedIntention: Bool { effectiveClosingIntentions }

  static let legacyClosingOptionKeys = ["closingPopeIntention", "closingBishopIntention", "closingDepartedIntention"]

  /// Generic saved Rosaries can carry the former bundle option keys instead of this model.
  static func normalizedCustomOptions(_ options: [String: String], bundleId: String) -> [String: String] {
    guard bundleId == "rosary", legacyClosingOptionKeys.contains(where: { options[$0] != nil }) else {
      return options
    }
    var result = options
    let baseline = options["closingIntentions"] == "true"
    let enabled = legacyClosingOptionKeys.contains { key in
      options[key].flatMap(Bool.init) ?? baseline
    }
    for key in legacyClosingOptionKeys { result.removeValue(forKey: key) }
    result["closingIntentions"] = enabled ? "true" : "false"
    return result
  }

  var includeStMichaelPrayer: Bool = false

  var includeLitanyOfLoreto: Bool = false
  var includeRosaryCollect: Bool = true

  var effectiveRosaryCollect: Bool { includeRosaryCollect || includeLitanyOfLoreto }

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

  private enum CodingKeys: String, CodingKey {
    case mysterySelectionMode
    case specificMysteryGroup
    case specificMysteryOrder
    case skipFifthDecade
    case includeApostlesCreed
    case includeOpeningPrayers
    case includeOpeningFatimaPrayer
    case includeFatimaPrayer
    case eternalRestForDeceased
    case marianAntiphon
    case includeClosingIntentions
    case includeClosingPopeIntention
    case includeClosingBishopIntention
    case includeClosingDepartedIntention
    case includeStMichaelPrayer
    case includeLitanyOfLoreto
    case includeRosaryCollect
    case includeFinalSignOfCross
    case aramaicSignOfCrossForm
    case presenterMode
    case mysteryImageStyle
  }

  var mysterySelectionSummary: String {
    switch mysterySelectionMode {
    case .specific:
      return String(localized: "rosaryOptions.summary.always", defaultValue: "Always \(specificMysteryGroup.displayName)", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .singleMystery:
      let chosen = MysteryCatalog.forGroup(specificMysteryGroup).first { $0.order == specificMysteryOrder }
      let title = chosen.map { HebrewDisplayText.unpointed(MysteryTranslations.get(
        languageCode: UILanguage.current,
        imageKey: $0.imageKey).title) } ?? specificMysteryGroup.displayName
      return String(localized: "rosaryOptions.summary.singleMystery", defaultValue: "Only \(title)", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .fifteenMystery:
      return String(localized: "rosaryOptions.summary.fifteenMystery", defaultValue: "The 15 Mysteries", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .twentyMystery:
      return String(localized: "rosaryOptions.summary.twentyMystery", defaultValue: "The 20 Mysteries", bundle: UILanguage.bundle, locale: UILanguage.locale)
    case .todaysMysteries:
      return String(localized: "mysterySelectionMode.todaysMysteries", defaultValue: "Today's Mysteries", bundle: UILanguage.bundle, locale: UILanguage.locale)
    }
  }
}

// An absent option in an older exported prayer keeps the model default.
extension RosaryOptions {
  init(from decoder: Decoder) throws {
    self.init()
    let values = try decoder.container(keyedBy: CodingKeys.self)
    mysterySelectionMode = try values.decodeIfPresent(MysterySelectionMode.self, forKey: .mysterySelectionMode) ?? mysterySelectionMode
    specificMysteryGroup = try values.decodeIfPresent(MysteryGroup.self, forKey: .specificMysteryGroup) ?? specificMysteryGroup
    specificMysteryOrder = try values.decodeIfPresent(Int.self, forKey: .specificMysteryOrder) ?? specificMysteryOrder
    skipFifthDecade = try values.decodeIfPresent(Bool.self, forKey: .skipFifthDecade) ?? skipFifthDecade
    includeApostlesCreed = try values.decodeIfPresent(Bool.self, forKey: .includeApostlesCreed) ?? includeApostlesCreed
    includeOpeningPrayers = try values.decodeIfPresent(Bool.self, forKey: .includeOpeningPrayers) ?? includeOpeningPrayers
    includeOpeningFatimaPrayer = try values.decodeIfPresent(Bool.self, forKey: .includeOpeningFatimaPrayer) ?? includeOpeningFatimaPrayer
    includeFatimaPrayer = try values.decodeIfPresent(Bool.self, forKey: .includeFatimaPrayer) ?? includeFatimaPrayer
    eternalRestForDeceased = try values.decodeIfPresent(EternalRestPlacement.self, forKey: .eternalRestForDeceased) ?? eternalRestForDeceased
    marianAntiphon = try values.decodeIfPresent(MarianAntiphonOption.self, forKey: .marianAntiphon) ?? marianAntiphon
    includeClosingIntentions = try values.decodeIfPresent(Bool.self, forKey: .includeClosingIntentions) ?? includeClosingIntentions
    includeClosingPopeIntention = try values.decodeIfPresent(Bool.self, forKey: .includeClosingPopeIntention)
    includeClosingBishopIntention = try values.decodeIfPresent(Bool.self, forKey: .includeClosingBishopIntention)
    includeClosingDepartedIntention = try values.decodeIfPresent(Bool.self, forKey: .includeClosingDepartedIntention)
    includeStMichaelPrayer = try values.decodeIfPresent(Bool.self, forKey: .includeStMichaelPrayer) ?? includeStMichaelPrayer
    includeLitanyOfLoreto = try values.decodeIfPresent(Bool.self, forKey: .includeLitanyOfLoreto) ?? includeLitanyOfLoreto
    includeRosaryCollect = try values.decodeIfPresent(Bool.self, forKey: .includeRosaryCollect) ?? includeRosaryCollect
    includeFinalSignOfCross = try values.decodeIfPresent(Bool.self, forKey: .includeFinalSignOfCross) ?? includeFinalSignOfCross
    aramaicSignOfCrossForm = try values.decodeIfPresent(String.self, forKey: .aramaicSignOfCrossForm) ?? aramaicSignOfCrossForm
    presenterMode = try values.decodeIfPresent(Bool.self, forKey: .presenterMode) ?? presenterMode
    mysteryImageStyle = try values.decodeIfPresent(MysteryImageStyle.self, forKey: .mysteryImageStyle) ?? mysteryImageStyle
  }
}
