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

  func testBasicPrayersUseUkrainianTitlesAndSourcedBodiesOrDeclaredFallbacks() {
    let titles = ["Знак хреста", "Отче наш", "Радуйся, Маріє", "Слава Отцю",
                  "Апостольський символ віри", "Святий Боже", "Слався, Царице",
                  "Мати Відкупителя", "Радуйся, Царице небес", "Царице Неба"]
    XCTAssertEqual(titles.count, BasicPrayerCatalog.all.count)
    for (prayer, title) in zip(BasicPrayerCatalog.all, titles) {
      let step = BasicPrayerCatalog.step(for: prayer, languageCode: "uk")
      XCTAssertEqual(step.title, title, prayer.id)
      // These two existing antiphon translations have sourced titles only. The catalog
      // must preserve the established body fallback rather than invent liturgical text.
      if ["almaRedemptorisMater", "aveReginaCaelorum"].contains(prayer.id) {
        XCTAssertEqual(step.body, BasicPrayerCatalog.step(for: prayer, languageCode: "en").body)
        continue
      }
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

  func testStationsUseUkrainianScriptureAndEditorialNarratives() {
    let scriptural = steps("stationsOfTheCross", variant: "scriptural")
    XCTAssertEqual(scriptural[2].title, "Ісус у Гетсиманському саду")
    XCTAssertTrue(scriptural[2].body.hasPrefix("І приходять на врочище Гетсиман"))
    XCTAssertTrue(scriptural[2].body.contains("Марко 14:32–36"))
    XCTAssertTrue(scriptural[2].isScripture)
    let traditional = steps("stationsOfTheCross", variant: "traditional")
    XCTAssertTrue(traditional[2].body.hasPrefix("Пилат не знаходить провини в Ісусі"))
    for number in 1...14 {
      let key = String(format: "station%02dBody", number)
      let ukrainian = PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "uk", key: key)
      XCTAssertEqual(PrayerTypography.script(of: ukrainian), .cyrillic, key)
      XCTAssertNotEqual(ukrainian, PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "en", key: key))
      XCTAssertTrue(traditional[number + 1].body.contains(ukrainian), key)
      XCTAssertFalse(traditional[number + 1].isScripture, key)
    }
  }

  func testMissingStationsOpeningAndClosingFollowTheSelectedFallback() {
    let traditional = steps("stationsOfTheCross", variant: "traditional")
    for key in ["stationsOpeningPrayer", "stationsClosingPrayer"] {
      let english = PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "en", key: key)
      XCTAssertNotEqual(english, key)
      XCTAssertEqual(PrayerPackStore.resolveBodyText(bundleId: "stationsOfTheCross", languageCode: "uk", key: key), english)
      XCTAssertTrue(traditional.contains { $0.body == english }, key)
    }
  }
}
