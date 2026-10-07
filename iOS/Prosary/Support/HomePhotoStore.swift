import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The picker grants access only to the chosen photo. Home retains a small private copy.
enum HomePhotoStore {
  static let key = "homePhotoPath"
  enum PhotoError: Error { case invalidImage }

  static var directory: URL {
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("HomePhotos", isDirectory: true)
  }

  static func ownedURL(_ path: String) -> URL? {
    guard !path.isEmpty else { return nil }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    guard url.deletingLastPathComponent() == directory.standardizedFileURL,
          url.pathExtension == "jpg" else { return nil }
    return url
  }

  static func install(_ data: Data) throws -> String {
    guard data.count <= 40 * 1024 * 1024,
          let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1600
          ] as CFDictionary) else { throw PhotoError.invalidImage }
    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
    else { throw PhotoError.invalidImage }
    CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { throw PhotoError.invalidImage }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(UUID().uuidString + ".jpg")
    try (output as Data).write(to: url, options: .atomic)
    return url.path
  }

  static func image(_ path: String) -> CGImage? {
    guard let url = ownedURL(path), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
  }

  static func remove(_ path: String) throws {
    guard let url = ownedURL(path), FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.removeItem(at: url)
  }
}
