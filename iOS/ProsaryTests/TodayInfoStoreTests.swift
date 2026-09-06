//
//  TodayInfoStoreTests.swift
//  ProsaryTests
//
//  Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
//  movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
//  Roman Calendar), the Pope's monthly intention, and the graceful out-of-range nil that hides
//  the row.
//

import Foundation
import XCTest
@testable import Prosary

@MainActor
final class TodayInfoStoreTests: XCTestCase {
  // The test host shares the real app's UserDefaults, so every case pins the calendar
  // selection explicitly and the original value is restored afterwards — the store reloads
  // live on selection change, so no reset hook is needed.
  private var originalCalendarId: String?
  private var originalPaschaStyle: String?

  override func setUp() {
    super.setUp()
    originalCalendarId = UserDefaults.standard.string(forKey: TodayInfoStore.calendarDefaultsKey)
    originalPaschaStyle = UserDefaults.standard.string(forKey: TodayInfoStore.paschaStyleDefaultsKey)
    UserDefaults.standard.removeObject(forKey: TodayInfoStore.calendarDefaultsKey)
    UserDefaults.standard.removeObject(forKey: TodayInfoStore.paschaStyleDefaultsKey)
  }

  override func tearDown() {
    if let originalPaschaStyle {
      UserDefaults.standard.set(originalPaschaStyle, forKey: TodayInfoStore.paschaStyleDefaultsKey)
    } else {
      UserDefaults.standard.removeObject(forKey: TodayInfoStore.paschaStyleDefaultsKey)
    }
    if let originalCalendarId {
      UserDefaults.standard.set(originalCalendarId, forKey: TodayInfoStore.calendarDefaultsKey)
    } else {
      UserDefaults.standard.removeObject(forKey: TodayInfoStore.calendarDefaultsKey)
    }
    super.tearDown()
  }

  private func select(_ calendarId: String) {
    UserDefaults.standard.set(calendarId, forKey: TodayInfoStore.calendarDefaultsKey)
  }

