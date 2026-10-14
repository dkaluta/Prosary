import XCTest
@testable import Prosary

@MainActor
final class NiceneCreedTests: XCTestCase {
  private let bracketed = CreedPolicy(apostlesCreed: false, filioque: .bracketed)
  private let unbracketed = CreedPolicy(apostlesCreed: true, filioque: .unbracketed)

  private func preferences() throws -> UserDefaults {
    let suite = "NiceneCreedTests.\(UUID())"
    addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: suite) }
    return try XCTUnwrap(UserDefaults(suiteName: suite))
  }

  func testObsoleteSwitchCannotOverrideAuthoredPolicyOrInitializeAChoice() throws {
    let defaults = try preferences()
    let source = "qui ex Patre Filioque procedit. Qui cum Patre et Filio"
    for savedChoice in [false, true] {
      defaults.set(savedChoice, forKey: NiceneCreedText.defaultsKey)
      let result = NiceneCreedText.render(key: "symbolumNicaenum", text: source, alternate: nil, policy: unbracketed, defaults: defaults)
      XCTAssertEqual(result.text, source)
      XCTAssertEqual(defaults.bool(forKey: NiceneCreedText.defaultsKey), savedChoice)
    }
    defaults.removeObject(forKey: NiceneCreedText.defaultsKey)
    NiceneCreedText.initialize(for: "el", defaults: defaults)
    _ = NiceneCreedText.render(key: "symbolumNicaenum", text: source, alternate: nil, policy: unbracketed, defaults: defaults)
    XCTAssertNil(defaults.object(forKey: NiceneCreedText.defaultsKey))
  }

  func testSyriacBothScriptsBracketOnlyTheSourcedPhrase() {
    let primary = "הַו דּמֶן אַבָא ובא ננפֶק, ועַם אַבָא ✠ ועַם ברא"
    let alternate = "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ"
    let result = NiceneCreedText.render(key: "symbolumNicaenum", text: primary, alternate: alternate, policy: bracketed)
    XCTAssertEqual(result.text, "הַו דּמֶן אַבָא [ובא] ננפֶק, ועַם אַבָא ✠ ועַם ברא")
    XCTAssertEqual(result.alternate, "ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ [ܘܒܐ] ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ✠ ܘܥܰܡ ܒܪܐ")
  }

  func testMissionParenthesesAndUkrainianSourceUseSquareBrackets() {
    let mission = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)\nוְעִם הָאָב ✠ וְהַבֵּן נִסְגָּד"
    XCTAssertEqual(NiceneCreedText.render(key: "symbolumApostolorum", text: mission, alternate: nil, policy: bracketed).text,
      "אֲשֶׁר נֶאֱצַל מִן הָאָב [וּמִן הַבֵּן]\nוְעִם הָאָב ✠ וְהַבֵּן נִסְגָּד")
    XCTAssertEqual(NiceneCreedText.applying(.bracketed, text: "що від Отця [і Сина] ісходить"), "що від Отця [і Сина] ісходить")
    XCTAssertEqual(NiceneCreedText.applying(.unbracketed, text: "що від Отця [і Сина] ісходить"), "що від Отця і Сина ісходить")
  }

  func testAbsentPolicyRemovesOnlyRecognizedPhraseAndNeverInventsInsertion() {
    XCTAssertEqual(NiceneCreedText.applying(.absent, text: "qui ex Patre Filioque procedit. Qui cum Patre et Filio"),
      "qui ex Patre procedit. Qui cum Patre et Filio")
    let greek = PrayerTranslations.greek[.symbolumApostolorum]!
    XCTAssertEqual(NiceneCreedText.applying(.unbracketed, text: greek), greek)
    let apostles = PrayerTranslations.hebrew[.symbolumApostolorum]!
    XCTAssertEqual(NiceneCreedText.render(key: "symbolumApostolorum", text: apostles, alternate: nil, policy: bracketed).text, apostles)
  }

  func testUnmarkedImportsAndUnrelatedKeysRetainExactSourceText() {
    let source = "אֲשֶׁר נֶאֱצַל מִן הָאָב (וּמִן הַבֵּן)"
    XCTAssertEqual(NiceneCreedText.render(key: "symbolumNicaenum", text: source, alternate: source).text, source)
    XCTAssertEqual(NiceneCreedText.render(key: "otherPrayer", text: source, alternate: nil, policy: bracketed).text, source)
  }

  func testEasternCreedAvailabilityAndLegacyDevotionReferencesUseNicene() throws {
    let apostles = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "creed"))
    let nicene = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "niceneCreed"))
    for code in ["arc", "he-x-gamliel", "el", "uk"] {
      XCTAssertFalse(BasicPrayerCatalog.isAvailable(apostles, languageCode: code), code)
      XCTAssertTrue(BasicPrayerCatalog.isAvailable(nicene, languageCode: code), code)
      let redirected = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: code, key: "symbolumApostolorum")
      let source = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: code, key: "symbolumNicaenum")
      XCTAssertEqual(redirected, source, code)
      XCTAssertEqual(PrayerTranslations.get(languageCode: code, key: .symbolumApostolorum), source, code)
    }
    for code in ["la", "he"] { XCTAssertTrue(BasicPrayerCatalog.isAvailable(apostles, languageCode: code), code) }
  }

  func testWinningFallbackSourceOwnsPolicyWithoutMutatingPreferences() throws {
    let previous = UserDefaults.standard.object(forKey: LanguageCatalog.fallbackOrderKey)
    defer {
      if let previous { UserDefaults.standard.set(previous, forKey: LanguageCatalog.fallbackOrderKey) }
      else { UserDefaults.standard.removeObject(forKey: LanguageCatalog.fallbackOrderKey) }
    }
    UserDefaults.standard.set(["arc", "he", "la"], forKey: LanguageCatalog.fallbackOrderKey)
    let apostles = try XCTUnwrap(BasicPrayerCatalog.prayer(id: "creed"))
    XCTAssertTrue(BasicPrayerCatalog.isAvailable(apostles, languageCode: "en"), "English has its own Apostles source regardless of its Nicene fallback")
    XCTAssertFalse(BasicPrayerCatalog.isAvailable(apostles, languageCode: "arc"))
    let source = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "en", key: "symbolumNicaenum")
    XCTAssertEqual(source, PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "arc", key: "symbolumNicaenum"))
    XCTAssertTrue(source.contains("[ובא]"))
  }

  func testSourceDrivenRosaryOptionUsesTheActualCreed() throws {
    let option = try XCTUnwrap(PrayerPackStore.options(for: "rosary").first { $0.key == "apostlesCreed" })
    XCTAssertEqual(option.localizedName(bundleId: "rosary", languageCode: "arc"),
      UILanguage.text("favoriteEditor.niceneCreed", language: UILanguage.current, fallback: "Nicene Creed"))
    XCTAssertEqual(option.localizedName(bundleId: "rosary", languageCode: "en"), option.localizedName)
  }
}
