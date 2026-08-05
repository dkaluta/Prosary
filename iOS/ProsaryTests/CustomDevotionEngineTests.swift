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
  var isLentValue = false
  var seasonalAntiphonValue: MarianAntiphonOption = .salveRegina

  func mysteryGroup(for date: Date) -> MysteryGroup { .joyful }
  func seasonColor(for date: Date) -> Color { .clear }
  func seasonalMarianAntiphon(for date: Date) -> MarianAntiphonOption { seasonalAntiphonValue }
  func isEasterSeason(for date: Date) -> Bool { isEasterSeasonValue }
  func isLent(for date: Date) -> Bool { isLentValue }
}

@MainActor
final class CustomDevotionEngineTests: XCTestCase {
  private func steps(_ bundleId: String, language: String = "en", variantId: String? = nil,
                     customOptions: [String: String] = [:],
                     calendar: FixedLiturgicalCalendar = FixedLiturgicalCalendar()) -> [RosaryStep] {
    PrayerEngine(calendar: calendar).buildSteps(
      for: Prayer(kind: .custom, languageCode: language, customDevotionId: bundleId,
                  variantId: variantId, customOptions: customOptions))
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


  /// A repeated step's counter is part of the prayer, not the interface: praying in Hebrew, the Divine Mercy
  /// decade reads "(1 מתוך 10)". Splicing the English "of" into right-to-left text left bidi
  /// to reorder it into "(of 10 1)".
  /// The decade ordinal is part of the prayer too: "1st Sorrow" in English, "מכאוב 1" in
  /// Hebrew — English is the only one of the six that inflects the number.
  func testDecadeOrdinalUsesThePrayerLanguage() {
    XCTAssertTrue(steps("sevenSorrows", language: "en")[3].subtitle?.hasPrefix("1st Sorrow") == true)
    XCTAssertTrue(steps("sevenSorrows", language: "he")[3].subtitle?.hasPrefix("מכאוב 1") == true)
    XCTAssertTrue(steps("sevenSorrows", language: "ru")[3].subtitle?.hasPrefix("Скорбь 1") == true)
  }

  func testRepeatCounterUsesThePrayerLanguage() {
    let hebrew = steps("divineMercyChaplet", language: "he")
    XCTAssertTrue(hebrew[5].title.contains("(1 מתוך 10)"), hebrew[5].title)

    let latin = steps("divineMercyChaplet", language: "la")
    XCTAssertTrue(latin[5].title.contains("(1 ex 10)"), latin[5].title)

    let english = steps("divineMercyChaplet", language: "en")
    XCTAssertTrue(english[5].title.contains("(1 of 10)"), english[5].title)
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

  func testStationsProducesEighteenStepsWithTranslatedTitlesAndOrdinals() {
    let steps = steps("stationsOfTheCross")
    XCTAssertEqual(steps.count, 18)
    XCTAssertEqual(steps.first?.title, "Sign of the Cross")
    XCTAssertEqual(steps[1].title, "Opening Prayer")
    XCTAssertEqual(steps[2].title, "Jesus is Condemned to Death")
    XCTAssertEqual(steps[2].subtitle, "1st Station")
    XCTAssertEqual(steps[15].subtitle, "14th Station")
    XCTAssertEqual(steps[16].title, "Closing Prayer")
    // Anima Christi closes the Way of the Cross — a shared "main" prayer (hardcoded in all six
    // languages), so the bundle references it without shipping its own text.
    XCTAssertEqual(steps.last?.title, "Anima Christi")
    XCTAssertTrue(steps.last!.body.contains("Soul of Christ, sanctify me"))
    XCTAssertEqual(steps[2].acclamation?.contains("We adore You, O Christ"), true)
    XCTAssertFalse(steps[2].body.contains("We adore You"))
    XCTAssertEqual(steps[2].acclamation?.contains("**Because by Your holy Cross You have redeemed the world.**"), true)
    XCTAssertEqual(steps[2].imageKey, "station_01_condemned_to_death")
    // No bead fields anywhere — Stations is a flat devotion.
    XCTAssertTrue(steps.allSatisfy { $0.decadeIndex == nil && $0.hailMaryIndexInDecade == nil })
  }

  /// The Hebrew Stations (user-provided, Hebrew-Catholic usage) carry scriptural meditations
  /// instead of the Liguori texts — spot-check the translated title and the Isaiah 53:8 body.
  func testStationsHebrewUsesTheScripturalMeditations() {
    let steps = steps("stationsOfTheCross", language: "he")
    XCTAssertEqual(steps[2].title, "יֵשׁוּעַ נִדּוֹן לַמָּוֶת")
    XCTAssertTrue(steps[2].body.contains("מֵעֹ֤צֶר וּמִמִּשְׁפָּט֙ לֻקָּ֔ח"))
    XCTAssertEqual(steps[2].acclamation?.contains("**כִּי בִּצְלָבְךָ גָּאַלְתָּ אֶת הָעוֹלָם.**"), true)
    XCTAssertTrue(steps.last!.body.contains("נֶפֶשׁ הַמָּשִׁיחַ קַדְּשִׁינִי"))
  }

  // MARK: - Stations variants (traditional vs. scriptural)

  /// An unknown/nil variantId resolves to the default (first) variant — the traditional set.
  func testStationsDefaultVariantIsTheTraditionalSet() {
    XCTAssertEqual(steps("stationsOfTheCross", variantId: nil).map(\.title),
                   steps("stationsOfTheCross", variantId: "traditional").map(\.title))
    XCTAssertEqual(steps("stationsOfTheCross", variantId: "no-such-variant").count, 18)
  }

  /// The scriptural (St. John Paul II) variant — same 18-step frame (shared opening/closing/
  /// Anima Christi), fourteen different scenes with scriptural meditations.
  func testStationsScripturalVariantSequence() {
    let steps = steps("stationsOfTheCross", variantId: "scriptural")
    XCTAssertEqual(steps.count, 18)
    XCTAssertEqual(steps[0].title, "Sign of the Cross")
    XCTAssertEqual(steps[1].title, "Opening Prayer")
    XCTAssertEqual(steps[2].title, "Jesus Prays in the Garden of Gethsemane")
    XCTAssertEqual(steps[2].subtitle, "1st Station")
    XCTAssertEqual(steps[2].imageKey, "sorrowful_01_agony_in_the_garden")
    XCTAssertEqual(steps[2].acclamation?.contains("We adore You, O Christ"), true)
    XCTAssertFalse(steps[2].body.contains("We adore You"))
    XCTAssertTrue(steps[2].body.contains("Gethsemani"))
    XCTAssertTrue(steps[2].body.contains("— Mark 14:32-36 (Douay-Rheims)"))
    // The Sanhedrin scene skips verses 56-59 — the gap is marked, not papered over.
    XCTAssertTrue(steps[4].body.contains("[…]"))
    XCTAssertEqual(steps[3].imageKey, "scriptural_02_kiss_of_judas")
    XCTAssertEqual(steps[12].title, "Jesus Promises His Kingdom to the Good Thief")
    XCTAssertEqual(steps[12].imageKey, "scriptural_11_the_good_thief")
    XCTAssertEqual(steps[13].imageKey, "seven_sorrows_05_crucifixion")
    XCTAssertEqual(steps[16].title, "Closing Prayer")
    XCTAssertEqual(steps.last?.title, "Anima Christi")
    // The fourteen station bodies are quoted Gospel passages, so they render in the
    // scripture typeface; the shared opening/closing prayers do not.
    XCTAssertTrue(steps[2...15].allSatisfy(\.isScripture))
    XCTAssertFalse(steps[1].isScripture)
    XCTAssertFalse(steps[16].isScripture)
  }

  /// The traditional stations' meditations are quoted scripture in ar/he/ru/tl but Liguori
  /// prose in la/en — isScriptureByLanguage picks the typeface per session language.
  func testTraditionalStationsScriptureFlagFollowsTheLanguage() {
    XCTAssertTrue(steps("stationsOfTheCross", language: "he")[2].isScripture)
    XCTAssertTrue(steps("stationsOfTheCross", language: "ru")[2].isScripture)
    XCTAssertFalse(steps("stationsOfTheCross", language: "en")[2].isScripture)
    XCTAssertFalse(steps("stationsOfTheCross", language: "la")[2].isScripture)
  }

  func testStationsScripturalVariantHebrewTitles() {
    let steps = steps("stationsOfTheCross", language: "he", variantId: "scriptural")
    XCTAssertEqual(steps[2].title, "יֵשׁוּעַ מִתְפַּלֵּל בְּגַת שְׁמָנִים")
    XCTAssertTrue(steps[2].body.contains("(דליטש)"))
  }

  // MARK: - Via Lucis (flat, 14 scriptural stations)

  /// Cross + 14 stations + Regina Caeli + closing cross. Station bodies are the paschal
  /// acclamation ("...and Resurrection...") + the cited passage; the closing is the full
  /// composed Regina Caeli (antiphon, paschal versicle/response, collect).
  func testViaLucisSeventeenStepSequence() {
    let steps = steps("viaLucis")
    XCTAssertEqual(steps.count, 17)
    XCTAssertEqual(steps.first?.title, "Sign of the Cross")
    XCTAssertEqual(steps[1].title, "Jesus Rises from the Dead")
    XCTAssertEqual(steps[1].subtitle, "1st Station")
    XCTAssertEqual(steps[1].imageKey, "glorious_01_resurrection")
    XCTAssertEqual(steps[1].acclamation?.contains("Because by Your holy Cross and Resurrection"), true)
    XCTAssertTrue(steps[1].body.contains("— Matthew 28:1-7 (Douay-Rheims)"))
    XCTAssertTrue(steps[1...14].allSatisfy(\.isScripture))
    // The Emmaus-road station skips verses 17-24 — the gap is marked, not papered over.
    XCTAssertTrue(steps[4].body.contains("[…]"))
    XCTAssertEqual(steps[8].title, "Jesus Strengthens the Faith of Thomas")
    XCTAssertEqual(steps[8].imageKey, "via_lucis_08_incredulity_of_thomas")
    XCTAssertEqual(steps[14].title, "The Holy Spirit Descends at Pentecost")
    XCTAssertEqual(steps[14].imageKey, "glorious_03_descent_of_the_holy_spirit")
    XCTAssertEqual(steps[15].title, "Regina Caeli")
    XCTAssertTrue(steps[15].body.contains("Queen of Heaven, rejoice"))
    // The full antiphon and collect — this body was once clipped mid-sentence by a bad
    // authoring-time extraction, so the endings are pinned explicitly.
    XCTAssertTrue(steps[15].body.contains("Pray for us to God, alleluia."))
    XCTAssertTrue(steps[15].body.contains("**For the Lord has truly risen, alleluia.**"))
    XCTAssertTrue(steps[15].body.hasSuffix("through the same Christ our Lord. Amen."))
    XCTAssertEqual(steps.last?.title, "Sign of the Cross")
  }

  func testViaLucisLatinBodiesComeFromTheVulgate() {
    let steps = steps("viaLucis", language: "la")
    XCTAssertEqual(steps[1].title, "Iesus a mortuis resurgit")
    XCTAssertEqual(steps[1].acclamation?.contains("Quia per sanctam crucem et resurrectionem tuam"), true)
    XCTAssertTrue(steps[1].body.contains("— Matth. 28:1-7 (Vulgata)"))
    XCTAssertTrue(steps[15].body.contains("Regina caeli, laetare, alleluia."))
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

  /// The Crown's two optional closing devotions (the 72-completion Hail Marys, the Our Father
  /// for the Pope's intentions) default ON — the untouched 90-step sequence above is the proof
  /// that adding options.json changed nothing. Turning them off drops exactly those steps.
  func testFranciscanCrownOptionsDropTheirClosingSteps() {
    let noSeventyTwo = steps("franciscanCrown", customOptions: ["seventyTwoHailMarys": "false"])
    XCTAssertEqual(noSeventyTwo.count, 88)
    XCTAssertFalse(noSeventyTwo.contains { $0.subtitle == "For the years of Our Lady's life" })

    let neither = steps("franciscanCrown", customOptions: [
      "seventyTwoHailMarys": "false", "popeIntentions": "false",
    ])
    XCTAssertEqual(neither.count, 87)
    XCTAssertFalse(neither.contains { $0.subtitle == "For the intentions of the Holy Father" })

    // An override for a key the bundle doesn't declare is ignored, not an error.
    XCTAssertEqual(steps("franciscanCrown", customOptions: ["noSuchOption": "false"]).count, 90)
  }

  func testConditionExpressionEvaluation() {
    let values = ["fatima": "true", "creed": "false", "antiphon": "reginaCaeli"]
    XCTAssertTrue(PrayerEngine.evaluateCondition("fatima", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("creed", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("!fatima", values: values))
    XCTAssertTrue(PrayerEngine.evaluateCondition("!creed", values: values))
    XCTAssertTrue(PrayerEngine.evaluateCondition("antiphon=reginaCaeli", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("antiphon=salveRegina", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("missing", values: values))
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

  /// The sorrow texts live only in the bundle (they were deleted from the hardcoded tables) —
  /// a language the bundle doesn't declare must fall back to the bundle's Latin mysteries, not
  /// leak raw imageKeys as titles.
  func testSevenSorrowsFallsBackToBundleLatinForAnUndeclaredLanguage() {
    let steps = steps("sevenSorrows", language: "xx")
    XCTAssertEqual(steps[1].title, "Simeonis Prophetia")
  }

  // MARK: - Divine Mercy Chaplet (rosary type, no announcements, fixed image)

  func testDivineMercySixtyThreeStepSequence() {
    let steps = steps("divineMercyChaplet")
    XCTAssertEqual(steps.count, 63)
    XCTAssertEqual(steps.map(\.title).prefix(4), [
      "Sign of the Cross", "Our Father", "Hail Mary", "Apostles' Creed",
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

  // MARK: - O Antiphons (days)

  /// The one shipped days-type bundle: seven evenings of Advent Vespers, each a reading, the
  /// antiphon, the Magnificat, the Glory Be, and the antiphon again.
  func testOAntiphonsDayIsSelectedByTheDayIndex() {
    func day(_ index: Int, language: String = "en") -> [RosaryStep] {
      PrayerEngine().buildSteps(
        for: Prayer(kind: .custom, languageCode: language, customDevotionId: "oAntiphons",
                    dayIndex: index))
    }

    XCTAssertEqual(day(0).map(\.title),
                   ["A Reading", "O Wisdom", "The Magnificat", "Glory Be", "O Wisdom"])
    XCTAssertEqual(day(2).map(\.title),
                   ["A Reading", "O Root of Jesse", "The Magnificat", "Glory Be", "O Root of Jesse"])
    XCTAssertEqual(day(6)[1].title, "O Emmanuel")
    XCTAssertEqual(day(2, language: "la")[1].title, "O Radix Iesse")
    XCTAssertTrue(day(6)[1].body.contains("come to save us, O Lord our God"))
    // The reading and the canticle are Scripture; the antiphon is not.
    XCTAssertTrue(day(0)[0].isScripture)
    XCTAssertTrue(day(0)[2].isScripture)
    XCTAssertFalse(day(0)[1].isScripture)
    // Past the last day the engine clamps rather than emitting nothing.
    XCTAssertEqual(day(99)[1].title, "O Emmanuel")
  }

  /// The declarations the Pray row and the resumption logic read.
  func testOAntiphonsDeclaresItselfASeriesOfSevenDays() {
    let definition = PrayerPackStore.definition(for: "oAntiphons")
    XCTAssertEqual(definition?.days?.count, 7)
    XCTAssertEqual(definition?.dayProgression, .series)
    XCTAssertEqual(definition?.suggestedStart, "12-17")
    XCTAssertEqual(definition?.suggestedReminderTime, "18:00")
    XCTAssertEqual(definition?.suggestedNext, "angelus")
    XCTAssertEqual(definition?.days?.first?.period, "17 December")
    XCTAssertEqual(definition?.days?.first?.name, "O Sapientia")
  }

  // MARK: - The invitatory, and the Mission's Hebrew

  /// The Rosary may open with "O God, come to my assistance" — off by default, and the Alleluia
  /// leaves it during Lent, which is what the "invitatory & !isLent" gate is for.
  func testInvitatoryIsOptionalAndDropsItsAlleluiaInLent() {
    XCTAssertFalse(steps("rosary")[1].body.contains("come to my assistance"))

    let on = steps("rosary", customOptions: ["invitatory": "true"])
    XCTAssertEqual(on[1].title, "O God, Come to My Assistance")
    XCTAssertTrue(on[1].body.contains("O Lord, make haste to help me"))
    XCTAssertTrue(on[1].body.contains("Glory be to the Father"))
    XCTAssertTrue(on[1].body.hasSuffix("Alleluia."))

    var lenten = FixedLiturgicalCalendar()
    lenten.isLentValue = true
    let inLent = steps("rosary", customOptions: ["invitatory": "true"], calendar: lenten)
    XCTAssertEqual(inLent[1].title, "O God, Come to My Assistance")
    XCTAssertTrue(inLent[1].body.contains("Glory be to the Father"))
    XCTAssertFalse(inLent[1].body.contains("Alleluia"))
  }

  func testConjoinedConditionsRequireEveryTerm() {
    let values = ["invitatory": "true", "isLent": "false", "antiphon": "reginaCaeli"]
    XCTAssertTrue(PrayerEngine.evaluateCondition("invitatory & !isLent", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("invitatory & isLent", values: values))
    XCTAssertTrue(PrayerEngine.evaluateCondition("invitatory & antiphon=reginaCaeli", values: values))
    XCTAssertFalse(PrayerEngine.evaluateCondition("invitatory & antiphon=salveRegina", values: values))
    // A single term still parses exactly as before.
    XCTAssertTrue(PrayerEngine.evaluateCondition("invitatory", values: values))
  }

  /// The Mission of St. Gamaliel's wording overlays plain Hebrew key by key — their Creed is the
  /// Nicene one, and anything they have not sent still reads in the app's Hebrew.
  func testGamalielVariantOverlaysHebrew() {
    let variant = steps("rosary", language: "he-x-gamliel", customOptions: ["apostlesCreed": "true"])
    XCTAssertTrue(variant[1].body.contains("אָנוּ מַאֲמִינִים"), "the Creed is the Nicene one")
    XCTAssertEqual(variant[1].title, "מאמינים של ניקאה")
    XCTAssertTrue(variant.contains { $0.body.contains("שָׁלוֹם לָךְ מִרְיָם") }, "their Hail Mary")

    // Not sent by the Mission: the Fatima prayer still reads in the app's Hebrew.
    let hebrew = steps("rosary", language: "he", customOptions: ["apostlesCreed": "true"])
    let fatima = { (list: [RosaryStep]) in list.first { $0.title.contains("הו ישוע") }?.body }
    XCTAssertEqual(fatima(variant), fatima(hebrew))
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
