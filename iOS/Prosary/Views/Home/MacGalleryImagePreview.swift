#if os(macOS)
import AppKit
import SwiftUI

/// Preview traffic uses the same host, redirect and byte checks as the chosen image.
struct MacGalleryImagePreview: View {
  let result: MacGalleryImageSearch.Result
  @State private var image: NSImage?

  var body: some View {
    Group {
      if let image { Image(nsImage: image).resizable().scaledToFit() }
      else {
        Rectangle().fill(.quaternary)
          .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
      }
    }
    .task(id: result.thumbnailURL) {
      image = nil
      do {
        let loaded = try await MacGalleryImagePreviewLoader.shared.image(for: result)
        guard !Task.isCancelled else { return }
        image = loaded
      } catch { /* The result remains selectable if its preview is unavailable. */ }
    }
  }
}

@MainActor
final class MacGalleryImagePreviewLoader {
  static let shared = MacGalleryImagePreviewLoader()
  private let service: MacGalleryImageSearch
  private let cache = NSCache<NSURL, NSImage>()

  init(service: MacGalleryImageSearch = MacGalleryImageSearch()) {
    self.service = service
    cache.countLimit = 24
    cache.totalCostLimit = 8 * 1024 * 1024
  }

  func image(for result: MacGalleryImageSearch.Result) async throws -> NSImage {
    try Task.checkCancellation()
    if let image = cache.object(forKey: result.thumbnailURL as NSURL) { return image }
    let data = try await service.thumbnailData(result)
    try Task.checkCancellation()
    let worker = Task.detached(priority: .utility) { try MacPrayerGalleryImageStore.previewBitmap(data) }
    let bitmap = try await withTaskCancellationHandler(operation: { try await worker.value }, onCancel: { worker.cancel() })
    try Task.checkCancellation()
    let image = NSImage(cgImage: bitmap.image, size: NSSize(width: bitmap.image.width, height: bitmap.image.height))
    cache.setObject(image, forKey: result.thumbnailURL as NSURL, cost: bitmap.image.width * bitmap.image.height * 4)
    return image
  }
}
#endif
