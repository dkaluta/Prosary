#if os(macOS)
import CoreData
import Foundation
import SQLite3
import SwiftData
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerStoreLocationTests: XCTestCase {
  func testFreshLibraryUsesItsOwnDirectoryAndDoesNotCreateALegacyStore() throws {
    try withTemporarySupport { support in
      let expected = support.appendingPathComponent("com.dkaluta.prosary/PrayerLibrary/Prosary.store")
      XCTAssertEqual(try MacPrayerStoreLocation.prepare(applicationSupport: support), expected)
      XCTAssertEqual(try MacPrayerStoreLocation.prepare(applicationSupport: support), expected)
      XCTAssertTrue(FileManager.default.fileExists(atPath: expected.deletingLastPathComponent().path))
      XCTAssertFalse(FileManager.default.fileExists(atPath: expected.path))
      XCTAssertFalse(FileManager.default.fileExists(atPath: support.appendingPathComponent("default.store").path))
    }
  }

  func testWALBackedLegacyCopyRetainsSettingsRemindersAndItsSource() throws {
    try withTemporarySupport { support in
      let legacy = support.appendingPathComponent("default.store")
      let source = try makeContainer(at: legacy)
      var prayer = Prayer(name: "My Rosary", kind: .rosary, isDefault: true, languageCode: "he")
      prayer.rosary.includeOpeningFatimaPrayer = true
      prayer.rosary.includeClosingIntentions = true
      prayer.reminders = [PrayerReminder(hour: 18, minute: 30)]
      source.mainContext.insert(PresetEntry(prayer: prayer))
      try source.mainContext.save()
      let actualWAL = URL(fileURLWithPath: legacy.path + "-wal")
      let size = try FileManager.default.attributesOfItem(atPath: actualWAL.path)[.size] as? NSNumber
      XCTAssertGreaterThan(try XCTUnwrap(size).intValue, 32, "The migration must include outstanding WAL frames")

      let destination = try MacPrayerStoreLocation.prepare(applicationSupport: support)
      let migrated = try makeContainer(at: destination)
      let copied = try XCTUnwrap(migrated.mainContext.fetch(FetchDescriptor<PresetEntry>()).first).toPrayer()
      XCTAssertEqual(copied, prayer)
      XCTAssertEqual(try source.mainContext.fetch(FetchDescriptor<PresetEntry>()).first?.toPrayer(), prayer)
      XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
      XCTAssertEqual(try MacPrayerStoreLocation.prepare(applicationSupport: support), destination)
      XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: destination.deletingLastPathComponent().deletingLastPathComponent().path)
        .contains(where: { $0.hasPrefix(".PrayerLibrary-migration-") }))
    }
  }

  func testValidatedNamedStoreWinsEvenWhenLegacyBelongsToAnotherApp() throws {
    try withTemporarySupport { support in
      let destination = try MacPrayerStoreLocation.prepare(applicationSupport: support)
      let current = try makeContainer(at: destination)
      let prayer = Prayer(name: "Current library", kind: .jesusPrayer)
      current.mainContext.insert(PresetEntry(prayer: prayer))
      try current.mainContext.save()
      let legacy = support.appendingPathComponent("default.store")
      try makeForeignStore(at: legacy)
      let before = try Data(contentsOf: legacy)

      XCTAssertEqual(try MacPrayerStoreLocation.prepare(applicationSupport: support), destination)

      XCTAssertEqual(try current.mainContext.fetch(FetchDescriptor<PresetEntry>()).first?.toPrayer(), prayer)
      XCTAssertEqual(try Data(contentsOf: legacy), before)
    }
  }

  func testForeignLegacyStoreIsRejectedWithoutChangingItOrCreatingANamedStore() throws {
    try withTemporarySupport { support in
      let legacy = support.appendingPathComponent("default.store")
      try makeForeignStore(at: legacy)
      let before = try Data(contentsOf: legacy)

      XCTAssertThrowsError(try MacPrayerStoreLocation.prepare(applicationSupport: support)) { error in
        guard case MacPrayerStoreLocation.PreparationError.unrecognizedStore = error else {
          return XCTFail("Unexpected error: \(error)")
        }
      }

      XCTAssertEqual(try Data(contentsOf: legacy), before)
      XCTAssertFalse(FileManager.default.fileExists(atPath: namedStore(in: support).path))
    }
  }

  func testForeignOrCorruptNamedStoreIsNeverReplacedFromLegacy() throws {
    for foreign in [true, false] {
      try withTemporarySupport { support in
        let destination = try MacPrayerStoreLocation.prepare(applicationSupport: support)
        if foreign { try makeForeignStore(at: destination) }
        else { try Data("Unrecoverable store fixture".utf8).write(to: destination) }
        let before = try Data(contentsOf: destination)
        let source = try makeContainer(at: support.appendingPathComponent("default.store"))
        source.mainContext.insert(PresetEntry(prayer: Prayer(name: "Legacy must not replace current")))
        try source.mainContext.save()

        XCTAssertThrowsError(try MacPrayerStoreLocation.prepare(applicationSupport: support))

        XCTAssertEqual(try Data(contentsOf: destination), before)
      }
    }
  }

  func testFailedOrInvalidSnapshotNeverBecomesTheNamedStore() throws {
    struct CopyFailure: Error {}
    for throwsDuringCopy in [true, false] {
      try withTemporarySupport { support in
        let legacy = support.appendingPathComponent("default.store")
        let source = try makeContainer(at: legacy)
        let prayer = Prayer(name: "Keep this source")
        source.mainContext.insert(PresetEntry(prayer: prayer))
        try source.mainContext.save()

        XCTAssertThrowsError(try MacPrayerStoreLocation.prepare(applicationSupport: support) { _, destination in
          try Data("Partial copy".utf8).write(to: destination)
          if throwsDuringCopy { throw CopyFailure() }
        }) { error in
          guard case MacPrayerStoreLocation.PreparationError.migrationFailed = error else {
            return XCTFail("Unexpected error: \(error)")
          }
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: namedStore(in: support).path))
        XCTAssertEqual(try source.mainContext.fetch(FetchDescriptor<PresetEntry>()).first?.toPrayer(), prayer)
        XCTAssertTrue(FileManager.default.fileExists(atPath: legacy.path))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: support.appendingPathComponent("com.dkaluta.prosary").path), [])
      }
    }
  }

  func testOrphanedLegacyJournalDoesNotBecomeAnEmptyLibrary() throws {
    try withTemporarySupport { support in
      let journal = support.appendingPathComponent("default.store-wal")
      let bytes = Data("Retain for recovery".utf8)
      try bytes.write(to: journal)

      XCTAssertThrowsError(try MacPrayerStoreLocation.prepare(applicationSupport: support))

      XCTAssertEqual(try Data(contentsOf: journal), bytes)
      XCTAssertFalse(FileManager.default.fileExists(atPath: namedStore(in: support).path))
    }
  }

  func testLegacyPresetMetadataWithMissingPresetTableIsRejectedWithoutReset() throws {
    try withTemporarySupport { support in
      let legacy = support.appendingPathComponent("default.store")
      try autoreleasepool {
        let source = try makeContainer(at: legacy)
        source.mainContext.insert(PresetEntry(prayer: Prayer(name: "Lost-table fixture")))
        try source.mainContext.save()
      }
      // Only this disposable fixture is opened for writing. Retain Core Data metadata
      // while reproducing the exact missing-ZPRESETENTRY condition seen in the old app.
      var database: OpaquePointer?
      guard sqlite3_open_v2(legacy.path, &database, SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
            let database else {
        if let database { sqlite3_close(database) }
        throw CocoaError(.fileWriteUnknown)
      }
      let result = sqlite3_exec(database, "DROP TABLE ZPRESETENTRY", nil, nil, nil)
      sqlite3_close(database)
      guard result == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
      let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
        ofType: NSSQLiteStoreType, at: legacy, options: [NSReadOnlyPersistentStoreOption: true])
      let hashes = try XCTUnwrap(metadata[NSStoreModelVersionHashesKey] as? [String: Data])
      XCTAssertEqual(Set(hashes.keys), Set(["PresetEntry"]))
      let before = try Data(contentsOf: legacy)

      XCTAssertThrowsError(try MacPrayerStoreLocation.prepare(applicationSupport: support)) { error in
        guard case MacPrayerStoreLocation.PreparationError.unreadableStore = error else {
          return XCTFail("Unexpected error: \(error)")
        }
      }

      XCTAssertEqual(try Data(contentsOf: legacy), before)
      XCTAssertFalse(FileManager.default.fileExists(atPath: namedStore(in: support).path))
    }
  }

  private func namedStore(in support: URL) -> URL {
    support.appendingPathComponent("com.dkaluta.prosary/PrayerLibrary/Prosary.store")
  }

  private func makeContainer(at url: URL) throws -> ModelContainer {
    try ModelContainer(for: PresetEntry.self,
      configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
  }

  private func makeForeignStore(at url: URL) throws {
    let model = NSManagedObjectModel()
    let entity = NSEntityDescription()
    entity.name = "UnrelatedRecord"
    entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
    let attribute = NSAttributeDescription()
    attribute.name = "name"
    attribute.attributeType = .stringAttributeType
    entity.properties = [attribute]
    model.entities = [entity]
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
    let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
    try coordinator.remove(store)
  }

  private func withTemporarySupport(_ operation: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MacPrayerStoreLocationTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try operation(directory)
  }
}
#endif
