
//
//  RosaryEngineTests.swift
//  ProsaryTests
//
//  Tests that PrayerEngine builds the expected step sequences for a range of RosaryOptions
//  configurations.
//

import XCTest
import SwiftUI
@testable import Prosary

private struct FixedCalendar: LiturgicalCalendarProviding {
  let group: MysteryGroup
  func mysteryGroup(for date: Date) -> MysteryGroup { group }
  func seasonColor(for date: Date) -> Color { .clear }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { .salveRegina }
  func isEasterSeason(for date: Date) -> Bool { false }
  func isLent(for date: Date) -> Bool { false }
}

final class RosaryEngineTests: XCTestCase {
  private func makeEngine(group: MysteryGroup = .joyful) -> PrayerEngine {
    PrayerEngine(calendar: FixedCalendar(group: group))
  }

  private func prayer(
    group: MysteryGroup = .joyful,
    mode: MysterySelectionMode = .specific,
    order: Int = 1,
    includeCreed: Bool = true,
    includeOpening: Bool = true,
    includeOpeningFatima: Bool = false,
    includeFatima: Bool = true,
    eternalRest: EternalRestPlacement = .none,
    antiphon: MarianAntiphonOption = .salveRegina,
    closingIntentions: Bool = false,
    includeMichael: Bool = false,
    includeFinalCross: Bool = true,
    presenterMode: Bool = false,
    imageStyle: MysteryImageStyle = .classic,
    language: String = LanguageCatalog.defaultSentinel,
    aramaicSignOfCrossForm: String = AramaicSignOfCrossForm.formA
  ) -> Prayer {
    Prayer(languageCode: language, rosary: RosaryOptions(
      mysterySelectionMode: mode,
      specificMysteryGroup: group,
      specificMysteryOrder: order,
      includeApostlesCreed: includeCreed,
      includeOpeningPrayers: includeOpening,
      includeOpeningFatimaPrayer: includeOpeningFatima,
      includeFatimaPrayer: includeFatima,
      eternalRestForDeceased: eternalRest,
      marianAntiphon: antiphon,
      includeClosingIntentions: closingIntentions,
      includeStMichaelPrayer: includeMichael,
      includeFinalSignOfCross: includeFinalCross,
      aramaicSignOfCrossForm: aramaicSignOfCrossForm,
      presenterMode: presenterMode,
      mysteryImageStyle: imageStyle
    ))
  }

  // MARK: - Step count

  @MainActor
  func testAramaicReadingAidsSurviveEveryDecadeAndPresenterMode() throws {
    let steps = makeEngine().buildSteps(for: prayer(language: "arc"))
    for (key, expectedCount) in [("paterNoster", 5), ("aveMaria", 50), ("gloriaPatri", 5)] {
      let body = PrayerPackStore.resolveBodyText(bundleId: "rosary", languageCode: "arc", key: key)
      let readingAid = try XCTUnwrap(PrayerPackStore.transliteration(
        bundleId: "rosary", languageCode: "arc", key: key))
      let beads = steps.filter { $0.decadeIndex != nil && $0.body == body }
      XCTAssertEqual(beads.count, expectedCount, key)
      XCTAssertTrue(beads.allSatisfy { $0.transliteratedBody == readingAid }, key)
    }

    let presenter = makeEngine().buildSteps(for: prayer(presenterMode: true, language: "arc"))
    let combined = presenter.filter { $0.hailMaryIndexInDecade != nil }
    let readingAid = try ["aveMaria", "gloriaPatri"].map {
      try XCTUnwrap(PrayerPackStore.transliteration(bundleId: "rosary", languageCode: "arc", key: $0))
    }.joined(separator: "\n\n")
    XCTAssertEqual(combined.count, 5)
    XCTAssertTrue(combined.allSatisfy { $0.transliteratedBody == readingAid })
  }

