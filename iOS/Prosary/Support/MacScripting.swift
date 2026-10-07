#if os(macOS)
  import AppKit
  import Observation
  #if DEBUG
    import SwiftData
  #endif

  enum MacScriptingError: Error, Equatable, LocalizedError {
    case invalidReference, prayerNotFound, ambiguousName

    var errorNumber: Int {
      switch self {
      case .invalidReference: -1700
      case .prayerNotFound: -1728
      case .ambiguousName: -10000
      }
    }

    var errorDescription: String? {
      switch self {
      case .invalidReference:
        String(
          localized: "macScripting.invalidReference",
          defaultValue: "Provide a saved prayer's UUID or exact name.",
          bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .prayerNotFound:
        String(
          localized: "macScripting.prayerNotFound",
          defaultValue:
            "This saved prayer is not available. Use list prayers to find its current UUID.",
          bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      case .ambiguousName:
        String(
          localized: "macScripting.ambiguousName",
          defaultValue: "More than one saved prayer has this name. Open the prayer by its UUID.",
          bundle: UILanguage.persistedBundle, locale: UILanguage.persistedLocale)
      }
    }
  }

  enum MacScriptingLibrary {
    #if DEBUG
      /// A standalone scripting smoke uses the same isolated storage as UI tests. Release builds
      /// never decode these fixtures, and a normal launch cannot seed a persistent library.
      static func seedTestFixtures(in context: ModelContext) {
        struct Fixture: Decodable {
          let id: UUID
          let name: String
          let kind: PrayerKind
          let languageCode: String
          let customDevotionId: String?
        }
        guard ProsaryRuntimeEnvironment.isTesting,
          let text = ProcessInfo.processInfo.environment["PROSARY_SCRIPTING_TEST_FIXTURES"],
          let data = text.data(using: .utf8),
          let fixtures = try? JSONDecoder().decode([Fixture].self, from: data)
        else { return }
        for fixture in fixtures {
          context.insert(
            PresetEntry(
              prayer: Prayer(
                id: fixture.id, name: fixture.name,
                kind: fixture.kind, languageCode: fixture.languageCode,
                customDevotionId: fixture.customDevotionId)))
        }
        try? context.save()
      }
    #endif

    static func prayers(in store: any PresetStore) async throws -> [Prayer] {
      try await store.all().sorted {
        let comparison = $0.name.localizedStandardCompare($1.name)
        return comparison == .orderedSame
          ? $0.id.uuidString < $1.id.uuidString : comparison == .orderedAscending
      }
    }

    static func resolve(_ reference: String, in store: any PresetStore) async throws -> Prayer {
      guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw MacScriptingError.invalidReference
      }
      if let id = UUID(uuidString: reference) {
        guard let prayer = try await store.get(id: id) else {
          throw MacScriptingError.prayerNotFound
        }
        return prayer
      }
      let matches = try await store.all().filter { $0.name == reference }
      guard let prayer = matches.first else { throw MacScriptingError.prayerNotFound }
      guard matches.count == 1 else { throw MacScriptingError.ambiguousName }
      return prayer
    }

    static func records(for prayers: [Prayer]) -> NSArray {
      NSArray(
        array: prayers.map { prayer in
          NSDictionary(dictionary: [
            "id": prayer.id.uuidString, "name": prayer.name,
            "prayerKind": prayer.kind.rawValue, "languageCode": prayer.languageCode,
            "devotionId": prayer.customDevotionId ?? "", "isDefault": prayer.isDefault,
          ])
        })
    }
  }

  /// Retain library navigation until its scene exists. Its existing widget destination queue
  /// defers changing the sidebar while a prayer editor or another modal view is open.
  @Observable
  final class MacScriptingNavigation {
    static let shared = MacScriptingNavigation()
    var pendingLibraryDestination: String?
    private var showLibraryWindow: (() -> Void)?

    func install(_ showWindow: @escaping () -> Void) {
      showLibraryWindow = showWindow
      if pendingLibraryDestination != nil { showWindow() }
    }

    func openLibrary(destination: String) {
      pendingLibraryDestination = destination
      NSApp.activate(ignoringOtherApps: true)
      showLibraryWindow?()
    }
  }

  /// Cocoa retains the suspended command while the authoritative store is read asynchronously.
  /// Its handler returns before the main-actor task resumes the Apple event with its result.
  @objc(ProsaryScriptingCommand)
  final class ProsaryScriptingCommand: NSScriptCommand {
    nonisolated override func performDefaultImplementation() -> Any? {
      suspendExecution()
      DispatchQueue.main.async { [self] in
        Task { @MainActor in
          do {
            let result: Any?
            switch commandDescription.appleEventCode {
            case 0x5053_6c73:  // PSls: list prayers
              result = MacScriptingLibrary.records(
                for: try await MacScriptingLibrary.prayers(in: AppServices.shared.presetStore))
            case 0x5053_6f70:  // PSop: open prayer
              guard let reference = directParameter as? String else {
                throw MacScriptingError.invalidReference
              }
              let prayer = try await MacScriptingLibrary.resolve(
                reference, in: AppServices.shared.presetStore)
              MacPrayerWindowActions.open(.prayer(id: prayer.id))
              result = prayer.id.uuidString
            case 0x5053_6c62:  // PSlb: open library
              MacScriptingNavigation.shared.openLibrary(destination: "library")
              result = nil
            case 0x5053_7264:  // PSrd: open readings
              MacScriptingNavigation.shared.openLibrary(destination: "readings")
              result = nil
            default:
              scriptErrorNumber = -1708
              result = nil
            }
            // Cocoa may re-enter AppKit while delivering a suspended reply. Leave the Swift
            // task's executor context before resuming the command on the main dispatch queue.
            DispatchQueue.main.async { [self] in resumeExecution(withResult: result) }
          } catch {
            scriptErrorNumber = (error as? MacScriptingError)?.errorNumber ?? -10000
            scriptErrorString = error.localizedDescription
            DispatchQueue.main.async { [self] in resumeExecution(withResult: nil) }
          }
        }
      }
      return nil
    }
  }
#endif
