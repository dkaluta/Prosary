import XCTest
@testable import Prosary
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@MainActor
final class PrayerReadingAnchorTests: XCTestCase {
  func testNativeScrollCapturesAndRestoresTheBodyPositionAfterRewrapping() async {
    let position = PrayerReadingPosition()
    let harness = Harness(position: position, width: 400, textTop: 300, textHeight: 1200)
    defer { harness.close() }
    await settle()
    harness.scroll(to: 600)
    XCTAssertEqual(position.location.fraction, 0.25, accuracy: 0.01)

    harness.resize(width: 700, textTop: 16, textHeight: 800)
    await settle()
    XCTAssertEqual(harness.offset, 216, accuracy: 1)
    XCTAssertEqual(position.location.fraction, 0.25, accuracy: 0.01)
  }

  func testAReplacementScrollViewClaimsTheReadingPositionFromTheOldLayout() async {
    let position = PrayerReadingPosition()
    let narrow = Harness(position: position, width: 400, textTop: 300, textHeight: 1200)
    defer { narrow.close() }
    await settle()
    narrow.scroll(to: 600)

    let wide = Harness(position: position, width: 700, textTop: 16, textHeight: 800)
    defer { wide.close() }
    await settle()
    XCTAssertEqual(wide.offset, 216, accuracy: 1)
    narrow.scroll(to: 0)
    XCTAssertEqual(position.location.fraction, 0.25, accuracy: 0.01,
      "A disappearing layout cannot overwrite its replacement's reading position")
  }

  func testANewPrayerStepResetsTheNativeScrollView() async {
    let position = PrayerReadingPosition()
    let harness = Harness(position: position, width: 400, textTop: 300, textHeight: 1200)
    defer { harness.close() }
    await settle()
    harness.scroll(to: 600)
    harness.marker.configure(position: position, step: 1)
    await settle()
    XCTAssertEqual(harness.offset, 0, accuracy: 1)
  }

  private func settle() async {
    for _ in 0..<3 {
      await withCheckedContinuation { continuation in
        DispatchQueue.main.async { continuation.resume() }
      }
    }
  }

  #if canImport(UIKit)
  @MainActor
  private final class Harness {
    let window: UIWindow
    let scrollView = UIScrollView()
    let marker = PrayerReadingAnchorView()
    var offset: CGFloat { scrollView.contentOffset.y }

    init(position: PrayerReadingPosition, width: CGFloat, textTop: CGFloat, textHeight: CGFloat) {
      window = UIWindow(frame: CGRect(x: 0, y: 0, width: width, height: 300))
      scrollView.frame = window.bounds
      scrollView.contentInsetAdjustmentBehavior = .never
      marker.configure(position: position, step: 0)
      scrollView.addSubview(marker)
      window.addSubview(scrollView)
      resize(width: width, textTop: textTop, textHeight: textHeight)
    }

    func resize(width: CGFloat, textTop: CGFloat, textHeight: CGFloat) {
      scrollView.frame = CGRect(x: 0, y: 0, width: width, height: 300)
      scrollView.contentSize = CGSize(width: width, height: textTop + textHeight + 16)
      marker.frame = CGRect(x: 0, y: textTop, width: width, height: textHeight)
      marker.setNeedsLayout()
      marker.layoutIfNeeded()
    }

    func scroll(to offset: CGFloat) { scrollView.setContentOffset(CGPoint(x: 0, y: offset), animated: false) }
    func close() { scrollView.removeFromSuperview() }
  }
  #else
  private final class FlippedDocument: NSView {
    override var isFlipped: Bool { true }
  }

  @MainActor
  private final class Harness {
    let window: NSWindow
    let scrollView = NSScrollView()
    let document = FlippedDocument()
    let marker = PrayerReadingAnchorView()
    var offset: CGFloat { scrollView.contentView.bounds.minY }

    init(position: PrayerReadingPosition, width: CGFloat, textTop: CGFloat, textHeight: CGFloat) {
      window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: width, height: 300),
        styleMask: .borderless, backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      marker.configure(position: position, step: 0)
      document.addSubview(marker)
      scrollView.documentView = document
      window.contentView = scrollView
      resize(width: width, textTop: textTop, textHeight: textHeight)
    }

    func resize(width: CGFloat, textTop: CGFloat, textHeight: CGFloat) {
      scrollView.setFrameSize(CGSize(width: width, height: 300))
      document.setFrameSize(CGSize(width: width, height: textTop + textHeight + 16))
      marker.frame = CGRect(x: 0, y: textTop, width: width, height: textHeight)
      scrollView.tile()
      marker.needsLayout = true
      marker.layoutSubtreeIfNeeded()
    }

    func scroll(to offset: CGFloat) {
      scrollView.contentView.scroll(to: CGPoint(x: 0, y: offset))
      scrollView.reflectScrolledClipView(scrollView.contentView)
    }
    func close() { window.close() }
  }
  #endif
}