  func testFiveDecadeStepCountDefaultConfig() {
    let engine = makeEngine()
    let steps = engine.buildSteps(for: prayer())
    // 1 sign of cross + 1 creed + 1 OurFather + 3 HailMarys + 1 GloryBe = 7 opening
    // Per decade: 1 mystery + 1 OurFather + 10 HailMarys + 1 GloryBe + 1 Fatima = 14
    // 5 decades = 70
    // 1 antiphon + 1 closing cross = 2
    // Total = 7 + 70 + 2 = 79
    XCTAssertEqual(steps.count, 79)
  }

  func testNoOpeningPrayersReducesCount() {
    let engine = makeEngine()
    let withOpening = engine.buildSteps(for: prayer(includeOpening: true)).count
    let withoutOpening = engine.buildSteps(for: prayer(includeOpening: false)).count
    // Opening = OurFather(1) + 3HailMarys(3) + GloryBe(1) = 5
    XCTAssertEqual(withoutOpening, withOpening - 5)
  }

  func testNoApostlesCreedReducesCount() {
    let engine = makeEngine()
    let with = engine.buildSteps(for: prayer(includeCreed: true)).count
    let without = engine.buildSteps(for: prayer(includeCreed: false)).count
    XCTAssertEqual(without, with - 1)
  }

  func testNoFatimaPrayerReducesCountByFiveDecades() {
    let engine = makeEngine()
    let with = engine.buildSteps(for: prayer(includeFatima: true)).count
    let without = engine.buildSteps(for: prayer(includeFatima: false)).count
    XCTAssertEqual(without, with - 5)
  }

  func testOptionalFatimaPrayerFollowsTheThreeOpeningHailMarys() {
    let engine = makeEngine()
    var p = prayer(includeOpeningFatima: true)
    p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    guard let charity = steps.firstIndex(where: { $0.imageOverrideKey == "virtue_charity" }) else {
      return XCTFail("missing opening charity Hail Mary")
    }
    XCTAssertEqual(steps[charity + 1].title, "Fatima Prayer")
    XCTAssertEqual(steps[charity + 2].title, "Glory Be")
    XCTAssertEqual(steps.filter { $0.title == "Fatima Prayer" }.count, 6)
    XCTAssertEqual(steps.count, 80)
  }

  func testOpeningVirtueHailMarysCarryLocalizedThreePartCounters() {
    let english = makeEngine().buildSteps(for: prayer(language: "en"))
      .filter { $0.imageOverrideKey?.hasPrefix("virtue_") == true }
    XCTAssertEqual(english.map(\.title), [
      "Hail Mary (1 of 3)", "Hail Mary (2 of 3)", "Hail Mary (3 of 3)",
    ])

    let hebrew = makeEngine().buildSteps(for: prayer(language: "he"))
      .filter { $0.imageOverrideKey?.hasPrefix("virtue_") == true }
    XCTAssertEqual(hebrew.map(\.title), [
      "שמחי מרים (1 מתוך 3)", "שמחי מרים (2 מתוך 3)", "שמחי מרים (3 מתוך 3)",
    ])
    XCTAssertTrue(hebrew.allSatisfy { $0.subtitle == $0.subtitle.map(HebrewDisplayText.unpointed) })
    XCTAssertTrue(hebrew.first?.body.contains("שִׂמְחִי מִרְיָם") == true,
                  "display-only title stripping must not alter the pointed prayer body")
  }

  func testOpeningFatimaPrayerRequiresTheOpeningPrayers() {
    var p = prayer(includeOpening: false, includeOpeningFatima: true, includeFatima: false)
    p.languageCode = "en"
    let steps = makeEngine().buildSteps(for: p)
    XCTAssertFalse(steps.contains { $0.title == "Fatima Prayer" })
  }

  func testNoFinalCrossReducesCountByOne() {
    let engine = makeEngine()
    let with = engine.buildSteps(for: prayer(includeFinalCross: true)).count
    let without = engine.buildSteps(for: prayer(includeFinalCross: false)).count
    XCTAssertEqual(without, with - 1)
  }

