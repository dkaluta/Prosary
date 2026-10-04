import SwiftUI

/// Editorial notes are siblings of the selectable scripture, never part of its text.
struct ScriptureSourceNotesView: View {
  let notes: [ScriptureSourceNote]
  @State private var expanded = false
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  var body: some View {
    if let first = notes.first {
      DisclosureGroup(isExpanded: $expanded) {
        VStack(alignment: .leading, spacing: 12) {
          ForEach(sourceGroups, id: \.first!.id) { sourceNotes in
            VStack(alignment: .leading, spacing: 8) {
              ForEach(anchorGroups(sourceNotes), id: \.first!.id) { anchorNotes in
                VStack(alignment: .leading, spacing: 8) {
                  let note = anchorNotes[0]
                  Text(verbatim: note.anchor)
                    .font(PrayerTypography.font(languageCode: "he", isScripture: true, text: note.anchor, typefaces: typography.typefaces))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .rightToLeft)
                    .accessibilityIdentifier("scripture.sourceNote.anchor.\(note.id)")
                  ForEach(anchorNotes) { note in
                    detail(note)
                      .accessibilityIdentifier("scripture.sourceNote.detail.\(note.id)")
                  }
                }
              }
              let source = sourceNotes[0]
              Text(String(format: String(localized: "scripture.sourceNote.pages", defaultValue: "PDF pages: %@", bundle: UILanguage.bundle, locale: UILanguage.locale), locale: UILanguage.locale,
                          source.sourcePages.map { $0.formatted(.number.locale(UILanguage.locale)) }.joined(separator: ", ")))
              if let link = source.sourceLink {
                Link(String(localized: "scripture.sourceNote.sourceScan", defaultValue: "Source scan", bundle: UILanguage.bundle, locale: UILanguage.locale), destination: link)
              }
            }
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
      .accessibilityIdentifier("scripture.sourceNote.\(first.id)")
      .accessibilityValue(anchorGroups(notes).map { $0[0].anchor }.joined(separator: ", "))
      .onChange(of: notes) { expanded = false }
    }
  }

  @ViewBuilder private func detail(_ note: ScriptureSourceNote) -> some View {
    VStack(alignment: .leading, spacing: 4) {
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
    }
  }

  private var sourceGroups: [[ScriptureSourceNote]] {
    grouped(notes) { $0.sourcePages == $1.sourcePages && $0.sourceURL.unicodeScalars.elementsEqual($1.sourceURL.unicodeScalars) }
  }

  private func anchorGroups(_ notes: [ScriptureSourceNote]) -> [[ScriptureSourceNote]] {
    grouped(notes) { $0.anchor.unicodeScalars.elementsEqual($1.anchor.unicodeScalars) && $0.occurrence == $1.occurrence }
  }

  /// Retain every distinct finding and each group's order of first appearance.
  private func grouped(_ notes: [ScriptureSourceNote], matches: (ScriptureSourceNote, ScriptureSourceNote) -> Bool) -> [[ScriptureSourceNote]] {
    var groups: [[ScriptureSourceNote]] = []
    for note in notes {
      if let index = groups.firstIndex(where: { matches($0[0], note) }) { groups[index].append(note) }
      else { groups.append([note]) }
    }
    return groups
  }
}
