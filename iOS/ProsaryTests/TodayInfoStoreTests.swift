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

  override func setUp() {
    super.setUp()
    originalCalendarId = UserDefaults.standard.string(forKey: TodayInfoStore.calendarDefaultsKey)
    UserDefaults.standard.removeObject(forKey: TodayInfoStore.calendarDefaultsKey)
  }

  override func tearDown() {
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

  func testTodayTranslationDefaultsFollowHebrewLanguageVariants() {
    XCTAssertTrue(TodayTranslationLanguage.defaultsToHebrew("he"))
    XCTAssertTrue(TodayTranslationLanguage.defaultsToHebrew("he-x-gamliel"))
    XCTAssertFalse(TodayTranslationLanguage.defaultsToHebrew("en"))
    XCTAssertFalse(TodayTranslationLanguage.defaultsToHebrew("arc"))
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
      ["lpj", "roman", "roman1962", "ugcc", "syriac"])
    XCTAssertEqual(TodayInfoStore.selectedCalendarId, "lpj")
  }

  /// Hebrew titles are translations on the one General Roman calendar rather than a second
  /// calendar with a different set of days.
  func testGeneralRomanCalendarLocalizesItsTitlesWhenAvailable() {
    select("roman")
    let bartholomew = TodayInfoStore.feast(on: date("2026-08-24"))
    XCTAssertEqual(bartholomew?.title, "Saint Bartholomew, Apostle")
    XCTAssertEqual(bartholomew?.localizedTitle("he"), "חג בר-תלמי השליח")
    XCTAssertEqual(bartholomew?.rank, "Feast")
    let sunday = TodayInfoStore.feast(on: date("2026-08-30"))
    XCTAssertEqual(sunday?.localizedTitle("he"), "יום א ה-22 של הזמן הרגיל")
    XCTAssertEqual(sunday?.rank, "Sunday")
    XCTAssertNotNil(TodayInfoStore.feast(on: date("2026-09-03")))
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
      TodayInfoStore.feast(on: date("2026-10-25"))?.title, "22nd Sunday after Pentecost")
  }

  /// The UGCC dataset is the diasporic (fully Gregorian) usage prayed in the Holy Land:
  /// Pascha falls with the Gregorian computus (April 5, 2026 — the same day as the Roman
  /// Easter), and a fixed Great Feast landing in Holy Week is joined, never displaced —
  /// in 2027 the Annunciation falls on Great and Holy Thursday.
  func testUkrainianCalendarPraysTheGregorianPascha() {
    select("ugcc")
    let pascha = TodayInfoStore.feast(on: date("2026-04-05"))
    XCTAssertEqual(pascha?.title, "The Resurrection of Our Lord — Holy Pascha")
    XCTAssertEqual(pascha?.rank, "Great Feast")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2026-10-01"))?.title,
      "The Protection of the Most Holy Theotokos (Pokrov)")
    XCTAssertEqual(
      TodayInfoStore.feast(on: date("2027-03-25"))?.title,
      "The Annunciation of the Most Holy Theotokos; Great and Holy Thursday")
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
    XCTAssertEqual(readings.last?.hebrew, "הבשורה על-פי לוקס ד׳ 16–30")
    XCTAssertEqual(readings.map { $0.localizedShort("he") }, [
      "הראשונה אל הקורינתים ב׳", "תהלים קי״ט", "לוקס ד׳",
    ])
    XCTAssertEqual(readings.map { $0.localizedShort("he-x-gamliel") }, [
      "הראשונה אל הקורינתים ב׳", "תהלים קי״ט", "לוקס ד׳",
    ], "Hebrew prayer-language variants inherit the authored Hebrew citations unchanged")
    XCTAssertEqual(readings.last?.localizedFull("he-x-gamliel"), "הבשורה על-פי לוקס ד׳ 16–30")

    let day = TodayInfoStore.liturgicalDayInfo(on: date("2026-08-31"))
    XCTAssertTrue(day.english.hasPrefix("Monday · Week "))
    XCTAssertTrue(day.english.hasSuffix(" of Ordinary Time"))
    XCTAssertTrue(day.hebrew.contains("בזמן הרגיל"))
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
      TodayInfoStore.readings(on: date("2026-09-03")).map(\.short),
      ["Gal. 3", "Mk. 6"])

    select("syriac")
    XCTAssertEqual(
      TodayInfoStore.readings(on: date("2026-09-03")).map(\.short),
      ["Phil. 1", "Lk. 21"])

    // Syriac's current rolling table has no August 1 entry. It must be empty, not the Roman
    // values loaded at the start of this test.
    XCTAssertTrue(TodayInfoStore.readings(on: date("2026-08-01")).isEmpty)
  }

  func testMonthOutsideThePublishedListHasNoIntention() {
    XCTAssertNil(TodayInfoStore.intention(for: date("2031-05-01")))
  }
}