  func testAramaicSignOfCrossUsesPerRosaryFormUntilAramaicBecomesTheAppDefault() {
    let defaults = UserDefaults.standard
    let savedDefault = defaults.string(forKey: "defaultLanguageCode")
    let savedForm = defaults.string(forKey: AramaicSignOfCrossForm.defaultsKey)
    defer {
      if let savedDefault { defaults.set(savedDefault, forKey: "defaultLanguageCode") }
      else { defaults.removeObject(forKey: "defaultLanguageCode") }
      if let savedForm { defaults.set(savedForm, forKey: AramaicSignOfCrossForm.defaultsKey) }
      else { defaults.removeObject(forKey: AramaicSignOfCrossForm.defaultsKey) }
    }

    defaults.set("en", forKey: "defaultLanguageCode")
    defaults.set(AramaicSignOfCrossForm.formB, forKey: AramaicSignOfCrossForm.defaultsKey)

    let formA = makeEngine().buildSteps(for: prayer(
      language: "arc", aramaicSignOfCrossForm: AramaicSignOfCrossForm.formA))
    XCTAssertEqual(formA.first?.body,
                   "בשמָא דַאבָא ודַברָא ודרוּחָא קַדִישָא, חַד אַלָהָא שַרִירָא. אַמִין.")
    XCTAssertEqual(formA.first?.transliteratedBody,
                   "ܒܫܡܳܐ ܕܰܐܒܳܐ ܘܕܰܒܪܳܐ ܘܕܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.")
    XCTAssertEqual(formA.last?.body, formA.first?.body)

    let formB = makeEngine().buildSteps(for: prayer(
      language: "arc", aramaicSignOfCrossForm: AramaicSignOfCrossForm.formB))
    XCTAssertEqual(formB.first?.body,
                   "בשֶם אַבָא ובַרָא ורוּחָא קַדִישָא، חַד אַלָהָא שַרִירָא. אַמִין.")
    XCTAssertEqual(formB.first?.transliteratedBody,
                   "ܒܫܶܡ ܐܰܒܳܐ ܘܒܰܪܳܐ ܘܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.")

    defaults.set("arc", forKey: "defaultLanguageCode")
    let systemWide = makeEngine().buildSteps(for: prayer(
      language: "arc", aramaicSignOfCrossForm: AramaicSignOfCrossForm.formA))
    XCTAssertEqual(systemWide.first?.body, formB.first?.body,
                   "the app-wide form wins once Aramaic is the default")
  }

  func testStMichaelPrayerAddsOneStep() {
    let engine = makeEngine()
    let without = engine.buildSteps(for: prayer(includeMichael: false)).count
    let with = engine.buildSteps(for: prayer(includeMichael: true)).count
    XCTAssertEqual(with, without + 1)
  }

  func testEternalRestAfterEachDecadeAddsOnePerDecade() {
    let engine = makeEngine()
    let without = engine.buildSteps(for: prayer(eternalRest: .none)).count
    let perDecade = engine.buildSteps(for: prayer(eternalRest: .afterEachDecade)).count
    XCTAssertEqual(perDecade, without + 5)
  }

  func testEternalRestAtEndAddsOneTotal() {
    let engine = makeEngine()
    let without = engine.buildSteps(for: prayer(eternalRest: .none)).count
    let atEnd = engine.buildSteps(for: prayer(eternalRest: .atEndOnly)).count
    XCTAssertEqual(atEnd, without + 1)
  }

  // MARK: - Closing intentions

  func testClosingIntentionsAddTenSteps() {
    let engine = makeEngine()
    let without = engine.buildSteps(for: prayer(closingIntentions: false)).count
    let with_ = engine.buildSteps(for: prayer(closingIntentions: true)).count
    // 3 intentions x (Our Father + Hail Mary + Glory Be) + the requiescant versicle = 10
    XCTAssertEqual(with_, without + 10)
  }

