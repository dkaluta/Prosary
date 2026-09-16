import Foundation
import Observation
import XCTest
@testable import Prosary

@MainActor
final class UILanguageTests: XCTestCase {
  func testAppLanguageStartsWithSystemAndLeavesPrayerOverrideIntact() throws {
    let suite = "UILanguageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("arc", forKey: LanguageCatalog.defaultsKey)
    let store = InterfaceLanguageStore(defaults: defaults, notificationCenter: NotificationCenter(),
                                       systemLanguage: { "fr_CA" })

    XCTAssertEqual(store.selection, "")
    XCTAssertEqual(store.code, "fr")
    store.selection = "he"
    XCTAssertEqual(store.code, "he")
    XCTAssertEqual(defaults.string(forKey: LanguageCatalog.defaultsKey), "arc")
    store.selection = ""
    XCTAssertEqual(store.code, "fr")
    XCTAssertEqual(defaults.string(forKey: UILanguage.defaultsKey), "")
  }

  func testAppLanguageSelectionsPersistAndNormalizeSupportedAliases() throws {
    let suite = "UILanguageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let center = NotificationCenter()
    let store = InterfaceLanguageStore(defaults: defaults, notificationCenter: center, systemLanguage: { "en" })

    for language in UILanguage.all.map(\.code) {
      store.selection = language
      XCTAssertEqual(store.code, language)
      XCTAssertEqual(defaults.string(forKey: UILanguage.defaultsKey), language)
      let reopened = InterfaceLanguageStore(defaults: defaults, notificationCenter: center, systemLanguage: { "en" })
      XCTAssertEqual(reopened.selection, language)
      XCTAssertEqual(reopened.code, language)
    }
    for (alias, expected) in ["fil-PH": "tl", "iw-IL": "he", "uk_UA": "uk"] {
      store.selection = alias
      XCTAssertEqual(store.selection, expected)
      XCTAssertEqual(store.code, expected)
    }
    // Prayer-only choices belong in the separate prayer preference.
    store.selection = "arc"
    XCTAssertEqual(store.selection, "")
    XCTAssertEqual(store.code, "en")
  }

  func testAppLanguageRefreshTracksSystemOnlyWhileFollowingSystem() throws {
    let suite = "UILanguageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    var systemLanguage = "fr"
    let store = InterfaceLanguageStore(defaults: defaults, notificationCenter: NotificationCenter(),
                                       systemLanguage: { systemLanguage })
    systemLanguage = "iw-IL"
    store.refresh()
    XCTAssertEqual(store.code, "he")
    store.selection = "it"
    systemLanguage = "ar"
    store.refresh()
    XCTAssertEqual(store.code, "it")
    defaults.set("fil-PH", forKey: UILanguage.defaultsKey)
    store.refresh()
    XCTAssertEqual(store.code, "tl")
    defaults.removeObject(forKey: UILanguage.defaultsKey)
    store.refresh()
    XCTAssertEqual(store.code, "ar")
  }

