import SwiftUI
import Combine
import XCTest
#if canImport(UIKit)
import UIKit
#endif
@testable import Prosary

@MainActor
final class PrayerTypographyTests: XCTestCase {
  func testStoredCustomPrayerSizeHasAVisiblePickerChoice() {
    XCTAssertEqual(PrayerTypography.textSizeChoices(including: 133), [80, 90, 100, 110, 125, 133, 150, 175, 200])
    XCTAssertEqual(PrayerTypography.textSizeChoices(including: -1), PrayerTypography.prayerTextSizeChoices)
    XCTAssertEqual(PrayerTypography.textSizeChoices(including: 999), PrayerTypography.prayerTextSizeChoices)
  }
  func testPrayerTextSizeDefaultsAndBoundsExcludeScripture() {
    XCTAssertEqual(PrayerTypography.Typefaces().prayerTextSizePercent, 100)
    XCTAssertEqual(PrayerTypography.normalizedTextSizePercent(-1), 80)
    XCTAssertEqual(PrayerTypography.normalizedTextSizePercent(999), 200)
    XCTAssertEqual(PrayerTypography.bodySizeMultiplier(percent: 150, isScripture: false), 1.5)
    XCTAssertEqual(PrayerTypography.bodySizeMultiplier(percent: 200, isScripture: true), 1)
    var small = PrayerTypography.Typefaces(), large = PrayerTypography.Typefaces()
    small.prayerTextSizePercent = 80
    large.prayerTextSizePercent = 200
    XCTAssertEqual(PrayerTypography.font(languageCode: "he", isScripture: true, typefaces: small),
      PrayerTypography.font(languageCode: "he", isScripture: true, typefaces: large))
    XCTAssertEqual(PrayerTypography.aramaicHeadingFont(text: "שלם", languageCode: "arc", typefaces: small, pointSize: 22),
      PrayerTypography.aramaicHeadingFont(text: "שלם", languageCode: "arc", typefaces: large, pointSize: 22))
  }

  func testOpenPrayerReceivesTextSizeChangesAfterSettingsUpdate() async {
    let defaults = UserDefaults.standard
    let key = PrayerTypography.prayerTextSizeKey
    let original = defaults.object(forKey: key)
    let monitor = PrayerTypographyMonitor.shared
    let target = monitor.typefaces.prayerTextSizePercent == 150 ? 125 : 150
    let updated = expectation(description: "live prayer receives its body text size")
    let subscription = monitor.$typefaces.dropFirst().sink { value in
      if value.prayerTextSizePercent == target { updated.fulfill() }
    }
    defer {
      subscription.cancel()
      if let original { defaults.set(original, forKey: key) }
      else { defaults.removeObject(forKey: key) }
    }
    defaults.set(target, forKey: key)
    NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
    await fulfillment(of: [updated], timeout: 2)
  }

  #if canImport(UIKit)
  func testShortAndLongPrayerBodiesFillTheSameProposedColumn() {
    for text in ["Fixture.", String(repeating: "Long fixture paragraph. ", count: 30), "טקסט לדוגמה.", "ܐܒܘܢ ܕܒܫܡܝܐ"] {
      let host = UIHostingController(rootView: Text(text).prayerTextStartAlignment(text: text, languageCode: "en"))
      XCTAssertEqual(host.sizeThatFits(in: CGSize(width: 280, height: 10_000)).width, 280, accuracy: 0.1)
    }
  }

  func testPrayerTextSizeChangesBodyLayoutWhileScriptureAndDynamicTypeRemainIndependent() {
    let body = PrayerTranslations.get(languageCode: "en", key: .paterNoster)
    func height(percent: Int, scripture: Bool, dynamic: DynamicTypeSize = .large) -> CGFloat {
      var fonts = PrayerTypography.Typefaces()
      fonts.prayerTextSizePercent = percent
      let host = UIHostingController(rootView: Text(body)
        .prayerFont(languageCode: "en", isScripture: scripture, text: body, typefaces: fonts)
        .dynamicTypeSize(dynamic))
      return host.sizeThatFits(in: CGSize(width: 280, height: 10_000)).height
    }
    XCTAssertGreaterThan(height(percent: 200, scripture: false), height(percent: 100, scripture: false))
    XCTAssertEqual(height(percent: 200, scripture: true), height(percent: 100, scripture: true), accuracy: 0.1)
    XCTAssertGreaterThan(height(percent: 150, scripture: false, dynamic: .accessibility3),
      height(percent: 150, scripture: false))
  }
  func testHebrewSystemSansRetainsDynamicTypeAtAccessibilitySizes() {
    var fonts = PrayerTypography.Typefaces()
    fonts.hebrewPrayer = PrayerTypography.TypefaceValue.sansSerif
    let body = "שלום לך מרים מלאת חסד האדון עמך ברוכה את בנשים וברוך פרי בטנך ישוע"
    func measuredHeight(_ size: DynamicTypeSize) -> CGFloat {
      let host = UIHostingController(rootView: Text(body)
        .prayerFont(languageCode: "he", isScripture: false, text: body, typefaces: fonts)
        .dynamicTypeSize(size))
      return host.sizeThatFits(in: CGSize(width: 280, height: 10_000)).height
    }
    XCTAssertGreaterThan(measuredHeight(.accessibility3), measuredHeight(.large) * 1.5)
  }
  #endif

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

  func testUkrainianUsesTheCyrillicPreferenceWhenNoLettersIdentifyTheScript() {
    var fonts = PrayerTypography.Typefaces()
    fonts.latinPrayer = "sansSerif"
    XCTAssertEqual(PrayerTypography.resolvedScript(text: "1 — 2", languageCode: "uk"), .cyrillic)
    XCTAssertEqual(PrayerTypography.font(languageCode: "uk", isScripture: false, typefaces: fonts),
                   .system(.body, design: .serif))
    fonts.cyrillicPrayer = "sansSerif"
    XCTAssertEqual(PrayerTypography.font(languageCode: "uk", isScripture: false, typefaces: fonts),
                   .system(.body, design: .default))
  }

  func testDominantLettersIgnoreMarksNumbersAndFormatting() {
    XCTAssertEqual(PrayerTypography.script(of: "**ܐܒܘܢ ܕܒܫܡܝܐ** — 12345:67–89"), .syriac)
    XCTAssertEqual(PrayerTypography.script(of: "Отче наш, ѿче нашъ — Jn 3:16"), .cyrillic)
    XCTAssertEqual(PrayerTypography.script(of: "éèàçôûñü"), .latin)
    XCTAssertEqual(PrayerTypography.script(of: "أَبَانَا الَّذِي فِي السَّمَاوَاتِ"), .arabic)
    XCTAssertEqual(PrayerTypography.resolvedScript(text: "123 – ✠", languageCode: "arc"), .hebrew)
  }
}