  func testClosingIntentionsFollowTheAntiphonDirectly() {
    let engine = makeEngine()
    var p = prayer(closingIntentions: true)
    p.languageCode = "la"
    let steps = engine.buildSteps(for: p)
    guard let antiphonIndex = steps.firstIndex(where: { $0.isAntiphon }) else {
      return XCTFail("no antiphon step")
    }
    let intentions = Array(steps[(antiphonIndex + 1)...(antiphonIndex + 10)])
    XCTAssertEqual(intentions.first?.title, "Pater Noster")
    XCTAssertEqual(
      intentions.first?.subtitle,
      "Pro intentionibus Summi Pontificis et necessitatibus Ecclesiae et patriae.")
    XCTAssertEqual(intentions.last?.body, "Requiescant in pace.\n**Amen.**")
  }

  func testClosingIntentionsPrayThePatriarchInHebrewAndTheExarchInTheGamlielRite() {
    let engine = makeEngine()
    var p = prayer(closingIntentions: true)
    p.languageCode = "he"
    let vicariate = engine.buildSteps(for: p)
    XCTAssertTrue(vicariate.contains { $0.subtitle?.contains("הפטריארך") == true })
    p.languageCode = "he-x-gamliel"
    let gamliel = engine.buildSteps(for: p)
    XCTAssertTrue(gamliel.contains { $0.subtitle?.contains("ההגמון") == true })
    XCTAssertFalse(gamliel.contains { $0.subtitle?.contains("הפטריארך") == true })
  }

  // MARK: - Mystery artwork

  func testEasternImageStyleSwapsOnlyMysteryImagery() {
    let engine = makeEngine()
    let classic = engine.buildSteps(for: prayer())
    XCTAssertFalse(classic.contains { $0.imageKey.hasPrefix("eastern_") })
    let eastern = engine.buildSteps(for: prayer(imageStyle: .eastern))
    XCTAssertEqual(classic.count, eastern.count)
    for (c, e) in zip(classic, eastern) {
      if let mystery = c.mystery {
        XCTAssertEqual(e.imageKey, "eastern_\(mystery.imageKey)")
      } else {
        XCTAssertEqual(e.imageKey, c.imageKey)
      }
    }
  }

  func testEasternImageStyleAppliesToPresenterCombinedStep() {
    let engine = makeEngine()
    let steps = engine.buildSteps(for: prayer(presenterMode: true, imageStyle: .eastern))
    let combined = steps.filter { $0.hailMaryIndexInDecade == 10 }
    XCTAssertEqual(combined.count, 5)
    XCTAssertTrue(combined.allSatisfy { $0.imageKey.hasPrefix("eastern_") })
  }

  @MainActor
  func testEveryEasternMysteryImageShipsInTheRosaryPack() {
    for mystery in MysteryCatalog.all {
      XCTAssertNotNil(
        PrayerPackStore.imageData(for: "eastern_\(mystery.imageKey)"),
        "missing eastern image for \(mystery.imageKey)")
    }
  }

  // MARK: - Twenty mysteries

  func testTwentyMysteryDecadeCount() {
    let engine = makeEngine()
    let p = prayer(mode: .twentyMystery)
    let steps = engine.buildSteps(for: p)
    let mysteries = steps.filter { $0.isScripture }
    XCTAssertEqual(mysteries.count, 20)
  }

  // MARK: - Step titles & content

  func testFirstStepIsSignOfCross() {
    let engine = makeEngine()
    var p = prayer(); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    XCTAssertEqual(steps.first?.title, "Sign of the Cross")
  }

