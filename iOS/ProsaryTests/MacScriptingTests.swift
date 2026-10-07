#if os(macOS)
import AppKit
import Foundation
import SwiftData
import XCTest
@testable import Prosary

@MainActor
final class MacScriptingTests: XCTestCase {
  func testHostedMacAppEnablesItsPackagedScriptingDictionary() throws {
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "NSAppleScriptEnabled") as? Bool, true)
    XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "OSAScriptingDefinition") as? String,
                   "Prosary.sdef")
    let resource = try XCTUnwrap(Bundle.main.url(forResource: "Prosary", withExtension: "sdef"),
                                "The Mac app must ship the dictionary named by its Info.plist")
    XCTAssertTrue(FileManager.default.fileExists(atPath: resource.path))
  }

  func testPackagedDictionaryRoutesEveryCustomCommandToTheRuntimeHandler() throws {
    let resource = try XCTUnwrap(Bundle.main.url(forResource: "Prosary", withExtension: "sdef"))
    let dictionary = try XMLDocument(contentsOf: resource, options: [])
    let commands = try dictionary.nodes(forXPath: "/dictionary/suite/command")
    XCTAssertEqual(commands.count, 4)
    XCTAssertEqual(Set(commands.compactMap { ($0 as? XMLElement)?.attribute(forName: "name")?.stringValue }),
                   Set(["list prayers", "open prayer", "open library", "open readings"]))
    for command in commands {
      let handlers = try command.nodes(forXPath: "cocoa")
      XCTAssertEqual(handlers.count, 1)
      let className = try XCTUnwrap((handlers.first as? XMLElement)?.attribute(forName: "class")?.stringValue)
      XCTAssertEqual(className, "ProsaryScriptingCommand")
      let runtimeHandler = try XCTUnwrap(NSClassFromString(className) as? NSScriptCommand.Type,
                                        "Cocoa scripting must resolve the shipped handler class at runtime")
      XCTAssertEqual(ObjectIdentifier(runtimeHandler), ObjectIdentifier(ProsaryScriptingCommand.self))
    }
    let properties = try dictionary.nodes(forXPath: "/dictionary/suite/record-type[@code='PSpi']/property")
    let expectedKeys = ["ID  ": "id", "pnam": "name", "PSkd": "prayerKind", "PSlg": "languageCode",
                        "PSdv": "devotionId", "PSdf": "isDefault"]
    XCTAssertEqual(properties.count, expectedKeys.count)
    for property in properties {
      let field = try XCTUnwrap(property as? XMLElement)
      let code = try XCTUnwrap(field.attribute(forName: "code")?.stringValue)
      let mapping = try XCTUnwrap(try field.nodes(forXPath: "cocoa").first as? XMLElement)
      XCTAssertEqual(mapping.attribute(forName: "key")?.stringValue, expectedKeys[code],
                     "Each Apple event record field must map to its NSDictionary key")
    }
  }

  func testCocoaRegistryLoadsEveryCustomAppleEventWithItsConcreteCommandClass() throws {
    let registry = NSScriptSuiteRegistry.shared()
    let commands: [(FourCharCode, String)] = [
      (0x50536c73, "list prayers"), (0x50536f70, "open prayer"),
      (0x50536c62, "open library"), (0x50537264, "open readings"),
    ]
    for (eventCode, label) in commands {
      let description = try XCTUnwrap(registry.commandDescription(
        withAppleEventClass: 0x50537279, andAppleEventCode: eventCode),
        "Cocoa must register the shipped \(label) command")
      print("Cocoa scripting registry: \(label) -> \(description.commandName), class \(description.commandClassName)")
      XCTAssertEqual(description.appleEventClassCode, 0x50537279)
      XCTAssertEqual(description.appleEventCode, eventCode)
      XCTAssertEqual(description.commandClassName, "ProsaryScriptingCommand")
      XCTAssertTrue(description.createCommandInstance() is ProsaryScriptingCommand,
                    "Cocoa must instantiate the concrete handler for \(label)")
    }
  }

  func testMacSourcePlistRetainsEverySharedPhoneMetadataEntry() throws {
    let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    func load(_ name: String) throws -> [String: Any] {
      let data = try Data(contentsOf: project.appendingPathComponent(name))
      return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    }
    let shared = try load("Prosary-Info.plist")
    var mac = try load("Prosary-Mac-Info.plist")
    XCTAssertEqual(mac.removeValue(forKey: "NSAppleScriptEnabled") as? Bool, true)
    XCTAssertEqual(mac.removeValue(forKey: "OSAScriptingDefinition") as? String, "Prosary.sdef")
    XCTAssertEqual(mac as NSDictionary, shared as NSDictionary,
                   "Selecting a Mac plist must retain the shared document and URL declarations")
  }

  func testExternalScriptingCommandsAgainstThisIsolatedTestHost() async throws {
    guard ProcessInfo.processInfo.environment["PROSARY_RUN_SCRIPTING_SMOKE"] == "1" else {
      throw XCTSkip("Opt in with PROSARY_RUN_SCRIPTING_SMOKE=1 to exercise external Apple events")
    }
    // Never initialize the shared services until the host has proved it is a test process.
    guard ProsaryRuntimeEnvironment.isTesting else {
      XCTFail("The scripting smoke requires isolated test storage")
      return
    }
    guard !AppServices.modelContainer.configurations.isEmpty,
          AppServices.modelContainer.configurations.allSatisfy({ $0.isStoredInMemoryOnly
            && $0.cloudKitContainerIdentifier == nil }) else {
      XCTFail("The scripting smoke must never seed a persistent or CloudKit library")
      return
    }
    let suffix = UUID().uuidString
    let ordinary = Prayer(name: "Scripting Smoke \(suffix)", kind: .rosary, languageCode: "en")
    let unicode = Prayer(name: "תפילה ܨܠܘܬܐ 🙏 \(suffix)", kind: .jesusPrayer, languageCode: "he")
    let duplicate = "Duplicate Scripting Smoke \(suffix)"
    let fixtures = [ordinary, unicode,
      Prayer(name: duplicate, kind: .custom, languageCode: "ar", customDevotionId: "angelus"),
      Prayer(name: duplicate, kind: .custom, languageCode: "la", customDevotionId: "trisagion")]
    let store = AppServices.shared.presetStore
    let initial = try await store.all()
    let progressBefore = progressSnapshot()
    let clientPath = try XCTUnwrap(ProcessInfo.processInfo.environment["PROSARY_SCRIPTING_CLIENT"],
      "Compile the Apple event client outside App Sandbox and provide PROSARY_SCRIPTING_CLIENT")
    let client = URL(fileURLWithPath: clientPath)
    XCTAssertTrue(FileManager.default.isExecutableFile(atPath: client.path),
                  "PROSARY_SCRIPTING_CLIENT must name the externally compiled client")
    do {
      for fixture in fixtures {
        // Avoid an app-wide auto-advance preference changing these fresh fixtures during the smoke.
        MacPrayerPlaybackSettings.shared.setAutoAdvanceSeconds(0, for: fixture.id)
        try await store.save(fixture)
      }
      let before = try await store.all()
      let pid = ProcessInfo.processInfo.processIdentifier
      print("Scripting smoke exact host PID: \(pid); LaunchServices registration: \(NSRunningApplication(processIdentifier: pid) != nil)")
      let response = try await runProcess(client, arguments: [String(pid), "smoke", ordinary.id.uuidString,
        unicode.name, duplicate, UUID().uuidString], timeout: 30)
      let result = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
      let records = try XCTUnwrap(result["prayers"] as? [[String: Any]])
      for fixture in fixtures {
        let record = try XCTUnwrap(records.first { ($0["id"] as? String) == fixture.id.uuidString })
        XCTAssertEqual(record["name"] as? String, fixture.name)
        XCTAssertEqual(record["prayerKind"] as? String, fixture.kind.rawValue)
        XCTAssertEqual(record["languageCode"] as? String, fixture.languageCode)
        XCTAssertEqual(record["devotionId"] as? String, fixture.customDevotionId ?? "")
        XCTAssertEqual(record["isDefault"] as? Bool, fixture.isDefault)
      }
      XCTAssertEqual(result["openedID"] as? String, ordinary.id.uuidString)
      XCTAssertEqual(result["openedUnicodeName"] as? String, unicode.id.uuidString)
      for (key, expected) in [("duplicate", -10000), ("missing", -1728), ("invalid", -1700)] {
        let error = try XCTUnwrap(result[key] as? [String: Any])
        XCTAssertEqual(error["number"] as? Int, expected, "\(key) must return its Cocoa scripting error")
        XCTAssertFalse((error["message"] as? String ?? "").isEmpty)
      }

      let window = await fixtureWindow(for: ordinary.id)
      let reopenedResponse = try await runProcess(client,
        arguments: [String(pid), "reopen", ordinary.id.uuidString], timeout: 10)
      let reopened = try XCTUnwrap(JSONSerialization.jsonObject(with: reopenedResponse) as? [String: Any])
      XCTAssertEqual(reopened["opened"] as? String, ordinary.id.uuidString)
      if let window {
        let reused = await fixtureWindow(for: ordinary.id)
        XCTAssertTrue(reused === window, "Opening a saved UUID again must reuse its existing prayer window")
        XCTAssertEqual(fixtureWindows(for: ordinary.id).count, 1)
      } else {
        print("Scripting smoke: hosted app did not materialize a prayer scene; window reuse remains unverified.")
      }
      let after = try await store.all()
      XCTAssertEqual(Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0) }),
                     Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) }))
      XCTAssertEqual(progressSnapshot(), progressBefore, "Opening scripts must preserve existing bookmarks")
    } catch {
      await removeSmokeFixtures(fixtures, from: store)
      throw error
    }
    await removeSmokeFixtures(fixtures, from: store)
    let remaining = try await store.all()
    XCTAssertEqual(Dictionary(uniqueKeysWithValues: remaining.map { ($0.id, $0) }),
                   Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) }))
  }

  func testListingUsesNaturalNameOrderAcrossEveryPrayerKind() async throws {
    let rosary = Prayer(name: "Prayer 2", kind: .rosary)
    let jesus = Prayer(name: "Prayer 10", kind: .jesusPrayer)
    let custom = Prayer(name: "Prayer 20", kind: .custom, customDevotionId: "angelus")
    let store = ReadOnlySpyStore([custom, jesus, rosary])

    let listed = try await MacScriptingLibrary.prayers(in: store)

    XCTAssertEqual(listed, [rosary, jesus, custom])
    XCTAssertEqual(Set(listed.map(\.kind)), Set(PrayerKind.allCases))
    XCTAssertEqual(store.writeCount, 0)
  }

  func testEqualNamesHaveDeterministicUUIDOrder() async throws {
    let lower = Prayer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, name: "Same name")
    let higher = Prayer(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "Same name")

    for input in [[higher, lower], [lower, higher]] {
      let listed = try await MacScriptingLibrary.prayers(in: ReadOnlySpyStore(input))
      XCTAssertEqual(listed.map(\.id), [lower.id, higher.id])
    }
  }

  func testEmptyLibraryReturnsEmptyList() async throws {
    let listed = try await MacScriptingLibrary.prayers(in: ReadOnlySpyStore([]))
    XCTAssertTrue(listed.isEmpty)
    XCTAssertEqual(MacScriptingLibrary.records(for: listed).count, 0)
  }

  func testUUIDSelectsSavedIdentityDespiteDuplicateNamesAndRenames() async throws {
    let first = Prayer(name: "Same prayer", kind: .rosary)
    var second = Prayer(name: "Same prayer", kind: .jesusPrayer)
    let store = ReadOnlySpyStore([first, second])

    let resolvedFirst = try await MacScriptingLibrary.resolve(first.id.uuidString, in: store)
    let resolvedSecond = try await MacScriptingLibrary.resolve(second.id.uuidString.lowercased(), in: store)
    XCTAssertEqual(resolvedFirst, first)
    XCTAssertEqual(resolvedSecond, second)

    second.name = "Renamed prayer"
    store.prayers = [first, second]
    let renamed = try await MacScriptingLibrary.resolve(second.id.uuidString, in: store)
    XCTAssertEqual(renamed, second)
    XCTAssertEqual(store.writeCount, 0)
  }

  func testUUIDIdentityTakesPriorityOverAnotherPrayersUUIDLookingName() async throws {
    let target = Prayer(name: "Real target", kind: .rosary)
    let namedLikeID = Prayer(name: target.id.uuidString, kind: .custom, customDevotionId: "angelus")
    let store = ReadOnlySpyStore([namedLikeID, target])

    let result = try await MacScriptingLibrary.resolve(target.id.uuidString, in: store)

    XCTAssertEqual(result.id, target.id)
  }

  func testMissingUUIDNeverFallsBackToUUIDLookingName() async {
    let missingID = UUID()
    let namedLikeID = Prayer(name: missingID.uuidString, kind: .rosary)
    await assertResolutionFailure(missingID.uuidString, .prayerNotFound,
                                  in: ReadOnlySpyStore([namedLikeID]))
  }

  func testUnicodeNamesResolveExactlyForEveryPrayerKind() async throws {
    let prayers = [
      Prayer(name: "מחרוזת הורדים — בוקר", kind: .rosary, languageCode: "he"),
      Prayer(name: "ܨܠܘܬܐ • 33", kind: .jesusPrayer, languageCode: "arc"),
      Prayer(name: "صلاتي «المساء»", kind: .custom, languageCode: "ar", customDevotionId: "angelus"),
      Prayer(name: "Молитва 🙏", kind: .custom, languageCode: "uk", customDevotionId: "trisagion"),
    ]
    let store = ReadOnlySpyStore(prayers)

    for prayer in prayers {
      let resolved = try await MacScriptingLibrary.resolve(prayer.name, in: store)
      XCTAssertEqual(resolved, prayer)
    }
    let listed = try await MacScriptingLibrary.prayers(in: store)
    XCTAssertEqual(Set(listed.map(\.name)), Set(prayers.map(\.name)))
    XCTAssertEqual(store.writeCount, 0)
  }

  func testNonemptyNamesPreserveSignificantWhitespace() async throws {
    let plain = Prayer(name: "Evening Prayer", kind: .rosary)
    let spaced = Prayer(name: " Evening Prayer ", kind: .jesusPrayer)
    let store = ReadOnlySpyStore([plain, spaced])

    let resolvedPlain = try await MacScriptingLibrary.resolve(plain.name, in: store)
    let resolvedSpaced = try await MacScriptingLibrary.resolve(spaced.name, in: store)

    XCTAssertEqual(resolvedPlain.id, plain.id)
    XCTAssertEqual(resolvedSpaced.id, spaced.id)
    await assertResolutionFailure(" Evening Prayer", .prayerNotFound, in: store)
  }

  func testNameLookupIsNeitherCaseInsensitiveNorFuzzy() async {
    let store = ReadOnlySpyStore([Prayer(name: "Evening Rosary")])
    for reference in ["evening rosary", "Evening", "Evening Rosar", "Evening Rosary "] {
      await assertResolutionFailure(reference, .prayerNotFound, in: store)
    }
  }

  func testDuplicateExactNamesAreAmbiguousInsteadOfChoosingFirst() async {
    let prayers = [Prayer(name: "Angelus", kind: .custom, customDevotionId: "angelus"),
                   Prayer(name: "Angelus", kind: .rosary)]
    for input in [prayers, Array(prayers.reversed())] {
      await assertResolutionFailure("Angelus", .ambiguousName, in: ReadOnlySpyStore(input))
    }
  }

  func testEmptyAndWhitespaceOnlyReferencesAreInvalid() async {
    let store = ReadOnlySpyStore([Prayer(name: " ")])
    for reference in ["", " ", "\t\n\r", "\u{00A0}\u{2003}"] {
      await assertResolutionFailure(reference, .invalidReference, in: store)
    }
    XCTAssertEqual(store.writeCount, 0)
  }

  func testUnderlyingStorageErrorsPropagateForListAndBothLookupPaths() async {
    let store = ReadOnlySpyStore([])
    store.readFailure = .unavailable
    do {
      _ = try await MacScriptingLibrary.prayers(in: store)
      XCTFail("Listing must report a storage failure")
    } catch {
      XCTAssertEqual(error as? StorageFailure, .unavailable)
    }
    for reference in [UUID().uuidString, "Angelus"] {
      do {
        _ = try await MacScriptingLibrary.resolve(reference, in: store)
        XCTFail("Lookup must report a storage failure")
      } catch {
        XCTAssertEqual(error as? StorageFailure, .unavailable)
      }
    }
    XCTAssertEqual(store.writeCount, 0)
  }

  func testListingAndResolvingLeaveConfigurationsAndProgressUntouched() async throws {
    let prayers = [
      Prayer(name: "Rosary", kind: .rosary, isDefault: true, languageCode: "he",
             rosary: RosaryOptions(mysterySelectionMode: .specific, specificMysteryGroup: .sorrowful),
             reminders: [PrayerReminder(hour: 7, minute: 35)]),
      Prayer(name: "Jesus Prayer", kind: .jesusPrayer, languageCode: "la",
             jesusPrayer: JesusPrayerOptions(target: .count(77)),
             reminders: [PrayerReminder(hour: 21, isEnabled: false)]),
      Prayer(name: "Novena", kind: .custom, languageCode: "ar", customDevotionId: "angelus",
             variantId: "evening", dayIndex: 3, customOptions: ["intentions": "true"]),
    ]
    let store = ReadOnlySpyStore(prayers)
    let progressBefore = UserDefaults.standard.object(forKey: PrayerRunProgressStore.defaultsKey) as? Data

    _ = try await MacScriptingLibrary.prayers(in: store)
    for prayer in prayers {
      _ = try await MacScriptingLibrary.resolve(prayer.id.uuidString, in: store)
      _ = try await MacScriptingLibrary.resolve(prayer.name, in: store)
    }
    _ = MacScriptingLibrary.records(for: prayers)

    XCTAssertEqual(store.prayers, prayers)
    XCTAssertEqual(store.writeCount, 0)
    XCTAssertEqual(UserDefaults.standard.object(forKey: PrayerRunProgressStore.defaultsKey) as? Data,
                   progressBefore, "Scripting queries must not reset or advance prayer bookmarks")
  }

  func testRecordsIncludeStableTypedMetadataAndPreserveUnicodeAndInputOrder() throws {
    let prayers = [
      Prayer(name: "מחרוזת הורדים", kind: .rosary, isDefault: true, languageCode: "he"),
      Prayer(name: "ܨܠܘܬܐ", kind: .jesusPrayer, languageCode: LanguageCatalog.defaultSentinel),
      Prayer(name: "صلاة المساء 🙏", kind: .custom, languageCode: "ar", customDevotionId: "angelus"),
    ]

    let list = MacScriptingLibrary.records(for: prayers)

    XCTAssertEqual(list.count, prayers.count)
    for (offset, prayer) in prayers.enumerated() {
      let record = try XCTUnwrap(list[offset] as? NSDictionary)
      XCTAssertEqual(record["id"] as? String, prayer.id.uuidString)
      XCTAssertEqual(record["name"] as? String, prayer.name)
      XCTAssertEqual(record["prayerKind"] as? String, prayer.kind.rawValue)
      XCTAssertEqual(record["languageCode"] as? String, prayer.languageCode)
      XCTAssertEqual(record["devotionId"] as? String, prayer.customDevotionId ?? "")
      XCTAssertEqual(record["isDefault"] as? Bool, prayer.isDefault)
    }
  }

  private func assertResolutionFailure(
    _ reference: String, _ expected: MacScriptingError, in store: any PresetStore,
    file: StaticString = #filePath, line: UInt = #line
  ) async {
    do {
      _ = try await MacScriptingLibrary.resolve(reference, in: store)
      XCTFail("Expected \(expected) for \(String(reflecting: reference))", file: file, line: line)
    } catch {
      XCTAssertEqual(error as? MacScriptingError, expected, file: file, line: line)
    }
  }

  private func runProcess(_ executable: URL, arguments: [String], timeout: TimeInterval) async throws -> Data {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    let output = Pipe(), errors = Pipe()
    process.standardOutput = output
    process.standardError = errors
    let ended = expectation(description: "External scripting command returned")
    process.terminationHandler = { _ in ended.fulfill() }
    defer { if process.isRunning { process.terminate() } }
    try process.run()
    // Suspending rather than waiting on the process leaves the main run loop free for Apple events.
    await fulfillment(of: [ended], timeout: timeout)
    guard !process.isRunning else { throw ScriptingSmokeFailure.timedOut }
    let stdout = output.fileHandleForReading.readDataToEndOfFile()
    let stderr = errors.fileHandleForReading.readDataToEndOfFile()
    guard process.terminationStatus == 0 else {
      throw ScriptingSmokeFailure.commandFailed(String(decoding: stderr, as: UTF8.self))
    }
    return stdout
  }

  /// Reference source for a client compiled outside the app sandbox and supplied with
  /// PROSARY_SCRIPTING_CLIENT. Direct process addressing works without LaunchServices.
  private static let appleEventClientSource = #"""
  import AppKit
  import Foundation

  enum ClientFailure: Error {
    case server(Int, String)
    case malformed(String)
  }

  func keyword(_ value: String) -> AEKeyword {
    value.utf8.reduce(0) { ($0 << 8) | AEKeyword($1) }
  }

  let arguments = CommandLine.arguments
  guard arguments.count >= 4, let pid = Int32(arguments[1]), pid > 0 else {
    fatalError("Expected the exact running test-host PID and command arguments")
  }
  let target = NSAppleEventDescriptor(processIdentifier: pid)

  func send(_ code: String, reference: String? = nil) throws -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(eventClass: keyword("PSry"), eventID: keyword(code),
      targetDescriptor: target, returnID: -1, transactionID: 0)
    if let reference {
      event.setParam(NSAppleEventDescriptor(string: reference), forKeyword: keyword("----"))
    }
    let reply = try event.sendEvent(options: .waitForReply, timeout: 5)
    if let number = reply.paramDescriptor(forKeyword: keyword("errn")), number.int32Value != 0 {
      throw ClientFailure.server(Int(number.int32Value),
        reply.paramDescriptor(forKeyword: keyword("errs"))?.stringValue ?? "Application error")
    }
    return reply.paramDescriptor(forKeyword: keyword("----")) ?? .null()
  }

  func text(_ descriptor: NSAppleEventDescriptor) throws -> String {
    guard let value = descriptor.stringValue else { throw ClientFailure.malformed("Expected text") }
    return value
  }

  func expectedFailure(_ reference: String) -> [String: Any] {
    do { _ = try send("PSop", reference: reference); return ["unexpectedSuccess": true] }
    catch ClientFailure.server(let number, let message) { return ["number": number, "message": message] }
    catch { let error = error as NSError; return ["number": error.code, "message": error.localizedDescription] }
  }

  do {
    var result: [String: Any]
    if arguments[2] == "reopen" {
      result = ["opened": try text(send("PSop", reference: arguments[3]))]
    } else {
      guard arguments.count == 7 else { throw ClientFailure.malformed("Expected smoke fixture references") }
      let list = try send("PSls")
      var prayers: [[String: Any]] = []
      if list.numberOfItems > 0 {
        for index in 1...list.numberOfItems {
          guard let record = list.atIndex(index) else { throw ClientFailure.malformed("Missing list item") }
          var metadata: [String: Any] = [:]
          for (field, code) in [("id", "ID  "), ("name", "pnam"), ("prayerKind", "PSkd"),
                                ("languageCode", "PSlg"), ("devotionId", "PSdv")] {
            guard let value = record.forKeyword(keyword(code)) else { throw ClientFailure.malformed("Missing field \(code)") }
            metadata[field] = try text(value)
          }
          guard let isDefault = record.forKeyword(keyword("PSdf")) else { throw ClientFailure.malformed("Missing default flag") }
          metadata["isDefault"] = isDefault.booleanValue
          prayers.append(metadata)
        }
      }
      result = ["prayers": prayers,
        "openedID": try text(send("PSop", reference: arguments[3])),
        "openedUnicodeName": try text(send("PSop", reference: arguments[4])),
        "duplicate": expectedFailure(arguments[5]), "missing": expectedFailure(arguments[6]),
        "invalid": expectedFailure(" ")]
      _ = try send("PSlb")
      _ = try send("PSrd")
    }
    let data = try JSONSerialization.data(withJSONObject: result)
    FileHandle.standardOutput.write(data)
  } catch {
    FileHandle.standardError.write(Data(String(describing: error).utf8))
    exit(1)
  }
  """#

  private func fixtureWindows(for id: UUID) -> [NSWindow] {
    let prefix = "Prosary.Prayer.\(Data(id.uuidString.utf8).base64EncodedString()).slot."
    return NSApp.windows.filter { $0.frameAutosaveName.hasPrefix(prefix) }
  }

  private func fixtureWindow(for id: UUID) async -> NSWindow? {
    let deadline = Date().addingTimeInterval(2)
    while Date() < deadline {
      if let window = fixtureWindows(for: id).first { return window }
      try? await Task.sleep(for: .milliseconds(20))
    }
    return nil
  }

  private func progressSnapshot() -> [String: PrayerRunProgress] {
    guard let data = UserDefaults.standard.data(forKey: PrayerRunProgressStore.defaultsKey) else { return [:] }
    return (try? JSONDecoder().decode([String: PrayerRunProgress].self, from: data)) ?? [:]
  }

  private func removeSmokeFixtures(_ fixtures: [Prayer], from store: any PresetStore) async {
    for fixture in fixtures {
      fixtureWindows(for: fixture.id).forEach { $0.close() }
      do {
        if let saved = try await store.get(id: fixture.id) { try await store.delete(saved) }
      } catch { XCTFail("Could not clean the scripting fixture \(fixture.id): \(error)") }
      MacPrayerPlaybackSettings.shared.remove(for: fixture.id)
    }
    // Remove only fixture-owned presentation/progress entries, preserving every unrelated value.
    let ids = fixtures.map { $0.id.uuidString }
    for key in [MacPrayerPresentationStore.defaultsKey, PrayerRunProgressStore.defaultsKey] {
      guard let data = UserDefaults.standard.data(forKey: key),
            var entries = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
      let owned = entries.keys.filter { entry in ids.contains { entry.contains($0) } }
      guard !owned.isEmpty else { continue }
      for entry in owned { entries.removeValue(forKey: entry) }
      if entries.isEmpty { UserDefaults.standard.removeObject(forKey: key) }
      else if let data = try? JSONSerialization.data(withJSONObject: entries) {
        UserDefaults.standard.set(data, forKey: key)
      }
    }
    let prefixes = ids.map { "NSWindow Frame Prosary.Prayer.\(Data($0.utf8).base64EncodedString()).slot." }
    for key in UserDefaults.standard.dictionaryRepresentation().keys
    where prefixes.contains(where: key.hasPrefix) {
      UserDefaults.standard.removeObject(forKey: key)
    }
    await RecentPrayers.shared.refresh()
  }

  private enum ScriptingSmokeFailure: Error {
    case timedOut
    case commandFailed(String)
  }

  private enum StorageFailure: Error, Equatable { case unavailable }

  private final class ReadOnlySpyStore: PresetStore {
    var prayers: [Prayer]
    var readFailure: StorageFailure?
    private(set) var writeCount = 0

    init(_ prayers: [Prayer]) { self.prayers = prayers }

    func all() async throws -> [Prayer] {
      if let readFailure { throw readFailure }
      return prayers
    }

    func defaultPreset(kind: PrayerKind) async throws -> Prayer? {
      if let readFailure { throw readFailure }
      return prayers.first { $0.kind == kind && $0.isDefault }
    }

    func get(id: Prayer.ID) async throws -> Prayer? {
      if let readFailure { throw readFailure }
      return prayers.first { $0.id == id }
    }

    func save(_ prayer: Prayer) async throws { writeCount += 1 }
    func updateIfPresent(_ prayer: Prayer) async throws -> Bool { writeCount += 1; return false }
    func delete(_ prayer: Prayer) async throws { writeCount += 1 }
  }
}
#endif
