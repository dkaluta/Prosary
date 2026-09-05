import Foundation
import XCTest
@testable import Prosary

@MainActor
final class UILanguageTests: XCTestCase {
  func testLocaleAliasesAndRegionalCodesResolveWithoutLosingTagalog() {
    for (input, expected) in ["fil-PH": "tl", "tl_PH": "tl", "iw-IL": "he",
                              "he-x-gamliel": "he", "ar-SA": "ar", "ru-RU": "ru",
                              "fr_CA": "fr", "it-IT": "it", "en-GB": "en"] {
      XCTAssertEqual(UILanguage.resolve(input), expected)
    }
    XCTAssertEqual(UILanguage.resolve("la"), "en")
    XCTAssertEqual(UILanguage.resourceLanguage("tl"), "fil")
    XCTAssertTrue(UILanguage.isRightToLeft("ar-SA"))
    XCTAssertTrue(UILanguage.isRightToLeft("iw-IL"))
    XCTAssertFalse(UILanguage.isRightToLeft("fil-PH"))
    XCTAssertEqual(LanguageCatalog.resolve("fr").nativeName, "Français")
    XCTAssertEqual(LanguageCatalog.resolve("it").nativeName, "Italiano")
  }

  func testTodayFormatsWeekAndCaptionsInEverySelectedLanguage() {
    let date = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 9, day: 5))!
    let day = TodayInfoStore.liturgicalDayInfo(on: date)
    let expected = ["ar": "الزمن العادي", "ru": "Рядовое время", "tl": "Karaniwang Panahon",
                    "fr": "Temps ordinaire", "it": "Tempo Ordinario"]
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

  func testEveryUIStringHasSevenNonemptyTranslationsAndCompatibleArguments() throws {
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
        let unit = try XCTUnwrap(localizations[language]?["stringUnit"] as? [String: String], "\(key)/\(language)")
        let value = try XCTUnwrap(unit["value"], "\(key)/\(language)")
        XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(key)/\(language)")
        XCTAssertEqual(argumentTypes(value), argumentTypes(english), "\(key)/\(language)")
        XCTAssertNotNil(Bundle.main.path(forResource: UILanguage.resourceLanguage(language), ofType: "lproj"), language)
      }
    }
  }
}