  func testLastStepIsSignOfCrossWhenEnabled() {
    let engine = makeEngine()
    var p = prayer(includeFinalCross: true); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testStepsContainHailMarys() {
    let engine = makeEngine()
    var p = prayer(); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    let hailMarys = steps.filter { $0.title.hasPrefix("Hail Mary") }
    // 3 opening + 50 decade = 53
    XCTAssertEqual(hailMarys.count, 53)
  }

  func testAntiphonStepIsMarkedIsAntiphon() {
    let engine = makeEngine()
    let steps = engine.buildSteps(for: prayer())
    XCTAssertTrue(steps.contains { $0.isAntiphon })
  }

  func testNoAntiphonOptionProducesNoAntiphonStep() {
    let engine = makeEngine()
    let steps = engine.buildSteps(for: prayer(antiphon: .none))
    XCTAssertFalse(steps.contains { $0.isAntiphon })
  }

  // MARK: - Language passthrough

  func testEnglishBodyContainsEnglishText() {
    let engine = makeEngine()
    var p = prayer()
    p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    let creed = steps.first { $0.title == "Apostles' Creed" }
    XCTAssertNotNil(creed)
    XCTAssertTrue(creed?.body.contains("I believe in God") == true)
  }

  @MainActor
  func testBuiltInAramaicMysteryUsesPeshittaWithItsSyriacReadingAid() throws {
    let imageKey = "luminous_02_wedding_at_cana"
    let partial = try XCTUnwrap(
      PrayerPackStore.mysteryOverride(languageCode: "arc", imageKey: imageKey))
    XCTAssertNil(partial.title)
    XCTAssertNil(partial.fruit)

    let resolved = MysteryTranslations.get(languageCode: "arc", imageKey: imageKey)
    XCTAssertNotEqual(resolved.title, imageKey, "the title falls through independently")
    XCTAssertFalse(resolved.fruit.isEmpty, "the fruit falls through independently")
    XCTAssertTrue(resolved.description.contains("— יוחנן ב׳ 7–11 (פשיטתא)"),
                  "Hebrew citations keep gematria chapters, Arabic verses, and an en dash")
    XCTAssertFalse(resolved.description.contains("יוחנן ב׳:"),
                   "Hebrew-script citations use a space, never a colon")
    XCTAssertTrue(resolved.transliteratedDescription?.contains("— ܝܘܚܢܢ 2:") == true,
                  "the source-native Syriac citation stays with the Peshitta reading")

    let steps = makeEngine(group: .luminous).buildSteps(for: prayer(
      group: .luminous, mode: .singleMystery, order: 2, language: "arc"))
    let announcement = try XCTUnwrap(steps.first { $0.mystery?.imageKey == imageKey && $0.isScripture })
    let fruitLabel = PrayerTranslations.get(languageCode: "arc", key: .fructusMysteriiLabel)
    XCTAssertEqual(
      announcement.body,
      "\(resolved.description)\n\n\(fruitLabel): \(resolved.fruit)")
    XCTAssertEqual(
      announcement.transliteratedBody,
      "\(try XCTUnwrap(resolved.transliteratedDescription))\n\n\(fruitLabel): \(resolved.fruit)")
  }

  func testLatinBodyContainsLatinText() {
    let engine = makeEngine()
    var p = prayer()
    p.languageCode = "la"
    let steps = engine.buildSteps(for: p)
    let creed = steps.first { $0.title == "Symbolum Apostolorum" }
    XCTAssertTrue(creed?.body.contains("Credo in Deum") == true)
  }

  // MARK: - resolveMysteryGroups

  func testResolveSpecificReturnsOneGroup() {
    let engine = makeEngine()
    let p = prayer(group: .sorrowful, mode: .specific)
    XCTAssertEqual(engine.resolveMysteryGroups(for: p), [.sorrowful])
  }

  func testResolveFifteenReturnsTradtionalThree() {
    let engine = makeEngine()
    let p = prayer(mode: .fifteenMystery)
    XCTAssertEqual(engine.resolveMysteryGroups(for: p), [.joyful, .sorrowful, .glorious])
  }

  func testResolveTwentyReturnsFourGroups() {
    let engine = makeEngine()
    let p = prayer(mode: .twentyMystery)
    XCTAssertEqual(engine.resolveMysteryGroups(for: p), [.joyful, .luminous, .sorrowful, .glorious])
  }

  func testResolveTodaysMysteriesUsesCalendar() {
    let engine = PrayerEngine(calendar: FixedCalendar(group: .luminous))
    let p = prayer(mode: .todaysMysteries)
    XCTAssertEqual(engine.resolveMysteryGroups(for: p), [.luminous])
  }

  func testResolveSingleMysteryReturnsOneGroup() {
    let engine = makeEngine()
    let p = prayer(group: .sorrowful, mode: .singleMystery, order: 3)
    XCTAssertEqual(engine.resolveMysteryGroups(for: p), [.sorrowful])
  }

  // MARK: - Single Mystery

  func testSingleMysteryProducesExactlyOneDecade() {
    let engine = makeEngine()
    let p = prayer(group: .sorrowful, mode: .singleMystery, order: 3)
    let steps = engine.buildSteps(for: p)
    let decadeIndices = Set(steps.compactMap(\.decadeIndex))
    XCTAssertEqual(decadeIndices, [0])
  }

  func testSingleMysteryAnnouncesTheChosenMysteryNotTheFirst() {
    let engine = makeEngine()
    var p = prayer(group: .sorrowful, mode: .singleMystery, order: 3)
    // Mystery announcement titles are translated per-language (unlike fixed prayer titles like
    // "Our Father"), so this must be pinned explicitly rather than relying on the app-level
    // default language, which varies by machine/user.
    p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    let announcement = steps.first { $0.isScripture }
    // 3rd Sorrowful Mystery is the Crowning with Thorns, not the 1st (Agony in the Garden).
    XCTAssertEqual(announcement?.title, "The Crowning with Thorns")
    XCTAssertEqual(announcement?.subtitle, "3rd Mystery")
  }

  // MARK: - Presenter Mode

  func testPresenterModeOffReproducesExistingStepCount() {
    let engine = makeEngine()
    let steps = engine.buildSteps(for: prayer(presenterMode: false))
    XCTAssertEqual(steps.count, 79)
  }

  func testPresenterModeCollapsesHailMaryAndGloryBeIntoOneStepPerDecade() {
    let engine = makeEngine()
    var p = prayer(presenterMode: true); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)

    for d in 0..<5 {
      let hailMarySteps = steps.filter { $0.decadeIndex == d && $0.hailMaryIndexInDecade != nil }
      XCTAssertEqual(hailMarySteps.count, 1)
      XCTAssertEqual(hailMarySteps.first?.hailMaryIndexInDecade, 10)
      XCTAssertEqual(hailMarySteps.first?.title, "Hail Mary & Glory Be")
    }
  }

