import SwiftUI

func biblePrimaryLabel(_ unit: ReadingTextVerse, displayChapter: Int, edition: ReadingTextEdition, script: String) -> String {
  guard unit.chapter != displayChapter else { return unit.verseLabel }
  func number(_ value: Int) -> String { ScriptureChapterHeading.number(value, language: edition.languageCode, script: script) }
  let verses = unit.endVerse.map { $0 > unit.verse ? number(unit.verse) + "–" + number($0) : number(unit.verse) } ?? number(unit.verse)
  return number(unit.chapter) + ":" + verses
}

func biblePrintedLabel(_ label: String) -> String {
  String(format: bibleLabel("printedLabel", "Printed label: %1$@"), locale: UILanguage.locale, "\u{2068}" + label + "\u{2069}")
}

func bibleVerseChoiceLabel(_ block: BibleDisplayBlock, display: BibleDisplayChapter, edition: ReadingTextEdition, script: String, usesPrintedLabels: Bool = false) -> String {
  let label = block.printedLabel ?? block.unit?.verseLabel ?? ""
  let displayedLabel = usesPrintedLabels ? biblePrintedLabel(label) : label
  if let occurrence = display.occurrence(of: block) {
    return String(format: bibleLabel("occurrence", "%1$@ — occurrence %2$d"), locale: UILanguage.locale, displayedLabel, occurrence)
  }
  if usesPrintedLabels { return displayedLabel }
  // Primary navigation always keeps the numeric address, even when print differs.
  return block.unit.map { biblePrimaryLabel($0, displayChapter: display.chapter.chapter, edition: edition, script: script) } ?? label
}

/// Presentation blocks do not alter the primary address index. Notes, printed-label
/// annotations, source headings and colophons remain outside selectable scripture.
struct BibleSourceBlockList: View {
  let edition: ReadingTextEdition
  let display: BibleDisplayChapter
  let script: String
  var canonicalReference: String? = nil
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 16) {
      let heading = ScriptureChapterHeading(chapter: display.chapter.chapter, edition: edition, script: script)
      Group {
        if let canonicalReference { Text(verbatim: canonicalReference).bold() }
        else { Text(verbatim: heading.label).bold() + Text(verbatim: " \(heading.number)") }
      }
        .font(sourceFont(canonicalReference ?? heading.text))
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("readings.chapter.\(display.chapter.chapter)")
      ForEach(display.blocks) { block in
        VStack(alignment: .leading, spacing: 8) {
          if block.isScripture {
            let text = block.unit?.displayedText(script: script, edition: edition) ?? block.text
            if canonicalReference != nil, let label = block.printedLabel ?? block.unit?.verseLabel {
              Text(biblePrintedLabel(label)).font(.caption).foregroundStyle(.secondary).textSelection(.disabled)
                .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
                .accessibilityIdentifier("bible.printedLabel.\(block.id)")
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              if canonicalReference == nil, let label = block.unit.map({ biblePrimaryLabel($0, displayChapter: display.chapter.chapter, edition: edition, script: script) }) ?? block.printedLabel {
                Text(verbatim: label).font(.caption).foregroundStyle(.secondary).fixedSize()
              }
              Text(verbatim: text).font(sourceFont(text)).lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .textSelection(.enabled)
            .accessibilityIdentifier(block.unit.map { "bible.verse.\($0.verse)" } ?? "bible.scripture.\(block.id)")
            if canonicalReference == nil, block.kind == .verse, let printedLabel = block.printedLabel {
              Text(biblePrintedLabel(printedLabel))
                .font(.caption).foregroundStyle(.secondary).textSelection(.disabled)
                .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
                .accessibilityIdentifier("bible.printedLabel.\(block.id)")
            }
          } else if block.kind == .heading {
            Text(verbatim: block.text).font(sourceFont(block.text)).bold()
              .accessibilityAddTraits(.isHeader).textSelection(.disabled)
          } else {
            Text(verbatim: block.text).font(.caption).foregroundStyle(.secondary)
              .textSelection(.disabled)
          }
          ScriptureSourceNotesView(notes: block.sourceNotes)
        }
        .id(block.id)
        .accessibilityIdentifier("bible.block.\(block.id)")
      }
    }
    .environment(\.layoutDirection, edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("bible.sourceBlocks")
  }

  private func sourceFont(_ text: String) -> Font {
    PrayerTypography.font(languageCode: edition.languageCode, isScripture: true, text: text, typefaces: typography.typefaces)
  }
}
