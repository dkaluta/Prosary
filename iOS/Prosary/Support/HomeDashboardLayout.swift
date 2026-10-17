import Foundation

/// Count columns from the readable space inside the current native pane, including padding.
enum HomeDashboardLayout {
  static let maximumContentWidth: CGFloat = 1200
  static let minimumCardWidth: CGFloat = 340
  static let spacing: CGFloat = 16
  static let horizontalPadding: CGFloat = 40

  static func columnCount(availableWidth: CGFloat) -> Int {
    let width = min(maximumContentWidth, max(0, availableWidth - horizontalPadding))
    return max(1, Int((width + spacing) / (minimumCardWidth + spacing)))
  }
}
