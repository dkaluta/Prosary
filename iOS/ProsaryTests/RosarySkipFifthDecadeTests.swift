import XCTest
@testable import Prosary

@MainActor
final class RosarySkipFifthDecadeTests: XCTestCase {
  func testChooseOnLaunchIsBlankUntilAllFourSetsCanBeChosenWithoutSavingThem() throws {
    let saved = RosaryOptions(mysterySelectionMode: .chooseOnLaunch, specificMysteryCount: 3)
    let engine = PrayerEngine()
    XCTAssertTrue(engine.buildSteps(for: Prayer(rosary: saved)).isEmpty)
    XCTAssertTrue(engine.resolveMysteryGroups(rosary: saved).isEmpty)
    for group in MysteryGroup.allCases {
      for order in 1...5 {
        let selected = try XCTUnwrap(saved.navigationOptions(group: group.rawValue, order: order))
        XCTAssertEqual(selected.mysterySelectionMode, .singleMystery)
        let steps = engine.buildSteps(for: Prayer(languageCode: "en", rosary: selected))
        let starts = RosaryMysteryNavigation.announcementIndices(in: steps)
        XCTAssertEqual(starts.compactMap { steps[$0].mystery?.order }, Array(order...min(5, order + 2)))
        XCTAssertEqual(steps.first?.prayerKey, "signumCrucis")
      }
    }
    XCTAssertEqual(saved.mysterySelectionMode, .chooseOnLaunch)
    XCTAssertEqual(saved.specificMysteryGroup, .joyful)
    XCTAssertNil(saved.navigationOptions(group: "unknown", order: 1))
    XCTAssertEqual(saved.navigationOptions(group: "joyful", order: nil)?.mysterySelectionMode, .specific)
    XCTAssertNil(saved.navigationOptions(group: "joyful", order: 6))
    let encoded = try JSONEncoder().encode(saved)
    XCTAssertEqual(try JSONDecoder().decode(RosaryOptions.self, from: encoded), saved)
    XCTAssertEqual(PresetEntry(prayer: Prayer(rosary: saved)).toPrayer().rosary, saved)
  }

  func testEntireSetChoiceBuildsAllFiveAndResumesWithoutSavingTheChoice() throws {
    let engine = PrayerEngine()
    for mode in [MysterySelectionMode.chooseOnLaunch, .singleMystery] {
      let original = RosaryOptions(mysterySelectionMode: mode, specificMysteryCount: 2)
      for group in MysteryGroup.allCases {
        let options = try XCTUnwrap(original.navigationOptions(group: group.rawValue, order: nil))
        let steps = engine.buildSteps(for: Prayer(languageCode: "en", rosary: options))
        let starts = RosaryMysteryNavigation.announcementIndices(in: steps)
        XCTAssertEqual(starts.compactMap { steps[$0].mystery?.order }, [1, 2, 3, 4, 5])
        XCTAssertEqual(Set(steps.compactMap { $0.mystery?.group }), [group])
        XCTAssertEqual(steps.first?.prayerKey, "signumCrucis")
        let signature = PrayerRunSignature.rosary(original, navigationGroup: group.rawValue)
        let progress = PrayerRunProgress(configurationSignature: signature, stepIndex: 8, languageCode: "en",
          savedLocalDate: PrayerRunProgress.localDateString(for: Date()), rosaryNavigationGroup: group.rawValue)
        let decoded = try JSONDecoder().decode(PrayerRunProgress.self, from: JSONEncoder().encode(progress))
        let restored = try XCTUnwrap(original.navigationOptions(group: decoded.rosaryNavigationGroup, order: decoded.rosaryNavigationOrder))
        XCTAssertEqual(restored.mysterySelectionMode, .specific)
        XCTAssertNil(decoded.rosaryNavigationOrder)
        XCTAssertTrue(decoded.canResume(stepCount: steps.count, sameLocalDayOnly: true,
          expectedConfigurationSignature: PrayerRunSignature.rosary(original, navigationGroup: decoded.rosaryNavigationGroup)))
        XCTAssertNotEqual(signature, PrayerRunSignature.rosary(original, navigationGroup: group.rawValue, navigationOrder: 1))
      }
      XCTAssertEqual(original.mysterySelectionMode, mode)
      XCTAssertEqual(original.specificMysteryCount, 2)
    }
  }

