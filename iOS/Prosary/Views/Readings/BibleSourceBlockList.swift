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

  var body: some View {
    LazyVStack(alignment: .leading, spacing: 16) {
      BibleSourceChapterHeading(edition: edition, chapter: display.chapter.chapter,
        script: script, canonicalReference: canonicalReference)
      ForEach(display.blocks) { block in
        BibleSourceBlockRow(edition: edition, displayChapter: display.chapter.chapter,
          block: block, script: script, canonicalReference: canonicalReference)
      }
    }
    .environment(\.layoutDirection, edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("bible.sourceBlocks")
  }
}

struct BibleSourceChapterHeading: View {
  let edition: ReadingTextEdition
  let chapter: Int
  let script: String
  var canonicalReference: String? = nil
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  var body: some View {
    let heading = ScriptureChapterHeading(chapter: chapter, edition: edition, script: script)
    Group {
      if let canonicalReference { Text(verbatim: canonicalReference).bold() }
      else { Text(verbatim: heading.label).bold() + Text(verbatim: " \(heading.number)") }
    }
    .font(PrayerTypography.font(languageCode: edition.languageCode, isScripture: true,
      text: canonicalReference ?? heading.text, typefaces: typography.typefaces))
    .accessibilityAddTraits(.isHeader)
    .accessibilityIdentifier("readings.chapter.\(chapter)")
  }
}

/// The continuous and paged readers render exactly the same source unit, including notes.
struct BibleSourceBlockRow: View {
  let edition: ReadingTextEdition
  let displayChapter: Int
  let block: BibleDisplayBlock
  let script: String
  var canonicalReference: String? = nil
  var bookTypography = false
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  var body: some View {
        VStack(alignment: .leading, spacing: 8) {
          if block.isScripture {
            let text = block.unit?.displayedText(script: script, edition: edition) ?? block.text
            if canonicalReference != nil, let label = block.printedLabel ?? block.unit?.verseLabel {
              Text(biblePrintedLabel(label)).font(.caption).foregroundStyle(.secondary).textSelection(.disabled)
                .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
                .accessibilityIdentifier("bible.printedLabel.\(block.id)")
            }
            scriptureText(text)
            .accessibilityElement(children: .contain)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("bible.block.\(block.id)")
    .environment(\.layoutDirection, edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
  }

  private func sourceFont(_ text: String) -> Font {
    PrayerTypography.font(languageCode: edition.languageCode, isScripture: true, text: text, typefaces: typography.typefaces)
  }

  @ViewBuilder
  private func scriptureText(_ text: String) -> some View {
    let label = canonicalReference == nil ? block.unit.map {
      biblePrimaryLabel($0, displayChapter: displayChapter, edition: edition, script: script)
    } ?? block.printedLabel : nil
    #if os(iOS)
    if bookTypography {
      BibleBookVerseText(text: text, label: label, languageCode: edition.languageCode,
        isRightToLeft: edition.isBibleRightToLeft, typefaces: typography.typefaces)
    } else {
      continuousScriptureText(text, label: label)
    }
    #else
    continuousScriptureText(text, label: label)
    #endif
  }

  private func continuousScriptureText(_ text: String, label: String?) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      if let label { Text(verbatim: label).font(.caption).foregroundStyle(.secondary).fixedSize() }
      Text(verbatim: text).font(sourceFont(text)).lineSpacing(5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .textSelection(.enabled)
  }
}
