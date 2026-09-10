import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// Relative to the prayer text, so moving the artwork out of the scroller doesn't move the
/// reader to another part of the prayer. This belongs to the session, not a layout branch.
struct PrayerReadingLocation: Equatable {
  var fraction: CGFloat = 0
  var isAtStart = true

  mutating func record(offset: CGFloat, textTop: CGFloat, textHeight: CGFloat) {
    guard textHeight > 0 else { return }
    isAtStart = offset <= max(0, textTop)
    fraction = min(1, max(0, (offset - textTop) / textHeight))
  }

  func offset(textTop: CGFloat, textHeight: CGFloat, maximumOffset: CGFloat) -> CGFloat {
    guard !isAtStart else { return 0 }
    return min(max(0, maximumOffset), max(0, textTop + fraction * textHeight))
  }
}

@MainActor
final class PrayerReadingPosition {
  var location = PrayerReadingLocation()
  private(set) var step: Int?
  var owner: UUID?

  func start(step: Int) {
    guard self.step != step else { return }
    self.step = step
    location = PrayerReadingLocation()
  }
}

/// The SwiftUI scroll views remain native on every supported OS, including iOS 17/macOS 14.
/// A marker on the text observes their geometry and restores the same body-relative position
/// after wrapping or changing columns. It never replaces a scroll delegate or handles input.
struct PrayerReadingAnchor {
  let position: PrayerReadingPosition
  let step: Int
}

private struct ReadingGeometry: Equatable {
  let viewport: CGSize
  let content: CGSize
  let textTop: CGFloat
  let textHeight: CGFloat
}

#if canImport(UIKit)
extension PrayerReadingAnchor: UIViewRepresentable {
  func makeUIView(context: Context) -> PrayerReadingAnchorView { PrayerReadingAnchorView() }
  func updateUIView(_ view: PrayerReadingAnchorView, context: Context) {
    view.configure(position: position, step: step)
  }
}

final class PrayerReadingAnchorView: UIView {
  private let identity = UUID()
  private var position: PrayerReadingPosition?
  private var step = 0
  private weak var scrollView: UIScrollView?
  private var observations: [NSKeyValueObservation] = []
  private var geometry: ReadingGeometry?
  private var restoreGeneration = 0
  private var isRestoring = false

  func configure(position: PrayerReadingPosition, step: Int) {
    let changedStep = self.position !== position || self.step != step
    self.position = position
    self.step = step
    position.start(step: step)
    attach()
    if changedStep { restore() }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    if window == nil { observations = []; scrollView = nil }
    else { attach() }
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    attach()
    changed()
  }

  private func attach() {
    guard window != nil else { return }
    var ancestor = superview
    while let view = ancestor, !(view is UIScrollView) { ancestor = view.superview }
    guard let scroll = ancestor as? UIScrollView, scrollView !== scroll else { return }
    scrollView = scroll
    position?.owner = identity
    observations = [
      scroll.observe(\.contentOffset, options: [.new]) { [weak self] _, _ in self?.changed() },
      scroll.observe(\.contentSize, options: [.new]) { [weak self] _, _ in self?.changed() },
      scroll.observe(\.bounds, options: [.new]) { [weak self] _, _ in self?.changed() }
    ]
    restore()
  }

  private func metrics(_ scroll: UIScrollView) -> ReadingGeometry {
    ReadingGeometry(viewport: scroll.bounds.size, content: scroll.contentSize,
      textTop: convert(bounds, to: scroll).minY + scroll.adjustedContentInset.top,
      textHeight: bounds.height)
  }

  private func changed() {
    guard let scroll = scrollView, let position, position.owner == identity, position.step == step else { return }
    let current = metrics(scroll)
    if geometry != current { restore(); return }
    guard !isRestoring else { return }
    position.location.record(offset: scroll.contentOffset.y + scroll.adjustedContentInset.top,
      textTop: current.textTop, textHeight: current.textHeight)
  }

