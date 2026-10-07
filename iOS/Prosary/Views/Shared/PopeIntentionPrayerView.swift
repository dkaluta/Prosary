import SwiftUI

struct PopeIntentionPrayerPublication: Equatable {
  let languageCode: String
  let title: String
  let text: String
  let translationCredit: String?

  static func resolve(step: RosaryStep, intention: PopeIntention?, language: String,
                      isEnabled: Bool = false) -> Self? {
    guard isEnabled, step.prayerKey == "intentioPontificis", let intention else { return nil }
    let requested = UILanguage.normalized(language)
    let hasTitle = intention.titleByLanguage?[requested]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    let hasText = intention.textByLanguage?[requested]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    let code = hasTitle && hasText ? requested : "en"
    return Self(languageCode: code, title: intention.localizedTitle(code), text: intention.localizedText(code),
                translationCredit: intention.translationCredit(code))
  }
}

/// Published context accompanies the existing intercession without changing its prayer text.
struct PopeIntentionPrayerView: View {
  let step: RosaryStep
  let languageCode: String?
  @AppStorage("showPopeIntentionInPrayers") private var isEnabled = false

  var body: some View {
    if let publication = PopeIntentionPrayerPublication.resolve(step: step, intention: TodayInfoStore.intention(),
        language: languageCode ?? UILanguage.current, isEnabled: isEnabled) {
      VStack(alignment: .leading, spacing: 8) {
        Text(publication.title).font(.headline)
        Text(publication.text).font(.body).textSelection(.enabled)
        Text(String(localized: "prayer.popeIntentionSource", defaultValue: "Pope’s Worldwide Prayer Network", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .font(.caption).foregroundStyle(.secondary)
        if let credit = publication.translationCredit {
          Text(credit).font(.caption).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding()
      .prosaryContentCardBackground()
      .environment(\.layoutDirection, LanguageCatalog.resolve(publication.languageCode).isRightToLeft ? .rightToLeft : .leftToRight)
      .accessibilityIdentifier("publishedPopeIntention")
    }
  }
}