  func testChosenLaunchBookmarkReconstructsTheRangeAndRejectsChangedCount() throws {
    let original = RosaryOptions(mysterySelectionMode: .chooseOnLaunch, specificMysteryCount: 2)
    let group = "sorrowful", order = 4
    let signature = PrayerRunSignature.rosary(original, navigationGroup: group, navigationOrder: order)
    let progress = PrayerRunProgress(configurationSignature: signature, stepIndex: 8, languageCode: "he",
      savedLocalDate: PrayerRunProgress.localDateString(for: Date()), rosaryNavigationGroup: group, rosaryNavigationOrder: order)
    let restored = try JSONDecoder().decode(PrayerRunProgress.self, from: JSONEncoder().encode(progress))
    let copyContinuation = try XCTUnwrap(PrayerCopyProgressIdentity.continuation(restored, savedLanguageCode: "uk"))
    XCTAssertEqual(copyContinuation.rosaryNavigationGroup, group)
    XCTAssertEqual(copyContinuation.rosaryNavigationOrder, order)
    let options = try XCTUnwrap(original.navigationOptions(group: restored.rosaryNavigationGroup, order: restored.rosaryNavigationOrder))
    let steps = PrayerEngine().buildSteps(for: Prayer(languageCode: restored.languageCode, rosary: options))
    XCTAssertEqual(Set(steps.compactMap { $0.mystery?.order }), [4, 5])
    XCTAssertTrue(restored.canResume(stepCount: steps.count, sameLocalDayOnly: true, expectedConfigurationSignature: signature))
    var changed = original
    changed.specificMysteryCount = 1
    XCTAssertFalse(restored.canResume(stepCount: steps.count,
      expectedConfigurationSignature: PrayerRunSignature.rosary(changed, navigationGroup: group, navigationOrder: order)))
    let legacy = try JSONDecoder().decode(PrayerRunProgress.self,
      from: Data("{\"stepIndex\":8,\"languageCode\":\"en\",\"savedLocalDate\":\"2026-10-07\"}".utf8))
    XCTAssertNil(legacy.rosaryNavigationGroup)
    XCTAssertNil(legacy.rosaryNavigationOrder)
  }
  func testSelectedMysteriesStaySequentialAndNeverWrap() {
    let engine = PrayerEngine()
    for start in 1...5 {
      for requested in 1...5 {
        for presenter in [false, true] {
          let options = RosaryOptions(mysterySelectionMode: .singleMystery,
            specificMysteryGroup: .sorrowful, specificMysteryOrder: start,
            specificMysteryCount: requested, presenterMode: presenter)
          let steps = engine.buildSteps(for: Prayer(languageCode: "en", rosary: options))
          let starts = RosaryMysteryNavigation.announcementIndices(in: steps)
          XCTAssertEqual(starts.compactMap { steps[$0].mystery?.order }, Array(start...min(5, start + requested - 1)))
          XCTAssertEqual(Set(steps.compactMap { $0.mystery?.group }), [.sorrowful])
          XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), Set(0..<starts.count))
        }
      }
    }
    let malformed = RosaryOptions(mysterySelectionMode: .singleMystery,
      specificMysteryOrder: 999, specificMysteryCount: -2)
    XCTAssertEqual(malformed.selectedMysteryIndices, [4])
    XCTAssertFalse(engine.buildSteps(for: Prayer(rosary: malformed)).isEmpty)
  }

  func testSelectionDefaultsPersistenceAndBookmarkIdentity() throws {
    let legacy = try JSONDecoder().decode(RosaryOptions.self, from: Data("{}".utf8))
    XCTAssertEqual(legacy.specificMysteryCount, 1)
    XCTAssertFalse(legacy.useTraditionalMysteries)
    let options = RosaryOptions(mysterySelectionMode: .singleMystery,
      specificMysteryOrder: 3, specificMysteryCount: 3, useTraditionalMysteries: true)
    XCTAssertEqual(try JSONDecoder().decode(RosaryOptions.self, from: JSONEncoder().encode(options)), options)
    let entry = PresetEntry(prayer: Prayer(rosary: options))
    XCTAssertEqual(entry.toPrayer().rosary, options)
    var changed = options
    changed.specificMysteryCount = 1
    XCTAssertNotEqual(PrayerRunSignature.rosary(options), PrayerRunSignature.rosary(changed))
    changed.mysterySelectionMode = .todaysMysteries
    let traditional = PrayerRunSignature.rosary(changed)
    changed.useTraditionalMysteries = false
    XCTAssertNotEqual(PrayerRunSignature.rosary(changed), traditional)
  }

  func testPrayerPickerGroupsEveryAnnouncementOnce() {
    let engine = PrayerEngine()
    for (mode, expected) in [(MysterySelectionMode.fifteenMystery, 3), (.twentyMystery, 4)] {
      let steps = engine.buildSteps(for: Prayer(rosary: RosaryOptions(mysterySelectionMode: mode)))
      let starts = RosaryMysteryNavigation.announcementIndices(in: steps)
      let groups = Dictionary(grouping: starts) { steps[$0].mystery!.group }
      XCTAssertEqual(groups.count, expected)
      XCTAssertTrue(groups.values.allSatisfy { $0.count == 5 })
      XCTAssertEqual(groups[.luminous]?.count, mode == .twentyMystery ? 5 : nil)
    }
  }

  func testAnOlderInstalledRosaryCannotRestoreTheRetiredControl() {
    let old = CustomDevotionOption(key: "skipFifthDecade", kind: .toggle, name: "Legacy skip", defaultValue: "true")
    let kept = CustomDevotionOption(key: "fatimaPrayer", kind: .toggle, name: "Fatima", defaultValue: "true")
    XCTAssertEqual(CustomDevotionOption.normalizedForEditing([old, kept], bundleId: "rosary").map(\.key), ["fatimaPrayer"])
    XCTAssertEqual(CustomDevotionOption.normalizedForEditing([old, kept], bundleId: "anotherRosary").map(\.key), ["skipFifthDecade", "fatimaPrayer"])
    let saved = ["skipFifthDecade": "true", "fatimaPrayer": "true"]
    XCTAssertEqual(RosaryOptions.normalizedCustomOptions(saved, bundleId: "rosary"), ["fatimaPrayer": "true"])
    XCTAssertEqual(RosaryOptions.normalizedCustomOptions(saved, bundleId: "anotherRosary"), saved)
  }

  func testRetiredSkipPreferenceKeepsEveryDecadeAndFinalDecadeCanJumpToClosing() {
    let engine = PrayerEngine(calendar: StubLiturgicalCalendar())
    for (mode, decades) in [(MysterySelectionMode.specific, 5), (.todaysMysteries, 5), (.fifteenMystery, 15), (.twentyMystery, 20)] {
      for presenter in [false, true] {
        var prayer = Prayer(languageCode: "en", rosary: RosaryOptions(mysterySelectionMode: mode,
          includeClosingIntentions: true, includeStMichaelPrayer: true, presenterMode: presenter))
        let original = engine.buildSteps(for: prayer)
        prayer.rosary.skipFifthDecade = true
        let steps = engine.buildSteps(for: prayer)
        XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), Set(0..<decades))
        XCTAssertTrue(steps.contains { $0.mystery?.order == 5 })
        XCTAssertEqual(steps.filter { $0.mystery != nil && $0.isScripture }.count, decades)
        XCTAssertEqual(steps.map { "\($0.title)|\($0.body)" }, original.map { "\($0.title)|\($0.body)" })
        let lastDecadeEnd = steps.lastIndex { $0.decadeIndex != nil }!
        let closing = lastDecadeEnd + 1
        for index in steps.indices where steps[index].decadeIndex == decades - 1 {
          XCTAssertEqual(RosaryMysteryNavigation.nextIndex(in: steps, from: index), closing)
        }
        XCTAssertNil(RosaryMysteryNavigation.nextIndex(in: steps, from: closing))
        XCTAssertEqual(RosaryMysteryNavigation.previousIndex(in: steps, from: closing),
                       steps.firstIndex { $0.decadeIndex == decades - 1 })
      }
    }
  }

  func testExplicitFifthSingleMysteryRemainsAvailable() {
    let prayer = Prayer(languageCode: "en", rosary: RosaryOptions(mysterySelectionMode: .singleMystery,
      specificMysteryOrder: 5, skipFifthDecade: true))
    let steps = PrayerEngine().buildSteps(for: prayer)
    XCTAssertEqual(Set(steps.compactMap(\.decadeIndex)), [0])
    XCTAssertEqual(Set(steps.compactMap { $0.mystery?.order }), [5])
  }

  func testPersistenceAndLegacyDecodingKeepRetiredFieldWithoutChangingRunIdentity() throws {
    var prayer = Prayer(rosary: RosaryOptions(skipFifthDecade: true))
    let entry = PresetEntry(prayer: prayer)
    XCTAssertTrue(entry.toPrayer().rosary.skipFifthDecade)
    let signature = PrayerRunSignature.rosary(prayer.rosary)
    let encoded = try JSONEncoder().encode(prayer.rosary)
    XCTAssertTrue(try JSONDecoder().decode(RosaryOptions.self, from: encoded).skipFifthDecade)
    var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    legacy.removeValue(forKey: "skipFifthDecade")
    let restored = try JSONDecoder().decode(RosaryOptions.self, from: JSONSerialization.data(withJSONObject: legacy))
    XCTAssertFalse(restored.skipFifthDecade)
    XCTAssertEqual(PrayerRunSignature.rosary(restored), signature)
    XCTAssertFalse(signature.contains("skip-fifth"))
    prayer.rosary.skipFifthDecade = false
    entry.update(from: prayer)
    XCTAssertFalse(entry.toPrayer().rosary.skipFifthDecade)
    prayer.rosary.mysterySelectionMode = .singleMystery
    let singleSignature = PrayerRunSignature.rosary(prayer.rosary)
    prayer.rosary.skipFifthDecade = true
    XCTAssertEqual(PrayerRunSignature.rosary(prayer.rosary), singleSignature)
  }
}
