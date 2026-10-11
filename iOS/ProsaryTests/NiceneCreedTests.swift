import XCTest
@testable import Prosary

@MainActor
final class NiceneCreedTests: XCTestCase {
  private func preferences() throws -> UserDefaults {
    let suite = "NiceneCreedTests.\(UUID().uuidString)"
    addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
    return try XCTUnwrap(UserDefaults(suiteName: suite))
  }

  func testFirstChosenRiteInitializesOnceAndUserChoiceSurvivesLaterRites() throws {
    let defaults = try preferences()
    XCTAssertFalse(NiceneCreedText.included(for: "el", defaults: defaults))
    XCTAssertNil(defaults.object(forKey: NiceneCreedText.defaultsKey), "Displaying Settings must not choose the rite")
    NiceneCreedText.initialize(for: "el", defaults: defaults)
    NiceneCreedText.initialize(for: "he", defaults: defaults)
    XCTAssertFalse(defaults.bool(forKey: NiceneCreedText.defaultsKey))
    defaults.set(true, forKey: NiceneCreedText.defaultsKey)
    NiceneCreedText.initialize(for: "el", defaults: defaults)
    XCTAssertTrue(defaults.bool(forKey: NiceneCreedText.defaultsKey))
  }

  func testBothAramaicScriptsChangeOnlyTheirProcessionClause() throws {
    let defaults = try preferences()
    let primary = "הַו דּמֶן אַבָא ובא ננפֶק, ועַם אַבָא ✠ ועַם ברא"
    let alternate = "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ"
    defaults.set(false, forKey: NiceneCreedText.defaultsKey)
    let omitted = NiceneCreedText.render(key: "symbolumNicaenum", text: primary, alternate: alternate, defaults: defaults)
    XCTAssertEqual(omitted.text, "הַו דּמֶן אַבָא ננפֶק, ועַם אַבָא ✠ ועַם ברא")
    XCTAssertEqual(omitted.alternate, "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ")
    defaults.set(true, forKey: NiceneCreedText.defaultsKey)
    let included = NiceneCreedText.render(key: "symbolumNicaenum", text: primary, alternate: alternate, defaults: defaults)
    XCTAssertEqual(included.text, primary)
    XCTAssertEqual(included.alternate, alternate)
    XCTAssertEqual(NiceneCreedText.applying(true, key: "symbolumNicaenum", text: omitted.text), omitted.text,
                   "Do not invent an insertion in a source that did not supply it")
  }

