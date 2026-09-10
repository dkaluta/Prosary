import XCTest
@testable import Prosary

@MainActor
final class WidgetIntegrationTests: XCTestCase {
  private var defaults: UserDefaults!
  private var suite: String!

  override func setUp() {
    super.setUp()
    suite = "Prosary.WidgetTests.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suite)!
  }

  override func tearDown() {
    defaults.removePersistentDomain(forName: suite)
    defaults = nil
    super.tearDown()
  }

  func testWidgetLinksOnlyAcceptKnownDestinationsAndValidSavedIDs() {
    let id = UUID()
    XCTAssertEqual(ProsaryWidgetLink(url: URL(string: "prosary://today")!), .today)
    XCTAssertEqual(ProsaryWidgetLink(url: URL(string: "prosary://library")!), .library)
    XCTAssertEqual(ProsaryWidgetLink(url: URL(string: "prosary://rosary/")!), .rosary)
    XCTAssertEqual(ProsaryWidgetLink(url: URL(string: "prosary://prayer/\(id)")!), .prayer(id))
    for invalid in ["https://today", "prosary://delete", "prosary://prayer/nope",
                    "prosary://prayer/\(id)/extra", "prosary://today/extra",
                    "prosary://today?date=2020-01-01", "prosary://user@today", "prosary://today:12"] {
      XCTAssertNil(ProsaryWidgetLink(url: URL(string: invalid)!), invalid)
    }
  }

  func testRosaryShortcutKeepsPreferredOptionsAndLeavesSavedCopyAlone() {
    var saved = Prayer(name: "Morning", isDefault: true, languageCode: "he")
    saved.rosary.mysterySelectionMode = .specific
    saved.rosary.includeFatimaPrayer = false
    let quick = ProsaryWidgetLink.rosaryPrayer(from: saved)
    XCTAssertNotEqual(quick.id, saved.id)
    XCTAssertEqual(quick.rosary.mysterySelectionMode, .todaysMysteries)
    XCTAssertFalse(quick.rosary.includeFatimaPrayer)
    XCTAssertEqual(quick.languageCode, "he")
    XCTAssertFalse(quick.isDefault)
    XCTAssertTrue(quick.reminders.isEmpty)
    XCTAssertEqual(saved.rosary.mysterySelectionMode, .specific)
  }

  func testSnapshotFollowsInterfaceAndSettingsAndRemovesDeletedPrayers() {
    defaults.set("ugcc", forKey: "feastCalendarId")
    defaults.set("gregorian", forKey: "easternPaschaStyle")
    defaults.set(false, forKey: "showTodayFeast")
    defaults.set(true, forKey: "showTodayTorahPortion")
    defaults.set("he", forKey: "todayLanguageCode") // Retired override must stay ignored.
    let engine = PrayerEngine(calendar: MockLiturgicalCalendar())
    let prayer = Prayer(name: "Saved")
    let snapshot = WidgetSnapshotPublisher.snapshot(prayers: [prayer], defaults: defaults,
                                                   engine: engine, language: "ar")
    XCTAssertEqual(snapshot.today.calendarID, "ugcc")
    XCTAssertEqual(snapshot.today.easternPaschaStyle, "gregorian")
    XCTAssertFalse(snapshot.today.showFeast)
    XCTAssertTrue(snapshot.today.showIntention)
    XCTAssertTrue(snapshot.today.showTorah)
    XCTAssertTrue(snapshot.today.isRightToLeft)
    XCTAssertEqual(snapshot.today.languageCode, "ar")
    XCTAssertTrue(snapshot.save(to: defaults))
    XCTAssertEqual(ProsaryWidgetSnapshot.load(defaults: defaults), snapshot)
    let deleted = WidgetSnapshotPublisher.snapshot(prayers: [], defaults: defaults, engine: engine)
    XCTAssertTrue(deleted.save(to: defaults))
    XCTAssertTrue(ProsaryWidgetSnapshot.load(defaults: defaults).prayers.isEmpty)
  }

  func testRosaryProjectionValidatesSignatureAndExpiresOnNextLocalDay() {
    let now = Date()
    let prayer = Prayer(name: "Saved", languageCode: "en")
    let store = PrayerRunProgressStore(defaults: defaults)
    let engine = PrayerEngine(calendar: MockLiturgicalCalendar())
    store.save(runKey: PrayerRunKey.rosary(prayer), stepIndex: 3, languageCode: "en",
               configurationSignature: PrayerRunSignature.rosary(prayer.rosary), today: now)
    let row = WidgetPrayerProjection.make(prayer, progressStore: store, engine: engine, now: now)
    XCTAssertEqual(row.stepIndex, 3)
    XCTAssertGreaterThan(row.stepCount ?? 0, 3)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    XCTAssertFalse(row.hasProgress(on: tomorrow))
    XCTAssertNil(WidgetPrayerProjection.make(prayer, progressStore: store, engine: engine, now: tomorrow).stepIndex)
    var changed = prayer
    changed.rosary.includeOpeningPrayers.toggle()
    XCTAssertNil(WidgetPrayerProjection.make(changed, progressStore: store, engine: engine, now: now).stepIndex)
    // Widget reads never clear or rewrite the prayer flow's bookmark.
    XCTAssertEqual(store.progress(for: PrayerRunKey.rosary(prayer))?.stepIndex, 3)
  }

  func testJesusPrayerProgressSurvivesMidnightAndRejectsFinishedCounts() {
    let now = Date()
    var prayer = Prayer(name: "Jesus Prayer", kind: .jesusPrayer)
    prayer.jesusPrayer.target = .count(100)
    let store = PrayerRunProgressStore(defaults: defaults)
    let engine = PrayerEngine(calendar: MockLiturgicalCalendar())
    store.save(runKey: PrayerRunKey.jesus(prayer, target: .count(100)), stepIndex: 25,
               languageCode: "en", configurationSignature: PrayerRunSignature.jesus(.count(100)), today: now)
    let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
    let row = WidgetPrayerProjection.make(prayer, progressStore: store, engine: engine, now: tomorrow)
    XCTAssertEqual(row.stepIndex, 25)
    XCTAssertEqual(row.fractionCompleted(on: tomorrow), 0.26)
    store.save(runKey: PrayerRunKey.jesus(prayer, target: .count(100)), stepIndex: 100,
               languageCode: "en", configurationSignature: PrayerRunSignature.jesus(.count(100)), today: now)
    XCTAssertNil(WidgetPrayerProjection.make(prayer, progressStore: store, engine: engine, now: now).stepIndex)
  }

  func testUnboundedPrayerHasCountWithoutInventedPercentage() {
    var prayer = Prayer(name: "Quiet prayer", kind: .jesusPrayer)
    prayer.jesusPrayer.target = .unbounded
    let store = PrayerRunProgressStore(defaults: defaults)
    store.save(runKey: PrayerRunKey.jesus(prayer, target: .unbounded), stepIndex: 12,
               languageCode: "en", configurationSignature: PrayerRunSignature.jesus(.unbounded))
    let row = WidgetPrayerProjection.make(prayer, progressStore: store,
                                         engine: PrayerEngine(calendar: MockLiturgicalCalendar()))
    XCTAssertEqual(row.stepIndex, 12)
    XCTAssertNil(row.stepCount)
    XCTAssertNil(row.fractionCompleted(on: Date()))
  }
}
