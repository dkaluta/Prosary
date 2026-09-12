#if os(macOS)
import AppKit
import CryptoKit
import ImageIO
import Observation
import UniformTypeIdentifiers

nonisolated struct MacGalleryImageStoragePolicy {
  let isTesting: Bool
  let testRoot: URL

  func directory(production: () -> URL) -> URL {
    isTesting ? testRoot.appendingPathComponent("GalleryImages", isDirectory: true) : production()
  }
}

/// Local Gallery presentation only. A per-prayer folder holds UUIDv7 JPEGs and an atomic
/// record pointing to the current image. Pack defaults remain inside their source packs.
@MainActor @Observable
final class MacPrayerGalleryImageStore {
  static let shared = MacPrayerGalleryImageStore()
  nonisolated static let maximumInputBytes = 20 * 1024 * 1024
  nonisolated static let maximumJPEGBytes = 2 * 1024 * 1024
  nonisolated static let maximumDimension = 2048

  nonisolated struct Attribution: Codable, Equatable, Sendable {
    var title: String? = nil
    var author: String? = nil
    var license: String? = nil
    var sourceURL: URL? = nil
    var licenseURL: URL? = nil
  }

  nonisolated struct Record: Codable, Equatable, Sendable {
    let devotionID: String
    let pixelWidth: Int
    let pixelHeight: Int
    let attribution: Attribution?
  }

  nonisolated enum Failure: Error, LocalizedError {
    case invalidImage, imageTooLarge, invalidID

    var errorDescription: String? {
      switch self {
      case .invalidImage: String(localized: "macGallery.image.invalid", defaultValue: "Choose a supported image file.")
      case .imageTooLarge: String(localized: "macGallery.image.tooLarge", defaultValue: "This image is too large. Choose a smaller image.")
      case .invalidID: String(localized: "macGallery.image.unavailable", defaultValue: "This prayer’s image could not be changed.")
      }
    }
  }

  nonisolated private struct Stored: Codable, Sendable {
    let version: Int
    let record: Record
    let imageFilename: String?
    let jpeg: Data?
  }

  private final class Cached: NSObject {
    let value: Stored
    let image: NSImage
    init(value: Stored, image: NSImage) { self.value = value; self.image = image }
  }

  private(set) var revision = 0
  let directory: URL
  @ObservationIgnored private let cache = NSCache<NSString, Cached>()
  @ObservationIgnored private var operations: [String: UUID] = [:]

  init(directory: URL? = nil) {
    self.directory = directory ?? MacGalleryImageStoragePolicy(
      isTesting: ProsaryRuntimeEnvironment.isTesting,
      testRoot: FileManager.default.temporaryDirectory.appendingPathComponent("Prosary-Gallery-Tests-\(ProcessInfo.processInfo.processIdentifier)-\(UUID())", isDirectory: true)
    ).directory {
      URL.applicationSupportDirectory.appendingPathComponent("Prosary/GalleryImages", isDirectory: true)
    }
    cache.countLimit = 32
    cache.totalCostLimit = 32 * 1024 * 1024
  }

  func image(for devotionID: String) -> NSImage? { _ = revision; return load(devotionID)?.image }
  func record(for devotionID: String) -> Record? { _ = revision; return load(devotionID)?.value.record }
  func hasOverride(for devotionID: String) -> Bool { record(for: devotionID) != nil }

  func setImage(data: Data, for devotionID: String, attribution: Attribution? = nil) async throws {
    _ = try recordURL(for: devotionID)
    let ticket = UUID()
    operations[devotionID] = ticket
    defer { if operations[devotionID] == ticket { operations[devotionID] = nil } }
    let worker = Task.detached(priority: .userInitiated) { try Self.normalized(data) }
    let normalized = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    try Task.checkCancellation()
    guard operations[devotionID] == ticket else { throw CancellationError() }
    let record = Record(devotionID: devotionID, pixelWidth: normalized.width,
      pixelHeight: normalized.height, attribution: Self.cleaned(attribution))
    _ = try commit(jpeg: normalized.data, record: record)
    cache.removeObject(forKey: devotionID as NSString)
    revision += 1
  }

