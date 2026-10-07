import SwiftUI

func bibleLabel(_ key: String, _ fallback: String) -> String {
  UILanguage.text("bible." + key, language: UILanguage.current, fallback: fallback)
}

func bibleChapterLabel(_ number: Int, book: BibleBook, edition: ReadingTextEdition, script: String) -> String {
  book.chapters.first { $0.number == number }?.canonicalReference
    ?? ScriptureChapterHeading(chapter: number, edition: edition, script: script).text
}

@MainActor @Observable final class BibleLibraryModel {
  static let shared = BibleLibraryModel()
  var editions: [BibleEdition] = []
  var installed: Set<String> = []
  var progress: [String: Double] = [:]
  var failures: Set<String> = []
  var catalogFailed = false
  private var tasks: [String: Task<Void, Never>] = [:]

  func refresh() async {
    do {
      editions = try await BibleStore.shared.editions()
      catalogFailed = false
      var values = Set<String>()
      for edition in editions where await BibleStore.shared.isInstalled(edition) { values.insert(edition.id) }
      installed = values
    } catch { catalogFailed = true }
  }

  func download(_ edition: BibleEdition) {
    guard tasks[edition.id] == nil else { return }
    failures.remove(edition.id)
    progress[edition.id] = 0
    tasks[edition.id] = Task {
      do {
        try await BibleStore.shared.download(edition) { [weak self] value in
          Task { @MainActor in if self?.progress[edition.id] != nil { self?.progress[edition.id] = value } }
        }
        installed.insert(edition.id)
      } catch {
        if !Task.isCancelled { failures.insert(edition.id) }
      }
      progress[edition.id] = nil
      tasks[edition.id] = nil
    }
  }

  func cancel(_ edition: BibleEdition) { tasks[edition.id]?.cancel() }

  func remove(_ edition: BibleEdition) async {
    guard tasks[edition.id] == nil else { return }
    do {
      try await BibleStore.shared.remove(edition)
      installed.remove(edition.id)
      failures.remove(edition.id)
    } catch { failures.insert(edition.id) }
  }
}

/// The scope belongs to this window; the civil date remains owned by ContentView.
#if !os(macOS)
struct ReadingsView: View {
  @Binding var dateSelection: MacTodayDateSelection
  @Binding var mode: String
  @State private var showsFeasts = false
  @State private var showsMonthCalendar = false

  var body: some View {
    Group {
      if mode == "bible" { BibleView(mode: $mode) }
      else { DailyReadingsView(dateSelection: $dateSelection, mode: $mode) }
    }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button { showsFeasts = true } label: {
          Label(String(localized: "calendar.feastsAndSolemnities", defaultValue: "Feasts and Solemnities", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "calendar")
        }
        .labelStyle(.iconOnly)
        .accessibilityIdentifier("calendar.list")
      }
    }
    .sheet(isPresented: $showsFeasts) {
      NavigationStack {
        FeastsAndSolemnitiesView(dateSelection: $dateSelection) {
          mode = "daily"
          showsFeasts = false
        }
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "common.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showsFeasts = false }
          }
        }
      }
    }
    .sheet(isPresented: $showsMonthCalendar) {
      NavigationStack {
        LiturgicalCalendarView(dateSelection: $dateSelection) { showsMonthCalendar = false }
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button(String(localized: "common.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showsMonthCalendar = false }
          }
        }
      }
    }
    .onAppear { if mode == "calendar" { mode = "daily"; showsMonthCalendar = true } }
    .onChange(of: mode) { _, value in
      if value == "calendar" { mode = "daily"; showsMonthCalendar = true }
    }
  }
}

/// An ordinary content control scrolls with the reader and cannot cover its large title.
struct ReadingModeSelector: View {
  @Binding var mode: String
  var body: some View {
    Picker(String(localized: "tabs.readings", defaultValue: "Readings", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $mode) {
      Text(bibleLabel("daily", "Daily Readings")).tag("daily")
      Text(bibleLabel("title", "Bible")).tag("bible")
    }
    .pickerStyle(.segmented)
    .accessibilityIdentifier("readings.mode")
  }
}
#endif

struct BibleView: View {
  var mode: Binding<String>? = nil
  @AppStorage(ReadingEditionSelection.defaultsKey) private var preference = ""
  @AppStorage(PrayerTranslations.aramaicDefaultScriptKey) private var defaultScript = "Hebr"
  @State private var model = BibleLibraryModel.shared
  @State private var removal: BibleEdition?

