#if os(iOS)
import SwiftUI
import UIKit

/// A native text paragraph supplies justification and inline verse markers without
/// changing the sourced Scripture or the reader's selected typeface.
struct BibleBookVerseText: View {
  let text: String
  let label: String?
  let languageCode: String
  let isRightToLeft: Bool
  let typefaces: PrayerTypography.Typefaces
  @ScaledMetric(relativeTo: .body) private var bodyScale = 1.0

  var body: some View {
    let face = PrayerTypography.scriptureFace(
      script: PrayerTypography.resolvedScript(text: text, languageCode: languageCode), typefaces: typefaces)
    BibleJustifiedParagraph(text: text, label: label,
      font: UIFont(name: face.name, size: face.size * bodyScale) ?? .systemFont(ofSize: face.size * bodyScale),
      isRightToLeft: isRightToLeft)
      .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct BibleJustifiedParagraph: UIViewRepresentable {
  let text: String
  let label: String?
  let font: UIFont
  let isRightToLeft: Bool

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
    view.accessibilityLabel = [label, text].compactMap { $0 }.joined(separator: " ")
  }

  func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
    guard let width = proposal.width, width.isFinite else { return nil }
    let size = uiView.sizeThatFits(CGSize(width: max(1, width), height: .greatestFiniteMagnitude))
    return CGSize(width: width, height: ceil(size.height))
  }

  var attributedText: NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .justified
    paragraph.baseWritingDirection = isRightToLeft ? .rightToLeft : .leftToRight
    paragraph.lineSpacing = 5
    let attributes: [NSAttributedString.Key: Any] = [
      .font: font, .foregroundColor: UIColor.label, .paragraphStyle: paragraph
    ]
    let result = NSMutableAttributedString(string: "")
    if let label, !label.isEmpty {
      // Isolate the printed address from surrounding RTL text and keep it with the
      // first word. The marker is presentation; the source string stays untouched.
      var marker = attributes
      marker[.font] = UIFont.systemFont(ofSize: font.pointSize * 0.65)
      marker[.baselineOffset] = font.pointSize * 0.25
      marker[.foregroundColor] = UIColor.secondaryLabel
      result.append(NSAttributedString(string: "\u{2068}" + label + "\u{2069}\u{00A0}", attributes: marker))
    }
    result.append(NSAttributedString(string: text, attributes: attributes))
    return result
  }
}
#endif
