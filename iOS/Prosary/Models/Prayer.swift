
//
//  Prayer.swift
//  Prosary
//
//  A saved, user-configurable prayer session (a "Favorite"). `kind` selects the prayer type;
//  kind-specific settings live in nested option structs. Add new PrayerKind cases and matching
//  option structs here to expand into new devotions (Divine Mercy Chaplet, Seven Sorrows, etc.).
//

import Foundation

struct Prayer: Identifiable, Hashable, Codable {
  var id = UUID()
  var name: String = "My Prayer"
  var kind: PrayerKind = .rosary

  /// The starred/primary favorite for its kind — used when the home screen launches this
  /// kind of prayer without the user picking one explicitly. At most one per kind at a time.
  var isDefault: Bool = false

  /// Prayer language for this favorite. `LanguageCatalog.defaultSentinel` means follow the
  /// app-level default language setting.
  var languageCode: String = LanguageCatalog.defaultSentinel

  // Kind-specific options — populate the relevant struct when creating a Prayer.
  var rosary: RosaryOptions = .init()
  var jesusPrayer: JesusPrayerOptions = .init()

  /// The bundle id (e.g. `"angelus"`) whose `devotion.json` defines this favorite's step
  /// sequence — populated only when `kind == .custom`, nil otherwise. See `PrayerEngine.
  /// buildCustomDevotionSteps`.
  var customDevotionId: String? = nil

  /// Which of the bundle's variants (alternate step-sets, e.g. the Stations' traditional vs.
  /// scriptural forms) this favorite prays. Nil = the bundle's default (first) variant; only
  /// meaningful when `kind == .custom` and the bundle declares variants.
  var variantId: String? = nil

  /// Multi-day ("days"-type) devotions: the day this favorite prays next, 0-based. Advances
  /// when a day's session finishes; clamped by the engine so a completed novena re-prays its
  /// last day. Nil (the CloudKit-safe optional default) means day 1. Only meaningful when
  /// `kind == .custom` and the bundle's devotion is days-type.
  var dayIndex: Int? = nil

  /// This favorite's choices for the bundle's `options.json` options, keyed by option key —
  /// "true"/"false" for toggles, a case id for choices. Only overrides: an absent key means the
  /// option's declared default. Only meaningful when `kind == .custom`.
  var customOptions: [String: String] = [:]

  /// Daily reminders to pray this favorite. Scheduled via `ReminderScheduler`.
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
