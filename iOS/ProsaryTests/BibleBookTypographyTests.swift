#if os(iOS)
import SwiftUI
import UIKit
import XCTest
@testable import Prosary

@MainActor
final class BibleBookTypographyTests: XCTestCase {
  func testInlineRangeMarkerPreservesTheEntireSourceAndWritingDirection() {
    let source = "Fixture paragraph with its exact punctuation.\nA second source line."
    for rtl in [false, true] {
      let paragraph = BibleJustifiedParagraph(text: source, label: "12–13",
        font: .systemFont(ofSize: 19), isRightToLeft: rtl)
      let content = paragraph.attributedText
      let sourceRange = (content.string as NSString).range(of: source)
      XCTAssertEqual(content.attributedSubstring(from: sourceRange).string, source)
      XCTAssertEqual(content.string, "\u{2068}12–13\u{2069}\u{00A0}" + source)
      let style = content.attribute(.paragraphStyle, at: sourceRange.location, effectiveRange: nil) as? NSParagraphStyle
      XCTAssertEqual(style?.alignment, .justified)
      XCTAssertEqual(style?.baseWritingDirection, rtl ? .rightToLeft : .leftToRight)
      XCTAssertGreaterThan(content.attribute(.baselineOffset, at: 0, effectiveRange: nil) as? CGFloat ?? 0, 0)
      XCTAssertNil(content.attribute(.baselineOffset, at: sourceRange.location, effectiveRange: nil))
    }
  }

  func testJoinedVersesKeepSourceTextAndIndependentInlineMarkers() {
    let parts = [BibleBookTextPart(text: "First exact verse.", label: "1"), BibleBookTextPart(text: "Second exact verse!", label: "2–3")]
    let value = BibleJustifiedParagraph(text: "", label: nil, font: .systemFont(ofSize: 19),
      isRightToLeft: false, parts: parts).attributedText
    XCTAssertEqual(value.string, "\u{2068}1\u{2069}\u{00A0}First exact verse. \u{2068}2–3\u{2069}\u{00A0}Second exact verse!")
    XCTAssertFalse(value.string.contains("\n"))
  }

  func testUnnumberedScriptureDoesNotAcquireAnInventedMarker() {
    let source = "Unnumbered fixture."
    let content = BibleJustifiedParagraph(text: source, label: nil,
      font: .systemFont(ofSize: 19), isRightToLeft: false).attributedText
    XCTAssertEqual(content.string, source)
    XCTAssertNil(content.attribute(.baselineOffset, at: 0, effectiveRange: nil))
  }

  func testJustifiedParagraphRemeasuresForDynamicTypeAndNarrowColumns() {
    let source = String(repeating: "A fixture paragraph with several words for wrapping. ", count: 10)
    func height(width: CGFloat, size: DynamicTypeSize) -> CGFloat {
      let host = UIHostingController(rootView: BibleBookVerseText(text: source, label: "1",
        languageCode: "en", isRightToLeft: false, typefaces: .init()).dynamicTypeSize(size))
      return host.sizeThatFits(in: CGSize(width: width, height: 10_000)).height
    }
    let baseline = height(width: 400, size: .large)
    XCTAssertGreaterThan(baseline, 0)
    XCTAssertGreaterThan(height(width: 200, size: .large), baseline)
    XCTAssertGreaterThan(height(width: 400, size: .accessibility3), baseline)
  }
}
#endif