  private func date(_ string: String) -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: string)!
  }

  func testSundaySuppressesOnlyTheSupplementalDayHeadingInEveryCalendar() {
    for calendarId in TodayInfoStore.calendars.map(\.id) {
      select(calendarId)
      XCTAssertNil(TodayInfoStore.displayDayInfo(on: date("2026-09-06")), calendarId)
      XCTAssertNotNil(TodayInfoStore.feast(on: date("2026-09-06")), calendarId)
    }
  }

  func testOtherRitesUseCivilDayHeadingWithoutLatinSeasons() throws {
    for calendarId in ["roman1962", "ugcc", "syriac"] {
      let day = try XCTUnwrap(TodayInfoStore.displayDayInfo(on: date("2026-09-07"), calendarId: calendarId))
      XCTAssertEqual(day.localized("en"), "Day 7 of September", calendarId)
      let hebrew = day.localized("he").replacingOccurrences(of: "\u{2068}", with: "")
        .replacingOccurrences(of: "\u{2069}", with: "")
      XCTAssertEqual(hebrew, "יום 7 בחודש ספטמבר", calendarId)
      XCTAssertEqual(day.season, "")
      for language in UILanguage.all where language.code != "en" {
        XCTAssertNotEqual(day.localized(language.code), day.localized("en"), language.code)
      }
    }
    for calendarId in ["roman", "lpj"] {
      let day = try XCTUnwrap(TodayInfoStore.displayDayInfo(on: date("2026-09-07"), calendarId: calendarId))
      XCTAssertTrue(day.localized("en").contains("Ordinary Time"), calendarId)
    }
  }

  func testDateNavigationCrossesMonthYearAndLeapDayBoundaries() {
    XCTAssertEqual(TodayInfoStore.dateByMoving(1, from: date("2026-12-31")), date("2027-01-01"))
    XCTAssertEqual(TodayInfoStore.dateByMoving(-1, from: date("2027-01-01")), date("2026-12-31"))
    XCTAssertEqual(TodayInfoStore.dateByMoving(1, from: date("2028-02-28")), date("2028-02-29"))
    XCTAssertEqual(TodayInfoStore.dateByMoving(1, from: date("2028-02-29")), date("2028-03-01"))
  }

  func testTorahReadingContractPreservesFestivalStatusAndLocalizedCitations() throws {
    let portion = try JSONDecoder().decode(TorahPortion.self, from: Data(#"{"saturday":"2026-09-12","title":"Rosh Hashana","titleByLanguage":{"he":"ראש השנה"},"isHoliday":true,"readings":[{"type":"torah","short":"Gen. 21","full":"Genesis 21:1–34","fullByLanguage":{"he":"בראשית כ״א 1–34"}}],"sourceUrl":"https://www.hebcal.com"}"#.utf8))
    XCTAssertTrue(portion.isHoliday)
    XCTAssertEqual(portion.localizedTitle("iw"), "ראש השנה")
    XCTAssertEqual(portion.readings.first?.localizedFull("he"), "בראשית כ״א 1–34")
    XCTAssertEqual(portion.saturday, "2026-09-12")
    XCTAssertNil(TodayInfoStore.torahPortion(on: date("2031-01-01")))
  }

  func testBundledTorahScheduleUsesTheUpcomingIsraelSabbathAndFestivalReplacement() throws {
    let friday = try XCTUnwrap(TodayInfoStore.torahPortion(on: date("2026-05-22")))
    let sabbath = try XCTUnwrap(TodayInfoStore.torahPortion(on: date("2026-05-23")))
    XCTAssertEqual(friday, sabbath)
    XCTAssertEqual(sabbath.saturday, "2026-05-23")
    XCTAssertFalse(sabbath.isHoliday, "Israel reads the weekly portion while the diaspora keeps a second festival day")
    XCTAssertTrue(sabbath.localizedTitle("he").contains("נשא"))
    XCTAssertFalse(sabbath.readings.isEmpty)
    let festival = try XCTUnwrap(TodayInfoStore.torahPortion(on: date("2026-09-12")))
    XCTAssertTrue(festival.isHoliday)
    XCTAssertTrue(festival.localizedTitle("he").contains("ראש השנה"))
    XCTAssertNotEqual(TodayInfoStore.torahPortion(on: date("2026-05-24"))?.saturday, sabbath.saturday)
  }

  func testOldTodayLanguageOverrideCannotChangeInterfaceLanguage() {
    let original = UserDefaults.standard.object(forKey: "todayLanguageCode")
    defer {
      if let original { UserDefaults.standard.set(original, forKey: "todayLanguageCode") }
      else { UserDefaults.standard.removeObject(forKey: "todayLanguageCode") }
    }
    let interfaceLanguage = UILanguage.current
    for oldOverride in ["ar", "he", "fr", "unsupported"] {
      UserDefaults.standard.set(oldOverride, forKey: "todayLanguageCode")
      XCTAssertEqual(UILanguage.current, interfaceLanguage)
    }
  }

  func testFixedSolemnityResolves() {
    let feast = TodayInfoStore.feast(on: date("2026-12-25"))
    XCTAssertEqual(feast?.title, "Christmas")
    XCTAssertEqual(feast?.rank, "Solemnity")
  }

  func testMovableFeastIsBakedInPerYear() {
    // Easter falls on April 5 in 2026 and March 28 in 2027 — both must resolve.
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-04-05"))?.rank, "Solemnity")
    XCTAssertNotNil(TodayInfoStore.feast(on: date("2027-03-26")))  // Good Friday 2027
  }

  /// The Holy Land calendar's own principal feast overlays the General Roman Calendar — in 2026
  /// October 25 is a Sunday of Ordinary Time in the GRC, but the diocese's patronal solemnity
  /// takes precedence.
  func testLatinPatriarchatePropersOverlayTheGeneralCalendar() {
    let feast = TodayInfoStore.feast(on: date("2026-10-25"))
    XCTAssertEqual(feast?.title, "Our Lady, Queen of Palestine and of the Holy Land")
    XCTAssertEqual(feast?.rank, "Solemnity")

    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-07-15"))?.title,
      "Dedication of the Basilica of the Holy Sepulchre")
  }

  func testFerialDayHasNoFeast() {
    // An ordinary weekday with no memorial in either calendar.
    XCTAssertNil(TodayInfoStore.feast(on: date("2026-07-27")))
  }

  func testDateOutsideTheGeneratedYearsHasNoFeast() {
    XCTAssertNil(TodayInfoStore.feast(on: date("2031-12-25")))
  }

  // MARK: - Switchable calendars

  func testCalendarRegistryListsTheShippedCalendarsInPickerOrder() {
    XCTAssertEqual(
      TodayInfoStore.calendars.map(\.id),
      ["lpj", "roman", "roman1962", "ugcc", "syriac", "maronite"])
    XCTAssertEqual(TodayInfoStore.selectedCalendarId, "lpj")
  }

  /// Hebrew titles are translations on the one General Roman calendar rather than a second
  /// calendar with a different set of days.
  func testGeneralRomanCalendarLocalizesItsTitlesWhenAvailable() {
    select("roman")
    let bartholomew = TodayInfoStore.feast(on: date("2026-08-24"))
    XCTAssertEqual(bartholomew?.title, "Saint Bartholomew, Apostle")
    XCTAssertEqual(bartholomew?.localizedTitle("he"), "חג בר־תלמי השליח")
    XCTAssertEqual(bartholomew?.rank, "Feast")
    let sunday = TodayInfoStore.feast(on: date("2026-08-30"))
    XCTAssertEqual(sunday?.localizedTitle("he"), "יום א ה־22 של הזמן הרגיל")
    XCTAssertEqual(sunday?.rank, "Sunday")
    XCTAssertNotNil(TodayInfoStore.feast(on: date("2026-09-03")))
  }

  func testEveryCalendarLocalizesItsOwnFeastWithoutChangingItsTitleOrRank() throws {
    let expected = [
      ("lpj", "Exaltation of the Holy Cross", "Feast"),
      ("roman", "Exaltation of the Holy Cross", "Feast"),
      ("roman1962", "Exaltation of the Holy Cross", "2nd Class"),
      ("ugcc", "The Exaltation of the Precious and Life-Giving Cross", "Great Feast"),
      ("syriac", "Exaltation of the Holy Cross—Feast", "Feast"),
    ]
    for (calendarId, title, rank) in expected {
      select(calendarId)
      let feast = try XCTUnwrap(TodayInfoStore.feast(on: date("2026-09-14")), calendarId)
      XCTAssertEqual(feast.title, title, calendarId)
      XCTAssertEqual(feast.rank, rank, calendarId)
      XCTAssertEqual(feast.localizedTitle("he"), "חג תפארת הצלב", calendarId)
      XCTAssertEqual(feast.localizedTitle("he-x-gamliel"), "חג תפארת הצלב", calendarId)
      XCTAssertEqual(feast.localizedTitle("en"), title, calendarId)
    }
  }

  func testFeastWithoutATranslationKeepsItsOwnTitle() {
    let feast = FeastDay(title: "Untranslated feast", titleByLanguage: nil, rank: "Feast")
    XCTAssertEqual(feast.localizedTitle("he"), "Untranslated feast")
    XCTAssertEqual(feast.localizedTitle("he-x-gamliel"), "Untranslated feast")
  }

  func testTeresaOfCalcuttaLocalizesWithoutReplacingAnotherCalendarsDay() throws {
    for calendarId in ["lpj", "roman"] {
      select(calendarId)
      let feast = try XCTUnwrap(TodayInfoStore.feast(on: date("2026-09-05")), calendarId)
      XCTAssertEqual(feast.title, "Saint Teresa of Calcutta, Virgin", calendarId)
      XCTAssertEqual(feast.rank, "Optional Memorial", calendarId)
      XCTAssertEqual(feast.localizedTitle("he"), "תרזה הקדושה מקלקוטה, בתולה", calendarId)
      XCTAssertEqual(feast.localizedTitle("he-x-gamliel"), "תרזה הקדושה מקלקוטה, בתולה", calendarId)
      XCTAssertEqual(feast.localizedTitle("en"), "Saint Teresa of Calcutta, Virgin", calendarId)

      // September 5 falls on Sunday in 2027; translating a saint must not change precedence.
      let sunday = TodayInfoStore.feast(on: date("2027-09-05"))
      XCTAssertEqual(sunday?.title, "23rd Sunday of Ordinary Time", calendarId)
      XCTAssertEqual(sunday?.rank, "Sunday", calendarId)
    }

    select("roman1962")
    let vetus = TodayInfoStore.feast(on: date("2026-09-05"))
    XCTAssertEqual(vetus?.title, "St. Lawrence Justinian")
    XCTAssertEqual(vetus?.rank, "3rd Class")
    for calendarId in ["ugcc", "syriac"] {
      select(calendarId)
      XCTAssertNil(TodayInfoStore.feast(on: date("2026-09-05")), calendarId)
    }
  }

  func testSaintTitlesRetainTheirRolesAcrossCalendarAliases() throws {
    let expected = [
      ("roman", "2026-05-26", "Saint Philip Neri, Priest", "Memorial", "פיליפוס נרי, כהן"),
      ("roman", "2026-10-22", "Saint John Paul II, Pope", "Optional Memorial", "יוחנן פאולוס השני, אפיפיור"),
      ("roman", "2026-07-15", "Saint Bonaventure, Bishop and Doctor of the Church", "Memorial", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
      ("roman1962", "2026-07-14", "St. Bonaventure", "3rd Class", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
      ("roman", "2026-07-03", "Saint Thomas the Apostle", "Feast", "תאמא השליח"),
      ("syriac", "2026-10-06", "Feast of Saint Thomas the Apostle", "Feast", "תאמא השליח"),
      ("roman1962", "2026-12-21", "St. Thomas", "2nd Class", "תאמא השליח"),
      ("roman", "2026-01-28", "Saint Thomas Aquinas, Priest and Doctor of the Church", "Memorial", "תומאס אקווינס, כהן ודוקטור הכנסייה"),
    ]
    for (calendarId, feastDate, title, rank, hebrew) in expected {
      select(calendarId)
      let feast = try XCTUnwrap(TodayInfoStore.feast(on: date(feastDate)), title)
      XCTAssertEqual(feast.title, title)
      XCTAssertEqual(feast.rank, rank)
      XCTAssertEqual(feast.localizedTitle("he"), hebrew, title)
      XCTAssertEqual(feast.localizedTitle("he-x-gamliel"), hebrew, title)
      XCTAssertEqual(feast.localizedTitle("en"), title)
    }
  }

  func testFeastRanksFollowTodayLanguageWithoutChangingCanonicalValues() {
    let expected = [
      ("Solemnity", "מועד"),
      ("Feast", "חג"),
      ("Memorial", "זיכרון"),
      ("Optional Memorial", "זיכרון רשות"),
      ("Sunday", "יום ראשון"),
      ("Great Feast", "חג גדול"),
      ("Holy Week", "השבוע הקדוש"),
      ("Fast", "צום"),
      ("1st Class", "דרגה ראשונה"),
      ("2nd Class", "דרגה שנייה"),
      ("3rd Class", "דרגה שלישית"),
    ]
    for (rank, hebrew) in expected {
      let feast = FeastDay(title: "Feast", titleByLanguage: nil, rank: rank)
      XCTAssertEqual(feast.localizedRank("he"), hebrew, rank)
      XCTAssertEqual(feast.localizedRank("he-x-gamliel"), hebrew, rank)
      XCTAssertEqual(feast.localizedRank("en"), rank)
      XCTAssertNotEqual(feast.localizedRank("fr"), rank, rank)
      XCTAssertEqual(feast.rank, rank)
    }
    let unknown = FeastDay(title: "Feast", titleByLanguage: nil, rank: "Future rank")
    XCTAssertEqual(unknown.localizedRank("he"), "Future rank")
  }

  func testLocalizedDisplayTitlesDropHebrewPointingOnly() {
    let feast = FeastDay(
      title: "Vocalized feast", titleByLanguage: ["he": "חַג הַבְּשׂוֹרָה"], rank: "Feast")
    XCTAssertEqual(feast.localizedTitle("he"), "חג הבשורה")

    let intention = PopeIntention(
      title: "Vocalized intention", text: "Body",
      titleByLanguage: ["he": "כַּוָּנַת הַתְּפִלָּה"],
      textByLanguage: ["he": "גּוּף מְנֻקָּד"])
    XCTAssertEqual(intention.localizedTitle("he"), "כונת התפלה")
    XCTAssertEqual(intention.localizedText("he"), "גּוּף מְנֻקָּד",
                   "prose/body text keeps its authored pointing")
  }

  func testLegacyHebrewRomanSelectionMigratesToGeneralRoman() {
    select("roman-he")
    XCTAssertEqual(TodayInfoStore.selectedCalendarId, "roman")
    XCTAssertEqual(UserDefaults.standard.string(forKey: TodayInfoStore.calendarDefaultsKey), "roman")
  }

  /// The Syriac Catholic table comes from Evangelizo.org's Daily Gospel (credited on the
  /// About screen): the Antiochene year names its Sundays from the season's anchor feasts,
  /// and Evangelizo's plain-date ferial titles are omitted like ferial days everywhere else.
  func testSyriacCalendarNamesTheAntiocheneSeasons() {
    select("syriac")
    let sunday = TodayInfoStore.feast(on: date("2026-10-25"))
    XCTAssertEqual(sunday?.title, "Sixth Sunday after the Feast of the Cross")
    XCTAssertEqual(sunday?.rank, "Sunday")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-08-15"))?.title, "Assumption of the Mother of God")
    XCTAssertNil(TodayInfoStore.feast(on: date("2026-07-27")))
  }

  /// October 25, 2026 wears four different faces: the LPJ's patronal solemnity, a plain
  /// Sunday of Ordinary Time in the general calendar, Christ the King in the 1962 books
  /// (which place the feast on October's last Sunday), and a numbered Sunday after Pentecost
  /// in the Byzantine reckoning.
  func testSwitchingCalendarsResolvesEachCalendarsOwnFeast() {
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-25"))?.title,
      "Our Lady, Queen of Palestine and of the Holy Land")

    select("roman")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-25"))?.title, "30th Sunday of Ordinary Time")

    select("roman1962")
    let vetus = TodayInfoStore.feast(on: date("2026-10-25"))
    XCTAssertEqual(vetus?.title, "Christ the King")
    XCTAssertEqual(vetus?.rank, "1st Class")

    select("ugcc")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-25"))?.title, "21st Sunday after Pentecost")
  }

  /// The default matches the UGCC's revised fixed calendar with Julian Pascha; Gregorian
  /// Pascha is an explicit alternative whose feast and reading files change together.
  func testUkrainianCalendarDefaultsToJulianPaschaWithGregorianFixedFeasts() {
    select("ugcc")
    let pascha = TodayInfoStore.feast(on: date("2026-04-12"))
    XCTAssertEqual(pascha?.title, "The Resurrection of Our Lord — Holy Pascha")
    XCTAssertEqual(pascha?.rank, "Great Feast")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-01"))?.title,
      "The Protection of the Most Holy Theotokos (Pokrov)")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2027-03-25"))?.title,
      "The Annunciation of the Most Holy Theotokos")
  }

  func testChangingPaschaStyleReloadsFeastsAndReadingsWithoutChangingCalendar() {
    select("ugcc")
    XCTAssertEqual(TodayInfoStore.selectedPaschaStyle, "julian")
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-09-06"))?.title, "14th Sunday after Pentecost")
    XCTAssertEqual(TodayInfoStore.readings(on: date("2026-09-06")).map(\.full),
                   ["2 Corinthians 1:21–2:4", "Matthew 22:1–14"])
    UserDefaults.standard.set("gregorian", forKey: TodayInfoStore.paschaStyleDefaultsKey)
    XCTAssertEqual(TodayInfoStore.selectedCalendarId, "ugcc")
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-04-05"))?.title, "The Resurrection of Our Lord — Holy Pascha")
    XCTAssertEqual(TodayInfoStore.readings(on: date("2026-09-06")).map(\.full),
                   ["2 Corinthians 4:6–15", "Matthew 22:35–46"])
    UserDefaults.standard.set("future-style", forKey: TodayInfoStore.paschaStyleDefaultsKey)
    XCTAssertEqual(TodayInfoStore.selectedPaschaStyle, "julian")
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-09-06"))?.title, "14th Sunday after Pentecost")
    XCTAssertEqual(TodayInfoStore.readings(on: date("2026-09-06")).map(\.full),
                   ["2 Corinthians 1:21–2:4", "Matthew 22:1–14"])
    select("roman")
    let roman = TodayInfoStore.readings(on: date("2026-09-06"))
    UserDefaults.standard.set("gregorian", forKey: TodayInfoStore.paschaStyleDefaultsKey)
    XCTAssertEqual(TodayInfoStore.readings(on: date("2026-09-06")), roman)
  }

  func testUnknownCalendarIdFallsBackToTheDefault() {
    select("narnia")
    XCTAssertEqual(TodayInfoStore.selectedCalendarId, "lpj")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-25"))?.title,
      "Our Lady, Queen of Palestine and of the Holy Land")
  }

  func testVetusOrdoKeepsSeptuagesimaAndClassRanks() {
    select("roman1962")
    let septuagesima = TodayInfoStore.feast(on: date("2026-02-01"))
    XCTAssertEqual(septuagesima?.title, "Septuagesima Sunday")
    XCTAssertEqual(septuagesima?.rank, "2nd Class")
    XCTAssertEqual(TodayInfoStore.feast(on: date("2026-12-25"))?.rank, "1st Class")
  }

  func testMonthIntentionResolves() {
    let intention = TodayInfoStore.intention(for: date("2026-07-27"))
    XCTAssertEqual(intention?.title, "For respect for human life")
    XCTAssertTrue(intention?.text.contains("human life in all its stages") ?? false)
    XCTAssertEqual(intention?.localizedTitle("he"), "למען כבוד לחיי אדם")
    XCTAssertTrue(intention?.localizedText("he").contains("בכל שלביהם") ?? false)
  }

  func testReadingsAndLiturgicalDayResolve() {
    let readings = TodayInfoStore.readings(on: date("2026-08-31"))
    XCTAssertEqual(readings.map(\.short), ["1 Cor. 2", "Ps. 119", "Lk. 4"])
    XCTAssertEqual(readings.last?.full, "Luke 4:16–30")
    XCTAssertEqual(readings.last?.hebrew, "הבשורה על־פי לוקס ד׳ 16–30")
    XCTAssertEqual(readings.map { $0.localizedShort("he") }, [
      "הראשונה אל הקורינתים ב׳", "תהלים קי״ט", "לוקס ד׳",
    ])
    XCTAssertEqual(readings.map { $0.localizedShort("he-x-gamliel") }, [
      "הראשונה אל הקורינתים ב׳", "תהלים קי״ט", "לוקס ד׳",
    ], "Hebrew prayer-language variants inherit the authored Hebrew citations unchanged")
    XCTAssertEqual(readings.last?.localizedFull("he-x-gamliel"), "הבשורה על־פי לוקס ד׳ 16–30")

    let day = TodayInfoStore.liturgicalDayInfo(on: date("2026-08-31"))
    XCTAssertTrue(day.english.hasPrefix("Monday · Week "))
    XCTAssertTrue(day.english.hasSuffix(" of Ordinary Time"))
    XCTAssertTrue(day.hebrew.contains("בזמן הרגיל"))
    XCTAssertTrue(day.hebrew.contains("השבוע ה־"))
    XCTAssertFalse(day.hebrew.contains("ה-"))
  }

  func testHebrewEpistleShorthandPreservesFullSourceCitation() throws {
    let corinthians = TodayInfoStore.readings(on: date("2026-09-04")).first
    XCTAssertEqual(corinthians?.localizedShort("he"), "הראשונה אל הקורינתים ד׳")
    XCTAssertEqual(
      corinthians?.localizedFull("he"),
      "אגרת שאול הראשונה אל הקורינתים ד׳ 1–5")

    let petrine = try JSONDecoder().decode(
      ReadingCitation.self,
      from: Data(#"{"type":"reading","short":"2 Pet. 2","full":"2 Peter 2:1–3","shortByLanguage":{"he":"השנייה של כיפא ב׳"},"fullByLanguage":{"he":"אגרת כיפא השניה ב׳ 1–3"}}"#.utf8))
    XCTAssertEqual(petrine.localizedShort("he"), "השנייה של כיפא ב׳")
    XCTAssertEqual(petrine.localizedFull("he"), "אגרת כיפא השניה ב׳ 1–3")
  }

  func testOtherCalendarsLocalizeTheirOwnAppointedReadingsInHebrew() {
    select("roman1962")
    let vetus = TodayInfoStore.readings(on: date("2026-09-03"))
    XCTAssertEqual(vetus.first?.localizedShort("he"), "הראשונה אל התסלוניקים ב׳")
    XCTAssertEqual(vetus.last?.localizedFull("he"), "הבשורה  על־פי יוחנן כ״א 15–17")

    select("ugcc")
    let byzantine = TodayInfoStore.readings(on: date("2026-09-06"))
    XCTAssertEqual(byzantine.first?.localizedShort("he"), "השנייה אל הקורינתים א׳")
    XCTAssertEqual(byzantine.first?.localizedFull("he"), "אגרת שאול השניה אל הקורינתים א׳ 21–ב׳ 4")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-08-06")).first?.localizedShort("he"),
      "השנייה של כיפא א׳")

    select("syriac")
    let syriac = TodayInfoStore.readings(on: date("2026-09-03"))
    XCTAssertEqual(syriac.first?.localizedShort("he-x-gamliel"), "אל הפיליפים א׳")
    XCTAssertEqual(syriac.first?.localizedFull("he"), "אגרת שאול אל הפיליפים א׳ 12–21")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-08-08")).first?.localizedShort("he"),
      "השנייה אל טימותיאוס ב׳")
    XCTAssertTrue(TodayInfoStore.readings(on: date("2031-08-01")).isEmpty)
  }

  func testReadingsFollowTheSelectedCalendarAndClearBetweenFiles() {
    select("roman")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-09-03")).map(\.short),
      ["1 Cor. 3", "Ps. 24", "Lk. 5"])

    select("roman1962")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-09-03")).map(\.short),
      ["1 Thess. 2", "Jn. 21"])

    select("ugcc")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-09-06")).map(\.short),
      ["2 Cor. 1", "Mt. 22"])

    select("syriac")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-09-03")).map(\.short),
      ["Phil. 1", "Lk. 21"])

    select("maronite")
    XCTAssertEqual(TodayInfoStore.readings(on: date("2026-09-06")).map(\.full),
                   ["Amos 5:21–24", "Romans 8:18–27", "Luke 18:9–14"])
    select("syriac")
    // A date outside the generated range must be empty, never the previous rite's readings.
    XCTAssertTrue(TodayInfoStore.readings(on: date("2031-08-01")).isEmpty)
  }

  func testMonthOutsideThePublishedListHasNoIntention() {
    XCTAssertNil(TodayInfoStore.intention(for: date("2031-05-01")))
  }
}
