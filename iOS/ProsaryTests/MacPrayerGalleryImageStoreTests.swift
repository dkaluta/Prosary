#if os(macOS)
import AppKit
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import Prosary

@MainActor
final class MacPrayerGalleryImageStoreTests: XCTestCase {
  func testTestStorageNeverResolvesProductionDirectory() {
    let policy = MacGalleryImageStoragePolicy(isTesting: true, testRoot: URL(fileURLWithPath: "/fixture"))
    XCTAssertEqual(policy.directory { XCTFail("Tests must not inspect production storage"); return .applicationSupportDirectory }.path, "/fixture/GalleryImages")
    let production = MacGalleryImageStoragePolicy(isTesting: false, testRoot: URL(fileURLWithPath: "/unused"))
    XCTAssertEqual(production.directory { URL(fileURLWithPath: "/local/gallery") }.path, "/local/gallery")
  }

  func testNormalizationPreservesAspectRatioCreditsAndSmallCachedPreview() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let credit = MacPrayerGalleryImageStore.Attribution(title: "A painting", author: "Artist",
      license: "Public domain", sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Painting.jpg"))
    try await fixture.store.setImage(data: png(width: 3200, height: 1600), for: "angelus", attribution: credit)
    let record = try XCTUnwrap(fixture.store.record(for: "angelus"))
    XCTAssertEqual(record.pixelWidth, 2048)
    XCTAssertEqual(record.pixelHeight, 1024)
    XCTAssertEqual(record.attribution, credit)
    let preview = try XCTUnwrap(fixture.store.image(for: "angelus"))
    XCTAssertEqual(preview.size, NSSize(width: 512, height: 256))
    XCTAssertEqual(fixture.store.revision, 1)
    let reopened = MacPrayerGalleryImageStore(directory: fixture.directory)
    XCTAssertEqual(reopened.record(for: "angelus"), record)
    XCTAssertEqual(reopened.image(for: "angelus")?.size, preview.size)
    let files = try FileManager.default.contentsOfDirectory(at: fixture.directory, includingPropertiesForKeys: nil)
    XCTAssertEqual(files.count, 1, "Each prayer has its own image directory")
    let image = try XCTUnwrap(reopened.imageURL(for: "angelus"))
    XCTAssertEqual(image.deletingLastPathComponent(), files.first)
    XCTAssertNotNil(image.lastPathComponent.range(of: "^[0-9a-f-]{14}7[0-9a-f-]{21}\\.jpg$", options: .regularExpression))
    XCTAssertLessThan(try Data(contentsOf: image).count, MacPrayerGalleryImageStore.maximumJPEGBytes)
    let manifest = try Data(contentsOf: image.deletingLastPathComponent().appendingPathComponent("record.json"))
    XCTAssertFalse(String(decoding: manifest, as: UTF8.self).contains("\"jpeg\""), "Images are separate JPEG files, not base64 metadata")
  }

