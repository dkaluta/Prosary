//
//  TodaysMysteryIntent.swift
//  Prosary
//

import AppIntents

struct TodaysMysteryIntent: AppIntent {
  static var title: LocalizedStringResource = LocalizedStringResource("appIntents.todaysMystery.title", defaultValue: "Today's Mysteries")
  static var description = IntentDescription(LocalizedStringResource(
    "appIntents.todaysMystery.description",
    defaultValue: "Tells you which set of Rosary mysteries is traditionally prayed today."))

  @MainActor
  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    let group = AppServices.shared.calendar.mysteryGroupToday()
    let text = String(localized: "appIntents.todaysMystery.response",
                      defaultValue: "Today's Mysteries: \(group.displayName).",
                      bundle: UILanguage.bundle, locale: UILanguage.locale)
    return .result(value: text, dialog: IntentDialog(stringLiteral: text))
  }
}
