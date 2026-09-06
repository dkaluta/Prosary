import SwiftUI
import Combine
import XCTest
@testable import Prosary

@MainActor
final class PrayerTypographyTests: XCTestCase {
  func testOpenPrayerReceivesTypefaceChangesAfterSettingsUpdate() async {
    let defaults = UserDefaults.standard
    let key = PrayerTypography.syriacTypefaceKey
    let original = defaults.object(forKey: key)
    let monitor = PrayerTypographyMonitor.shared
    let newValue = monitor.typefaces.syriac == "eastern" ? "western" : "eastern"
    let updated = expectation(description: "live reading view receives changed typography")
    let subscription = monitor.$typefaces.dropFirst().sink { value in
      if value.syriac == newValue { updated.fulfill() }
    }
    defer {
      subscription.cancel()
      if let original { defaults.set(original, forKey: key) }
      else { defaults.removeObject(forKey: key) }
    }
    defaults.set(newValue, forKey: key)
    await fulfillment(of: [updated], timeout: 3)
  }

  func testOriginalSyriacBodyUsesTheSelectedAramaicFont() {
    let body = "ܐܒܘܢ ܕܒܫܡܝܐ ܢܬܩܕܫ ܫܡܟ — 28:1–7"
    XCTAssertEqual(PrayerTypography.resolvedScript(text: body, languageCode: "arc"), .syriac)
    var fonts = PrayerTypography.Typefaces()
    let original = PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts)
    fonts.syriac = "western"
    let western = PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts)
    fonts.syriac = "eastern"
    let eastern = PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts)
    XCTAssertNotEqual(original, western)
    XCTAssertNotEqual(western, eastern)
    XCTAssertNotEqual(original, eastern)
  }

  func testSquareAramaicKeepsHebrewFontAndScriptureChoice() {
    let body = "בשום אבא וברא ורוחא דקודשא"
    var fonts = PrayerTypography.Typefaces()
    let original = PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts)
    fonts.syriac = "eastern"
    XCTAssertEqual(PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts), original)
    fonts.hebrewPrayer = "davidLibre"
    XCTAssertNotEqual(PrayerTypography.font(languageCode: "arc", isScripture: false, text: body, typefaces: fonts), original)
    let scripture = PrayerTypography.font(languageCode: "arc", isScripture: true, text: body, typefaces: fonts)
    fonts.hebrewPrayer = "sansSerif"
    XCTAssertEqual(PrayerTypography.font(languageCode: "arc", isScripture: true, text: body, typefaces: fonts), scripture)
    fonts.hebrewScripture = "rashi"
    XCTAssertNotEqual(PrayerTypography.font(languageCode: "arc", isScripture: true, text: body, typefaces: fonts), scripture)
  }

  func testLatinAndCyrillicPrayerPreferencesAreIndependentOfScripture() {
    var fonts = PrayerTypography.Typefaces()
    let latin = "Notre Père, qui es aux cieux"
    let cyrillic = "Отче наш, сущий на небесах"
    let scripture = PrayerTypography.font(languageCode: "ru", isScripture: true, text: cyrillic, typefaces: fonts)
    fonts.latinPrayer = "sansSerif"
    XCTAssertEqual(PrayerTypography.font(languageCode: "fr", isScripture: false, text: latin, typefaces: fonts), .system(.body, design: .default))
    XCTAssertEqual(PrayerTypography.font(languageCode: "ru", isScripture: false, text: cyrillic, typefaces: fonts), .system(.body, design: .serif))
    fonts.cyrillicPrayer = "sansSerif"
    XCTAssertEqual(PrayerTypography.font(languageCode: "en", isScripture: false, text: cyrillic, typefaces: fonts), .system(.body, design: .default))
    XCTAssertEqual(PrayerTypography.font(languageCode: "ru", isScripture: true, text: cyrillic, typefaces: fonts), scripture)
    XCTAssertEqual(PrayerTypography.font(languageCode: "el", isScripture: false, text: "Κύριε ἐλέησον", typefaces: fonts), .system(.body, design: .serif))
  }

  func testDominantLettersIgnoreMarksNumbersAndFormatting() {
    XCTAssertEqual(PrayerTypography.script(of: "**ܐܒܘܢ ܕܒܫܡܝܐ** — 12345:67–89"), .syriac)
    XCTAssertEqual(PrayerTypography.script(of: "Отче наш, ѿче нашъ — Jn 3:16"), .cyrillic)
    XCTAssertEqual(PrayerTypography.script(of: "éèàçôûñü"), .latin)
    XCTAssertEqual(PrayerTypography.script(of: "أَبَانَا الَّذِي فِي السَّمَاوَاتِ"), .arabic)
    XCTAssertEqual(PrayerTypography.resolvedScript(text: "123 – ✠", languageCode: "arc"), .hebrew)
  }
}
