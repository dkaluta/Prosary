import Foundation
import SwiftUI

/// Count columns from the readable space inside the current native pane, including padding.
enum HomeDashboardLayout {
  static let maximumContentWidth: CGFloat = 1200
  static let minimumCardWidth: CGFloat = 340
  static let spacing: CGFloat = 16
  static let horizontalPadding: CGFloat = 40

  static func columnCount(availableWidth: CGFloat, isHorizontalPane: Bool = false) -> Int {
    if isHorizontalPane { return 1 }
    let width = min(maximumContentWidth, max(0, availableWidth - horizontalPadding))
    return max(1, Int((width + spacing) / (minimumCardWidth + spacing)))
  }

  static func cardWidth(contentWidth: CGFloat, columnCount: Int) -> CGFloat {
    let count = max(1, columnCount)
    return max(0, (contentWidth - CGFloat(count - 1) * spacing) / CGFloat(count))
  }

  /// Side-by-side fold panes are columns; stacked fold panes retain top-to-bottom order.
  static func paneItems<Item>(_ ordered: [Item], paneIndex: Int, isHorizontal: Bool) -> [Item] {
    guard paneIndex == 0 || paneIndex == 1 else { return [] }
    if isHorizontal {
      return ordered.enumerated().compactMap { index, item in index % 2 == paneIndex ? item : nil }
    }
    let split = (ordered.count + 1) / 2
    return paneIndex == 0 ? Array(ordered.prefix(split)) : Array(ordered.dropFirst(split))
  }

  /// Place each saved card at the shortest column, breaking ties from the leading edge.
  static func cardFrames(heights: [CGFloat], contentWidth: CGFloat, columnCount: Int) -> [CGRect] {
    let count = max(1, columnCount)
    let width = cardWidth(contentWidth: contentWidth, columnCount: count)
    var nextY = Array(repeating: CGFloat.zero, count: count)
    return heights.map { height in
      let column = nextY.indices.min { nextY[$0] < nextY[$1] } ?? 0
      let frame = CGRect(x: CGFloat(column) * (width + spacing), y: nextY[column],
        width: width, height: max(0, height))
      nextY[column] = frame.maxY + spacing
      return frame
    }
  }
}

/// Flat children preserve card identity and accessibility order while each column grows freely.
struct HomeCardColumnsLayout: Layout {
  let columnCount: Int

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let proposedWidth = proposal.width ?? HomeDashboardLayout.minimumCardWidth
    let width = proposedWidth.isFinite ? max(0, proposedWidth) : HomeDashboardLayout.maximumContentWidth
    let frames = cardFrames(width: width, subviews: subviews)
    return CGSize(width: width, height: frames.map(\.maxY).max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let frames = cardFrames(width: bounds.width, subviews: subviews)
    for (index, frame) in frames.enumerated() {
      subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        anchor: .topLeading, proposal: ProposedViewSize(width: frame.width, height: frame.height))
    }
  }

  private func cardFrames(width: CGFloat, subviews: Subviews) -> [CGRect] {
    let cardWidth = HomeDashboardLayout.cardWidth(contentWidth: width, columnCount: columnCount)
    let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: cardWidth, height: nil)).height }
    return HomeDashboardLayout.cardFrames(heights: heights, contentWidth: width, columnCount: columnCount)
  }
}
