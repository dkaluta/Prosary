import Foundation
import CoreGraphics
#if os(iOS)
import SwiftUI
#endif

/// Budgets the columns against this prayer window, including the session's complete bead track.
/// Artwork can yield some width; the readable prayer column never does.
struct PrayerFlowLayout {
  static let readerViewportMaximumWidth: CGFloat = 640
  static let readerHorizontalInset: CGFloat = 16
  let available: CGSize
  let compactHeight: Bool
  let accessoryWidth: CGFloat?

  var hasRoomForSingleMinorColumn: Bool { available.height >= 300 }
  var spacing: CGFloat { compactHeight ? 16 : 24 }
  var leadingPadding: CGFloat { compactHeight ? 16 : 40 }
  var trailingPadding: CGFloat { compactHeight ? 12 : 28 }
  var topPadding: CGFloat { compactHeight ? 8 : 16 }
  var minimumTextWidth: CGFloat { 320 }
  var contentWidth: CGFloat { min(available.width, 1100) }
  var columnOverhead: CGFloat {
    leadingPadding + trailingPadding + spacing * (accessoryWidth == nil ? 1 : 2)
      + (accessoryWidth ?? 0)
  }
  var wideImageSide: CGFloat {
    let preferred = compactHeight ? 190 : min(320, max(160, available.height - 32))
    return max(0, min(preferred, available.height - topPadding,
      contentWidth - columnOverhead - minimumTextWidth))
  }
  var isWide: Bool {
    contentWidth >= (compactHeight ? 700 : 860)
      && wideImageSide >= (compactHeight ? 120 : 160)
  }
  var requiredWideWidth: CGFloat { columnOverhead + wideImageSide + minimumTextWidth }
}

/// A camera can be active inside the safe area. Keep custom prayer content within the largest
/// unobscured rectangle; region frames already include the system's interactive margins.
enum PrayerReservedRegionLayout {
  static func intersects(_ region: CGRect, bounds: CGRect) -> Bool {
    let overlap = region.intersection(bounds)
    return !overlap.isNull && overlap.width > 0 && overlap.height > 0
  }

  static func unobscuredFrame(in bounds: CGRect, avoiding occlusions: [CGRect]) -> CGRect {
    guard bounds.width > 0, bounds.height > 0 else { return bounds }
    var candidates = [bounds]
    for occlusion in occlusions where intersects(occlusion, bounds: bounds) {
      candidates = candidates.flatMap { candidate in
        guard intersects(occlusion, bounds: candidate) else { return [candidate] }
        let overlap = candidate.intersection(occlusion)
        // These rectangles intentionally overlap: a later occlusion may make either a
        // full-width or full-height alternative the largest usable viewport.
        return [
          CGRect(x: candidate.minX, y: candidate.minY,
            width: candidate.width, height: overlap.minY - candidate.minY),
          CGRect(x: candidate.minX, y: overlap.maxY,
            width: candidate.width, height: candidate.maxY - overlap.maxY),
          CGRect(x: candidate.minX, y: candidate.minY,
            width: overlap.minX - candidate.minX, height: candidate.height),
          CGRect(x: overlap.maxX, y: candidate.minY,
            width: candidate.maxX - overlap.maxX, height: candidate.height)
        ].filter { $0.width > 0 && $0.height > 0 }
      }
    }
    return candidates.max { $0.width * $0.height < $1.width * $1.height }
      ?? CGRect(origin: bounds.origin, size: .zero)
  }
}

#if os(iOS)
/// Reuse inside each native arrangement pane or custom screen so active camera regions
/// never cover its content. Physical geometry stays fixed while content keeps its locale.
@available(iOS 27.1, *)
struct ReservedRegionAvoidingContent<Content: View>: View {
  @Environment(\.layoutDirection) private var layoutDirection
  @ViewBuilder var content: (CGSize) -> Content

  var body: some View {
    GeometryReader { geometry in
      let occlusions = geometry.reservedRegions(kind: .occlusion,
        layoutDirectionBehavior: .fixed).filter(\.isActive).map(\.frame)
      let frame = PrayerReservedRegionLayout.unobscuredFrame(
        in: CGRect(origin: .zero, size: geometry.size), avoiding: occlusions)
      content(frame.size)
        .environment(\.layoutDirection, layoutDirection)
        .frame(width: frame.width, height: frame.height)
        .clipped()
        .position(x: frame.midX, y: frame.midY)
    }
    .environment(\.layoutDirection, .leftToRight)
  }
}
#endif
