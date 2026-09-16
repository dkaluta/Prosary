import SwiftUI

struct ReadingEditionPicker: View {
  @AppStorage(ReadingEditionSelection.defaultsKey) private var preference = ""
  @State private var editions: [ReadingTextEdition] = []
  @State private var hasLoadedEditions = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Picker(String(localized: "readings.edition", defaultValue: "Bible edition", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $preference) {
        Text(String(localized: "readings.followInterface", defaultValue: "Follow Interface Language", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("")
        ForEach(editions, id: \.id) { edition in
          Text(edition.name).tag(edition.id)
        }
        if !preference.isEmpty, !editions.contains(where: { $0.id == preference }) {
          Text(String(localized: "readings.unavailableEdition", defaultValue: "Unavailable edition", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag(preference)
        }
      }
      .pickerStyle(.menu)
      .accessibilityIdentifier("readings.editionPicker")
      if let selected = ReadingEditionSelection.selected(preference, interfaceLanguage: UILanguage.current, editions: editions) {
        Text(selected.name).font(.caption).foregroundStyle(.secondary)
      } else if hasLoadedEditions && preference.isEmpty {
        Text(String(localized: "readings.noEdition", defaultValue: "No Bible edition is available for this language.", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .font(.caption).foregroundStyle(.secondary)
      }
      Text(String(localized: "readings.bibleNote", defaultValue: "Bible passages; wording may differ from the liturgical reading.", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .font(.caption).foregroundStyle(.secondary)
    }
    .task {
      editions = await ReadingTextStore.shared.editions()
      hasLoadedEditions = true
    }
  }
}

/// The citation always remains visible. Only an opened disclosure loads the optional
/// Bible text, and changing editions never substitutes an available language silently.
struct ScripturePassageView: View {
  let reading: ReadingCitation
  var isTorah = false
  var interfaceLanguage: String = UILanguage.current
  @AppStorage(ReadingEditionSelection.defaultsKey) private var preference = ""
  @State private var expanded = true
  @AppStorage(PrayerTranslations.aramaicDefaultScriptKey) private var defaultAramaicScript = "Hebr"
  // Keep the passage's choice when its disclosure closes, without rewriting the app default.
  @State private var scriptOverride: String?

  private var script: Binding<String> {
    Binding(get: { ReadingTextScript.resolved(override: scriptOverride, defaultScript: defaultAramaicScript) },
            set: { scriptOverride = $0 })
  }

  var body: some View {
    DisclosureGroup(isExpanded: $expanded) {
      if expanded {
        ScripturePassageBody(
          citation: reading.full, isTorah: isTorah,
          preference: $preference, interfaceLanguage: interfaceLanguage, script: script)
          .padding(.top, 8)
      }
    } label: {
      Text(reading.localizedFull(interfaceLanguage))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("readings.passage.\(isTorah ? "torah" : "daily").\(reading.full)")
    .onAppear { expanded = true }
    .onChange(of: reading.full) { _, _ in expanded = true; scriptOverride = nil }
    .onChange(of: isTorah) { _, _ in scriptOverride = nil }
    .onChange(of: preference) { _, _ in scriptOverride = nil }
  }
}

private struct ScripturePassageBody: View {
  let citation: String
  let isTorah: Bool
  @Binding var preference: String
  let interfaceLanguage: String
  @Binding var script: String
  @State private var passage: ReadingTextPassage?
  @State private var availableEditions: [ReadingTextEdition] = []
  @State private var loading = true
  @ObservedObject private var typography = PrayerTypographyMonitor.shared

  private var requestID: String { "\(isTorah)|\(citation)|\(preference)|\(interfaceLanguage)" }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "readings.biblePassage", defaultValue: "Bible passage", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
      if loading {
        ProgressView().accessibilityLabel(String(localized: "readings.loading", defaultValue: "Loading passage", bundle: UILanguage.bundle, locale: UILanguage.locale))
      } else if let passage {
        if passage.edition.supportsAramaicScriptChoice {
          Picker(String(localized: "readings.script", defaultValue: "Aramaic Script", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $script) {
            Text(String(localized: "settings.script.hebrew", defaultValue: "Hebrew Script", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("Hebr")
            Text(String(localized: "settings.script.syriac", defaultValue: "Syriac Script", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("Syrc")
          }
          .pickerStyle(.segmented)
          .accessibilityIdentifier("readings.scriptPicker")
        }
        if passage.includesWholeVerses {
          Text(String(localized: "readings.wholeVersesNotice", defaultValue: "Full verses are shown where the reading cites only part of a verse.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .font(.callout).foregroundStyle(.secondary)
            .accessibilityIdentifier("readings.wholeVersesNotice")
        }
        VStack(alignment: .leading, spacing: 12) {
          ForEach(Array(passage.verses.enumerated()), id: \.offset) { _, verse in
            let text = verse.displayedText(script: script, edition: passage.edition)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
              Text(verbatim: "\(verse.chapter):\(verse.verse)")
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                .fixedSize()
              Text(text)
                .font(PrayerTypography.font(languageCode: passage.edition.languageCode, isScripture: true,
                                           text: text, typefaces: typography.typefaces))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
          }
        }
        .environment(\.layoutDirection, passage.edition.languageCode == "arc" || UILanguage.isRightToLeft(passage.edition.languageCode) ? .rightToLeft : .leftToRight)
        .textSelection(.enabled)
        .accessibilityIdentifier("readings.verses")

        VStack(alignment: .leading, spacing: 5) {
          Text(passage.edition.name).fontWeight(.medium)
          Text(passage.edition.attribution)
          if let source = passage.edition.sourceLink {
            Link(String(localized: "readings.source", defaultValue: "Text source", bundle: UILanguage.bundle, locale: UILanguage.locale), destination: source)
          }
        }
        .font(.caption).foregroundStyle(.secondary)
        .textSelection(.enabled)
        .accessibilityIdentifier("readings.source")
      } else {
        Text(String(localized: "readings.unavailable", defaultValue: "Bible text is unavailable for this passage in the selected edition.", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .foregroundStyle(.secondary)
          .accessibilityIdentifier("readings.unavailable")
        if !availableEditions.isEmpty {
          Menu {
            ForEach(availableEditions, id: \.id) { edition in
              Button(edition.name) { preference = edition.id }
            }
          } label: {
            Label(String(localized: "readings.edition", defaultValue: "Bible edition", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "book")
          }
          .buttonStyle(.bordered)
          .accessibilityIdentifier("readings.availableEditions.\(citation)")
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .task(id: requestID) {
      passage = nil
      availableEditions = []
      loading = true
      let editions = await ReadingTextStore.shared.editions()
      let selected = ReadingEditionSelection.selected(preference, interfaceLanguage: interfaceLanguage, editions: editions)
      let result: ReadingTextPassage?
      if let selected {
        result = await ReadingTextStore.shared.passage(citation: citation, isTorah: isTorah, editionID: selected.id)
      } else { result = nil }
      let alternatives = result == nil
        ? await ReadingTextStore.shared.availableEditions(citation: citation, isTorah: isTorah) : []
      guard !Task.isCancelled else { return }
      passage = result
      availableEditions = alternatives
      loading = false
    }
  }
}
