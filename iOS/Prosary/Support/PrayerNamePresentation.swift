import Foundation

/// Card names use the interface language unless the user requests a bilingual prayer shelf.
/// The translation stays separate from a card's description, preset, or progress subtitle.
struct PrayerNamePresentation: Equatable {
  static let defaultsKey = "showPrayerNameInPrayerLanguage"
  let title: String
  let translation: String?

  /// Hebrew interface names use the Hebrew tradition of the prayer being opened.
  /// Other interface and prayer languages keep their ordinary interface translation.
  static func interfaceTitleLanguage(prayerCode: String, interfaceLanguage: String) -> String {
    interfaceLanguage == "he" && (prayerCode == "he" || prayerCode == "he-x-gamliel")
      ? prayerCode : interfaceLanguage
  }

  init(interfaceTitle: String, prayerTitle: String, showPrayerLanguage: Bool) {
    let interfaceTitle = HebrewDisplayText.unpointed(interfaceTitle)
    let prayerTitle = HebrewDisplayText.unpointed(prayerTitle)
    title = showPrayerLanguage ? prayerTitle : interfaceTitle
    translation = showPrayerLanguage && prayerTitle != interfaceTitle ? interfaceTitle : nil
  }

  private init(title: String, translation: String?) {
    self.title = title
    self.translation = translation
  }

  /// Basic prayers name the exact prayer/tradition being opened. The shelf preference only
  /// adds an interface-language subtitle; it must not replace that prayer's own heading.
  @MainActor
  static func basicPrayer(_ prayer: BasicPrayer, languageCode: String,
                          interfaceLanguage: String? = nil,
                          showPrayerLanguage: Bool) -> Self {
    let interfaceLanguage = interfaceLanguage ?? UILanguage.current
    let prayerLanguage = BasicPrayerCatalog.languageCode(for: prayer, requested: languageCode)
    let titleLanguage = interfaceTitleLanguage(prayerCode: prayerLanguage, interfaceLanguage: interfaceLanguage)
    let interfaceTitle = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: BasicPrayerCatalog.languageCode(for: prayer, requested: titleLanguage), key: prayer.titleKey))
    let prayerTitle = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: prayerLanguage, key: prayer.titleKey))
    return Self(title: prayerTitle,
                translation: showPrayerLanguage && interfaceTitle != prayerTitle ? interfaceTitle : nil)
  }
}

/// Hebrew option and progress captions name the selected Rosary tradition's prayers, just as
/// the reader does. Other language combinations keep their established interface captions.
enum RosaryPrayerLabels {
  static func option(_ key: String, languageCode: String?, interfaceLanguage: String? = nil,
                     fallback: String) -> String {
    let interfaceLanguage = interfaceLanguage ?? UILanguage.current
    let language = LanguageCatalog.resolve(languageCode).code
    guard interfaceLanguage == "he", language == "he" || language == "he-x-gamliel" else {
      return UILanguage.text(key, language: interfaceLanguage, fallback: fallback)
    }

    func title(_ key: String) -> String {
      HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
        bundleId: "rosary", languageCode: language, key: key))
    }
    func format(_ key: String, _ fallback: String, _ values: CVarArg...) -> String {
      String(format: UILanguage.text(key, language: interfaceLanguage, fallback: fallback),
             locale: Locale(identifier: interfaceLanguage), arguments: values)
    }
    switch key {
    case "favoriteEditor.openingPrayers":
      return format("favoriteEditor.openingPrayersNamed", "%1$@ + 3 × %2$@ at the opening",
                    title("paterNosterTitle"), title("aveMariaTitle"))
    case "favoriteEditor.openingFatimaPrayer":
      return format("favoriteEditor.openingFatimaPrayerNamed", "“%1$@” after the opening “%2$@”",
                    title("oratioFatimaeTitle"), title("gloriaPatriTitle"))
    case "favoriteEditor.fatimaPrayer":
      return format("favoriteEditor.fatimaPrayerNamed", "“%1$@” at the end of each mystery",
                    title("oratioFatimaeTitle"))
    case "favoriteEditor.presenterModeFooter":
      return format("favoriteEditor.presenterModeFooterNamed",
                    "Combines each decade’s ten “%1$@” prayers and “%2$@” on one screen — useful when leading a group prayer from memory.",
                    title("aveMariaTitle"), title("gloriaPatriTitle"))
    case "favoriteEditor.apostlesCreed", "favoriteEditor.niceneCreed":
      return title("symbolumApostolorumTitle")
    case "favoriteEditor.eternalRest": return title("requiemAeternamTitle")
    case "favoriteEditor.stMichaelPrayer": return title("sanctusMichaelTitle")
    case "favoriteEditor.finalSignOfCross":
      return format("favoriteEditor.finalSignOfCrossNamed", "%1$@ at the end", title("signumCrucisTitle"))
    default: return UILanguage.text(key, language: interfaceLanguage, fallback: fallback)
    }
  }

  static func hailMaryProgress(_ index: Int, total: Int, languageCode: String?,
                              interfaceLanguage: String? = nil, bundleId: String = "rosary") -> String {
    let interfaceLanguage = interfaceLanguage ?? UILanguage.current
    let language = PrayerPackStore.effectiveLanguage(for: bundleId, chosen: languageCode)
    if interfaceLanguage == "he", language == "he" || language == "he-x-gamliel" {
      let title = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
        bundleId: bundleId, languageCode: language, key: "aveMariaTitle"))
      return String(format: UILanguage.text("beadTrack.namedPrayer", language: interfaceLanguage,
                                           fallback: "%1$@ %2$lld of %3$lld"),
                    locale: Locale(identifier: interfaceLanguage), title, index, total)
    }
    return String(format: UILanguage.text("beadTrack.hailMary", language: interfaceLanguage,
                                         fallback: "Hail Mary %1$lld of %2$lld"),
                  locale: Locale(identifier: interfaceLanguage), index, total)
  }
}
