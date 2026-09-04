//
//  PrayerArtwork.swift
//  Prosary
//
//  Placeholder-first, asynchronous rendering for bundle artwork. ZIP inflation and ImageIO
//  decode run away from MainActor; a small pressure-sensitive cache retains recent decoded
//  images. The pack store itself holds only file-backed archive indexes.
//

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI

final class DecodedPrayerArtwork: @unchecked Sendable {
  let image: CGImage
  let cost: Int

  nonisolated init(image: CGImage) {
    self.image = image
    cost = image.bytesPerRow * image.height
  }
}

@MainActor
enum PrayerArtwork {
  static let fallbackAssetName = "cross_placeholder"

  private static let decodedImages: NSCache<NSString, DecodedPrayerArtwork> = {
    let cache = NSCache<NSString, DecodedPrayerArtwork>()
    cache.countLimit = 8
    cache.totalCostLimit = 32 * 1_024 * 1_024
    return cache
  }()

  static func cached(cacheKey: String) -> DecodedPrayerArtwork? {
    decodedImages.object(forKey: cacheKey as NSString)
  }

  static func load(_ resource: PrayerPackImageResource) async -> DecodedPrayerArtwork? {
    if let cached = cached(cacheKey: resource.cacheKey) { return cached }

    let decoded = await Task.detached(priority: .userInitiated) {
      decode(resource)
    }.value
    PrayerPackStore.recordImageRead()
    guard !Task.isCancelled, let decoded else { return nil }
    decodedImages.setObject(
      decoded, forKey: resource.cacheKey as NSString, cost: decoded.cost)
    return decoded
  }

  /// ImageIO applies EXIF orientation and bounds unusually large imported artwork before it ever
  /// becomes a decoded bitmap. 2048 px is comfortably above the app's largest rendered prayer
  /// image (including Retina backing scale) without allowing one custom image to dominate memory.
  nonisolated private static func decode(
    _ resource: PrayerPackImageResource
  ) -> DecodedPrayerArtwork? {
    guard let data = try? resource.contents(),
          let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: 2_048,
      kCGImageSourceShouldCacheImmediately: true,
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    else { return nil }
    return DecodedPrayerArtwork(image: image)
  }
}

struct PrayerArtworkView: View {
  let imageKey: String

  @State private var loaded: DecodedPrayerArtwork?
  @State private var loadedCacheKey: String?

  var body: some View {
    let resource = PrayerPackStore.imageResource(for: imageKey)
    let cacheKey = resource?.cacheKey
    let current = loadedCacheKey == cacheKey ? loaded : nil
    let artwork = current ?? cacheKey.flatMap(PrayerArtwork.cached(cacheKey:))

    Group {
      if let artwork {
        Image(decorative: artwork.image, scale: 1)
          .resizable()
      } else {
        Image(decorative: PrayerArtwork.fallbackAssetName)
          .resizable()
      }
    }
    .task(id: cacheKey) {
      guard let resource else {
        loaded = nil
        loadedCacheKey = nil
        return
      }
      let decoded = await PrayerArtwork.load(resource)
      guard !Task.isCancelled else { return }
      loaded = decoded
      loadedCacheKey = resource.cacheKey
    }
  }
}
