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

  /// The shipped Trisagion was always the Byzantine form; it just never said so. Erez prays the
  /// Syriac one — the acclamation thrice, then Lord-have-mercy thrice — so the bundle now names
  /// both, Byzantine first so the default sequence stays byte-identical (the six-step test above
  /// is the guard). His rite's Kyrie is his own יְהֹוָה רַחֵם־נָא; plain Hebrew has no Vicariate wording
  /// for it yet and deliberately falls back to the bundle's Latin rather than to an invention.
  func testTrisagionSyriacVariant() {
    let syriac = steps("trisagion", variantId: "syriac")
    XCTAssertEqual(syriac.count, 4)
    XCTAssertEqual(syriac.map(\.title),
                   Array(repeating: "Holy God", count: 3) + ["Lord, Have Mercy"])
    XCTAssertTrue(syriac[0].body.contains("Holy God, Holy Mighty One"))
    // The Kyrie is ONE composed step — the threefold form is a single text, so repeating it
    // would pray nine invocations.
    XCTAssertEqual(syriac[3].body, "Lord, have mercy.\nChrist, have mercy.\nLord, have mercy.")
    XCTAssertFalse(syriac.contains { $0.body.contains("Glory be") }, "the Syriac form has no Gloria")

    // The Vicariate's Hebrew is the full threefold form in one line, exactly as sent; Erez's
    // rite overlays the same slot with his own line said thrice.
    let hebrewKyrie = steps("trisagion", language: "he", variantId: "syriac")[3]
    XCTAssertEqual(hebrewKyrie.body, "יֵשׁוּעַ שְׁמָעֵנוּ, הַמָּשִׁיחַ עָזְרֵנוּ, הָאָדוֹן חָנֵּנוּ.")
    XCTAssertEqual(hebrewKyrie.title, "ישוע שמענו", "the heading is the unpointed line's own incipit")
    XCTAssertEqual(steps("trisagion", language: "he-x-gamliel", variantId: "syriac")[3].body,
                   "יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא")
  }

  /// A variant can claim a prayer language as its own (`defaultForLanguages`), and a favorite
  /// with no explicit choice opens in it: the Mission prays the Syriac form, so Erez's rite gets
  /// it without touching the variant menu. Exact-code match only — plain Hebrew (the Vicariate,
  /// Latin rite) keeps the first-declared default, which per the canonical tradition order
  /// (latin → byzantine → west syriac → armenian → alexandrian → east syriac) is the earliest
  /// tradition the bundle ships: today the Byzantine. An explicit choice always wins.
  func testTrisagionDefaultFormFollowsThePrayerLanguage() {
    let gamliel = steps("trisagion", language: "he-x-gamliel")
    XCTAssertEqual(gamliel.count, 4, "no explicit variant: the rite's own Syriac form")
    XCTAssertEqual(gamliel[3].body, "יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא")
    XCTAssertEqual(steps("trisagion", language: "he").count, 6,
                   "the Vicariate's Hebrew keeps the Byzantine default")
    XCTAssertEqual(steps("trisagion", language: "he-x-gamliel", variantId: "byzantine").count, 6,
                   "an explicit choice beats the rite's default")

    // Classical Syriac claims the same form (2026-08-08): the Qadishat thrice, then the
    // Kurielaison the Syriac liturgy keeps in Greek — Aramaic in Hebrew square script, with
    // the same Aramaic in Syriac letters riding in the script-toggle transliteration.
    let aramaic = steps("trisagion", language: "arc")
    XCTAssertEqual(aramaic.count, 4)
    XCTAssertEqual(aramaic[0].title, "קדישת אלהא")
    XCTAssertEqual(aramaic[0].body,
                   "קַדּישַת אַלָהָא\nקַדִישַת חַילתָּנָא\nקַדִישַת לָא מִיותָּא אֶתַרחַמעלִין")
    XCTAssertEqual(aramaic[0].transliteratedBody,
                   "ܩܰܕ݁ܝܫܰܬ݂ ܐܰܠܳܗܳܐ\nܩܰܕܺܝܫܰܬ݂ ܚܰܝܠܬ݁ܳܢܳܐ\nܩܰܕܺܝܫܰܬ݂ ܠܳܐ ܡܺܝܘܬ݁ܳܐ ܐܶܬܰܪܚܰܡܥܠܺܝܢ")
    XCTAssertEqual(aramaic[3].body, "קוריאליסונ\nקוריאליסונ\nקוריאליסונ")
    // Erez supplied the Mission's doxology in both scripts on 2026-08-26. Pin every mark and
    // vowel so the Hebrew-square-script Aramaic and its pointed Syriac rendering cannot drift.
    let glory = steps("trisagion", language: "arc", variantId: "byzantine")[3]
    XCTAssertEqual(glory.title, "שובחא לאבא")
    XCTAssertEqual(glory.body,
                   "שוּבחָא לַאבָא ולַברָא וַלרוּחָא קַדישָא\nמֶן עָלַם וַעדַמָא לעָלַם עָלמִין. אַמִין.")
    XCTAssertEqual(glory.transliteratedBody,
                   "ܫܽܘܒܚܳܐ ܠܰܐܒܳܐ ܘܠܰܒܪܳܐ ܘܰܠܪܽܘܚܳܐ ܩܰܕܝܫܳܐ\nܡܶܢ ܥܳܠܰܡ ܘܰܥܕܰܡܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ. ܐܰܡܺܝܢ.")
  }

  /// The basic-prayers list resolves through the same chains the flows use, so it follows the
  /// prayer language rites included — the whole point of surfacing it: in Erez's rite the Holy
  /// God is קדישת over his own acclamation, and the Hail Mary reads his community's text.
  func testBasicPrayerCatalogResolvesInThePrayerLanguage() {
    let saved = UserDefaults.standard.string(forKey: "defaultLanguageCode")
    defer {
      if let saved { UserDefaults.standard.set(saved, forKey: "defaultLanguageCode") }
      else { UserDefaults.standard.removeObject(forKey: "defaultLanguageCode") }
    }

    XCTAssertEqual(BasicPrayerCatalog.all.map(\.id),
                   ["signOfCross", "ourFather", "hailMary", "gloryBe", "creed", "holyGod"])

    UserDefaults.standard.set("en", forKey: "defaultLanguageCode")
    let selected = BasicPrayerCatalog.step(
      for: BasicPrayerCatalog.prayer(id: "ourFather")!, languageCode: "arc")
    XCTAssertEqual(selected.title, "צלותא מרניתא")
    XCTAssertNotNil(selected.transliteratedBody)
    XCTAssertEqual(UserDefaults.standard.string(forKey: "defaultLanguageCode"), "en")
    XCTAssertEqual(BasicPrayerCatalog.step(
      for: BasicPrayerCatalog.prayer(id: "holyGod")!, languageCode: "").title, "Holy God")
    let english = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "holyGod")!)
    XCTAssertEqual(english.title, "Holy God")
    XCTAssertTrue(english.body.contains("Holy Immortal One"))
    XCTAssertTrue(
      BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "creed")!)
        .body.contains("I believe in God"),
      "the shared tables' Apostles' Creed")

    UserDefaults.standard.set("he-x-gamliel", forKey: "defaultLanguageCode")
    let rite = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "holyGod")!)
    XCTAssertEqual(rite.title, "קדישת")
    XCTAssertTrue(rite.body.hasPrefix("אַתָּה ✠▼▲ קָדוֹשׁ"))

    // "The Creed" is the community's own: the Mission's overlay replaces the Apostles' with
    // the Nicene, so the basic prayer follows — the whole reason it names keys, not text.
    let creed = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "creed")!)
    XCTAssertTrue(creed.body.hasPrefix("אָנוּ מַאֲמִינִים"), "the Nicene confesses in the plural")

    let hailMary = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "hailMary")!)
    XCTAssertTrue(hailMary.body.contains("שָׁלוֹם לָךְ מִרְיָם"), "his community's Hail Mary")

    // The Sign of the Cross carries its mark in every language the same way the flows show it.
    UserDefaults.standard.set("la", forKey: "defaultLanguageCode")
    let cross = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "signOfCross")!)
    XCTAssertTrue(cross.body.contains("✠"))

    // Erez's Aramaic Nicene Creed, Our Father and Hail Mary (2026-08-31), in Hebrew square and
    // pointed Syriac scripts.
    UserDefaults.standard.set("arc", forKey: "defaultLanguageCode")
    let aramaicCreed = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "creed")!)
    XCTAssertEqual(aramaicCreed.title, "מהימנינן")
    XCTAssertEqual(aramaicCreed.body,
      "מהַימנִינַן בחד אַלָהָא, אַבָּא אַחִיד כֻּל, עָבוּדָא דַּשמַיָא ודַארעָא וַדכֻלהֶין אַיללין דמֶתחַזין וַדלָא מֶתחַזיָן, וַבחַד מָריָא יֶשוּע משיחָא יַחחָדָיֶא ברא דַּאַלָהָא, הַו דּמֶן אַבָּא אֶתִילֶד קדדם כלהון עָלמֶא, אַלָהָא מֶן אַלָהָא, נוּהרָא מֶן נוּהרָא, אַלָהָא שַרִירא מֶן אַלָהָא שַרִירָא, יַלִידא ולָא עבִידא, וַשוֶא בֻּאוסִיא לַאבּוּהי, הַו דבּאִידֶה הוֹא כַּל מֶדֶם, הַו דּמֶטֻלָתַן בּנַינשָא, ומֶטֻל פּוּרקָנַן נחֶת מֶן שמַיָא ואֶתגַשַם מֶן רוּחָא קַדִישָא, מֶן מַריַם בּתוּלתָא וַהוֹא בַּרננשֶא, ואֶצטלֶב חלָפִין ביומי פַּנטִיָוס פִילַטָוס, חַש ומִית וְאתקבַר, קם לַתלָתָא יַוַמִין אַיך דַכתִיב, וַסלֶק לַשמַיָא וִיתֶב מֶן יָמִין אַבּוּהי, ותוב אִתֶּא בשוּבחֶה רַבָא לַמן ליַיֶא וַלמִיָתֶא, הַו דַּלמַלכּוּתֶּה שוּלָמָא לָאאית, וַבחַד רוּחָא קַדִישָא דאַיָתַוהי מָריָא מַחינָא דכֻל, הַו דּמֶן אַבָא ובא ננפֶק, ועַם אַבָא ועַם ברא מֶסתגֶד ומֶשתַבַח, הַו דּמַלֶל בַנכָיֶא, ובַחדָא עִדתָא קַדִישתָא קָתוּלִיקִי וַשלִיחָיתָא, ומַודֶינַן דַחדָא הי מַעמַודָיתָא לשוּבקָנָא דּחַטָהֶא, וַמסַכֶינַן לַקיָמתָא דמִיתֶא וַלִיֶא חַדתֶא דבעָלמָא דַעתִיד. אַמִין.")
    XCTAssertEqual(aramaicCreed.transliteratedBody,
      "ܡܗܰܝܡܢܺܝܢܰܢ ܒܚܕ ܐܰܠܳܗܳܐ. ܐܰܒ݁ܳܐ ܐܰܚܺܝܕ݂ ܟ݁ܽܠ. ܥܳܒܽܘܕܳܐ ܕ݁ܰܫܡܰܝܳܐ ܘܕ݂ܰܐܪܥܳܐ ܘܰܕ݂ܟܽܠܗܶܝܢ ܐܰܝܠܠ̈ܝܢ ܕܡܶܬ݂ܚܰܙܝܢ ܘܰܕ݂ܠܳܐ ܡܶܬ݂ܚܰܙܝܳܢ. ܘܰܒ݂ܚܰܕ݂ ܡܳܪܝܳܐ ܝܶܫܽܘܥ ܡܫܝܚܳܐ ܝܰܚܚܳܕ݂ܳܝܶܐ ܒܪܐ ܕ݁ܰܐܰܠܳܗܳܐ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒ݁ܳܐ ܐܶܬܺܝܠܶܕ݂ ܩ݀ܕܕܡ ܟܠܗ݇ܘܢ ܥܳܠܡ̈ܶܐ. ܐܰܠܳܗܳܐ ܡܶܢ ܐܰܠܳܗܳܐ. ܢܽܘܗܪܳܐ ܡܶܢ ܢܽܘܗܪܳܐ. ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܐ ܡܶܢ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܝܰܠܺܝܕܐ ܘܠܳܐ ܥܒܿܺܝܕܐ. ܘܰܫܘܶܐ ܒ݁ܽܐܘܣܺܝܐ ܠܰܐܒ݁ܽܘܗ̄ܝ. ܗܰܘ ܕܒ݁ܐܺܝܕ݂ܶܗ ܗ݈ܘܳܐ ܟ݁ܰܠ ܡܶܕܶܡ. ܗܰܘ ܕ݁ܡܶܛܽܠܳܬ݂ܰܢ ܒ݁ܢܰܝ̈ܢܫܳܐ. ܘܡܶܛܽܠ ܦ݁ܽܘܪܩܳܢܰܢ ܢܚܶܬ݂ ܡܶܢ ܫܡܰܝܳܐ ܘܐܶܬ݂ܓܰܫܰܡ ܡܶܢ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ. ܡܶܢ ܡܰܪܝܰܡ ܒ݁ܬ݂ܽܘܠܬ݂ܳܐ ܘܰܗ݈ܘܳܐ ܒ݁ܰܪܢܢܫܶܐ. ܘܐܶܨܛܠܶܒ݂ ܚܠܳܦ݂ܺܝܢ ܒܝܵܘ̈ܡ̇ܝ ܦ݁ܰܢܛܺܝܳܘܣ ܦܺܝܠܰܛܳܘܣ. ܚܰܫ ܘܡܺܝܬ ܘܶܐܬܩܒܰܪ. ܩܿܡ ܠܰܬ݂ܠܳܬ݂ܳܐ ܝܰܘܰܡܺܝܢ ܐܰܝܟ݂ ܕܰܟܬܺܝܒ. ܘܰܣܠܶܩ ܠܰܫܡܰܝܳܐ ܘܺܝܬ݂ܶܒ݂ ܡܶܢ ܝܳܡܺܝܢ ܐܰܒ݁ܽܘܗ̄ܝ. ܘܬܘܒ ܐܺܬ݁ܶܐ ܒܫܽܘܒ݂ܚܶܗ ܪܰܒܳܐ ܠܰܡܢ ܠܝܰܝܶܐ ܘܰܠܡܺܝܳܬ݂ܶܐ. ܗܰܘ ܕ݁ܰܠܡܰܠܟ݁ܽܘܬ݁ܶܗ ܫܽܘܠܳܡܳܐ ܠܳܐܐܝܬ. ܘܰܒ݂ܚܰܕ݂ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ ܕܐܰܝܳܬ݂ܰܘܗ݈ܝ ܡܳܪܝܳܐ ܡܰܚܝܢܳܐ ܕܟܽܠ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ܘܥܰܡ ܒܪܐ ܡܶܣܬܓܶܕ ܘܡܶܫܬ݂ܰܒ݂ܰܚ. ܗܰܘ ܕ݁ܡܰܠܶܠ ܒܰܢ̈ܟܿܳܝܶܐ. ܘܒ݂ܰܚܕܳܐ ܥܺܕܬ݂ܳܐ ܩܰܕܺܝܫܬ݂ܳܐ ܩܳܬ݂ܽܘܠܺܝܩܺܝ ܘܰܫܠܺܝܚܳܝܬ݂ܳܐ. ܘܡܰܘܕ݂ܶܝܢܰܢ ܕܰܚܕ݂ܳܐ ܗ̄ܝ ܡܰܥܡܰܘܕ݂ܳܝܬܳܐ ܠܫܽܘܒܩܳܢܳܐ ܕ݁ܚܰܛܳܗܶܐ. ܘܰܡܣܰܟܶܝܢܰܢ ܠܰܩ݀ܝܳܡܬܳܐ ܕܡܺܝ̈ܬ݂ܶܐ ܘܰܠܺܝ̈ܶܐ ܚܰܕ̈ܬ݂ܶܐ ܕܒ݂ܥܳܠܡܳܐ ܕܰܥܬ݂ܺܝܕ݂. ܐܰܡܺܝܢ.")
    let abun = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "ourFather")!)
    XCTAssertEqual(abun.title, "צלותא מרניתא")
    XCTAssertEqual(abun.body,
      "אַבוּן דבַשמַיָא נֶתקַדַש שמָך\n" +
      "תִאתֶא מַלכוּתָך נֶהוֶא צֶביָנָך,\n" +
      "אַיכַנָא דבַשמַיָא אָף בַארעָא,\n" +
      "הַבלַן לַחמָא דסוּנקָנַן יַומָנָא,\n" +
      "וַשבוּק לַן חַובַין וַחטָהַין\n" +
      "אַיכַנָא דָאף חנַן שבַקן לחַיָבַין,\n" +
      "ולָא תַעלַן לנֶסיוּנָא\n" +
      "אֶלָא פַצָא לַן מֶן בִישָא,\n" +
      "מֶטֻל דדִילָך הִי " +
      "מַלכוּתָא וחַילָא ותֶשבוּחתָא לעָלַם עָלמִין אַמִין.")
    XCTAssertEqual(abun.transliteratedBody,
      "ܐܰܒ݁ܽܘܢ ܕܒܰܫܡܰܝܳܐ ܢܶܬܩܰܕܰܫ ܫܡܳܟ\n" +
      "ܬܺܐܬܶܐ ܡܰܠܟܽܘܬܳܟ ܢܶܗܘܶܐ ܨܶܒܝܳܢܳܟ.\n" +
      "ܐܰܝܟܰܢܳܐ ܕܒܰܫܡܰܝܳܐ ܐܳܦ ܒܰܐܪܥܳܐ.\n" +
      "ܗܰܒܠܰܢ ܠܰܚܡܳܐ ܕܣܽܘܢܩܳܢܰܢ ܝܰܘܡܳܢܳܐ.\n" +
      "ܘܰܫܒܽܘܩ ܠܰܢ ܚܰܘܒܰܝ̈ܢ ܘܰܚܛܳܗܰܝ̈ܢ\n" +
      "ܐܰܝܟܰܢܳܐ ܕܳܐܦ ܚܢܰܢ ܫܒܰܩܢ ܠܚܰܝܳܒܰܝ̈ܢ.\n" +
      "ܘܠܳܐ ܬܰܥܠܰܢ ܠܢܶܣܝܽܘܢܳܐ\n" +
      "ܐܶܠܳܐ ܦܰܨܳܐ ܠܰܢ ܡܶܢ ܒܺܝܫܳܐ.\n" +
      "ܡܶܛܽܠ ܕܕܺܝܠܳܟ ܗܺܝ ܡܰܠܟܽܘܬܳܐ ܘܚܰܝܠܳܐ ܘܬܶܫܒܽܘܚܬܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ܀")
    let aramaicHailMary = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "hailMary")!)
    XCTAssertEqual(aramaicHailMary.title, "שלם לך מרים")
    XCTAssertEqual(aramaicHailMary.body,
      "שלָם לֶך מַריַם\n" +
      "מַליַת טַיבוּתָא, מָרַן עַמֶך\n" +
      "מבַרַכתָא אַנת בנֶשָא\n" +
      "וַמבַרַך הוּ פִירָא דַבכַרסֶך מָרַן יֶשוּע משִיחָא,\n" +
      "מָרַת מַריַם יָלדַת אַלָהָא\n" +
      "אַפִיס חלָפַין חנַן חַטָיָא,\n" +
      "הָשָא וַבכֻלזבַן וַלעָלַם עָלמִין אַמִין.")
    XCTAssertEqual(aramaicHailMary.transliteratedBody,
      "ܫܠܳܡ ܠܶܟ ܡܰܪܝܰܡ\n" +
      "ܡܰܠܝܰܬ ܛܰܝܒܽܘܬܳܐ, ܡܳܪܰܢ ܥܰܡܶܟ\n" +
      "ܡܒܰܪܰܟܬܳܐ ܐܰܢܬ ܒܢܶܫܳܐ\n" +
      "ܘܰܡܒܰܪܰܟ ܗܽܘ ܦܺܝܪܳܐ ܕܰܒܟܰܪܣܶܟ ܡܳܪܰܢ ܝܶܫܽܘܥ ܡܫܺܝܚܳܐ,\n" +
      "ܡܳܪܰܬ ܡܰܪܝܰܡ ܝܳܠܕܰܬ ܐܰܠܳܗܳܐ\n" +
      "ܐܰܦܺܝܣ ܚܠܳܦܰܝܢ ܚܢܰܢ ܚܰܛܳܝܳܐ,\n" +
      "ܗܳܫܳܐ ܘܰܒܟܽܠܙܒܰܢ ܘܰܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ.")
    let qadishat = BasicPrayerCatalog.step(for: BasicPrayerCatalog.prayer(id: "holyGod")!)
    XCTAssertEqual(qadishat.title, "קדישת אלהא")
  }

  /// Spanish, pinned the same way as Greek — what is sourced works, what is not falls back.
  /// Its prayers come from the Holy See's own Spanish Compendium, which prints each beside its
  /// Latin twin; the Creed, the Fatima prayer and the St Michael prayer are not in that
  /// appendix and are deliberately absent rather than reconstructed.
  func testSpanishPraysWhatWasSourcedAndFallsBackForTheRest() {
    XCTAssertTrue(PrayerTranslations.get(languageCode: "es", key: .paterNoster)
      .hasPrefix("Padre nuestro que estás en el cielo"))
    XCTAssertTrue(PrayerTranslations.get(languageCode: "es", key: .salveRegina)
      .hasPrefix("Dios te salve, Reina y Madre de misericordia"))
    // The Rosary's own collect, not the Angelus's — both are in the appendix and only one fits.
    XCTAssertTrue(PrayerTranslations.get(languageCode: "es", key: .collectaStandard)
      .contains("los misterios del Rosario"))

    XCTAssertEqual(PrayerTranslations.get(languageCode: "es", key: .symbolumApostolorum),
                   PrayerTranslations.get(languageCode: "en", key: .symbolumApostolorum),
                   "the sourced Spanish set has no Creed, so the configured first fallback stands")

    // The Scripture is imported and in the pack; a session cannot reach it until a manifest
    // offers Spanish, which waits on Spanish bundle text — same as Greek.
    XCTAssertTrue(PrayerPackStore.resolveBodyText(
      bundleId: "stationsOfTheCross", languageCode: "es", key: "scriptural01Body")
      .contains("Gethsemaní"))
  }

  /// Where Greek stands, pinned exactly — because it is half-finished and the half that is done
  /// should not be mistaken for the whole.
  ///
  /// The shared prayers work: a Greek session says the Jesus Prayer and the Sub Tuum in the
  /// language they were written in, and follows the configured language precedence for the
  /// Latin-tradition prayers Greek has none of.
  ///
  /// The bundle Scripture does not, yet. The Peshitta/Byzantine import put 36 passages into the
  /// packs, and they are genuinely there — resolveBodyText finds them. But a *session* never
  /// asks for them: no bundle's manifest declares "el", so effectiveLanguage falls to the
  /// bundle's first language and the whole devotion prays Latin. Declaring it would fix that and
  /// would also be a lie — Greek covers 22–43% of those bundles' keys, so the offer would be a
  /// devotion that is mostly Latin wearing a Greek label. What flips this test is Greek titles
  /// and prayers in the bundles, not a manifest edit.
  func testGreekPraysItsOwnPrayersAndFallsBackForTheRest() {
    XCTAssertEqual(PrayerTranslations.get(languageCode: "el", key: .oratioIesu),
                   "Κύριε Ἰησοῦ Χριστέ, Υἱὲ τοῦ Θεοῦ, ἐλέησόν με τὸν ἁμαρτωλόν.")
    XCTAssertTrue(PrayerTranslations.get(languageCode: "el", key: .subTuumPraesidium)
      .hasPrefix("Ὑπὸ τὴν σὴν εὐσπλαγχνίαν"))
    XCTAssertEqual(PrayerTranslations.get(languageCode: "el", key: .salveRegina),
                   PrayerTranslations.get(languageCode: "en", key: .salveRegina),
                   "no citable Greek Salve Regina exists, so the configured fallback stands")

    // The imported Scripture is in the pack...
    let greek = PrayerPackStore.resolveBodyText(
      bundleId: "viaLucis", languageCode: "el", key: "viaLucis01Body")
    XCTAssertTrue(greek.contains("Ὀψὲ δὲ σαββάτων"), "Matthew 28 in the Byzantine text")

    // ...and a session uses the first available configured fallback, because no manifest offers
    // Greek yet.
    let session = steps("viaLucis", language: "el")
    XCTAssertEqual(session.map(\.body), steps("viaLucis", language: "en").map(\.body))
  }

  /// The Vicariate's Hebrew prayerbook leads each of the three acclamations with a cross, and
  /// gives the short form none. The asymmetry is the point: it is exactly what an editor would
  /// "tidy up" later, so both halves are pinned. Hebrew only — the other languages keep the
  /// plain text until someone has seen a prayerbook in those.
  func testTrisagionCrossesFollowTheVicariatesPrayerbook() {
    let hebrew = steps("trisagion", language: "he")
    XCTAssertEqual(hebrew[0].body.filter { $0 == "✠" }.count, 3, "one cross per acclamation")
    XCTAssertTrue(hebrew[0].body.hasPrefix("✠ קָדוֹשׁ הָאֱלֹהִים"))
    XCTAssertFalse(hebrew[4].body.contains("✠"), "the short form takes no cross")

    for language in ["la", "en", "ar", "ru", "tl"] {
      XCTAssertFalse(steps("trisagion", language: language)[0].body.contains("✠"),
                     "\(language) has no prayerbook behind it yet")
    }
  }

  /// The Mission of St. Gamaliel's Trisagion (sent by Erez 2026-08-06) addresses God in the
  /// second person where the app's own Hebrew declares of him, and heads the prayer with the
  /// Aramaic קדישת. Pinned so their wording — including the ✠▼▲ marks exactly as sent — cannot
  /// drift, and so it stays visibly distinct from the plain-Hebrew form beside it.
  func testTrisagionInTheMissionsRite() {
    // Explicitly the Byzantine form: the rite's *default* is now the Syriac one (see
    // testTrisagionDefaultFormFollowsThePrayerLanguage); this test pins the wording overlay.
    let mission = steps("trisagion", language: "he-x-gamliel", variantId: "byzantine")
    let hebrew = steps("trisagion", language: "he")

    XCTAssertEqual(mission.map(\.title), Array(repeating: "קדישת", count: 3) + ["השבח לאב"]
      + Array(repeating: "קדישת", count: 2))
    XCTAssertTrue(mission[0].body.hasPrefix("אַתָּה ✠▼▲ קָדוֹשׁ – אֱלוֹהִים"))
    XCTAssertTrue(mission[0].body.contains("תְּרַחֵם עָלֵינוּ"))
    XCTAssertFalse(mission[4].body.contains("חַיִל"), "the short form drops the second acclamation")

    XCTAssertNotEqual(mission[0].body, hebrew[0].body)
    XCTAssertEqual(hebrew[0].title, "קדוש האלהים")

    // Not sent by the Mission: the Glory Be itself still reads their wording from the shared
    // table, and everything else falls through to plain Hebrew.
    XCTAssertTrue(mission[3].body.contains("הַשֶּׁבַח לָאָב"))
  }


  /// A repeated step's counter is part of the heading, not the interface: praying in Hebrew, the Divine Mercy
  /// decade reads "(1 מתוך 10)". Splicing the English "of" into right-to-left text left bidi
  /// to reorder it into "(of 10 1)".
  /// The decade ordinal is part of the heading too: "1st Sorrow" in English, "מכאוב 1" in
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
    XCTAssertTrue(steps[1].body.contains("Hail Mary,\nfull of grace"))
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

  func testAngelusSentinelFollowsTheAppDefaultLanguage() {
    let key = "defaultLanguageCode"
    let original = UserDefaults.standard.object(forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }
    UserDefaults.standard.set("en", forKey: key)
    let steps = steps("angelus", language: LanguageCatalog.defaultSentinel)
    XCTAssertTrue(steps[0].body.contains("The Angel of the Lord declared unto Mary"))
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
    XCTAssertEqual(steps[2].title, "ישוע נדון למות")
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
    XCTAssertTrue(steps[2].body.contains("— Mark 14:32–36 (Douay-Rheims)"))
    // The Sanhedrin scene skips verses 56–59 — the gap is marked, not papered over.
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
    XCTAssertEqual(steps[2].title, "ישוע מתפלל בגת שמנים")
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
    XCTAssertTrue(steps[1].body.contains("— Matthew 28:1–7 (Douay-Rheims)"))
    XCTAssertTrue(steps[1...14].allSatisfy(\.isScripture))
    // The Emmaus-road station skips verses 17–24 — the gap is marked, not papered over.
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
    XCTAssertTrue(steps[1].body.contains("— Matth. 28:1–7 (Vulgata)"))
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

  /// The Divine Mercy chaplet's Hebrew is the Latin Patriarchate's own — approved by Patriarch
  /// Michel Sabbah in 2003 — so it is pinned here rather than left to drift.
  func testDivineMercyHebrewIsTheApprovedText() {
    let steps = steps("divineMercyChaplet", language: "he")
    XCTAssertTrue(steps.contains { $0.body.hasPrefix("אב נצחי שבשמים, אני מציע בפניך") },
                  "the offering on each major bead")
    XCTAssertTrue(steps.contains { $0.body == "למען אהבתו אותנו בייסוריו רחם עלינו ועל העולם כולו." },
                  "the petition on each minor bead")
    XCTAssertTrue(steps.contains { $0.body.hasPrefix("קדוש אלוהינו, קדוש וחזק") },
                  "the closing acclamation")
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

    // Headings belong to the rite that uses them: the Mission's in the Mission's rite, the
    // app's own in plain Hebrew.
    let hebrew = steps("rosary", language: "he", customOptions: ["apostlesCreed": "true"])
    XCTAssertEqual(variant.first?.title, "אות הצלב")
    XCTAssertEqual(hebrew.first?.title, "סימן הצלב")
    XCTAssertEqual(hebrew[1].title, "אני מאמין")
    XCTAssertTrue(variant.contains { $0.title.hasPrefix("שלום לך מרים") })
    XCTAssertTrue(hebrew.contains { $0.title.hasPrefix("שמחי מרים") })
    XCTAssertTrue(variant.contains { $0.title == "השבח לאב" })
    XCTAssertTrue(hebrew.contains { $0.title == "כבוד לאב" })

    // Not sent by the Mission: the Fatima prayer still reads in the app's Hebrew.
    let fatima = { (list: [RosaryStep]) in list.first { $0.title.contains("הו ישוע") }?.body }
    XCTAssertEqual(fatima(variant), fatima(hebrew))

    // The mysteries are announced in Hebrew too. The Mission ships no mystery texts of its own,
    // and the announcement is the one step whose body is quoted Scripture — before the base
    // language step in MysteryTranslations.get it fell past plain Hebrew all the way to Latin,
    // so the rite prayed its Rosary in Hebrew but heard every mystery announced in Latin.
    let announcement = { (list: [RosaryStep]) in list.first { $0.mystery != nil } }
    XCTAssertNotNil(announcement(variant))
    XCTAssertEqual(announcement(variant)?.title, announcement(hebrew)?.title)
    XCTAssertEqual(announcement(variant)?.body, announcement(hebrew)?.body)
    XCTAssertNotEqual(
      announcement(variant)?.body, announcement(steps("rosary", language: "la"))?.body,
      "the rite must not fall through to Latin while its prayers read Hebrew")
  }

  /// Both sourced Hebrew uses stay visible as separate prayer-language choices.
  func testRitesAreListedUnderTheirLanguage() {
    XCTAssertEqual(LanguageCatalog.all.filter { $0.code.hasPrefix("he") }.map(\.code),
                   ["he", "he-x-gamliel"])
    XCTAssertEqual(LanguageCatalog.availableOptions(for: ["la", "he", "en"]).map(\.code),
                   ["la", "en", "he", "he-x-gamliel"])
    XCTAssertEqual(LanguageCatalog.rites(of: "he").map(\.code), ["he", "he-x-gamliel"])
    XCTAssertEqual(LanguageCatalog.rites(of: "he-x-gamliel").map(\.code), ["he", "he-x-gamliel"])
    XCTAssertTrue(LanguageCatalog.rites(of: "la").isEmpty)

    // A rite resolves as its language for display, keeps its own code, and reads right-to-left.
    let resolved = LanguageCatalog.resolve("he-x-gamliel")
    XCTAssertEqual(resolved.code, "he-x-gamliel")
    XCTAssertEqual(resolved.nativeName, "עברית — נוסח השליחות")
    XCTAssertTrue(resolved.isRightToLeft)
  }

  func testLanguageFallbackOrderKeepsBaseFirstAndLatinLast() {
    let key = LanguageCatalog.fallbackOrderKey
    let original = UserDefaults.standard.array(forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }
    LanguageCatalog.setFallbackOrder(["ru", "en", "ar", "he", "he-x-gamliel", "arc", "el", "es", "tl", "la"])
    let chain = LanguageCatalog.fallbackChain(for: "he-x-gamliel")
    XCTAssertEqual(Array(chain.prefix(4)), ["he-x-gamliel", "he", "ru", "en"])
    XCTAssertEqual(chain.last, "la")
  }

  func testLanguageFallbackOrderCanResetToTheCanonicalOrder() {
    let key = LanguageCatalog.fallbackOrderKey
    let original = UserDefaults.standard.array(forKey: key)
    defer {
      if let original { UserDefaults.standard.set(original, forKey: key) }
      else { UserDefaults.standard.removeObject(forKey: key) }
    }

    LanguageCatalog.setFallbackOrder(Array(LanguageCatalog.defaultFallbackOrder.reversed()))
    XCTAssertNotEqual(LanguageCatalog.fallbackOrder, LanguageCatalog.defaultFallbackOrder)
    LanguageCatalog.resetFallbackOrder()
    XCTAssertEqual(LanguageCatalog.fallbackOrder, LanguageCatalog.defaultFallbackOrder)
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
