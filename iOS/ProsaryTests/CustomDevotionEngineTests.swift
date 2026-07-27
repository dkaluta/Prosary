//
//  CustomDevotionEngineTests.swift
//  ProsaryTests
//
//  PrayerEngine.buildCustomDevotionSteps is the one generic builder behind every
//  PrayerKind.custom devotion. These tests exercise it via the real shipped bundles (produced by
//  Shared/tools/make-prosaryprayer.sh from Shared/content/) and carry over the per-devotion
//  assertions from the five deleted hardcoded-engine test files — the step sequences must be
//  byte-for-byte what the hardcoded builders used to emit.
//

import XCTest
import SwiftUI
@testable import Prosary

private struct FixedLiturgicalCalendar: LiturgicalCalendarProviding {
  var isEasterSeasonValue = false
  var seasonalAntiphonValue: MarianAntiphonOption = .salveRegina

  func mysteryGroup(for date: Date) -> MysteryGroup { .joyful }
  func seasonColor(for date: Date) -> Color { .clear }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { seasonalAntiphonValue }
  func isEasterSeason(for date: Date) -> Bool { isEasterSeasonValue }
}

@MainActor
final class CustomDevotionEngineTests: XCTestCase {
  private func steps(_ bundleId: String, language: String = "en",
                     calendar: FixedLiturgicalCalendar = FixedLiturgicalCalendar()) -> [RosaryStep] {
    PrayerEngine(calendar: calendar).buildSteps(
      for: Prayer(kind: .custom, languageCode: language, customDevotionId: bundleId))
  }

  // MARK: - Trisagion (flat)

  func testTrisagionProducesTheSixStepSequence() {
    let steps = steps("trisagion")
    XCTAssertEqual(steps.map(\.title), [
      "Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God",
    ])
    XCTAssertTrue(steps[0].body.contains("Holy God, Holy Mighty One, Holy Immortal One"))
    XCTAssertTrue(steps[3].body.contains("Glory be to the Father"))
    XCTAssertFalse(steps[4].body.contains("Holy Mighty One"))
  }

  // MARK: - Angelus (flat + Eastertide swap)

  func testAngelusStandardFormOutsideEastertide() {
    let steps = steps("angelus")
    XCTAssertEqual(steps.count, 7)
    XCTAssertEqual(steps.map(\.title), [
      "The Annunciation", "Hail Mary",
      "The Fiat", "Hail Mary",
      "The Incarnation", "Hail Mary",
      "Let Us Pray",
    ])
    XCTAssertTrue(steps[0].body.contains("The Angel of the Lord declared unto Mary"))
    XCTAssertTrue(steps[0].body.contains("**And she conceived of the Holy Spirit.**"))
    XCTAssertTrue(steps[1].body.contains("Hail Mary, full of grace"))
    XCTAssertTrue(steps.last!.body.contains("Pour forth, we beseech Thee"))
    XCTAssertFalse(steps.contains { $0.body.contains("Queen of Heaven") })
    XCTAssertTrue(steps.allSatisfy { $0.imageKey == "joyful_01_annunciation" })
  }

  func testAngelusReginaCaeliSubstitutionDuringEastertide() {
    let steps = steps("angelus", calendar: FixedLiturgicalCalendar(isEasterSeasonValue: true))
    XCTAssertEqual(steps.count, 1)
    XCTAssertEqual(steps[0].title, "Regina Caeli")
    XCTAssertTrue(steps[0].body.contains("Queen of Heaven, rejoice"))
    XCTAssertTrue(steps[0].body.contains("Rejoice and be glad, O Virgin Mary"))
    XCTAssertFalse(steps[0].body.contains("Pour forth, we beseech Thee"))
    XCTAssertEqual(steps[0].imageKey, "madonna_and_child")
  }

  func testAngelusFallsBackToLatinWhenLanguageIsSentinel() {
    let steps = steps("angelus", language: LanguageCatalog.defaultSentinel)
    XCTAssertTrue(steps[0].body.contains("Angelus Domini nuntiavit Mariae"))
  }

