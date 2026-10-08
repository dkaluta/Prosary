import SwiftUI

struct ReadingEditionPicker: View {
  var compact = false
  var showsNotice = true
  @AppStorage(ReadingEditionSelection.defaultsKey) private var preference = ""
  @State private var editions: [ReadingTextEdition] = []
  @State private var hasLoadedEditions = false

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      if compact {
        picker.labelsHidden()
      } else {
        picker
      }
      if let selected = ReadingEditionSelection.selected(preference, interfaceLanguage: UILanguage.current, editions: editions),
         !compact || preference.isEmpty {
        Text(selected.name).font(.caption).foregroundStyle(.secondary)
      } else if hasLoadedEditions && preference.isEmpty {
        Text(String(localized: "readings.noEdition", defaultValue: "No Bible edition is available for this language.", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .font(.caption).foregroundStyle(.secondary)
      }
      if showsNotice {
        Text(String(localized: "readings.bibleNote", defaultValue: "Bible passages; wording may differ from the liturgical reading.", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .font(.caption).foregroundStyle(.secondary)
      }
    }
    .task {
      editions = await ReadingTextStore.shared.editions()
      hasLoadedEditions = true
    }
  }

  private var picker: some View {
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
    .help(ReadingEditionSelection.selected(preference, interfaceLanguage: UILanguage.current, editions: editions)?.name
      ?? String(localized: "readings.edition", defaultValue: "Bible edition", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .accessibilityIdentifier("readings.editionPicker")
  }
}

/// The citation always remains visible. Only an opened disclosure loads the optional
/// Bible text, and changing editions never substitutes an available language silently.
struct ScripturePassageView: View {
  let reading: ReadingCitation
  var isTorah = false
  var interfaceLanguage: String = UILanguage.current
  @AppStorage(ReadingEditionSelection.defaultsKey) private var preference = ""
  @AppStorage("expandReadingsByDefault") private var expandReadingsByDefault = false
  @State private var expanded = false
  @State private var hasInitializedExpansion = false
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
          citation: reading.full, isTorah: isTorah, datasetID: reading.readingDatasetID,
          preference: $preference, interfaceLanguage: interfaceLanguage, script: script)
          .padding(.top, 8)
      }
    } label: {
      Text(reading.localizedFull(interfaceLanguage))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .accessibilityIdentifier("readings.passage.\(isTorah ? "torah" : "daily").\(reading.full)")
    .onAppear {
      guard !hasInitializedExpansion else { return }
      expanded = expandReadingsByDefault
      hasInitializedExpansion = true
    }
    .onChange(of: reading.full) { _, _ in expanded = expandReadingsByDefault; scriptOverride = nil }
    .onChange(of: reading.readingDatasetID) { _, _ in expanded = expandReadingsByDefault; scriptOverride = nil }
    .onChange(of: expandReadingsByDefault) { _, value in expanded = value }
    .onChange(of: isTorah) { _, _ in scriptOverride = nil }
    .onChange(of: preference) { _, _ in scriptOverride = nil }
  }
}

private struct ScripturePassageBody: View {
  let citation: String
  let isTorah: Bool
  let datasetID: String?
  @Binding var preference: String
  let interfaceLanguage: String
  @Binding var script: String
  @State private var passage: ReadingTextPassage?
  @State private var availableEditions: [ReadingTextEdition] = []
  @State private var loading = true

  private var requestID: String { "\(isTorah)|\(datasetID ?? "")|\(citation)|\(preference)|\(interfaceLanguage)" }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(String(localized: "readings.biblePassage", defaultValue: "Bible passage", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
      if loading {
        ProgressView().accessibilityLabel(String(localized: "readings.loading", defaultValue: "Loading passage", bundle: UILanguage.bundle, locale: UILanguage.locale))
      } else if let passage {
        if passage.edition.supportsAramaicScriptChoice {
          AramaicScriptPicker(script: $script, accessibilityIdentifier: "readings.scriptPicker")
        }
        if passage.includesWholeVerses {
          Text(String(localized: "readings.wholeVersesNotice", defaultValue: "Full verses are shown and may extend beyond the reading’s cited limits.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .font(.callout).foregroundStyle(.secondary)
            .accessibilityIdentifier("readings.wholeVersesNotice")
        }
        if let source = passage.source {
          Text(verbatim: source.name).font(.headline).accessibilityAddTraits(.isHeader)
            .environment(\.layoutDirection, passage.edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
            .accessibilityIdentifier("readings.sourceTitle")
          if !source.isComplete {
            Text(bibleLabel("partial", "Only part of this chapter is available"))
              .font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("readings.partial")
          }
        }
        if let displays = passage.sourceDisplays {
          ForEach(Array(displays.enumerated()), id: \.offset) { _, display in
            BibleSourceBlockList(edition: passage.edition, display: display, script: script)
          }
        } else {
          ScriptureVerseList(edition: passage.edition, verses: passage.verses, script: script)
        }

        VStack(alignment: .leading, spacing: 5) {
          Text(passage.edition.name).fontWeight(.medium)
          Text(verbatim: passage.source?.attribution ?? passage.edition.attribution)
          if let source = passage.source?.sourceLink ?? passage.edition.sourceLink {
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
        result = await ReadingTextStore.shared.passage(citation: citation, isTorah: isTorah, editionID: selected.id, datasetID: datasetID)
      } else { result = nil }
      let alternatives = result == nil
        ? await ReadingTextStore.shared.availableEditions(citation: citation, isTorah: isTorah, datasetID: datasetID) : []
      guard !Task.isCancelled else { return }
      passage = result
      availableEditions = alternatives
      loading = false
    }
  }
}
