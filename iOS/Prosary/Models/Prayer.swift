
//
//  Prayer.swift
//  Prosary
//
//  A saved, user-configurable prayer session. `kind` selects the Rosary, the Jesus Prayer, or
//  the generic bundle path; adding an ordinary devotion means adding a bundle, not a new case.
//

import Foundation

struct Prayer: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String = "My Prayer"
  var kind: PrayerKind = .rosary

  /// The primary configuration for its devotion. At most one per
  /// (`kind`, `customDevotionId`) at a time.
  var isDefault: Bool = false

  /// Prayer language for this configuration. `LanguageCatalog.defaultSentinel` means follow the
  /// app-level default language setting.
  var languageCode: String = LanguageCatalog.defaultSentinel

  // Kind-specific options — populate the relevant struct when creating a Prayer.
  var rosary: RosaryOptions = .init()
  var jesusPrayer: JesusPrayerOptions = .init()

  /// The bundle id (e.g. `"angelus"`) whose `devotion.json` defines this configuration's step
  /// sequence — populated only when `kind == .custom`, nil otherwise. See `PrayerEngine.
  /// buildCustomDevotionSteps`.
  var customDevotionId: String? = nil

  /// Which of the bundle's variants (alternate step-sets, e.g. the Stations' traditional vs.
  /// scriptural forms) this configuration prays. Nil = the bundle's default variant; only
  /// meaningful when `kind == .custom` and the bundle declares variants.
  var variantId: String? = nil

  /// Multi-day ("days"-type) devotions: the day this configuration opens on, 0-based. Advances
  /// when a day's session finishes; clamped by the engine so a completed novena re-prays its
  /// last day. Nil (the CloudKit-safe optional default) means day 1. Only meaningful when
  /// `kind == .custom` and the bundle's devotion is days-type.
  var dayIndex: Int? = nil

  /// This configuration's choices for the bundle's `options.json` options, keyed by option key —
  /// "true"/"false" for toggles, a case id for choices. Only overrides: an absent key means the
  /// option's declared default. Only meaningful when `kind == .custom`.
  var customOptions: [String: String] = [:]

  /// Daily reminders for this configuration. Scheduled via `ReminderScheduler`.
  var reminders: [PrayerReminder] = []

  var isNotDefault: Bool { !isDefault }
  var resolvedLanguageCode: String { LanguageCatalog.resolve(languageCode).code }
  var languageNativeName: String { LanguageCatalog.resolve(languageCode).nativeName }

  /// Display string for list rows — shows "Default (Latina)" for sentinel, plain name otherwise.
  var languageDisplayName: String {
    languageCode == LanguageCatalog.defaultSentinel
      ? "Default (\(LanguageCatalog.resolve(languageCode).nativeName))"
      : LanguageCatalog.resolve(languageCode).nativeName
  }
}