  func testAnnotationIsRemovedAndUnrelatedReferencesToTheSonRemain() {
    let mission = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)\nוְעִם הָאָב ✠ וְהַבֵּן נִסְגָּד"
    XCTAssertEqual(NiceneCreedText.applying(true, key: "symbolumApostolorum", text: mission),
                   "אֲשֶׁר נֶאֱצַל מִן הָאָב וּמִן הַבֵּן\nוְעִם הָאָב ✠ וְהַבֵּן נִסְגָּד")
    XCTAssertEqual(NiceneCreedText.applying(false, key: "symbolumApostolorum", text: mission),
                   "אֲשֶׁר נֶאֱצַל מִן הָאָב\nוְעִם הָאָב ✠ וְהַבֵּן נִסְגָּד")
    XCTAssertEqual(NiceneCreedText.applying(false, key: "otherPrayer", text: mission), mission)
    let apostles = PrayerTranslations.hebrew[.symbolumApostolorum]!
    XCTAssertEqual(NiceneCreedText.applying(false, key: "symbolumApostolorum", text: apostles), apostles)
    XCTAssertEqual(NiceneCreedText.applying(true, key: "symbolumNicaenum", text: "Unrecognized authored wording"), "Unrecognized authored wording")
  }

  func testGreekHasNoInventedInsertionAndFirstActualSourceSetsTheDefault() throws {
    let defaults = try preferences()
    let greek = PrayerTranslations.greek[.symbolumApostolorum]!
    let result = NiceneCreedText.render(key: "symbolumNicaenum", text: greek, alternate: nil, defaults: defaults)
    XCTAssertFalse(defaults.bool(forKey: NiceneCreedText.defaultsKey))
    XCTAssertEqual(result.text, greek)
    XCTAssertEqual(NiceneCreedText.applying(true, key: "symbolumNicaenum", text: greek), greek)
    XCTAssertEqual(NiceneCreedText.applying(false, key: "symbolumNicaenum", text: "qui ex Patre Filioque procedit. Qui cum Patre et Filio"),
                   "qui ex Patre procedit. Qui cum Patre et Filio")
  }

  func testValidationDoesNotPickARiteAndActualSourceStillInitializes() throws {
    let defaults = try preferences()
    let greek = PrayerTranslations.greek[.symbolumApostolorum]!
    NiceneCreedText.withoutInitializingPreference {
      let candidate = NiceneCreedText.render(key: "symbolumNicaenum", text: greek, alternate: nil, defaults: defaults)
      XCTAssertEqual(candidate.text, greek)
      XCTAssertNil(defaults.object(forKey: NiceneCreedText.defaultsKey))
      NiceneCreedText.withoutInitializingPreference {
        _ = NiceneCreedText.render(key: "symbolumNicaenum", text: "qui ex Patre Filioque procedit", alternate: nil, defaults: defaults)
        XCTAssertNil(defaults.object(forKey: NiceneCreedText.defaultsKey))
      }
      XCTAssertNil(defaults.object(forKey: NiceneCreedText.defaultsKey))
    }
    let printed = "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן. כְּלָאָב וְכַלְבֵּן"
    let chosen = NiceneCreedText.render(key: "symbolumNicaenum", text: printed, alternate: nil, defaults: defaults)
    XCTAssertEqual(chosen.text, printed)
    XCTAssertTrue(defaults.bool(forKey: NiceneCreedText.defaultsKey))
    XCTAssertEqual(NiceneCreedText.applying(false, key: "symbolumNicaenum", text: printed),
                   "הַנּוֹבֵעַ מֵהָאָב. כְּלָאָב וְכַלְבֵּן")
  }

  func testCatalogAndRecentPrayerNamesDoNotInitializeTheChoice() async throws {
    let keys = [NiceneCreedText.defaultsKey, LanguageCatalog.defaultsKey, BasicPrayerCatalog.languageDefaultsKey]
    let saved = keys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
    defer {
      for (key, value) in saved {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
      }
    }
    UserDefaults.standard.removeObject(forKey: NiceneCreedText.defaultsKey)
    UserDefaults.standard.set("el", forKey: LanguageCatalog.defaultsKey)
    UserDefaults.standard.set("he", forKey: BasicPrayerCatalog.languageDefaultsKey)
    XCTAssertTrue(CatalogPrayerEntity.available().contains { $0.id == "basic:niceneCreed" })
    XCTAssertNil(UserDefaults.standard.object(forKey: NiceneCreedText.defaultsKey))
    let recent = RecentPrayers(defaults: try preferences(), prayerLookup: { _ in nil })
    await recent.record(.basicPrayer(id: "niceneCreed"))
    XCTAssertEqual(recent.entries.count, 1)
    XCTAssertEqual(recent.entries.first?.title, "אני מאמין של ניקיאה")
    XCTAssertNil(UserDefaults.standard.object(forKey: NiceneCreedText.defaultsKey))
  }

  func testSeparateVicariateCreedResolvesAndSwitchUsesWinningFallbackSource() throws {
    let saved = UserDefaults.standard.object(forKey: NiceneCreedText.defaultsKey)
    let savedOrder = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      for (key, value) in [(NiceneCreedText.defaultsKey, saved), (LanguageCatalog.fallbackOrderKey, savedOrder)] {
        if let value { UserDefaults.standard.set(value, forKey: key) }
        else { UserDefaults.standard.removeObject(forKey: key) }
      }
    }
    let prayer = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "niceneCreed"))
    UserDefaults.standard.set(true, forKey: NiceneCreedText.defaultsKey)
    let included = BasicPrayerCatalog.step(for: prayer, languageCode: "he")
    XCTAssertTrue(included.body.hasPrefix("אֲנִי מַאֲמִין בֵּאלֹהִים אֶחָד\n"))
    XCTAssertTrue(included.body.contains("הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן."))
    XCTAssertFalse(included.body.contains("["))
    XCTAssertNil(included.transliteratedBody)
    UserDefaults.standard.set(false, forKey: NiceneCreedText.defaultsKey)
    let omitted = BasicPrayerCatalog.step(for: prayer, languageCode: "he")
    XCTAssertEqual(omitted.body, included.body.replacingOccurrences(of: "הַנּוֹבֵעַ מֵהָאָב וּמֵהַבֵּן", with: "הַנּוֹבֵעַ מֵהָאָב"))
    UserDefaults.standard.set(["he", "en", "la"], forKey: LanguageCatalog.fallbackOrderKey)
    let fallback = BasicPrayerCatalog.step(for: prayer, languageCode: "en")
    XCTAssertEqual(fallback.body, omitted.body, "An English request falling back to Hebrew uses the Hebrew source clause")
  }
}
