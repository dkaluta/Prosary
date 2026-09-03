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
    let name = switch self {
    case .none:                 String(localized: "marianAntiphon.none", defaultValue: "None")
    case .seasonal:             String(localized: "marianAntiphon.seasonal", defaultValue: "Automatic (Seasonal)")
    case .salveRegina:          PrayerTranslations.get(languageCode: languageCode, key: .salveReginaTitle)
    case .almaRedemptorisMater: PrayerTranslations.get(languageCode: languageCode, key: .almaRedemptorisMaterTitle)
    case .aveReginaCaelorum:    PrayerTranslations.get(languageCode: languageCode, key: .aveReginaCaelorumTitle)
    case .reginaCaeli:          PrayerTranslations.get(languageCode: languageCode, key: .reginaCaeliTitle)
    case .subTuumPraesidium:    PrayerTranslations.get(languageCode: languageCode, key: .subTuumPraesidiumTitle)
    }
    return HebrewDisplayText.unpointed(name)
  }
}