  // MARK: - Stations of the Cross (flat, translated titles)

  func testStationsProducesSeventeenStepsWithTranslatedTitlesAndOrdinals() {
    let steps = steps("stationsOfTheCross")
    XCTAssertEqual(steps.count, 17)
    XCTAssertEqual(steps.first?.title, "Sign of the Cross")
    XCTAssertEqual(steps[1].title, "Opening Prayer")
    XCTAssertEqual(steps[2].title, "Jesus is Condemned to Death")
    XCTAssertEqual(steps[2].subtitle, "1st Station")
    XCTAssertEqual(steps[15].subtitle, "14th Station")
    XCTAssertEqual(steps.last?.title, "Closing Prayer")
    XCTAssertTrue(steps[2].body.contains("We adore You, O Christ"))
    XCTAssertTrue(steps[2].body.contains("**Because by Your holy Cross You have redeemed the world.**"))
    XCTAssertEqual(steps[2].imageKey, "station_01_condemned_to_death")
    // No bead fields anywhere — Stations is a flat devotion.
    XCTAssertTrue(steps.allSatisfy { $0.decadeIndex == nil && $0.hailMaryIndexInDecade == nil })
  }

  // MARK: - Franciscan Crown (rosary type, 7×10 + antiphon)

  func testFranciscanCrownNinetyStepSequence() {
    let steps = steps("franciscanCrown")
    XCTAssertEqual(steps.count, 90)
    XCTAssertEqual(steps.first?.title, "Sign of the Cross")
    // 7 decades of announce + Our Father + 10 Hail Marys.
    XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), Set(0...6))
    XCTAssertEqual(steps.compactMap(\.hailMaryIndexInDecade).max(), 10)
    // Joy 1 announcement reuses the shared Rosary mystery text/image cross-bundle.
    XCTAssertEqual(steps[1].title, "The Annunciation")
    XCTAssertEqual(steps[1].subtitle, "1st Joy")
    XCTAssertTrue(steps[1].isScripture)
    XCTAssertEqual(steps[1].imageKey, "joyful_01_annunciation")
    // Joy 4 is the Crown's own Adoration of the Magi.
    let joy4 = steps.first { $0.subtitle == "4th Joy" }
    XCTAssertEqual(joy4?.title, "The Adoration of the Magi")
    XCTAssertEqual(joy4?.imageKey, "franciscan_04_adoration_of_the_magi")
    // The Our Father inside a decade uses the decade's own art (unlike the Rosary).
    XCTAssertEqual(steps[2].title, "Our Father")
    XCTAssertEqual(steps[2].imageKey, "joyful_01_annunciation")
    // Closing (opening 1 + 7×12 decades = indices 0…84): 2 Hail Marys + Our Father +
    // seasonal antiphon + cross.
    XCTAssertEqual(steps[85].title, "Hail Mary (1 of 2)")
    XCTAssertEqual(steps[85].subtitle, "For the years of Our Lady's life")
    XCTAssertNil(steps[85].decadeIndex)
    XCTAssertNil(steps[85].hailMaryIndexInDecade)
    XCTAssertEqual(steps[87].title, "Our Father")
    XCTAssertEqual(steps[87].subtitle, "For the intentions of the Holy Father")
    XCTAssertTrue(steps[88].isAntiphon)
    XCTAssertEqual(steps[88].imageKey, "madonna_and_child")
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testFranciscanCrownAntiphonFollowsTheSeason() {
    let paschal = steps(
      "franciscanCrown",
      calendar: FixedLiturgicalCalendar(seasonalAntiphonValue: .reginaCaeli))
    XCTAssertEqual(paschal[88].title, "Regina Caeli")
    XCTAssertTrue(paschal[88].isAntiphon)
  }

  // MARK: - Seven Sorrows (rosary type, 7×7)

  func testSevenSorrowsSixtyNineStepSequence() {
    let steps = steps("sevenSorrows")
    XCTAssertEqual(steps.count, 69)
    XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), Set(0...6))
    XCTAssertEqual(steps.compactMap(\.hailMaryIndexInDecade).max(), 7)
    XCTAssertEqual(steps[1].title, "The Prophecy of Simeon")
    XCTAssertEqual(steps[1].subtitle, "1st Sorrow")
    // The Meeting on the Way (4th sorrow) is the one traditional non-Gospel scene.
    let announcements = steps.filter { $0.decadeIndex != nil && $0.hailMaryIndexInDecade == nil && $0.title != "Our Father" }
    XCTAssertEqual(announcements.count, 7)
    XCTAssertFalse(announcements[3].isScripture)
    XCTAssertTrue(announcements.enumerated().allSatisfy { $0.offset == 3 || $0.element.isScripture })
    // Closing: 3 Hail Marys for the tears, the composed Our Lady of Sorrows body, cross.
    XCTAssertEqual(steps[64].title, "Hail Mary (1 of 3)")
    XCTAssertEqual(steps[64].subtitle, "For the tears of Our Lady")
    XCTAssertEqual(steps[67].title, "Our Lady of Sorrows")
    XCTAssertTrue(steps[67].body.contains("**That we may be made worthy of the promises of Christ.**"))
    XCTAssertFalse(steps.contains { $0.isAntiphon })
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  // MARK: - Divine Mercy Chaplet (rosary type, no announcements, fixed image)

  func testDivineMercySixtyThreeStepSequence() {
    let steps = steps("divineMercyChaplet")
    XCTAssertEqual(steps.count, 63)
    XCTAssertEqual(steps.map(\.title).prefix(4), [
      "Sign of the Cross", "Our Father", "Hail Mary", "The Apostles' Creed",
    ])
    XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), Set(0...4))
    XCTAssertEqual(steps[4].title, "Eternal Father, I Offer You...")
    XCTAssertEqual(steps[4].subtitle, "1st Decade")
    XCTAssertEqual(steps[5].title, "For the Sake of His Sorrowful Passion (1 of 10)")
    XCTAssertEqual(steps[59].title, "Holy God, Holy Mighty One, Holy Immortal One (1 of 3)")
    XCTAssertNil(steps[59].decadeIndex)
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
    // Every step reuses the single Divine Mercy image.
    XCTAssertTrue(steps.allSatisfy { $0.imageKey == "divine_mercy_image" })
  }

  // MARK: - Structural guards

  func testMissingCustomDevotionIdProducesNoSteps() {
    let steps = PrayerEngine().buildSteps(for: Prayer(kind: .custom, languageCode: "en"))
    XCTAssertTrue(steps.isEmpty)
  }

  /// The bead track assumes the closing cross is the literal last step and decade indices are
  /// dense — guard every shipped rosary-type bundle at once.
  func testEveryRosaryTypeBundleSatisfiesTheBeadTrackInvariants() {
    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let definition = PrayerPackStore.definition(for: bundleId),
            definition.type == .rosary else { continue }
      let steps = steps(bundleId)
      XCTAssertEqual(steps.first?.title, "Sign of the Cross", "\(bundleId): opening cross must be step 0")
      if definition.hasClosingCross == true {
        XCTAssertEqual(steps.last?.title, "Sign of the Cross", "\(bundleId): closing cross must be last")
      }
      let indices = steps.compactMap(\.decadeIndex)
      XCTAssertEqual(Set(indices), Set(0..<(indices.max().map { $0 + 1 } ?? 0)), "\(bundleId): decadeIndex must be dense")
      XCTAssertLessThanOrEqual(steps.filter(\.isAntiphon).count, 1, "\(bundleId): at most one antiphon")
      // Minors carry indices; announcements/majors never do.
      for step in steps where step.hailMaryIndexInDecade != nil {
        XCTAssertNotNil(step.decadeIndex, "\(bundleId): minor steps must sit inside a decade")
      }
    }
  }
}
