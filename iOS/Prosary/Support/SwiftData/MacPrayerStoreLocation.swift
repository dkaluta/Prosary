#if os(macOS)
import CoreData
import Darwin
import Foundation
import SQLite3

/// Keep unsigned Mac builds out of the shared SwiftData `default.store` namespace. Migration
/// copies a recognized legacy store before SwiftData opens it; the source is never removed.
@MainActor
enum MacPrayerStoreLocation {
  nonisolated static var defaultAppSupport: URL { URL.applicationSupportDirectory }

  enum PreparationError: LocalizedError {
    case unrecognizedStore, unreadableStore, migrationFailed, incompleteMigration

    var errorDescription: String? {
      switch self {
      case .unrecognizedStore:
        String(localized: "macStore.unrecognized", defaultValue: "The saved prayer library could not be identified. Its files have been kept unchanged.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .unreadableStore:
        String(localized: "macStore.unreadable", defaultValue: "The saved prayer library could not be opened. Its files have been kept unchanged.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .migrationFailed:
        String(localized: "macStore.migrationFailed", defaultValue: "The saved prayer library could not be moved to its new location. Its original files have been kept unchanged.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .incompleteMigration:
        String(localized: "macStore.incompleteMigration", defaultValue: "A previous library migration did not finish. Its files have been kept unchanged.", bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      }
    }
  }

  static func prepare(applicationSupport: URL = defaultAppSupport) throws -> URL {
    try prepare(applicationSupport: applicationSupport, copyingStore: copyStore)
  }

  /// The injectable copy operation keeps failure tests away from permissions or user stores.
  static func prepare(
    applicationSupport: URL,
    copyingStore: (_ source: URL, _ destination: URL) throws -> Void
  ) throws -> URL {
    let files = FileManager.default
    let appDirectory = applicationSupport.appendingPathComponent("com.dkaluta.prosary", isDirectory: true)
    let libraryDirectory = appDirectory.appendingPathComponent("PrayerLibrary", isDirectory: true)
    let destination = libraryDirectory.appendingPathComponent("Prosary.store")
    let legacy = applicationSupport.appendingPathComponent("default.store")

    if files.fileExists(atPath: destination.path) {
      try validateStore(at: destination)
      return destination
    }
    if files.fileExists(atPath: libraryDirectory.path) {
      guard (try? files.contentsOfDirectory(atPath: libraryDirectory.path).isEmpty) == true else {
        throw PreparationError.incompleteMigration
      }
    }
    guard files.fileExists(atPath: legacy.path) else {
      // Sidecars without their database are not a fresh installation. Do not hide an
      // interrupted or damaged legacy store behind a newly created empty library.
      let legacyArtifacts = ["default.store-wal", "default.store-shm", ".default_SUPPORT", "default.store_ckAssets"]
      guard !legacyArtifacts.contains(where: { files.fileExists(atPath: applicationSupport.appendingPathComponent($0).path) }) else {
        throw PreparationError.unreadableStore
      }
      try files.createDirectory(at: libraryDirectory, withIntermediateDirectories: true)
      return destination
    }

    try validateStore(at: legacy)
    try files.createDirectory(at: appDirectory, withIntermediateDirectories: true)
    let stagingDirectory = appDirectory.appendingPathComponent(".PrayerLibrary-migration-\(UUID().uuidString)", isDirectory: true)
    try files.createDirectory(at: stagingDirectory, withIntermediateDirectories: false)
    defer { try? files.removeItem(at: stagingDirectory) }
    let stagedStore = stagingDirectory.appendingPathComponent("Prosary.store")
    do {
      try copyingStore(legacy, stagedStore)
      try validateStore(at: stagedStore)
      // One same-volume directory rename adopts the database and all copied support files.
      // POSIX rename may replace an empty directory, but refuses a nonempty destination if
      // another process has already created its own library since the checks above.
      let result = stagingDirectory.path.withCString { source in
        libraryDirectory.path.withCString { destination in rename(source, destination) }
      }
      guard result == 0 else { throw PreparationError.migrationFailed }
      return destination
    } catch {
      throw PreparationError.migrationFailed
    }
  }

  private static func copyStore(from source: URL, to destination: URL) throws {
    // This store-level API understands WAL, file locks and external binary support files.
    // It does not need to attach/open the source using a new managed-object schema.
    let coordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
    try coordinator.replacePersistentStore(
      at: destination, destinationOptions: nil,
      withPersistentStoreFrom: source,
      sourceOptions: [NSReadOnlyPersistentStoreOption: true],
      ofType: NSSQLiteStoreType)
  }

  private static func validateStore(at url: URL) throws {
    let metadata: [String: Any]
    do {
      metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
        ofType: NSSQLiteStoreType, at: url,
        options: [NSReadOnlyPersistentStoreOption: true])
    } catch {
      throw PreparationError.unreadableStore
    }
    // CloudKit/Core Data internals are SQLite tables, not application model hash entries.
    // No unrelated entity is allowed into Prosary's model migration path.
    guard let hashes = metadata[NSStoreModelVersionHashesKey] as? [String: Data],
          Set(hashes.keys) == Set(["PresetEntry"]) else {
      throw PreparationError.unrecognizedStore
    }

    var database: OpaquePointer?
    guard sqlite3_open_v2(url.path, &database, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
          let database else {
      if let database { sqlite3_close(database) }
      throw PreparationError.unreadableStore
    }
    defer { sqlite3_close(database) }
    guard try firstText("PRAGMA quick_check", in: database) == "ok",
          try firstText("SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'ZPRESETENTRY'", in: database) == "ZPRESETENTRY" else {
      throw PreparationError.unreadableStore
    }
    // Preparing this query also catches a table with the right name but no preset identity.
    _ = try firstText("SELECT ZNAME FROM ZPRESETENTRY WHERE ZID IS NOT NULL AND ZKIND IS NOT NULL LIMIT 1", in: database)
  }

  private static func firstText(_ query: String, in database: OpaquePointer) throws -> String? {
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK else {
      throw PreparationError.unreadableStore
    }
    defer { sqlite3_finalize(statement) }
    switch sqlite3_step(statement) {
    case SQLITE_ROW:
      return sqlite3_column_text(statement, 0).map { String(cString: $0) }
    case SQLITE_DONE:
      return nil
    default:
      throw PreparationError.unreadableStore
    }
  }
}
#endif
