//
//  MarianAntiphonBuilder.swift
//  Prosary
//
//  Builds the closing Marian antiphon step shared by any devotion that ends with one — the
//  Rosary (StubRosaryEngine) and the Franciscan Crown (StubFranciscanCrownEngine) both use this;
//  extracted here rather than duplicated once a second caller needed the exact same
//  style-branching logic.
//

import Foundation

enum MarianAntiphonBuilder {
  private enum Style { case standard, paschal, standalone }

  static func buildStep(_ antiphon: MarianAntiphonOption, languageCode: String?) -> RosaryStep {
    func text(_ key: PrayerKey) -> String {
      PrayerTranslations.get(languageCode: languageCode, key: key)
    }

    let (titleKey, style): (PrayerKey, Style) = {
      switch antiphon {
      case .salveRegina:          return (.salveRegina, .standard)
      case .almaRedemptorisMater: return (.almaRedemptorisMater, .standard)
      case .aveReginaCaelorum:    return (.aveReginaCaelorum, .standard)
      case .reginaCaeli:          return (.reginaCaeli, .paschal)
      case .subTuumPraesidium:    return (.subTuumPraesidium, .standalone)
      case .none, .seasonal:      return (.salveRegina, .standard)
      }
    }()

    let body: String
    switch style {
    case .standalone:
      body = text(titleKey)
    case .standard:
      body = "\(text(titleKey))\n\nV. \(text(.versiculumStandard))\nR. \(text(.responsiumStandard))\n\n\(text(.collectaStandard))"
    case .paschal:
      body = "\(text(titleKey))\n\nV. \(text(.versiculumPaschale))\nR. \(text(.responsiumPaschale))\n\n\(text(.collectaPaschale))"
    }

    var step = RosaryStep(title: header(for: antiphon), subtitle: nil, body: body)
    step.isAntiphon = true
    step.imageOverrideKey = "madonna_and_child"
    return step
  }

  private static func header(for antiphon: MarianAntiphonOption) -> String {
    switch antiphon {
    case .salveRegina:          return "Salve Regina"
    case .almaRedemptorisMater: return "Alma Redemptoris Mater"
    case .aveReginaCaelorum:    return "Ave Regina Caelorum"
    case .reginaCaeli:          return "Regina Caeli"
    case .subTuumPraesidium:    return "Sub Tuum Praesidium"
    case .none, .seasonal:      return "Marian Antiphon"
    }
  }
}
