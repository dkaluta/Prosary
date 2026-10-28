import SwiftUI
#if os(iOS)
import UIKit
typealias BibleParagraphFont = UIFont
#elseif os(macOS)
import AppKit
typealias BibleParagraphFont = NSFont
#endif

#if os(iOS) || os(macOS)

struct BibleBookTextPart {
  let text: String
  let label: String?
}

/// A native text paragraph supplies justification and inline verse markers without
/// changing the sourced Scripture or the reader's selected typeface.
struct BibleBookVerseText: View {
  let text: String
  let label: String?
  let languageCode: String
  let isRightToLeft: Bool
  let typefaces: PrayerTypography.Typefaces
  var parts: [BibleBookTextPart]? = nil
  @ScaledMetric(relativeTo: .body) private var bodyScale = 1.0

  var body: some View {
    let face = PrayerTypography.scriptureFace(
      script: PrayerTypography.resolvedScript(text: text, languageCode: languageCode), typefaces: typefaces)
    BibleJustifiedParagraph(text: text, label: label,
      font: BibleParagraphFont(name: face.name, size: face.size * bodyScale) ?? .systemFont(ofSize: face.size * bodyScale),
      isRightToLeft: isRightToLeft, parts: parts)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

#if os(iOS)
struct BibleJustifiedParagraph: UIViewRepresentable {
  let text: String
  let label: String?
  let font: UIFont
  let isRightToLeft: Bool
  var parts: [BibleBookTextPart]? = nil

  func makeUIView(context: Context) -> UITextView {
    let view = UITextView()
    view.isEditable = false
    view.isSelectable = true
    view.isScrollEnabled = false
    view.backgroundColor = .clear
    view.textContainerInset = .zero
    view.textContainer.lineFragmentPadding = 0
    view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    return view
  }

  func updateUIView(_ view: UITextView, context: Context) {
    let content = attributedText
    if view.attributedText != content { view.attributedText = content }
    view.semanticContentAttribute = isRightToLeft ? .forceRightToLeft : .forceLeftToRight
    view.accessibilityLabel = content.string
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite else { return nil }
    let size = uiView.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: ceil(size.height))
  }

  var attributedText: NSAttributedString { BibleParagraphFormatting.attributed(text: text, label: label, font: font, isRightToLeft: isRightToLeft, parts: parts) }
}
#elseif os(macOS)
struct BibleJustifiedParagraph: NSViewRepresentable {
  let text: String
  let label: String?
  let font: NSFont
  let isRightToLeft: Bool
  var parts: [BibleBookTextPart]? = nil

  func makeNSView(context: Context) -> NSTextView {
    let view = NSTextView()
    view.isEditable = false
    view.isSelectable = true
    view.drawsBackground = false
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.isHorizontallyResizable = false
    view.isVerticallyResizable = true
    return view
  }
  func updateNSView(_ view: NSTextView, context: Context) {
    if view.attributedString() != attributedText { view.textStorage?.setAttributedString(attributedText) }
  }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite else { return nil }
    nsView.textContainer?.containerSize = CGSize(width: max(1, width), height: .greatestFiniteMagnitude)
    nsView.layoutManager?.ensureLayout(for: nsView.textContainer!)
    return CGSize(width: width, height: ceil(nsView.layoutManager?.usedRect(for: nsView.textContainer!).height ?? 0) + 2)
  }
  var attributedText: NSAttributedString { BibleParagraphFormatting.attributed(text: text, label: label, font: font, isRightToLeft: isRightToLeft, parts: parts) }
}
#endif

enum BibleParagraphFormatting {
  static func attributed(text: String, label: String?, font: BibleParagraphFont, isRightToLeft: Bool, parts: [BibleBookTextPart]?) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .justified
    paragraph.baseWritingDirection = isRightToLeft ? .rightToLeft : .leftToRight
    paragraph.lineSpacing = 5
    #if os(iOS)
    let foreground = UIColor.label
    let secondary = UIColor.secondaryLabel
    #else
    let foreground = NSColor.labelColor
    let secondary = NSColor.secondaryLabelColor
    #endif
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: foreground, .paragraphStyle: paragraph
    ]
    let result = NSMutableAttributedString(string: "")
    for (index, part) in (parts ?? [BibleBookTextPart(text: text, label: label)]).enumerated() {
      if index > 0 { result.append(NSAttributedString(string: " ", attributes: attributes)) }
      if let label = part.label, !label.isEmpty {
        // Isolate the printed address from surrounding RTL text and keep it with the
        // first word. The marker is presentation; the source string stays untouched.
        var marker = attributes
        marker[.font] = BibleParagraphFont.systemFont(ofSize: font.pointSize * 0.65)
        marker[.baselineOffset] = font.pointSize * 0.25
        marker[.foregroundColor] = secondary
        result.append(NSAttributedString(string: "\u{2068}" + label + "\u{2069}\u{00A0}", attributes: marker))
      }
      result.append(NSAttributedString(string: part.text, attributes: attributes))
    }
    return result
  }
}
#endif
