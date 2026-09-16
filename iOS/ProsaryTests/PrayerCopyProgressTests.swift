import XCTest
@testable import Prosary

@MainActor
final class PrayerCopyProgressTests: XCTestCase {
  func testNewCopyDoesNotInheritOriginalOrLegacyBookmark() throws {
    let suiteName = "PrayerCopyProgressTests.\(UUID().uuidString)"
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let originalID = UUID()
    let copyID = UUID()
    let original = PrayerRunKey.custom(
      PrayerCopyProgressIdentity.devotionID("novena", prayerID: originalID),
      variantId: nil, dayIndex: 0)
    let copy = PrayerRunKey.custom(
      PrayerCopyProgressIdentity.devotionID("novena", prayerID: copyID),
      variantId: nil, dayIndex: 0)
    let legacy = PrayerRunKey.custom("novena", variantId: nil, dayIndex: 0)
    let shared = PrayerRunProgressStore(defaults: defaults)
    shared.save(runKey: original, stepIndex: 3, languageCode: "en")
    shared.save(runKey: legacy, stepIndex: 6, languageCode: "he")

    let originalWindow = PrayerRunProgressStore(defaults: defaults, namespace: "original-window")
    let copyWindow = PrayerRunProgressStore(defaults: defaults, namespace: "copy-window")
    XCTAssertEqual(originalWindow.progress(for: original)?.stepIndex, 3)
    XCTAssertNil(copyWindow.progress(for: copy))

    copyWindow.save(runKey: copy, stepIndex: 2, languageCode: "fr")
    copyWindow.clear(runKey: copy)
    XCTAssertEqual(originalWindow.progress(for: original)?.stepIndex, 3)
    XCTAssertEqual(shared.progress(for: legacy)?.stepIndex, 6)
  }

  func testCopyIdentitySeparatesSeriesAndKeepsUnscopedSessionsCompatible() {
    let first = UUID()
    let second = UUID()
    let original = PrayerCopyProgressIdentity.devotionID("novena", prayerID: first)
    let copy = PrayerCopyProgressIdentity.devotionID("novena", prayerID: second)

    XCTAssertEqual(PrayerCopyProgressIdentity.devotionID("novena", prayerID: nil), "novena")
    XCTAssertEqual(original, PrayerCopyProgressIdentity.devotionID("novena", prayerID: first))
    XCTAssertNotEqual(original, copy)
    XCTAssertNotEqual(original, PrayerCopyProgressIdentity.devotionID("another-novena", prayerID: first))
    let runs = [original: MultiDayRun(devotionId: original, startedOn: Date())]
    XCTAssertNotNil(runs[original])
    XCTAssertNil(runs[copy])
  }

  func testSeriesNotificationKeepsBundleMetadataAndNamesTheSavedCopy() {
    let id = UUID()
    let copy = ReminderScheduler.seriesUserInfo(devotionId: "novena", dayIndex: 2, prayerID: id)
    XCTAssertEqual(copy["devotionId"] as? String, "novena")
    XCTAssertEqual(copy["dayIndex"] as? Int, 2)
    XCTAssertEqual(copy["prayerId"] as? String, id.uuidString)
    XCTAssertNil(ReminderScheduler.seriesUserInfo(devotionId: "novena", dayIndex: 2)["prayerId"])
  }

  func testSavedLanguageWinsWithoutLosingPositionOrConfigurationValidation() throws {
    let bookmark = PrayerRunProgress(
      configurationSignature: "original-form", stepIndex: 3,
      languageCode: "en", savedLocalDate: "2026-09-07")
    let updated = try XCTUnwrap(PrayerCopyProgressIdentity.continuation(bookmark, savedLanguageCode: "he"))
    XCTAssertEqual(updated.languageCode, "he")
    XCTAssertEqual(updated.stepIndex, 3)
    XCTAssertEqual(updated.savedLocalDate, bookmark.savedLocalDate)
    XCTAssertTrue(updated.canResume(stepCount: 10, expectedConfigurationSignature: "original-form"))
    XCTAssertFalse(updated.canResume(stepCount: 10, expectedConfigurationSignature: "different-form"))
    XCTAssertEqual(PrayerCopyProgressIdentity.continuation(bookmark, savedLanguageCode: nil), bookmark)
    XCTAssertEqual(PrayerCopyProgressIdentity.continuation(bookmark, savedLanguageCode: "",
                     preservesInheritedSession: true), bookmark)
    XCTAssertEqual(PrayerCopyProgressIdentity.continuation(bookmark, savedLanguageCode: "he",
                     preservesInheritedSession: true), updated)
    XCTAssertNil(PrayerCopyProgressIdentity.continuation(nil, savedLanguageCode: "he"))
  }
}
