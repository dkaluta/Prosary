//
//  PrayerPackLoaderTests.swift
//  ProsaryTests
//
//  Proves the whole .prosaryprayer pipeline end-to-end: the actual bundled rosary.prosaryprayer/
//  angelus.prosaryprayer resources (produced by Shared/tools/make-prosaryprayer.sh from
//  Shared/content/) parse correctly and their content overrides PrayerTranslations/
//  MysteryTranslations as designed.
//

import XCTest
@testable import Prosary

@MainActor
final class PrayerPackLoaderTests: XCTestCase {
  func testBundledPacksExist() {
    for pack in ["rosary", "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
                 "divineMercyChaplet", "trisagion", "oAntiphons"] {
      XCTAssertNotNil(
        Bundle.main.url(forResource: pack, withExtension: "prosaryprayer"),
        "missing \(pack).prosaryprayer")
    }
  }

  func testRosaryPackProvidedKeyOverridesEnglishText() {
    let text = PrayerTranslations.get(languageCode: "en", key: .oratioFatimae)
    XCTAssertEqual(text, "O my Jesus, forgive us our sins, save us from the fires of hell, lead all souls to Heaven, especially those who are in most need of Thy mercy.")
  }

  func testRosaryPackProvidedMysteryOverridesLatinTitle() {
    let text = MysteryTranslations.get(languageCode: "la", imageKey: "joyful_01_annunciation")
    XCTAssertEqual(text.title, "Nuntiatio")
    XCTAssertEqual(text.fruit, "Humilitas")
  }

  func testAngelusPackProvidesHebrewComposedBody() {
    let text = PrayerPackStore.resolveBodyText(
      bundleId: "angelus", languageCode: "he", key: "angelusCollectBody")
    XCTAssertFalse(text.isEmpty)
    XCTAssertTrue(text.contains("נִתְפַּלְּלָה"))
  }

