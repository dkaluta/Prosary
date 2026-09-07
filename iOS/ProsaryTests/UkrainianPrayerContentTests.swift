import XCTest
@testable import Prosary

@MainActor
final class UkrainianPrayerContentTests: XCTestCase {
  private var savedFallback: [String] = []

  override func setUp() {
    super.setUp()
    savedFallback = LanguageCatalog.fallbackOrder
    LanguageCatalog.setFallbackOrder(["en", "he", "la"])
  }

  override func tearDown() {
    LanguageCatalog.setFallbackOrder(savedFallback)
    super.tearDown()
  }

  private func steps(_ bundle: String, variant: String? = nil) -> [RosaryStep] {
    PrayerEngine(calendar: StubLiturgicalCalendar()).buildSteps(for:
      Prayer(kind: .custom, languageCode: "uk", customDevotionId: bundle, variantId: variant))
  }

  func testAllBasicPrayersUseTheSourcedUkrainianTitleAndBody() {
    let titles = ["Знак хреста", "Отче наш", "Радуйся, Маріє", "Слава Отцю",
                  "Апостольський символ віри", "Святий Боже"]
    for (prayer, title) in zip(BasicPrayerCatalog.all, titles) {
      let step = BasicPrayerCatalog.step(for: prayer, languageCode: "uk")
      XCTAssertEqual(step.title, title, prayer.id)
      XCTAssertEqual(PrayerTypography.script(of: step.body), .cyrillic, prayer.id)
      XCTAssertNotEqual(step.body, BasicPrayerCatalog.step(for: prayer, languageCode: "en").body)
    }
  }

  func testUkrainianDevotionsRenderTextInsteadOfUnresolvedKeys() {
    for bundle in ["divineMercyChaplet", "angelus", "oAntiphons", "sevenSorrows"] {
      let rendered = steps(bundle)
      XCTAssertFalse(rendered.isEmpty, bundle)
      XCTAssertTrue(rendered.contains { PrayerTypography.script(of: $0.body) == .cyrillic }, bundle)
      for step in rendered {
        XCTAssertNil(step.title.range(of: "^[a-z][A-Za-z0-9]*$", options: .regularExpression), step.title)
        XCTAssertNil(step.body.range(of: "^[a-z][A-Za-z0-9]*$", options: .regularExpression), step.body)
      }
    }
  }

  func testScripturalStationsUseUkrainianScriptureAndMissingMeditationsFollowTheSelectedFallback() {
    let scriptural = steps("stationsOfTheCross", variant: "scriptural")
    XCTAssertEqual(scriptural[2].title, "Ісус у Гетсиманському саду")
    XCTAssertTrue(scriptural[2].body.hasPrefix("І приходять на врочище Гетсиман"))
    XCTAssertTrue(scriptural[2].body.contains("Марко 14:32–36"))
    XCTAssertTrue(scriptural[2].isScripture)
    let english = PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "en", key: "station01Body")
    XCTAssertNotEqual(english, "station01Body")
    XCTAssertEqual(PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "uk", key: "station01Body"), english)
    XCTAssertTrue(steps("stationsOfTheCross", variant: "traditional")[2].body.contains(english))
  }
}
