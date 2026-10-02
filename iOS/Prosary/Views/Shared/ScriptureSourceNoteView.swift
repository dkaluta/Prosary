import SwiftUI

/// Editorial notes are siblings of the selectable scripture, never part of its text.
struct ScriptureSourceNoteView: View {
  let note: ScriptureSourceNote
  @State private var expanded = false
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  var body: some View {
    DisclosureGroup(isExpanded: $expanded) {
      VStack(alignment: .leading, spacing: 8) {
        Text(verbatim: note.anchor)
          .font(PrayerTypography.font(languageCode: "he", isScripture: true, text: note.anchor, typefaces: typography.typefaces))
          .frame(maxWidth: .infinity, alignment: .leading)
          .environment(\.layoutDirection, .rightToLeft)
          .accessibilityIdentifier("scripture.sourceNote.anchor.\(note.id)")
        if note.kind == .restoredLetter, let letter = note.affectedLetter {
          Text(String(format: String(localized: "scripture.sourceNote.restoredLetter", defaultValue: "The letter %@ (position %lld) in “%@” was restored editorially. It is unreadable in the source scan.", bundle: UILanguage.bundle, locale: UILanguage.locale), locale: UILanguage.locale,
                      "\u{2067}\(letter)\u{2069}", Int64(note.letterIndex), "\u{2067}\(note.anchor)\u{2069}"))
        } else {
          if let letter = note.affectedLetter {
            Text(String(format: String(localized: "scripture.sourceNote.letter", defaultValue: "Letter %@ (position %lld)", bundle: UILanguage.bundle, locale: UILanguage.locale), locale: UILanguage.locale, "\u{2067}\(letter)\u{2069}", Int64(note.letterIndex)))
          }
          Text(note.mark == .vowel || note.mark == .shuruq
            ? String(localized: "scripture.sourceNote.unreadableVowel", defaultValue: "Unreadable vowel mark omitted.", bundle: UILanguage.bundle, locale: UILanguage.locale)
            : String(localized: "scripture.sourceNote.unreadableDagesh", defaultValue: "Unreadable dagesh omitted.", bundle: UILanguage.bundle, locale: UILanguage.locale))
        }
        Text(String(format: String(localized: "scripture.sourceNote.pages", defaultValue: "PDF pages: %@", bundle: UILanguage.bundle, locale: UILanguage.locale), locale: UILanguage.locale,
                    note.sourcePages.map { $0.formatted(.number.locale(UILanguage.locale)) }.joined(separator: ", ")))
        if let source = note.sourceLink {
          Link(String(localized: "scripture.sourceNote.sourceScan", defaultValue: "Source scan", bundle: UILanguage.bundle, locale: UILanguage.locale), destination: source)
        }
      }
      .padding(.vertical, 6)
      .accessibilityElement(children: .contain)
    } label: {
      Label(String(localized: "scripture.sourceNote", defaultValue: "Source note", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "text.bubble")
    }
    .font(.footnote)
    .foregroundStyle(.secondary)
    .textSelection(.disabled)
    .environment(\.layoutDirection, UILanguage.isRightToLeft(UILanguage.current) ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("scripture.sourceNote.\(note.id)")
    .accessibilityValue(note.anchor)
  }
}