  func testAppLanguageInvalidatesObservedContentWithoutReplacingStore() throws {
    let suite = "UILanguageTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let store = InterfaceLanguageStore(defaults: defaults, notificationCenter: NotificationCenter(),
                                       systemLanguage: { "en" })
    let changed = expectation(description: "An existing view's language dependency changes")
    withObservationTracking {
      XCTAssertEqual(store.code, "en")
    } onChange: {
      changed.fulfill()
    }
    store.selection = "he"
    wait(for: [changed], timeout: 1)
    XCTAssertEqual(store.code, "he")
    XCTAssertTrue(UILanguage.isRightToLeft(store.code))
  }

  func testNativeStringLocalizationUsesSelectedBundleForEveryAppLanguage() {
    for language in UILanguage.all.map(\.code) {
      let title = String(localized: "settings.interfaceLanguage", defaultValue: "App Language",
                         bundle: UILanguage.resourceBundle(for: language),
                         locale: Locale(identifier: UILanguage.resourceLanguage(language)))
      XCTAssertEqual(title, UILanguage.text("settings.interfaceLanguage", language: language, fallback: "missing"))
      if language != "en" { XCTAssertNotEqual(title, "App Language", language) }
    }
  }

  func testSystemSettingsDirectsToTheAppInEveryInterfaceLanguage() throws {
    let settingsURL = try XCTUnwrap(Bundle.main.url(forResource: "Settings", withExtension: "bundle"))
    let data = try Data(contentsOf: settingsURL.appendingPathComponent("Root.plist"))
    let root = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    let specifiers = try XCTUnwrap(root["PreferenceSpecifiers"] as? [[String: Any]])
    // System Settings must not grow another independently maintained prayer-language list.
    XCTAssertTrue(specifiers.allSatisfy { $0["Type"] as? String == "PSGroupSpecifier" && $0["Key"] == nil })
    let note = try XCTUnwrap(specifiers.first?["FooterText"] as? String)
    XCTAssertFalse(note.isEmpty)
    XCTAssertEqual(root["StringsTable"] as? String, "Root")
    for language in UILanguage.all.map(\.code) {
      let resource = UILanguage.resourceLanguage(language)
      let localizedData = try Data(contentsOf: settingsURL.appendingPathComponent("\(resource).lproj/Root.strings"))
      let localized = try XCTUnwrap(PropertyListSerialization.propertyList(from: localizedData, format: nil) as? [String: String])
      let text = try XCTUnwrap(localized[note], language)
      XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, language)
      XCTAssertTrue(text.contains("Prosary"), language)
      if language == "en" { XCTAssertEqual(text, note) }
      else { XCTAssertNotEqual(text, note, language) }
    }
  }

  func testLocaleAliasesAndRegionalCodesResolveWithoutLosingTagalog() {
    for (input, expected) in ["fil-PH": "tl", "tl_PH": "tl", "iw-IL": "he",
                              "he-x-gamliel": "he", "ar-SA": "ar", "ru-RU": "ru",
                              "fr_CA": "fr", "it-IT": "it", "en-GB": "en", "uk-UA": "uk", "uk_UA": "uk"] {
      XCTAssertEqual(UILanguage.resolve(input), expected)
    }
    XCTAssertEqual(UILanguage.resolve("la"), "en")
    XCTAssertEqual(UILanguage.resourceLanguage("tl"), "fil")
    XCTAssertTrue(UILanguage.isRightToLeft("ar-SA"))
    XCTAssertTrue(UILanguage.isRightToLeft("iw-IL"))
    XCTAssertFalse(UILanguage.isRightToLeft("fil-PH"))
    XCTAssertFalse(UILanguage.isRightToLeft("uk-UA"))
    XCTAssertEqual(UILanguage.resourceLanguage("uk-UA"), "uk")
    XCTAssertEqual(LanguageCatalog.resolve("fr").nativeName, "Français")
    XCTAssertEqual(LanguageCatalog.resolve("it").nativeName, "Italiano")
  }

  func testTodayFormatsWeekAndCaptionsInEverySelectedLanguage() {
    let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 5))!
    let day = TodayInfoStore.liturgicalDayInfo(on: date)
    let expected = ["ar": "الزمن العادي", "ru": "Рядовое время", "tl": "Karaniwang Panahon",
                    "fr": "Temps ordinaire", "it": "Tempo Ordinario", "uk": "Звичайний період"]
    for (language, season) in expected {
      let heading = day.localized(language)
      XCTAssertTrue(heading.localizedCaseInsensitiveContains(season), "\(language): \(heading)")
      XCTAssertFalse(heading.contains("Week"), heading)
      XCTAssertFalse(heading.contains("%@"), heading)
      XCTAssertFalse(heading.contains("%lld"), heading)
      let caption = UILanguage.text("home.today.fullCitations", language: language, fallback: "missing")
      XCTAssertNotEqual(caption, "missing", language)
      XCTAssertNotEqual(caption, "View full citations", language)
    }
    XCTAssertEqual(day.localized("he-x-gamliel"), day.hebrew)
    XCTAssertEqual(day.localized("en-GB"), day.english)
  }

  func testAuthoredTodayMetadataHandlesAliasesAndEmptyTranslations() throws {
    let feast = FeastDay(title: "Source feast", titleByLanguage: ["tl": "Kapistahan", "fil-PH": " ", "fr": ""], rank: "Feast")
    XCTAssertEqual(feast.localizedTitle("fil-PH"), "Kapistahan")
    XCTAssertEqual(feast.localizedTitle("fr"), "Source feast")
    let intention = PopeIntention(title: "Source", text: "Source body", titleByLanguage: ["ru": "Намерение"], textByLanguage: ["it": "Testo"])
    XCTAssertEqual(intention.localizedTitle("ru_RU"), "Намерение")
    XCTAssertEqual(intention.localizedText("it-IT"), "Testo")
    let citation = try JSONDecoder().decode(ReadingCitation.self, from: Data("""
      {"type":"gospel","short":"Jn. 3","full":"John 3:16","shortByLanguage":{"tl":"Jn. 3"},"fullByLanguage":{"tl":"Juan 3:16","ar":"يوحنا \u{2066}3:16-18\u{2069}"}}
      """.utf8))
    XCTAssertEqual(citation.localizedFull("fil-PH"), "Juan 3:16")
    XCTAssertEqual(citation.localizedFull("ar-SA"), "يوحنا \u{2066}3:16-18\u{2069}")
  }

  func testEveryUIStringHasAllInterfaceTranslationsAndCompatibleArguments() throws {
    // Validate the source catalog as well as the compiled bundles. A fallback to English can
    // otherwise make a missing language look successful in a runtime-only test.
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: project.appendingPathComponent("Prosary/Localizable.xcstrings"))
    let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let strings = try XCTUnwrap(catalog["strings"] as? [String: [String: Any]])
    let argument = try NSRegularExpression(pattern: "%([0-9]+\\$)?(lld|@)")
    func argumentTypes(_ text: String) -> [String] {
      argument.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
        Range(match.range(at: 2), in: text).map { String(text[$0]) }
      }.sorted()
    }
    for (key, entry) in strings where !key.isEmpty {
      let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], key)
      let english = try XCTUnwrap((localizations["en"]?["stringUnit"] as? [String: String])?["value"], key)
      for language in UILanguage.all.map(\.code) {
        // Xcode can canonicalize the catalog's Tagalog identifier to fil as well as
        // its compiled resource folder. Require a real translation under either alias.
        let localization = localizations[language] ?? localizations[UILanguage.resourceLanguage(language)]
        let unit = try XCTUnwrap(localization?["stringUnit"] as? [String: String], "\(key)/\(language)")
        let value = try XCTUnwrap(unit["value"], "\(key)/\(language)")
        XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key)/\(language)")
        XCTAssertEqual(argumentTypes(value), argumentTypes(english), "\(key)/\(language)")
        XCTAssertNotNil(Bundle.main.path(forResource: UILanguage.resourceLanguage(language), ofType: "lproj"), language)
      }
    }
  }

  func testUkrainianLoadsItsOwnInterfaceResourcesWithoutRussianOrEnglishFallback() throws {
    XCTAssertEqual(UILanguage.all.first { $0.code == "uk" }?.nativeName, "Українська")
    for (key, expected) in [
      "settings.title": "Налаштування",
      "tabs.pray": "Молитва",
      "basicPrayers.title": "Основні молитви",
      "home.today.today": "Сьогодні",
      "home.today.torahPortion": "Тижневий розділ Тори",
      "prayerFlow.language": "Мова молитви",
    ] {
      let ukrainian = UILanguage.text(key, language: "uk-UA", fallback: "missing")
      XCTAssertEqual(ukrainian, expected, key)
      XCTAssertNotEqual(ukrainian, UILanguage.text(key, language: "ru", fallback: "missing"), key)
      XCTAssertNotEqual(ukrainian, UILanguage.text(key, language: "en", fallback: "missing"), key)
    }
  }
}
