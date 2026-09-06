import Foundation

/// Card names use the interface language unless the user requests a bilingual prayer shelf.
/// The translation stays separate from a card's description, preset, or progress subtitle.
struct PrayerNamePresentation: Equatable {
  static let defaultsKey = "showPrayerNameInPrayerLanguage"
  let title: String
  let translation: String?

  init(interfaceTitle: String, prayerTitle: String, showPrayerLanguage: Bool) {
    let interfaceTitle = HebrewDisplayText.unpointed(interfaceTitle)
    let prayerTitle = HebrewDisplayText.unpointed(prayerTitle)
    title = showPrayerLanguage ? prayerTitle : interfaceTitle
    translation = showPrayerLanguage && prayerTitle != interfaceTitle ? interfaceTitle : nil
  }

  @MainActor
  static func basicPrayer(_ prayer: BasicPrayer, languageCode: String,
                          showPrayerLanguage: Bool) -> Self {
    Self(
      interfaceTitle: PrayerPackStore.resolveBodyText(
        bundleId: prayer.bundleId, languageCode: UILanguage.current, key: prayer.titleKey),
      prayerTitle: PrayerPackStore.resolveBodyText(
        bundleId: prayer.bundleId, languageCode: languageCode, key: prayer.titleKey),
      showPrayerLanguage: showPrayerLanguage)
  }
}
