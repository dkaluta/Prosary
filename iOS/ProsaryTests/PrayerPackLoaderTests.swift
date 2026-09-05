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
  func testSharedAramaicPrayersKeepTheirHeadingsAndMatchingReadingAid() throws {
    XCTAssertEqual(PrayerPackStore.resolveBodyText(
      bundleId: "oAntiphons", languageCode: "arc", key: "gloriaPatriTitle"), "שוּבחָא לַאבָא")
    XCTAssertEqual(PrayerPackStore.resolveBodyText(
      bundleId: "oAntiphons", languageCode: "arc", key: "gloriaPatri"),
      PrayerPackStore.resolveBodyText(bundleId: "trisagion", languageCode: "arc", key: "gloriaPatri"))
    let readingAid = try XCTUnwrap(PrayerPackStore.transliteration(
      bundleId: "oAntiphons", languageCode: "arc", key: "gloriaPatri"))
    XCTAssertEqual(readingAid, PrayerPackStore.transliteration(
      bundleId: "trisagion", languageCode: "arc", key: "gloriaPatri"))
    XCTAssertNotEqual(readingAid, PrayerPackStore.transliteration(
      bundleId: "rosary", languageCode: "arc", key: "gloriaPatri"),
      "the two sourced editions have different line divisions and must keep their own reading aids")
    XCTAssertNil(PrayerPackStore.transliteration(
      bundleId: "oAntiphons", languageCode: "en", key: "gloriaPatri"))
  }

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
  /// deliberately absent from every bundle (see Shared/ARCHITECTURE.markdown) and must keep resolving
  /// from the hardcoded table even with both packs loaded.
  func testMainPrayerKeyStillResolvesFromHardcodedTableNotFromAPack() {
    let text = PrayerTranslations.get(languageCode: "en", key: .aveMaria)
    XCTAssertEqual(text, PrayerTranslations.english[.aveMaria])
  }

  func testMysteryPartialsMergeWithoutErasingEarlierFields() {
    let scripture = MysteryTextOverride(
      title: nil, fruit: nil, description: "Peshitta", transliteratedDescription: "ܦܫܝܛܬܐ")
    let laterMetadata = MysteryTextOverride(
      title: "The Mystery", fruit: "Faith", description: nil,
      transliteratedDescription: nil)

    XCTAssertEqual(
      scripture.merging(laterMetadata),
      MysteryTextOverride(
        title: "The Mystery", fruit: "Faith", description: "Peshitta",
        transliteratedDescription: "ܦܫܝܛܬܐ"))

    let replacement = scripture.merging(MysteryTextOverride(description: "Later Scripture"))
    XCTAssertEqual(replacement.description, "Later Scripture")
    XCTAssertNil(replacement.transliteratedDescription)
  }

  /// A source-language file may own only the Scripture reading. Its title and fruit resolve
  /// independently through the ordinary precedence, while its Syriac-script reading aid stays
  /// paired with that exact Peshitta description in the generated announcement step.
  func testAramaicDescriptionOnlyMysteryOverrideFallsThroughFieldByField() throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "peshitta\(Int.random(in: 1000...9999))"
    let imageKey = "\(id)_annunciation"
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)",
       "displayName": "Peshitta Test", "languages": ["arc", "en"],
       "hasCatalog": false, "images": []}
      """
    let aramaicDescription = "מלכותא דשמיא קרבת — מתי א׳ 18–25 (פשיטתא)"
    let syriacDescription = "ܡܠܟܘܬܐ ܕܫܡܝܐ ܩܪܒܬ — ܡܬܝ 1:18–25 (ܦܫܝܛܬܐ)"
    let aramaicContent = """
      {"prayers": {}, "mysteries": {"\(imageKey)": {
        "description": "\(aramaicDescription)",
        "transliteratedDescription": "\(syriacDescription)"
      }}}
      """
    let englishContent = """
      {"prayers": {}, "mysteries": {"\(imageKey)": {
        "title": "The Inherited Mystery", "fruit": "Inherited fruit",
        "description": "English fallback description"
      }}}
      """
    let devotion = """
      {"type": "rosary", "opening": [], "decades": {
        "ordinalNoun": "Mystery", "announceMystery": true,
        "entries": [{"imageKey": "\(imageKey)"}],
        "majorStep": {"title": "Major", "bodyKey": "paterNoster"},
        "minorStep": {"title": "Minor", "bodyKey": "aveMaria"},
        "minorCount": 1
      }, "closing": [], "hasClosingCross": false}
      """
    try PrayerPackStore.installPack(from: Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/arc.json", Data(aramaicContent.utf8)),
      ("content/en.json", Data(englishContent.utf8)),
      ("devotion.json", Data(devotion.utf8)),
    ]))
    defer { PrayerPackStore.removeInstalledPack(id: id) }

    let resolved = MysteryTranslations.get(languageCode: "arc", imageKey: imageKey)
    XCTAssertEqual(resolved.title, "The Inherited Mystery")
    XCTAssertEqual(resolved.fruit, "Inherited fruit")
    XCTAssertEqual(resolved.description, aramaicDescription)
    XCTAssertEqual(resolved.transliteratedDescription, syriacDescription)

    let announcement = try XCTUnwrap(PrayerEngine().buildSteps(for: Prayer(
      kind: .custom, languageCode: "arc", customDevotionId: id)).first)
    let fruitLabel = PrayerTranslations.get(languageCode: "arc", key: .fructusMysteriiLabel)
    XCTAssertEqual(announcement.title, "The Inherited Mystery")
    XCTAssertEqual(announcement.body, "\(aramaicDescription)\n\n\(fruitLabel): Inherited fruit")
    XCTAssertEqual(
      announcement.transliteratedBody,
      "\(syriacDescription)\n\n\(fruitLabel): Inherited fruit")
    let beads = PrayerEngine().buildSteps(for: Prayer(
      kind: .custom, languageCode: "arc", customDevotionId: id)).filter { !$0.isScripture }
    XCTAssertEqual(beads.count, 2)
    for (bead, key) in zip(beads, ["paterNoster", "aveMaria"]) {
      XCTAssertEqual(bead.transliteratedBody, PrayerPackStore.transliteration(
        bundleId: "rosary", languageCode: "arc", key: key))
      XCTAssertNotNil(bead.transliteratedBody)
    }
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

  /// These were formerly duplicated byte-for-byte in Assets.xcassets. They now have one shipped
  /// source of truth: their owning .prosaryprayer pack. Pin every key so removing the redundant
  /// catalog copies can never turn a Rosary/shared/Jesus Prayer illustration into a blank view.
  func testEveryFormerCatalogRasterResolvesFromAShippedPack() {
    let groups = ["joyful", "sorrowful", "glorious", "luminous"]
    let mysteries = groups.flatMap { group in
      (1...5).map { "\(group)_\(String(format: "%02d", $0))_\(Self.mysterySlug(group: group, number: $0))" }
    }
    let easternMysteries = mysteries.map { "eastern_\($0)" }
    let shared = [
      "christ_pantocrator", "crucifix", "eternal_rest", "glory_be", "jesus_portrait",
      "madonna_and_child", "our_father", "st_michael", "virtue_charity", "virtue_faith",
      "virtue_hope",
    ]
    let formerlyCatalogBacked = mysteries + easternMysteries + shared

    XCTAssertEqual(formerlyCatalogBacked.count, 51)
    for key in formerlyCatalogBacked {
      XCTAssertGreaterThan(
        PrayerPackStore.imageData(for: key)?.count ?? 0, 0,
        "missing pack-owned artwork for \(key)")
    }
    // The Jesus Prayer uses this key directly; it is intentionally covered above rather than
    // retaining a one-off duplicate in Assets.xcassets.
    XCTAssertTrue(formerlyCatalogBacked.contains("christ_pantocrator"))
  }

  func testImportedArtworkIsLazyAndDecodedOnlyOncePerCacheRevision() async throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "lazyart\(Int.random(in: 1000...9999))"
    let imageKey = "\(id)_image"
    let jpeg = try XCTUnwrap(PrayerPackStore.imageData(for: "joyful_01_annunciation"))
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)",
       "displayName": "Lazy Artwork", "languages": ["en"],
       "hasCatalog": false, "images": ["\(imageKey)"]}
      """
    let content = #"{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"#
    let devotion = """
      {"type": "steps", "steps": [
        {"title": "Example", "bodyKey": "exampleBody", "imageKey": "\(imageKey)"}
      ]}
      """
    let pack = Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/en.json", Data(content.utf8)),
      ("devotion.json", Data(devotion.utf8)),
      ("images/\(imageKey).jpg", jpeg),
    ])

    let readsBeforeInstall = PrayerPackStore.imageReadCountForTesting
    try PrayerPackStore.installPack(from: pack)
    defer { PrayerPackStore.removeInstalledPack(id: id) }

    // Loading metadata registers only a central-directory location; it does not inflate bytes.
    XCTAssertEqual(PrayerPackStore.imageReadCountForTesting, readsBeforeInstall)
    let resource = try XCTUnwrap(PrayerPackStore.imageResource(for: imageKey))

    _ = await PrayerArtwork.load(resource)
    let readsAfterFirstRender = PrayerPackStore.imageReadCountForTesting
    XCTAssertEqual(readsAfterFirstRender, readsBeforeInstall + 1)

    _ = await PrayerArtwork.load(resource)
    XCTAssertEqual(PrayerPackStore.imageReadCountForTesting, readsAfterFirstRender)
  }

  func testCorruptImportedArtworkFallsBackToTheCatalogPlaceholder() async throws {
    PrayerPackStore.installedPacksDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-test-packs-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: PrayerPackStore.installedPacksDirectory) }

    let id = "corruptart\(Int.random(in: 1000...9999))"
    let imageKey = "\(id)_image"
    let manifest = """
      {"schemaVersion": 1, "id": "\(id)", "kind": "\(id)",
       "displayName": "Corrupt Artwork", "languages": ["en"],
       "hasCatalog": false, "images": ["\(imageKey)"]}
      """
    let content = #"{"prayers": {"exampleBody": "Kyrie eleison."}, "mysteries": {}}"#
    let devotion = """
      {"type": "steps", "steps": [
        {"title": "Example", "bodyKey": "exampleBody", "imageKey": "\(imageKey)"}
      ]}
      """
    let imagePath = "images/\(imageKey).jpg"
    let pack = Self.storedZip([
      ("manifest.json", Data(manifest.utf8)),
      ("content/en.json", Data(content.utf8)),
      ("devotion.json", Data(devotion.utf8)),
      (imagePath, Data("not deflate data".utf8)),
    ], compressionMethods: [imagePath: 8], uncompressedSizes: [imagePath: 4_096])

    // Installation succeeds despite the deliberately invalid DEFLATE payload. That proves pack
    // loading indexed the image rather than inflating it eagerly; the failure is deferred until
    // the asynchronous artwork request, which then preserves the placeholder.
    try PrayerPackStore.installPack(from: pack)
    defer { PrayerPackStore.removeInstalledPack(id: id) }

    let resource = try XCTUnwrap(PrayerPackStore.imageResource(for: imageKey))
    let decoded = await PrayerArtwork.load(resource)
    XCTAssertNil(decoded)
    XCTAssertEqual(PrayerArtwork.fallbackAssetName, "cross_placeholder")
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
    XCTAssertEqual(
      PrayerPackStore.resolveBodyText(bundleId: id, languageCode: "en", key: "exampleBody"),
      "exampleBody")
  }

  func testInstallRejectsAPathTraversingBundleId() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-path-test-\(UUID().uuidString)", isDirectory: true)
    PrayerPackStore.installedPacksDirectory = root
      .appendingPathComponent("PrayerPacks", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let escapedName = "escaped\(Int.random(in: 1000...9999))"
    XCTAssertThrowsError(
      try PrayerPackStore.installPack(from: makeExamplePack(id: "../\(escapedName)")))
    XCTAssertFalse(FileManager.default.fileExists(
      atPath: root.appendingPathComponent("\(escapedName).prosaryprayer").path))
  }

  /// A days-type (multi-day) bundle decodes, installs, and prays its first day — the
  /// groundwork contract until per-favorite day progress ships (see ARCHITECTURE.markdown).
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

  /// An audio-bearing bundle (audio.json + Ogg Opus files — see ARCHITECTURE.markdown's "Audio
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
    XCTAssertEqual(
      PrayerPackStore.audioCacheKey(bundleId: id, file: "audio/en.opus"),
      "0b4c4a52-47")
    XCTAssertNil(PrayerPackStore.audioCacheKey(bundleId: id, file: "manifest.json"))
    XCTAssertNil(PrayerPackStore.audioData(bundleId: id, file: "manifest.json"))
    XCTAssertTrue(PrayerPackStore.audioTracks(for: "angelus").isEmpty)
    XCTAssertNil(PrayerPackStore.audioData(bundleId: "angelus", file: "audio/en.opus"))

    let extracted = PrayerPackStore.installedPacksDirectory
      .appendingPathComponent("extracted-\(id).opus")
    XCTAssertTrue(PrayerPackStore.extractAudioFile(
      bundleId: id, file: "audio/en.opus", to: extracted))
    XCTAssertEqual(try Data(contentsOf: extracted), opusBytes)
    XCTAssertFalse(PrayerPackStore.extractAudioFile(
      bundleId: id, file: "manifest.json", to: extracted))
  }

  func testZipReaderRejectsDuplicateAndDisagreeingNamesAndUnsupportedFlags() throws {
    let single = Self.storedZip([("manifest.json", Data("{}".utf8))])

    var disagreeingName = single
    disagreeingName[30] = Character("x").asciiValue!
    XCTAssertThrowsError(try MinimalZipReader(data: disagreeingName))

    XCTAssertThrowsError(try MinimalZipReader(data: Self.storedZip([
      ("same.json", Data("one".utf8)),
      ("same.json", Data("two".utf8)),
    ])))

    var unsupportedFlags = single
    let central = Self.centralDirectoryOffset(in: unsupportedFlags)
    Self.writeLE16(0x0010, at: 6, in: &unsupportedFlags)
    Self.writeLE16(0x0010, at: central + 8, in: &unsupportedFlags)
    XCTAssertThrowsError(try MinimalZipReader(data: unsupportedFlags))
  }

  func testZipReaderVerifiesPayloadCRCAndRejectsOverlappingEntries() throws {
    var corruptPayload = Self.storedZip([("value.txt", Data("trusted".utf8))])
    let payloadOffset = 30 + "value.txt".utf8.count
    corruptPayload[payloadOffset] ^= 0xff
    let corruptReader = try MinimalZipReader(data: corruptPayload)
    XCTAssertThrowsError(try corruptReader.contents(of: "value.txt"))

    var overlapping = Self.storedZip([
      ("a", Data([1])),
      ("b", Data([2])),
    ])
    let central = Self.centralDirectoryOffset(in: overlapping)
    // The first payload normally ends where the second local header begins. Advertising it as
    // the rest of the data area makes both validated local records occupy the same bytes.
    Self.writeLE32(33, at: 18, in: &overlapping)
    Self.writeLE32(33, at: 22, in: &overlapping)
    Self.writeLE32(33, at: central + 20, in: &overlapping)
    Self.writeLE32(33, at: central + 24, in: &overlapping)
    XCTAssertThrowsError(try MinimalZipReader(data: overlapping))
  }

  func testZipReaderRejectsCountAndExpandedSizeClaimsBeforeAllocation() {
    var excessiveCount = Self.storedZip([("a", Data())])
    let eocd = excessiveCount.count - 22
    Self.writeLE16(MinimalZipReader.maximumEntryCount + 1, at: eocd + 8, in: &excessiveCount)
    Self.writeLE16(MinimalZipReader.maximumEntryCount + 1, at: eocd + 10, in: &excessiveCount)
    XCTAssertThrowsError(try MinimalZipReader(data: excessiveCount))

    let claimedLarge = Self.storedZip(
      [("large.bin", Data([0]))],
      compressionMethods: ["large.bin": 8],
      uncompressedSizes: ["large.bin": MinimalZipReader.maximumEntryBytes + 1])
    XCTAssertThrowsError(try MinimalZipReader(data: claimedLarge))

    let claimedAggregate = Self.storedZip(
      [("a", Data([0])), ("b", Data([0])), ("c", Data([0]))],
      compressionMethods: ["a": 8, "b": 8, "c": 8],
      uncompressedSizes: ["a": 200 * 1024 * 1024,
                          "b": 200 * 1024 * 1024,
                          "c": 200 * 1024 * 1024])
    XCTAssertThrowsError(try MinimalZipReader(data: claimedAggregate))
  }

  func testInstallRejectsOversizedControlEntryBeforeInflation() {
    let claimedManifest = Self.storedZip(
      [("manifest.json", Data([0]))],
      compressionMethods: ["manifest.json": 8],
      uncompressedSizes: ["manifest.json": 8 * 1024 * 1024 + 1])
    XCTAssertThrowsError(try PrayerPackStore.installPack(from: claimedManifest))
  }

  func testUserSelectedOversizedArchiveIsRejectedBeforeReadingIt() throws {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("prosary-oversized-\(UUID().uuidString).prosaryprayer")
    XCTAssertTrue(FileManager.default.createFile(atPath: url.path, contents: nil))
    defer { try? FileManager.default.removeItem(at: url) }
    let output = try FileHandle(forWritingTo: url)
    try output.truncate(atOffset: UInt64(MinimalZipReader.maximumArchiveBytes + 1))
    try output.close()

    XCTAssertThrowsError(try PrayerPackStore.installPack(fromUserSelected: url))
  }

  /// Minimal stored (uncompressed) zip writer — enough for MinimalZipReader to consume.
  private static func storedZip(
    _ files: [(name: String, data: Data)],
    compressionMethods: [String: Int] = [:],
    uncompressedSizes: [String: Int] = [:]
  ) -> Data {
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
      let method = compressionMethods[name] ?? 0
      let uncompressedSize = uncompressedSizes[name] ?? data.count
      out += le32(0x0403_4B50) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
      out += le32(crc) + le32(data.count) + le32(uncompressedSize)
      out += le16(nameData.count) + le16(0) + nameData + data
    }
    for (i, (name, data)) in files.enumerated() {
      let nameData = Data(name.utf8)
      let crc = crc32(data)
      let method = compressionMethods[name] ?? 0
      let uncompressedSize = uncompressedSizes[name] ?? data.count
      central += le32(0x0201_4B50) + le16(20) + le16(20) + le16(0) + le16(method) + le16(0) + le16(0)
      central += le32(crc) + le32(data.count) + le32(uncompressedSize)
      central += le16(nameData.count) + le16(0) + le16(0) + le16(0) + le16(0)
      central += le32(0) + le32(offsets[i]) + nameData
    }
    let centralOffset = out.count
    out += central
    out += le32(0x0605_4B50) + le16(0) + le16(0) + le16(files.count) + le16(files.count)
    out += le32(central.count) + le32(centralOffset) + le16(0)
    return out
  }

  private static func centralDirectoryOffset(in zip: Data) -> Int {
    let offset = zip.count - 6
    return Int(zip[offset]) | (Int(zip[offset + 1]) << 8)
      | (Int(zip[offset + 2]) << 16) | (Int(zip[offset + 3]) << 24)
  }

  private static func writeLE16(_ value: Int, at offset: Int, in data: inout Data) {
    data[offset] = UInt8(value & 0xff)
    data[offset + 1] = UInt8((value >> 8) & 0xff)
  }

  private static func writeLE32(_ value: Int, at offset: Int, in data: inout Data) {
    data[offset] = UInt8(value & 0xff)
    data[offset + 1] = UInt8((value >> 8) & 0xff)
    data[offset + 2] = UInt8((value >> 16) & 0xff)
    data[offset + 3] = UInt8((value >> 24) & 0xff)
  }

  func testStationsPackProvidesItsImageData() {
    let data = PrayerPackStore.imageData(for: "station_01_condemned_to_death")
    XCTAssertGreaterThan(data?.count ?? 0, 0)
    // The scriptural variant's own scenes ship in the same pack.
    XCTAssertGreaterThan(PrayerPackStore.imageData(for: "scriptural_02_kiss_of_judas")?.count ?? 0, 0)
  }

  func testPackProvidesNoImageDataForAnUnknownKey() {
    XCTAssertNil(PrayerPackStore.imageData(for: "no_such_image_key"))
    XCTAssertNil(PrayerPackStore.imageResource(for: "no_such_image_key"))
    XCTAssertEqual(PrayerArtwork.fallbackAssetName, "cross_placeholder")
  }

  private static func mysterySlug(group: String, number: Int) -> String {
    let slugs: [String: [String]] = [
      "joyful": ["annunciation", "visitation", "nativity", "presentation", "finding_in_the_temple"],
      "sorrowful": ["agony_in_the_garden", "scourging_at_the_pillar", "crowning_with_thorns", "carrying_of_the_cross", "crucifixion"],
      "glorious": ["resurrection", "ascension", "descent_of_the_holy_spirit", "assumption", "coronation"],
      "luminous": ["baptism", "wedding_at_cana", "proclamation_of_the_kingdom", "transfiguration", "institution_of_the_eucharist"],
    ]
    return slugs[group]![number - 1]
  }

  // MARK: - Generic (bundle-driven) devotions

  func testTrisagionIsDiscoveredAsACustomDevotion() {
    XCTAssertTrue(PrayerPackStore.customDevotionIds().contains("trisagion"))
  }

  /// The Rosary's pack now ships a devotion.json (the engine builds the Rosary from it), but
  /// its manifest's builtinKind keeps it off the generic-devotion list — it backs the dedicated
  /// PrayerKind and must never appear in the devotion directory twice. The eight generic devotions
  /// appear in pack-load order.
  /// A devotion's name follows the prayer language, rites included — Erez's ask: with his rite
  /// as the default prayer language, the Trisagion card reads קדישת; plain Hebrew reads
  /// טריסאגיון; a language the manifest does not name falls back to the UI-language behavior.
  func testDisplayNameFollowsThePrayerLanguage() {
    let saved = UserDefaults.standard.string(forKey: "defaultLanguageCode")
    defer {
      if let saved { UserDefaults.standard.set(saved, forKey: "defaultLanguageCode") }
      else { UserDefaults.standard.removeObject(forKey: "defaultLanguageCode") }
    }

    UserDefaults.standard.set("he-x-gamliel", forKey: "defaultLanguageCode")
    XCTAssertEqual(PrayerPackStore.info(for: "trisagion")?.localizedDisplayName, "קדישת")

    UserDefaults.standard.set("he", forKey: "defaultLanguageCode")
    XCTAssertEqual(PrayerPackStore.info(for: "trisagion")?.localizedDisplayName, "טריסאגיון")

    // A rite falls to its base when the bundle only names the base language.
    UserDefaults.standard.set("he-x-gamliel", forKey: "defaultLanguageCode")
    XCTAssertEqual(PrayerPackStore.info(for: "divineMercyChaplet")?.localizedDisplayName,
                   PrayerPackStore.info(for: "divineMercyChaplet")?.displayNameByLanguage["he"])

    // Latin names nothing in the manifest, so the UI language decides as before.
    UserDefaults.standard.set("la", forKey: "defaultLanguageCode")
    XCTAssertEqual(PrayerPackStore.info(for: "trisagion")?.localizedDisplayName, "Trisagion")
  }

  func testCustomDevotionIdsAreTheGenericDevotionsInLoadOrder() {
    // A prefix assertion, not equality: user-installed bundles (repo.* imports) legitimately
    // append after the built-ins on a dev machine, and shipped order is what this test pins.
    let shipped = ["angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
                   "divineMercyChaplet", "trisagion", "oAntiphons"]
    XCTAssertEqual(Array(PrayerPackStore.customDevotionIds().prefix(shipped.count)), shipped)
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
    // The bundle names its forms now (Byzantine first = the default, Syriac second); the
    // default form must remain the authored six steps, byte-identical.
    XCTAssertEqual(definition?.variants?.map(\.id), ["byzantine", "syriac"])
    let steps = definition?.resolvedSteps(variantId: nil).steps ?? []
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
