//
//  PrayerRunProgressTests.swift
//  ProsaryTests
//

import XCTest
@testable import Prosary

final class PrayerRunProgressTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suiteName: String!
  private var store: PrayerRunProgressStore!

  override func setUp() {
    super.setUp()
    suiteName = "PrayerRunProgressTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    store = PrayerRunProgressStore(defaults: defaults)
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    store = nil
    defaults = nil
    suiteName = nil
    super.tearDown()
  }

  func testStoresStepLanguageAndLocalDateByRunIdentity() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
    let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 22))!

    store.save(
      runKey: "rosary:one", stepIndex: 17, languageCode: "arc",
      configurationSignature: "rosary|configured",
      today: date, calendar: calendar)

    XCTAssertEqual(
      store.progress(for: "rosary:one"),
      PrayerRunProgress(
        configurationSignature: "rosary|configured",
        stepIndex: 17,
        languageCode: "arc",
        savedLocalDate: "2026-09-03"))
    XCTAssertNil(store.progress(for: "rosary:two"))
  }

  func testStepZeroAndExplicitClearRemoveContinuation() {
    store.save(runKey: "custom:angelus::0", stepIndex: 4, languageCode: "en")
    store.save(runKey: "custom:angelus::0", stepIndex: 0, languageCode: "en")
    XCTAssertNil(store.progress(for: "custom:angelus::0"))

    store.save(runKey: "jesus:33", stepIndex: 8, languageCode: "he")
    store.clear(runKey: "jesus:33")
    XCTAssertNil(store.progress(for: "jesus:33"))
  }

  func testRosaryContinuationRequiresTheSameLocalCivilDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Jerusalem")!
    let saved = calendar.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23))!
    let nextDay = calendar.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 1))!
    let progress = PrayerRunProgress(stepIndex: 10, languageCode: "he", savedLocalDate: "2026-09-03")

    XCTAssertTrue(progress.canResume(
      stepCount: 70, today: saved, calendar: calendar, sameLocalDayOnly: true))
    XCTAssertFalse(progress.canResume(
      stepCount: 70, today: nextDay, calendar: calendar, sameLocalDayOnly: true))
    XCTAssertTrue(progress.canResume(
      stepCount: 70, today: nextDay, calendar: calendar, sameLocalDayOnly: false))
  }

  func testContinuationRejectsStartAndOutOfRangeSteps() {
    XCTAssertFalse(PrayerRunProgress(
      stepIndex: 0, languageCode: "en", savedLocalDate: "2026-09-03"
    ).canResume(stepCount: 4))
    XCTAssertFalse(PrayerRunProgress(
      stepIndex: 4, languageCode: "en", savedLocalDate: "2026-09-03"
    ).canResume(stepCount: 4))
    XCTAssertTrue(PrayerRunProgress(
      stepIndex: 3, languageCode: "en", savedLocalDate: "2026-09-03"
    ).canResume(stepCount: 4))
  }

  func testContinuationRequiresTheCurrentConfigurationSignature() throws {
    let progress = PrayerRunProgress(
      configurationSignature: "rosary|original",
      stepIndex: 3,
      languageCode: "he",
      savedLocalDate: "2026-09-03")

    XCTAssertTrue(progress.canResume(
      stepCount: 10, expectedConfigurationSignature: "rosary|original"))
    XCTAssertFalse(progress.canResume(
      stepCount: 10, expectedConfigurationSignature: "rosary|edited"))

    // Bookmarks written by 0.9 have no signature. They still decode safely, but are discarded
    // rather than risking a jump into a newly configured sequence.
    let oldJSON = Data(#"{"stepIndex":3,"languageCode":"he","savedLocalDate":"2026-09-03"}"#.utf8)
    let oldProgress = try JSONDecoder().decode(PrayerRunProgress.self, from: oldJSON)
    XCTAssertNil(oldProgress.configurationSignature)
    XCTAssertFalse(oldProgress.canResume(
      stepCount: 10, expectedConfigurationSignature: "rosary|current"))
  }

  func testConfigurationSignaturesTrackSequenceProducingOptions() {
    let original = RosaryOptions()
    var edited = original
    edited.includeOpeningFatimaPrayer = true
    XCTAssertNotEqual(
      PrayerRunSignature.rosary(original),
      PrayerRunSignature.rosary(edited))

    XCTAssertEqual(
      PrayerRunSignature.custom(
        "chaplet", effectiveVariantId: "long", dayIndex: 2, options: ["b": "2", "a": "1"]),
      PrayerRunSignature.custom(
        "chaplet", effectiveVariantId: "long", dayIndex: 2, options: ["a": "1", "b": "2"]))
    XCTAssertNotEqual(
      PrayerRunSignature.custom(
        "trisagion", effectiveVariantId: "byzantine", dayIndex: 0, options: [:]),
      PrayerRunSignature.custom(
        "trisagion", effectiveVariantId: "syriac", dayIndex: 0, options: [:]))
    XCTAssertNotEqual(
      PrayerRunSignature.jesus(.count(33)),
      PrayerRunSignature.jesus(.count(100)))
  }

  func testRunKeysSeparateRosaryPresetsAndCustomForms() {
    let first = Prayer(id: UUID(), kind: .rosary)
    let second = Prayer(id: UUID(), kind: .rosary)
    XCTAssertNotEqual(PrayerRunKey.rosary(first), PrayerRunKey.rosary(second))
    XCTAssertNotEqual(
      PrayerRunKey.custom("novena", variantId: "short", dayIndex: 2),
      PrayerRunKey.custom("novena", variantId: "long", dayIndex: 2))
    XCTAssertNotEqual(
      PrayerRunKey.custom("novena", variantId: "short", dayIndex: 2),
      PrayerRunKey.custom("novena", variantId: "short", dayIndex: 3))
  }

  func testLanguageSwitchOnlyKeepsPositionWhenTheEffectiveFormStaysTheSame() {
    XCTAssertEqual(CustomDevotionLanguageSwitch.indexAfterSwitch(
      currentIndex: 4,
      previousEffectiveVariantId: "byzantine",
      nextEffectiveVariantId: "byzantine",
      nextStepCount: 6), 4)
    XCTAssertEqual(CustomDevotionLanguageSwitch.indexAfterSwitch(
      currentIndex: 4,
      previousEffectiveVariantId: "byzantine",
      nextEffectiveVariantId: "syriac",
      nextStepCount: 4), 0)
  }

  func testMysteryNavigationTargetsAnnouncementsWithoutChangingStepSequence() {
    let firstMystery = Mystery(group: .joyful, order: 1, imageKey: "first")
    let secondMystery = Mystery(group: .joyful, order: 2, imageKey: "second")
    let ordinary = RosaryStep(title: "Prayer", subtitle: nil, body: "Body")
    let firstAnnouncement = RosaryStep(
      title: "Mystery", subtitle: nil, body: "Verse", mystery: firstMystery,
      isScripture: true, decadeIndex: 0)
    let firstPrayer = RosaryStep(
      title: "Prayer", subtitle: nil, body: "Body", mystery: firstMystery, decadeIndex: 0)
    let secondAnnouncement = RosaryStep(
      title: "Mystery", subtitle: nil, body: "Verse", mystery: secondMystery,
      isScripture: true, decadeIndex: 1)
    let secondPrayer = RosaryStep(
      title: "Prayer", subtitle: nil, body: "Body", mystery: secondMystery, decadeIndex: 1)
    let steps = [ordinary, firstAnnouncement, firstPrayer, firstPrayer, secondAnnouncement, secondPrayer,
                 ordinary]

    XCTAssertEqual(RosaryMysteryNavigation.announcementIndices(in: steps), [1, 4])
    XCTAssertEqual(RosaryMysteryNavigation.nextIndex(in: steps, from: 2), 4)
    XCTAssertNil(RosaryMysteryNavigation.previousIndex(in: steps, from: 3))
    XCTAssertEqual(RosaryMysteryNavigation.previousIndex(in: steps, from: 5), 1)
    XCTAssertEqual(RosaryMysteryNavigation.previousIndex(in: steps, from: 4), 1)
    XCTAssertNil(RosaryMysteryNavigation.previousIndex(in: steps, from: 1))
    XCTAssertNil(RosaryMysteryNavigation.nextIndex(in: steps, from: 4))
    XCTAssertEqual(RosaryMysteryNavigation.previousIndex(in: steps, from: 6), 4)
  }
}