  /// The "main" prayers (Sign of the Cross, Creed, Our Father, Hail Mary, Glory Be) are
  /// deliberately absent from every bundle (see Shared/ARCHITECTURE.md) and must keep resolving
  /// from the hardcoded table even with both packs loaded.
  func testMainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
    let text = PrayerTranslations.get(languageCode: "en", key: .aveMaria)
    XCTAssertEqual(text, PrayerTranslations.english[.aveMaria])
  }

  /// A devotion converted to a bundle resolves entirely bundle-locally — its keys no longer
  /// exist in the hardcoded tables at all.
  func testConvertedDevotionKeyResolvesFromItsBundle() {
    let text = PrayerPackStore.resolveBodyText(
      bundleId: "stationsOfTheCross", languageCode: "en", key: "stationsOpeningPrayer")
    XCTAssertTrue(text.hasPrefix("My Lord Jesus Christ, You made this journey"))
  }

  func testRosaryPackProvidesImageDataForAMysteryKey() {
    let data = PrayerPackStore.imageData(for: "joyful_01_annunciation")
    XCTAssertNotNil(data)
    XCTAssertGreaterThan(data?.count ?? 0, 0)
  }

  func testFranciscanCrownDeclaresItsOptions() {
    let options = PrayerPackStore.options(for: "franciscanCrown")
    XCTAssertEqual(options.map(\.key), ["seventyTwoHailMarys", "popeIntentions"])
    XCTAssertTrue(options.allSatisfy { $0.kind == .toggle && $0.defaultValue == "true" })
    XCTAssertEqual(options[0].name, "Complete the 72 Hail Marys")
    XCTAssertTrue(PrayerPackStore.options(for: "angelus").isEmpty)
  }

  // MARK: - User-installed bundles

  /// Builds a minimal, valid .prosaryprayer in memory (stored zip, no compression) — the same
  /// shape a third-party author would produce.
  private func makeExamplePack(id: String) -> Data {
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)", "displayName": "Example Devotion",
       "languages": ["la", "en"], "hasCatalog": false, "images": []}
      """
    let content = #"{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"#
    let devotion = """
      {"type": "steps", "steps": [
        {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
        {"title": "Example Prayer", "bodyKey": "exampleBody"}
      ]}
      """
    return Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/la.json", Data(content.utf8)),
      ("content/en.json", Data(content.utf8)),
      ("devotion.json", Data(devotion.utf8)),
    ])
  }

  func testInstallRemoveRoundTripForAnImportedBundle() throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "example\(Int.random(in: 1000...9999))"
    let installed = try PrayerPackStore.installPack(from: makeExamplePack(id: id))
    XCTAssertEqual(installed, id)
    XCTAssertTrue(PrayerPackStore.customDevotionIds().contains(id))
    XCTAssertTrue(PrayerPackStore.installedBundleIds().contains(id))
    XCTAssertEqual(PrayerPackStore.info(for: id)?.displayName, "Example Devotion")
    XCTAssertEqual(
      PrayerPackStore.resolveBodyText(bundleId: id, languageCode: "en", key: "exampleBody"),
      "Kyrie eleison.")

    // A second install of the same id must be rejected, not silently replaced.
    XCTAssertThrowsError(try PrayerPackStore.installPack(from: makeExamplePack(id: id)))

    // Garbage is rejected with the unreadable error.
    XCTAssertThrowsError(try PrayerPackStore.installPack(from: Data("not a zip".utf8)))

    PrayerPackStore.removeInstalledPack(id: id)
    XCTAssertFalse(PrayerPackStore.customDevotionIds().contains(id))
    XCTAssertNil(PrayerPackStore.definition(for: id))
  }

  /// A days-type (multi-day) bundle decodes, installs, and prays its first day — the
  /// groundwork contract until per-favorite day progress ships (see ARCHITECTURE.md).
  func testDaysTypeBundlePraysItsFirstDay() throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "novena\(Int.random(in: 1000...9999))"
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)", "displayName": "Example Novena",
       "languages": ["la", "en"], "hasCatalog": false, "images": []}
      """
    let content = #"{"prayers": {"day1Body": "Day one prayer.", "day2Body": "Day two prayer."}, "mysteries": {}}"#
    let devotion = """
      {"type": "days",
       "opening": [{"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"}],
       "days": [
         {"name": "Day 1", "steps": [{"title": "Day 1", "bodyKey": "day1Body"}]},
         {"name": "Day 2", "steps": [{"title": "Day 2", "bodyKey": "day2Body"}]}
       ],
       "closing": [{"title": "Glory Be", "bodyKey": "gloriaPatri", "imageKey": "glory_be"}]}
      """
    try PrayerPackStore.installPack(from: Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/la.json", Data(content.utf8)),
      ("content/en.json", Data(content.utf8)),
      ("devotion.json", Data(devotion.utf8)),
    ]))
    defer { PrayerPackStore.removeInstalledPack(id: id) }

    let steps = PrayerEngine().buildSteps(
      for: Prayer(kind: .custom, languageCode: "en", customDevotionId: id))
    XCTAssertEqual(steps.map(\.title), ["Sign of the Cross", "Day 1", "Glory Be"])
    XCTAssertEqual(steps[1].body, "Day one prayer.")
  }

  /// An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.md's "Audio
  /// (groundwork)") parses its track metadata and serves a declared file's bytes on demand;
  /// undeclared files stay unreachable, and audio-less bundles report no tracks.
  func testAudioBearingBundleParsesTracksAndServesDeclaredBytes() throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "audio\(Int.random(in: 1000...9999))"
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)", "displayName": "Example Devotion",
       "languages": ["la", "en"], "hasCatalog": false, "images": []}
      """
    let content = #"{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"#
    let devotion = """
      {"type": "steps", "steps": [
        {"title": "Sign of the Cross", "bodyKey": "signumCrucis", "imageKey": "crucifix"},
        {"title": "Example Prayer", "bodyKey": "exampleBody"}
      ]}
      """
    let audio = """
      {"tracks": [
        {"id": "en", "language": "en", "file": "audio/en.opus", "name": "Full recitation",
         "chapters": [
           {"start": 0, "title": "Sign of the Cross", "stepIndex": 0},
           {"start": 12.5, "title": "Example Prayer", "stepIndex": 1}
         ]}
      ]}
      """
    // A minimal Ogg Opus signature (RFC 7845): an "OggS" page whose one-segment payload is the
    // "OpusHead" identification header at offset 28 — enough for the format's checks, no real
    // audio needed to prove the metadata/bytes plumbing.
    let opusBytes = Data("OggS".utf8) + Data(repeating: 0, count: 24)
      + Data("OpusHead".utf8) + Data(repeating: 0, count: 11)
    try PrayerPackStore.installPack(from: Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/la.json", Data(content.utf8)),
      ("content/en.json", Data(content.utf8)),
      ("devotion.json", Data(devotion.utf8)),
      ("audio.json", Data(audio.utf8)),
      ("audio/en.opus", opusBytes),
    ]))
    defer { PrayerPackStore.removeInstalledPack(id: id) }

    let tracks = PrayerPackStore.audioTracks(for: id)
    let track = try XCTUnwrap(tracks.first)
    XCTAssertEqual(tracks.count, 1)
    XCTAssertEqual(track.id, "en")
    XCTAssertEqual(track.language, "en")
    XCTAssertEqual(track.file, "audio/en.opus")
    XCTAssertNil(track.variantId)
    XCTAssertEqual(track.name, "Full recitation")
    XCTAssertEqual(track.chapters.map(\.start), [0, 12.5])
    XCTAssertEqual(track.chapters.map(\.stepIndex), [0, 1])
    XCTAssertEqual(track.chapters[0].title, "Sign of the Cross")

    XCTAssertEqual(PrayerPackStore.audioData(bundleId: id, file: "audio/en.opus"), opusBytes)
    XCTAssertNil(PrayerPackStore.audioData(bundleId: id, file: "manifest.json"))
    XCTAssertTrue(PrayerPackStore.audioTracks(for: "angelus").isEmpty)
    XCTAssertNil(PrayerPackStore.audioData(bundleId: "angelus", file: "audio/en.opus"))
  }

  /// Minimal stored (uncompressed) zip writer — enough for MinimalZipReader to consume.
  private static func storedZip(_ files: [(name: String, data: Data)]) -> Data {
    func le16(_ v: Int) -> Data { Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF)]) }
    func le32(_ v: Int) -> Data {
      Data([UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8((v >> 24) & 0xFF)])
    }
    func crc32(_ data: Data) -> Int {
      var table = [UInt32](repeating: 0, count: 256)
      for i in 0..<256 {
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
        table[i] = c
      }
      var crc: UInt32 = 0xFFFF_FFFF
      for byte in data { crc = table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
      return Int(crc ^ 0xFFFF_FFFF)
    }

    var out = Data()
    var central = Data()
    var offsets: [Int] = []
    for (name, data) in files {
      offsets.append(out.count)
      let nameData = Data(name.utf8)
      let crc = crc32(data)
      out += le32(0x0403_4B50) + le16(20) + le16(0) + le16(0) + le16(0) + le16(0)
      out += le32(crc) + le32(data.count) + le32(data.count)
      out += le16(nameData.count) + le16(0) + nameData + data
    }
    for (i, (name, data)) in files.enumerated() {
      let nameData = Data(name.utf8)
      let crc = crc32(data)
      central += le32(0x0201_4B50) + le16(20) + le16(20) + le16(0) + le16(0) + le16(0) + le16(0)
      central += le32(crc) + le32(data.count) + le32(data.count)
      central += le16(nameData.count) + le16(0) + le16(0) + le16(0) + le16(0)
      central += le32(0) + le32(offsets[i]) + nameData
    }
    let centralOffset = out.count
    out += central
    out += le32(0x0605_4B50) + le16(0) + le16(0) + le16(files.count) + le16(files.count)
    out += le32(central.count) + le32(centralOffset) + le16(0)
    return out
  }

  func testStationsPackProvidesItsImageData() {
    let data = PrayerPackStore.imageData(for: "station_01_condemned_to_death")
    XCTAssertGreaterThan(data?.count ?? 0, 0)
    // The scriptural variant's own scenes ship in the same pack.
    XCTAssertGreaterThan(PrayerPackStore.imageData(for: "scriptural_02_kiss_of_judas")?.count ?? 0, 0)
  }

  func testPackProvidesNoImageDataForAnUnknownKey() {
    XCTAssertNil(PrayerPackStore.imageData(for: "no_such_image_key"))
  }

  // MARK: - Generic (bundle-driven) devotions

  func testTrisagionIsDiscoveredAsACustomDevotion() {
    XCTAssertTrue(PrayerPackStore.customDevotionIds().contains("trisagion"))
  }

  /// The Rosary's pack now ships a devotion.json (the engine builds the Rosary from it), but
  /// its manifest's builtinKind keeps it off the generic-devotion list — it backs the dedicated
  /// PrayerKind and must never appear as a Home/Favorites card twice. The six generic devotions
  /// appear in pack-load order.
  func testCustomDevotionIdsAreTheGenericDevotionsInLoadOrder() {
    XCTAssertEqual(PrayerPackStore.customDevotionIds(), [
      "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
      "divineMercyChaplet", "trisagion", "oAntiphons",
    ])
    XCTAssertNotNil(PrayerPackStore.definition(for: "rosary"))
  }

  func testTrisagionInfoReadsFromItsManifest() {
    let info = PrayerPackStore.info(for: "trisagion")
    XCTAssertEqual(info?.displayName, "Trisagion")
    XCTAssertEqual(info?.accentColorHex, "#00796B")
    XCTAssertEqual(info?.iconSystemName, "triangle")
  }

  func testTrisagionDefinitionMatchesTheAuthoredSixStepSequence() {
    let definition = PrayerPackStore.definition(for: "trisagion")
    XCTAssertEqual(definition?.type, .steps)
    let steps = definition?.steps ?? []
    // Headings are translatable keys, not literals, so they read in the prayer's language.
    XCTAssertEqual(steps.map(\.titleKey), [
      "trisagionAcclamationTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
      "gloriaPatriTitle", "trisagionAcclamationTitle", "trisagionAcclamationTitle",
    ])
    XCTAssertEqual(steps.map(\.bodyKey), [
      "trisagionAcclamation", "trisagionAcclamation", "trisagionAcclamation",
      "gloriaPatri", "trisagionShortAcclamation", "trisagionAcclamation",
    ])
  }

  /// `resolveBodyText` step 1 — a bundle-local-only key (never a `PrayerKey` case) resolves from
  /// the bundle's own raw content.
  func testResolveBodyTextResolvesABundleLocalKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "trisagionAcclamation")
    XCTAssertEqual(text, "Holy God, Holy Mighty One, Holy Immortal One, have mercy on us.")
  }

  /// `resolveBodyText` step 2 — a key matching an existing `PrayerKey` case (here, "gloriaPatri",
  /// a "main" prayer deliberately absent from every bundle) falls through to the ordinary
  /// hardcoded table.
  func testResolveBodyTextFallsThroughToASharedPrayerKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "gloriaPatri")
    XCTAssertEqual(text, PrayerTranslations.get(languageCode: "en", key: .gloriaPatri))
  }

  /// `resolveBodyText` step 3 — an unresolvable key returns itself, matching
  /// `PrayerTranslations.get`'s own last-resort fallback.
  func testResolveBodyTextFallsBackToTheRawKey() {
    let text = PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "en", key: "notARealKey")
    XCTAssertEqual(text, "notARealKey")
  }
}