  func testImportAndResetNeverModifySourceOrAnotherDevotionsCover() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let source = fixture.root.appendingPathComponent("source.png")
    let original = try png(width: 300, height: 100)
    try original.write(to: source)
    try await fixture.store.importImage(from: source, for: "angelus")
    try await fixture.store.setImage(data: original, for: "../a/path/../../rosary")
    let files = try FileManager.default.contentsOfDirectory(at: fixture.directory, includingPropertiesForKeys: nil)
    XCTAssertEqual(files.count, 2)
    XCTAssertTrue(files.allSatisfy { $0.deletingLastPathComponent() == fixture.directory && $0.lastPathComponent.count == 64 })
    try fixture.store.remove(for: "angelus")
    XCTAssertFalse(fixture.store.hasOverride(for: "angelus"))
    XCTAssertTrue(fixture.store.hasOverride(for: "../a/path/../../rosary"))
    XCTAssertEqual(try Data(contentsOf: source), original)
    XCTAssertFalse(MacPrayerGalleryImageStore(directory: fixture.directory).hasOverride(for: "angelus"))
  }

  func testRejectedAndCancelledChangesKeepTheExistingCover() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    try await fixture.store.setImage(data: png(width: 300, height: 100), for: "angelus")
    let original = fixture.store.record(for: "angelus")
    for data in [Data("not an image".utf8), Data(count: MacPrayerGalleryImageStore.maximumInputBytes + 1)] {
      do { try await fixture.store.setImage(data: data, for: "angelus"); XCTFail("Invalid image accepted") }
      catch { XCTAssertEqual(fixture.store.record(for: "angelus"), original) }
    }
    let data = try png(width: 100, height: 300)
    let operation = Task { try await fixture.store.setImage(data: data, for: "angelus") }
    operation.cancel()
    do { try await operation.value; XCTFail("Cancelled update committed") } catch is CancellationError { }
    XCTAssertEqual(fixture.store.record(for: "angelus"), original)
    XCTAssertEqual(fixture.store.revision, 1)
  }

  func testCorruptRecordCannotSupplyAnotherDevotionsImageOrUnsafeSourceLink() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let attribution = MacPrayerGalleryImageStore.Attribution(sourceURL: URL(string: "javascript:alert(1)"))
    try await fixture.store.setImage(data: png(width: 30, height: 20), for: "angelus", attribution: attribution)
    XCTAssertNil(fixture.store.record(for: "angelus")?.attribution?.sourceURL)
    let file = try XCTUnwrap(fixture.store.imageURL(for: "angelus")).deletingLastPathComponent().appendingPathComponent("record.json")
    var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
    var record = try XCTUnwrap(stored["record"] as? [String: Any])
    record["devotionID"] = "other-prayer"
    stored["record"] = record
    try JSONSerialization.data(withJSONObject: stored).write(to: file)
    XCTAssertNil(MacPrayerGalleryImageStore(directory: fixture.directory).image(for: "angelus"))
  }

  func testNewFilenameCarriesUUIDv7TimestampAndReplacementCommitsACompletePair() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let name = MacPrayerGalleryImageStore.newImageFilename(now: now)
    let uuid = String(name.dropLast(4))
    XCTAssertNotNil(UUID(uuidString: uuid))
    XCTAssertEqual(UInt64(uuid.replacingOccurrences(of: "-", with: "").prefix(12), radix: 16), 1_700_000_000_000)
    XCTAssertEqual(Array(uuid)[14], "7")
    XCTAssertTrue("89ab".contains(Array(uuid)[19]))
    XCTAssertNotEqual(name, MacPrayerGalleryImageStore.newImageFilename(now: now))

    let fixture = Fixture()
    defer { fixture.close() }
    try await fixture.store.setImage(data: png(width: 100, height: 300), for: "angelus")
    let first = try XCTUnwrap(fixture.store.imageURL(for: "angelus"))
    try await fixture.store.setImage(data: png(width: 300, height: 100), for: "angelus")
    let second = try XCTUnwrap(fixture.store.imageURL(for: "angelus"))
    XCTAssertNotEqual(first, second)
    XCTAssertFalse(FileManager.default.fileExists(atPath: first.path))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: second.deletingLastPathComponent().path).count, 2)
    XCTAssertEqual(MacPrayerGalleryImageStore(directory: fixture.directory).record(for: "angelus")?.pixelWidth, 300)
  }

  func testLegacyInlineJPEGRecordMigratesWithoutLosingTheImageOrCredit() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    let credit = MacPrayerGalleryImageStore.Attribution(title: "Painting", author: "Artist")
    try await fixture.store.setImage(data: png(width: 300, height: 100), for: "angelus", attribution: credit)
    let image = try XCTUnwrap(fixture.store.imageURL(for: "angelus"))
    let folder = image.deletingLastPathComponent()
    let jpeg = try Data(contentsOf: image)
    var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("record.json"))) as? [String: Any])
    legacy["version"] = 1
    legacy["imageFilename"] = nil
    legacy["jpeg"] = jpeg.base64EncodedString()
    let legacyURL = fixture.directory.appendingPathComponent(folder.lastPathComponent + ".json")
    try JSONSerialization.data(withJSONObject: legacy).write(to: legacyURL)
    try FileManager.default.removeItem(at: folder)

    let reopened = MacPrayerGalleryImageStore(directory: fixture.directory)
    XCTAssertEqual(reopened.record(for: "angelus")?.attribution, credit)
    XCTAssertEqual(reopened.record(for: "angelus")?.pixelWidth, 300)
    XCTAssertNotNil(reopened.imageURL(for: "angelus"))
    XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
  }

  func testARecordCannotReadAnImageOutsideItsOwnFolder() async throws {
    let fixture = Fixture()
    defer { fixture.close() }
    try await fixture.store.setImage(data: png(width: 30, height: 20), for: "angelus")
    let image = try XCTUnwrap(fixture.store.imageURL(for: "angelus"))
    let manifest = image.deletingLastPathComponent().appendingPathComponent("record.json")
    var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
    stored["imageFilename"] = "../outside.jpg"
    try JSONSerialization.data(withJSONObject: stored).write(to: manifest)
    XCTAssertNil(MacPrayerGalleryImageStore(directory: fixture.directory).image(for: "angelus"))
  }

  private func png(width: Int, height: Int) throws -> Data {
    let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.6, alpha: 0.5))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    let output = NSMutableData()
    let destination = try XCTUnwrap(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
    CGImageDestinationAddImage(destination, try XCTUnwrap(context.makeImage()), nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return output as Data
  }

  @MainActor private final class Fixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let directory: URL
    let store: MacPrayerGalleryImageStore
    init() {
      directory = root.appendingPathComponent("GalleryImages", isDirectory: true)
      store = MacPrayerGalleryImageStore(directory: directory)
      try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    func close() { try? FileManager.default.removeItem(at: root) }
  }
}
#endif