  private var selected: BibleEdition? {
    guard let chosen = ReadingEditionSelection.selected(preference, interfaceLanguage: UILanguage.current,
      editions: model.editions.map(\.readingEdition)) else { return nil }
    return model.editions.first { $0.id == chosen.id }
  }

  var body: some View {
    List {
      #if !os(macOS)
      if let mode {
        ReadingModeSelector(mode: mode)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
      }
      #endif
      Section {
        ReadingEditionPicker()
      }
      if let edition = selected {
        Section {
          Text(edition.name).font(.headline)
          if let progress = model.progress[edition.id] {
            ProgressView(value: progress)
              .accessibilityLabel(bibleLabel("downloading", "Downloading Bible"))
              .accessibilityIdentifier("bible.downloadProgress")
            Button(bibleLabel("cancel", "Cancel")) { model.cancel(edition) }
          } else if model.installed.contains(edition.id) {
            Label(bibleLabel("offline", "Available Offline"), systemImage: "checkmark.circle")
              .foregroundStyle(.secondary)
            Button(bibleLabel("remove", "Remove Download"), role: .destructive) { removal = edition }
              .accessibilityIdentifier("bible.remove")
          } else {
            Text(bibleLabel("downloadNotice", "Download this edition to read its available books offline."))
              .foregroundStyle(.secondary)
            Button { model.download(edition) } label: {
              Label(model.failures.contains(edition.id) ? bibleLabel("retry", "Retry Download") : bibleLabel("download", "Download"), systemImage: "arrow.down.circle")
            }
            .accessibilityIdentifier("bible.download")
            Text(ByteCountFormatter.string(fromByteCount: Int64(edition.archiveByteCount), countStyle: .file))
              .font(.caption).foregroundStyle(.secondary)
          }
          if model.failures.contains(edition.id) {
            Text(bibleLabel("downloadError", "The download could not be completed. Please try again."))
              .foregroundStyle(.secondary).accessibilityIdentifier("bible.downloadError")
          }
        }
        Section(bibleLabel("books", "Books")) {
          ForEach(edition.books) { book in
            NavigationLink {
              BibleChaptersView(edition: edition, book: book)
            } label: {
              Text(book.displayedName(script: defaultScript))
                .environment(\.layoutDirection, edition.readingEdition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
            }
            .disabled(!model.installed.contains(edition.id))
            .accessibilityIdentifier("bible.book.\(book.id)")
          }
        }
        Section { BibleCredits(edition: edition.readingEdition) }
      } else {
        Text(model.catalogFailed ? bibleLabel("catalogError", "The Bible catalog is unavailable.") :
          String(localized: "readings.noEdition", defaultValue: "No Bible edition is available for this language.", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle(bibleLabel("title", "Bible"))
    .accessibilityIdentifier("bible.screen")
    .task { await model.refresh() }
    .onReceive(NotificationCenter.default.publisher(for: .bibleDownloadsChanged)) { _ in
      Task { await model.refresh() }
    }
    .confirmationDialog(bibleLabel("remove", "Remove Download"), isPresented: Binding(
      get: { removal != nil }, set: { if !$0 { removal = nil } }), titleVisibility: .visible) {
      if let edition = removal {
        Button(bibleLabel("remove", "Remove Download"), role: .destructive) {
          removal = nil
          Task { await model.remove(edition) }
        }
      }
    } message: { Text(bibleLabel("removeNotice", "You can download this Bible again. Daily Readings will remain available.")) }
  }
}

private struct BibleChaptersView: View {
  let edition: BibleEdition
  let book: BibleBook
  @AppStorage(PrayerTranslations.aramaicDefaultScriptKey) private var script = "Hebr"

  var body: some View {
    List(book.chapters, id: \.number) { chapter in
      NavigationLink {
        BibleChapterView(edition: edition, book: book, initialChapter: chapter.number)
      } label: {
        VStack(alignment: .leading, spacing: 4) {
          Text(bibleChapterLabel(chapter.number, book: book, edition: edition.readingEdition, script: script))
          if !chapter.isComplete { Text(bibleLabel("partial", "Only part of this chapter is available")).font(.caption).foregroundStyle(.secondary) }
        }
        .environment(\.layoutDirection, edition.readingEdition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
      }
      .accessibilityIdentifier("bible.chapter.\(chapter.number)")
    }
    .navigationTitle(book.displayedName(script: script))
  }
}

struct BibleChapterView: View {
  let edition: BibleEdition
  let book: BibleBook
  let initialChapter: Int
  @AppStorage(PrayerTranslations.aramaicDefaultScriptKey) private var defaultScript = "Hebr"
  @State private var scriptOverride: String?
  @State private var chapterNumber = 0
  @State private var bookOverride: String?
  @State private var jumpGeneration = 0
  @State private var chapter: BibleDisplayChapter?
  @State private var unavailable = false
  @State private var jumpBlockID: String?
  @State private var pendingJumpBlockID: String?

  private var number: Int { chapterNumber == 0 ? initialChapter : chapterNumber }
  private var script: Binding<String> {
    Binding(get: { ReadingTextScript.resolved(override: scriptOverride, defaultScript: defaultScript) }, set: { scriptOverride = $0 })
  }
  private var activeBook: BibleBook { edition.books.first { $0.id == bookOverride } ?? book }
  private var position: BiblePosition { BiblePosition(book: activeBook.id, chapter: number) }

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if edition.readingEdition.supportsAramaicScriptChoice { BibleScriptPicker(script: script) }
          if activeBook.chapters.first(where: { $0.number == number })?.isComplete == false {
            Text(bibleLabel("partial", "Only part of this chapter is available"))
              .font(.callout).foregroundStyle(.secondary)
              .accessibilityIdentifier("bible.partial")
          }
          if let chapter {
            if let introduction = activeBook.introduction(for: number) {
              ScriptureIntroduction(text: introduction, edition: edition.readingEdition)
            }
            BibleSourceBlockList(edition: edition.readingEdition, display: chapter, script: script.wrappedValue,
              canonicalReference: activeBook.chapters.first { $0.number == number }?.canonicalReference)
          } else if unavailable {
            Text(bibleLabel("chapterUnavailable", "This chapter is not available offline. Return to Bible to download the edition."))
              .foregroundStyle(.secondary).accessibilityIdentifier("bible.unavailable")
          } else { ProgressView() }
          BibleCredits(edition: edition.readingEdition, book: activeBook)
        }
        .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        .padding(20).id("chapter.top")
      }
      .onChange(of: jumpGeneration) { _, _ in if let block = jumpBlockID { proxy.scrollTo(block, anchor: .top) } }
      .onChange(of: "\(activeBook.id)|\(number)") { _, _ in proxy.scrollTo("chapter.top", anchor: .top) }
    }
    .navigationTitle(activeBook.displayedName(script: script.wrappedValue))
    .toolbar {
      ToolbarItem(id: "bible.previousChapter", placement: .automatic) {
        Button { move(-1) } label: { Label(bibleLabel("previous", "Previous Chapter"), systemImage: "chevron.backward") }
          .disabled(position.moving(by: -1, in: edition) == nil).accessibilityIdentifier("bible.previousChapter")
      }
      ToolbarItem(id: "bible.chapterMenu", placement: .automatic) {
        Menu {
          ForEach(activeBook.chapters, id: \.number) { item in
            Button(bibleChapterLabel(item.number, book: activeBook, edition: edition.readingEdition, script: script.wrappedValue)) {
              chapterNumber = item.number
            }
          }
        } label: {
          Text(bibleChapterLabel(number, book: activeBook, edition: edition.readingEdition, script: script.wrappedValue))
        }
        .accessibilityIdentifier("bible.chapterMenu")
      }
      ToolbarItem(id: "bible.nextChapter", placement: .automatic) {
        Button { move(1) } label: { Label(bibleLabel("next", "Next Chapter"), systemImage: "chevron.forward") }
          .disabled(position.moving(by: 1, in: edition) == nil).accessibilityIdentifier("bible.nextChapter")
      }
      // Loading a chapter must not remove/reinsert a child of a native toolbar group.
      // Keep the menu's identity and size stable while its source choices are replaced.
      ToolbarItem(id: "bible.verseMenu", placement: .automatic) {
        Menu {
          if let chapter {
            ForEach(chapter.choices) { block in
              Button(bibleVerseChoiceLabel(block, display: chapter, edition: edition.readingEdition, script: script.wrappedValue,
                usesPrintedLabels: activeBook.chapters.first { $0.number == number }?.canonicalReference != nil)) {
                if let unit = block.unit {
                  Task { await jump(chapter: unit.chapter, verse: unit.verse) }
                } else {
                  jumpBlockID = block.id
                  jumpGeneration += 1
                }
              }
            }
          }
        } label: { Label(bibleLabel("verse", "Go to Verse"), systemImage: "text.line.first.and.arrowtriangle.forward") }
        .disabled(chapter == nil)
        .accessibilityIdentifier("bible.verseMenu")
      }
    }
    .task(id: "\(activeBook.id)|\(number)") { await load() }
    .onReceive(NotificationCenter.default.publisher(for: .bibleDownloadsChanged)) { _ in Task { await load() } }
  }

  private func jump(chapter sourceChapter: Int, verse: Int) async {
    let requestedBook = activeBook.id
    guard let target = try? await BibleStore.shared.verseTarget(edition: edition, book: requestedBook, chapter: sourceChapter, verse: verse),
          requestedBook == activeBook.id else { return }
    if target.displayChapter == number {
      jumpBlockID = target.blockId
      jumpGeneration += 1
    } else {
      pendingJumpBlockID = target.blockId
      chapterNumber = target.displayChapter
    }
  }

  private func move(_ delta: Int) {
    if let target = position.moving(by: delta, in: edition) {
      bookOverride = target.book
      chapterNumber = target.chapter
    }
  }
  private func load() async {
    let requested = position
    chapter = nil; unavailable = false; jumpBlockID = nil
    do {
      let value = try await BibleStore.shared.displayChapter(edition: edition, book: requested.book, number: requested.chapter)
      guard !Task.isCancelled, position == requested else { return }
      chapter = value
      if let pendingJumpBlockID {
        jumpBlockID = pendingJumpBlockID
        self.pendingJumpBlockID = nil
        jumpGeneration += 1
      }
    } catch { if !Task.isCancelled, position == requested { unavailable = true } }
  }
}

struct BibleScriptPicker: View {
  @Binding var script: String
  var body: some View {
    Picker(String(localized: "readings.script", defaultValue: "Aramaic Script", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: $script) {
      Text(String(localized: "settings.script.hebrew", defaultValue: "Hebrew Script", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("Hebr")
      Text(String(localized: "settings.script.syriac", defaultValue: "Syriac Script", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("Syrc")
    }
    .pickerStyle(.segmented).accessibilityIdentifier("bible.scriptPicker")
  }
}

struct BibleCredits: View {
  let edition: ReadingTextEdition
  var book: BibleBook? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(edition.name).fontWeight(.medium)
      Text(book?.attribution ?? edition.attribution)
      if let url = URL(string: book?.sourceURL ?? edition.sourceURL), url.scheme == "https" {
        Link(String(localized: "readings.source", defaultValue: "Text source", bundle: UILanguage.bundle, locale: UILanguage.locale), destination: url)
      }
    }
    .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
  }
}

extension ReadingTextEdition {
  var isBibleRightToLeft: Bool { languageCode == "arc" || UILanguage.isRightToLeft(languageCode) }
}

private struct ScriptureIntroduction: View {
  let text: String
  let edition: ReadingTextEdition
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  var body: some View {
    Text(verbatim: text)
      .font(PrayerTypography.font(languageCode: edition.languageCode, isScripture: true, text: text, typefaces: typography.typefaces))
      .lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading)
      .environment(\.layoutDirection, edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
      .textSelection(.enabled).accessibilityIdentifier("bible.introduction")
  }
}

struct ScriptureVerseList: View {
  let edition: ReadingTextEdition
  let verses: [ReadingTextVerse]
  let script: String
  @ObservedObject private var typography = PrayerTypographyMonitor.shared
  var body: some View {
    LazyVStack(alignment: .leading, spacing: 12) {
      ForEach(Array(verses.enumerated()), id: \.offset) { index, verse in
        if index == 0 || verses[index - 1].chapter != verse.chapter {
          let heading = ScriptureChapterHeading(chapter: verse.chapter, edition: edition, script: script)
          (Text(verbatim: heading.label).bold() + Text(verbatim: " \(heading.number)"))
            .font(PrayerTypography.font(languageCode: edition.languageCode, isScripture: true, text: heading.text, typefaces: typography.typefaces))
            .accessibilityAddTraits(.isHeader).accessibilityIdentifier("readings.chapter.\(verse.chapter)")
        }
        let text = verse.displayedText(script: script, edition: edition)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(verbatim: verse.verseLabel).font(.caption).monospacedDigit().foregroundStyle(.secondary).fixedSize()
          Text(text).font(PrayerTypography.font(languageCode: edition.languageCode, isScripture: true, text: text, typefaces: typography.typefaces))
            .lineSpacing(5).frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(verse.verse)
        .accessibilityIdentifier("bible.verse.\(verse.verse)")
        .textSelection(.enabled)
        ScriptureSourceNotesView(notes: verse.sourceNotes ?? [])
      }
    }
    .environment(\.layoutDirection, edition.isBibleRightToLeft ? .rightToLeft : .leftToRight)
    .accessibilityIdentifier("readings.verses")
  }
}
