//
//  MarianAntiphonOption.swift
//  Prosary
//

import Foundation

/// Which closing Marian antiphon (if any) follows the Rosary.
enum MarianAntiphonOption: String, Codable, CaseIterable, Identifiable {
  case none
  /// Pick the antiphon proper to the current liturgical season automatically.
  case seasonal
  case salveRegina
  case almaRedemptorisMater
  case aveReginaCaelorum
  case reginaCaeli
  case subTuumPraesidium

  var id: String { rawValue }

  var displayName: String {
    displayName(languageCode: LanguageCatalog.resolve(nil).code)
  }

  func displayName(languageCode: String) -> String {
    switch self {
    case .none:                 return String(localized: "marianAntiphon.none", defaultValue: "None")
    case .seasonal:             return String(localized: "marianAntiphon.seasonal", defaultValue: "Automatic (Seasonal)")
    case .salveRegina:          return PrayerTranslations.get(languageCode: languageCode, key: .salveReginaTitle)
    case .almaRedemptorisMater: return PrayerTranslations.get(languageCode: languageCode, key: .almaRedemptorisMaterTitle)
    case .aveReginaCaelorum:    return PrayerTranslations.get(languageCode: languageCode, key: .aveReginaCaelorumTitle)
    case .reginaCaeli:          return PrayerTranslations.get(languageCode: languageCode, key: .reginaCaeliTitle)
    case .subTuumPraesidium:    return PrayerTranslations.get(languageCode: languageCode, key: .subTuumPraesidiumTitle)
    }
  }
}
