
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
    includeFatima: Bool = true,
    eternalRest: EternalRestPlacement = .none,
    antiphon: MarianAntiphonOption = .salveRegina,
    includeMichael: Bool = false,
    includeFinalCross: Bool = true,
    presenterMode: Bool = false
  ) -> Prayer {
    Prayer(rosary: RosaryOptions(
      mysterySelectionMode: mode,
      specificMysteryGroup: group,
      specificMysteryOrder: order,
      includeApostlesCreed: includeCreed,
      includeOpeningPrayers: includeOpening,
      includeFatimaPrayer: includeFatima,
      eternalRestForDeceased: eternalRest,
      marianAntiphon: antiphon,
      includeStMichaelPrayer: includeMichael,
      includeFinalSignOfCross: includeFinalCross,
      presenterMode: presenterMode
    ))
  }

  // MARK: - Step count

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

  func testNoFinalCrossReducesCountByOne() {
    let engine = makeEngine()
    let with = engine.buildSteps(for: prayer(includeFinalCross: true)).count
    let without = engine.buildSteps(for: prayer(includeFinalCross: false)).count
    XCTAssertEqual(without, with - 1)
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
    XCTAssertTrue(combined?.body.contains("Hail Mary, full of grace") == true)
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