  func importImage(from url: URL, for devotionID: String) async throws {
    _ = try recordURL(for: devotionID)
    let ticket = UUID()
    operations[devotionID] = ticket
    defer { if operations[devotionID] == ticket { operations[devotionID] = nil } }
    let scoped = url.startAccessingSecurityScopedResource()
    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
    let worker = Task.detached(priority: .userInitiated) {
      try Task.checkCancellation()
      guard url.isFileURL else { throw Failure.invalidImage }
      return try Self.read(url, limit: Self.maximumInputBytes)
    }
    let data = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    try Task.checkCancellation()
    guard operations[devotionID] == ticket else { throw CancellationError() }
    try await setImage(data: data, for: devotionID)
  }

  func remove(for devotionID: String) throws {
    let folder = try imageDirectory(for: devotionID)
    let legacy = try legacyURL(for: devotionID)
    operations[devotionID] = nil
    // Delete the old record first, so a failed cleanup cannot reveal a previous override.
    if FileManager.default.fileExists(atPath: legacy.path) { try FileManager.default.removeItem(at: legacy) }
    if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) }
    cache.removeObject(forKey: devotionID as NSString)
    revision += 1
  }

  private func recordURL(for devotionID: String) throws -> URL {
    try imageDirectory(for: devotionID).appendingPathComponent("record.json")
  }

  private func imageDirectory(for devotionID: String) throws -> URL {
    guard !devotionID.isEmpty, devotionID.utf8.count <= 1024 else { throw Failure.invalidID }
    let key = SHA256.hash(data: Data(devotionID.utf8)).map { String(format: "%02x", $0) }.joined()
    return directory.appendingPathComponent(key, isDirectory: true)
  }

  private func legacyURL(for devotionID: String) throws -> URL {
    let key = try imageDirectory(for: devotionID).lastPathComponent
    return directory.appendingPathComponent(key + ".json", isDirectory: false)
  }

  /// RFC 9562: 48-bit Unix milliseconds, version 7, RFC variant, and 74 random bits.
  nonisolated static func newImageFilename(now: Date = .now) -> String {
    let random = UUID().uuid
    var bytes = withUnsafeBytes(of: random) { Array($0) }
    let milliseconds = UInt64(max(0, now.timeIntervalSince1970 * 1000)) & 0x0000_ffff_ffff_ffff
    for index in 0..<6 { bytes[index] = UInt8((milliseconds >> ((5 - index) * 8)) & 0xff) }
    bytes[6] = (bytes[6] & 0x0f) | 0x70
    bytes[8] = (bytes[8] & 0x3f) | 0x80
    let hex = bytes.map { String(format: "%02x", $0) }.joined()
    return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20)).jpg"
  }

  nonisolated private static func validImageFilename(_ filename: String) -> Bool {
    filename.range(of: "^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\\.jpg$",
                   options: .regularExpression) != nil
  }

  private func commit(jpeg: Data, record: Record) throws -> Stored {
    let folder = try imageDirectory(for: record.devotionID)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard try folder.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink != true else { throw Failure.invalidID }
    let filename = Self.newImageFilename()
    let image = folder.appendingPathComponent(filename)
    let value = Stored(version: 2, record: record, imageFilename: filename, jpeg: nil)
    let encoded = try JSONEncoder().encode(value)
    guard encoded.count <= 128 * 1024 else { throw Failure.invalidImage }
    var committed = false
    defer { if !committed { try? FileManager.default.removeItem(at: image) } }
    try jpeg.write(to: image, options: .atomic)
    // Readers see either the previous complete pair or this complete pair, never half a save.
    try encoded.write(to: folder.appendingPathComponent("record.json"), options: .atomic)
    committed = true
    if let oldFiles = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
      for old in oldFiles where old.lastPathComponent != filename && Self.validImageFilename(old.lastPathComponent) {
        try? FileManager.default.removeItem(at: old)
      }
    }
    if let legacy = try? legacyURL(for: record.devotionID) { try? FileManager.default.removeItem(at: legacy) }
    return value
  }

  func imageURL(for devotionID: String) -> URL? {
    guard let value = load(devotionID)?.value, let filename = value.imageFilename,
          Self.validImageFilename(filename) else { return nil }
    return try? imageDirectory(for: devotionID).appendingPathComponent(filename)
  }

  private func load(_ devotionID: String) -> Cached? {
    if let value = cache.object(forKey: devotionID as NSString) { return value }
    guard let url = try? recordURL(for: devotionID) else { return nil }
    var stored: Stored
    let jpeg: Data
    if FileManager.default.fileExists(atPath: url.path) {
      guard Self.isRegularFile(url),
            let data = try? Self.read(url, limit: 128 * 1024),
            let decoded = try? JSONDecoder().decode(Stored.self, from: data), decoded.version == 2,
            let filename = decoded.imageFilename, Self.validImageFilename(filename),
            Self.isRegularFile(url.deletingLastPathComponent().appendingPathComponent(filename)),
            let image = try? Self.read(url.deletingLastPathComponent().appendingPathComponent(filename), limit: Self.maximumJPEGBytes)
      else { return nil }
      stored = decoded
      jpeg = image
    } else {
      guard let legacy = try? legacyURL(for: devotionID), Self.isRegularFile(legacy),
            let data = try? Self.read(legacy, limit: Self.maximumJPEGBytes * 2),
            let decoded = try? JSONDecoder().decode(Stored.self, from: data), decoded.version == 1,
            decoded.record.devotionID == devotionID, let oldJPEG = decoded.jpeg,
            let normalized = try? Self.normalized(oldJPEG) else { return nil }
      let record = Record(devotionID: devotionID, pixelWidth: normalized.width, pixelHeight: normalized.height,
                          attribution: Self.cleaned(decoded.record.attribution))
      // The previous, small JPEG record migrates once on first access, without changing
      // observable state during view rendering or touching any original prayer pack.
      guard let migrated = try? commit(jpeg: normalized.data, record: record) else { return nil }
      stored = migrated
      jpeg = normalized.data
    }
    guard stored.record.devotionID == devotionID,
          stored.record.pixelWidth > 0, stored.record.pixelWidth <= Self.maximumDimension,
          stored.record.pixelHeight > 0, stored.record.pixelHeight <= Self.maximumDimension,
          Self.isSDRsRGBJPEG(jpeg),
          Self.cleaned(stored.record.attribution) == stored.record.attribution,
          let cgImage = Self.thumbnail(jpeg, dimension: 512) else { return nil }
    let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    let result = Cached(value: stored, image: image)
    cache.setObject(result, forKey: devotionID as NSString, cost: cgImage.width * cgImage.height * 4)
    return result
  }

  nonisolated private static func isRegularFile(_ url: URL) -> Bool {
    guard let attributes = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]) else { return false }
    return attributes.isRegularFile == true && attributes.isSymbolicLink != true
  }

  nonisolated static func read(_ url: URL, limit: Int) throws -> Data {
    let file = try FileHandle(forReadingFrom: url)
    defer { try? file.close() }
    let data = try file.read(upToCount: limit + 1) ?? Data()
    guard data.count <= limit else { throw Failure.imageTooLarge }
    return data
  }

  nonisolated private static func cleaned(_ value: Attribution?) -> Attribution? {
    guard let value else { return nil }
    func text(_ value: String?) -> String? {
      guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
      return String(trimmed.prefix(2048))
    }
    func link(_ url: URL?) -> URL? { url?.scheme == "https" && url?.host != nil && url?.user == nil && url?.password == nil ? url : nil }
    return Attribution(title: text(value.title), author: text(value.author), license: text(value.license),
      sourceURL: link(value.sourceURL), licenseURL: link(value.licenseURL))
  }

  nonisolated private static func thumbnail(_ data: Data, dimension: Int) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          let type = CGImageSourceGetType(source),
          [UTType.jpeg, .png, .heic, .heif, .tiff, .gif, .bmp, .webP].contains(where: { $0.identifier == type as String }),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= 32768, height <= 32768, width * height <= 120_000_000 else { return nil }
    guard let decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, [
      kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: dimension, kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceDecodeRequest: kCGImageSourceDecodeToSDR
    ] as CFDictionary),
      let sRGB = CGColorSpace(name: CGColorSpace.sRGB),
      let context = CGContext(data: nil, width: decoded.width, height: decoded.height, bitsPerComponent: 8,
        bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
    // ImageIO tone maps HDR before conversion. The named SDR destination also lets
    // ColorSync convert wide-gamut input; an 8-bit device RGB context cannot define sRGB.
    // Flatten here so previews have the same opaque white background as saved covers.
    let bounds = CGRect(x: 0, y: 0, width: decoded.width, height: decoded.height)
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(bounds)
    context.draw(decoded, in: bounds)
    return context.makeImage()
  }

  /// CGImage is immutable; the small decoded bitmap can safely leave the image worker.
  nonisolated struct PreviewBitmap: @unchecked Sendable {
    let image: CGImage
  }

  nonisolated static func previewBitmap(_ data: Data, dimension: Int = 256) throws -> PreviewBitmap {
    try Task.checkCancellation()
    guard data.count <= maximumInputBytes else { throw Failure.imageTooLarge }
    guard let image = thumbnail(data, dimension: min(512, max(1, dimension))) else { throw Failure.invalidImage }
    try Task.checkCancellation()
    return PreviewBitmap(image: image)
  }

  nonisolated static func normalized(_ data: Data) throws -> (data: Data, width: Int, height: Int) {
    try Task.checkCancellation()
    guard data.count <= maximumInputBytes else { throw Failure.imageTooLarge }
    guard let image = thumbnail(data, dimension: maximumDimension) else { throw Failure.invalidImage }
    for quality in [0.85, 0.65, 0.45] {
      try Task.checkCancellation()
      let output = NSMutableData()
      guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw Failure.invalidImage }
      // Start a new image from the SDR pixels, never copy an image source.
      CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
      guard CGImageDestinationFinalize(destination) else { throw Failure.invalidImage }
      let data = try taggedJPEG(output as Data)
      if data.count <= maximumJPEGBytes {
        guard isSDRsRGBJPEG(data) else { throw Failure.invalidImage }
        return (data, image.width, image.height)
      }
    }
    throw Failure.imageTooLarge
  }

  /// ImageIO normally substitutes EXIF ColorSpace=1 for the sRGB ICC profile.
  /// Keep the new JPEG pixels, replace application metadata with the actual profile,
  /// and stop parsing at the scan so compressed pixel bytes are never rewritten.
  nonisolated private static func taggedJPEG(_ encoded: Data) throws -> Data {
    guard encoded.starts(with: [0xff, 0xd8]),
          let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let profile = colorSpace.copyICCData() as Data?,
          !profile.isEmpty, profile.count <= 65519 else { throw Failure.invalidImage }
    let length = profile.count + 16 // segment length includes its two bytes and 14-byte ICC header
    var result = Data([0xff, 0xd8, 0xff, 0xe2, UInt8(length >> 8), UInt8(length & 0xff)])
    result.append(Data("ICC_PROFILE\0".utf8))
    result.append(contentsOf: [1, 1]) // one profile chunk
    result.append(profile)
    var offset = 2
    while offset + 4 <= encoded.count {
      guard encoded[offset] == 0xff else { throw Failure.invalidImage }
      let marker = encoded[offset + 1]
      if marker == 0xda {
        result.append(encoded[offset...])
        return result
      }
      let segmentLength = Int(encoded[offset + 2]) << 8 | Int(encoded[offset + 3])
      guard segmentLength >= 2, offset + 2 + segmentLength <= encoded.count else { throw Failure.invalidImage }
      let end = offset + 2 + segmentLength
      // Preserve the JFIF envelope (APP0), coding tables, and frame structure.
      if !(0xe1...0xef).contains(marker), marker != 0xfe { result.append(encoded[offset..<end]) }
      offset = end
    }
    throw Failure.invalidImage
  }

  /// Validate stored output without requesting HDR expansion or trusting a profile label.
  nonisolated static func isSDRsRGBJPEG(_ data: Data) -> Bool {
    guard !data.isEmpty, data.count <= maximumJPEGBytes,
          let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
          CGImageSourceGetType(source) as String? == UTType.jpeg.identifier,
          CGImageSourceGetCount(source) == 1,
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int,
          width > 0, height > 0, width <= maximumDimension, height <= maximumDimension,
          properties[kCGImagePropertyDepth] as? Int == 8,
          properties[kCGImagePropertyProfileName] is String,
          CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeHDRGainMap) == nil,
          let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCache: false] as CFDictionary),
          image.bitsPerComponent == 8, !image.bitmapInfo.contains(.floatComponents),
          let colorSpace = image.colorSpace, colorSpace.name == CGColorSpace.sRGB else { return false }
    if #available(macOS 15, *),
       CGImageSourceCopyAuxiliaryDataInfoAtIndex(source, 0, kCGImageAuxiliaryDataTypeISOGainMap) != nil { return false }
    return true
  }
}
#endif
