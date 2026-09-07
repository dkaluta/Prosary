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

  private init(title: String, translation: String?) {
    self.title = title
    self.translation = translation
  }

  /// Basic prayers name the exact prayer/tradition being opened. The shelf preference only
  /// adds an interface-language subtitle; it must not replace that prayer's own heading.
  @MainActor
  static func basicPrayer(_ prayer: BasicPrayer, languageCode: String,
                          interfaceLanguage: String = UILanguage.current,
                          showPrayerLanguage: Bool) -> Self {
    let interfaceTitle = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: interfaceLanguage, key: prayer.titleKey))
    let prayerTitle = HebrewDisplayText.unpointed(PrayerPackStore.resolveBodyText(
      bundleId: prayer.bundleId, languageCode: languageCode, key: prayer.titleKey))
    return Self(title: prayerTitle,
                translation: showPrayerLanguage && interfaceTitle != prayerTitle ? interfaceTitle : nil)
  }
}