  func testPresenterModeCombinedStepBodyContainsBothPrayers() {
    let engine = makeEngine()
    var p = prayer(presenterMode: true)
    p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    let combined = steps.first { $0.title == "Hail Mary & Glory Be" }
    XCTAssertTrue(combined?.body.contains("Hail Mary,\nfull of grace") == true)
    XCTAssertTrue(combined?.body.contains("Glory be to the Father") == true)
  }

  func testPresenterModeStillIncludesFatimaPrayerPerDecade() {
    let engine = makeEngine()
    var p = prayer(includeFatima: true, presenterMode: true); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    XCTAssertEqual(steps.filter { $0.title == "Fatima Prayer" }.count, 5)
  }

  func testPresenterModeKeepsAnnouncementAndOurFatherAsSeparateSteps() {
    let engine = makeEngine()
    var p = prayer(presenterMode: true); p.languageCode = "en"
    let steps = engine.buildSteps(for: p)
    let decadeZeroSteps = steps.filter { $0.decadeIndex == 0 }
    // Announcement, Our Father, Hail Mary & Glory Be, Fatima Prayer = 4 (default config includes Fatima).
    XCTAssertEqual(decadeZeroSteps.count, 4)
    XCTAssertTrue(decadeZeroSteps[0].isScripture)
    XCTAssertEqual(decadeZeroSteps[1].title, "Our Father")
    XCTAssertEqual(decadeZeroSteps[2].title, "Hail Mary & Glory Be")
  }
}
