import Foundation

/// Budgets the columns against this prayer window, including the session's complete bead track.
/// Artwork can yield some width; the readable prayer column never does.
struct PrayerFlowLayout {
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