  private func restore() {
    restoreGeneration += 1
    let generation = restoreGeneration
    isRestoring = true
    DispatchQueue.main.async { [weak self] in
      guard let self, generation == restoreGeneration,
            let scroll = scrollView, let position,
            position.owner == identity, position.step == step else { return }
      let current = metrics(scroll)
      guard current.textHeight > 0, current.viewport.height > 0 else { isRestoring = false; return }
      geometry = current
      let maximum = scroll.contentSize.height - scroll.bounds.height
        + scroll.adjustedContentInset.top + scroll.adjustedContentInset.bottom
      let target = position.location.offset(textTop: current.textTop, textHeight: current.textHeight,
        maximumOffset: maximum) - scroll.adjustedContentInset.top
      scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target), animated: false)
      isRestoring = false
    }
  }
}
#else
extension PrayerReadingAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> PrayerReadingAnchorView { PrayerReadingAnchorView() }
  func updateNSView(_ view: PrayerReadingAnchorView, context: Context) {
    view.configure(position: position, step: step)
  }
}

final class PrayerReadingAnchorView: NSView {
  private let identity = UUID()
  private var position: PrayerReadingPosition?
  private var step = 0
  private weak var scrollView: NSScrollView?
  private var observations: [NSObjectProtocol] = []
  private var geometry: ReadingGeometry?
  private var restoreGeneration = 0
  private var isRestoring = false

  func configure(position: PrayerReadingPosition, step: Int) {
    let changedStep = self.position !== position || self.step != step
    self.position = position
    self.step = step
    position.start(step: step)
    attach()
    if changedStep { restore() }
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if window == nil { detach() }
    else { attach() }
  }

  override func layout() {
    super.layout()
    attach()
    changed()
  }

  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    changed()
  }

  private func attach() {
    guard window != nil, let scroll = enclosingScrollView, scrollView !== scroll else { return }
    detach()
    scrollView = scroll
    position?.owner = identity
    scroll.contentView.postsBoundsChangedNotifications = true
    scroll.contentView.postsFrameChangedNotifications = true
    for name in [NSView.boundsDidChangeNotification, NSView.frameDidChangeNotification] {
      observations.append(NotificationCenter.default.addObserver(forName: name, object: scroll.contentView,
        queue: .main) { [weak self] _ in MainActor.assumeIsolated { self?.changed() } })
    }
    restore()
  }

  private func detach() {
    observations.forEach(NotificationCenter.default.removeObserver)
    observations = []
    scrollView = nil
  }

  private func metrics(_ scroll: NSScrollView) -> ReadingGeometry? {
    guard let document = scroll.documentView else { return nil }
    let rect = document.convert(bounds, from: self)
    return ReadingGeometry(viewport: scroll.contentView.bounds.size, content: document.bounds.size,
      textTop: document.isFlipped ? rect.minY : document.bounds.height - rect.maxY,
      textHeight: bounds.height)
  }

  private func changed() {
    guard let scroll = scrollView, let position, position.owner == identity, position.step == step,
          let current = metrics(scroll) else { return }
    if geometry != current { restore(); return }
    guard !isRestoring else { return }
    let offset = scroll.documentView?.isFlipped == true ? scroll.contentView.bounds.minY
      : current.content.height - scroll.contentView.bounds.maxY
    position.location.record(offset: offset, textTop: current.textTop, textHeight: current.textHeight)
  }

  private func restore() {
    restoreGeneration += 1
    let generation = restoreGeneration
    isRestoring = true
    DispatchQueue.main.async { [weak self] in
      guard let self, generation == restoreGeneration,
            let scroll = scrollView, let position,
            position.owner == identity, position.step == step,
            let current = metrics(scroll), current.textHeight > 0, current.viewport.height > 0 else { return }
      geometry = current
      let maximum = max(0, current.content.height - current.viewport.height)
      let target = position.location.offset(textTop: current.textTop, textHeight: current.textHeight,
        maximumOffset: maximum)
      let nativeTarget = scroll.documentView?.isFlipped == true ? target : maximum - target
      scroll.contentView.scroll(to: CGPoint(x: scroll.contentView.bounds.minX, y: nativeTarget))
      scroll.reflectScrolledClipView(scroll.contentView)
      isRestoring = false
    }
  }
}
#endif
