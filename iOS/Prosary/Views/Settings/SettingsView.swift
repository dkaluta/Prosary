//
//  SettingsView.swift
//  Prosary
//
//  The app's settings — shown on macOS via the Settings scene (Cmd+,) and on iOS as a sheet
//  from Home's gear (v0.7: populated with the app-wide controls that used to hide in flow
//  toolbars, plus downloads management — user request).
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
  @Environment(\.appServices) private var services
  @AppStorage("defaultLanguageCode") private var languageCode = LanguageCatalog.defaultCode
  @AppStorage(JaffaHailMaryWording.defaultsKey) private var usesJaffaHailMaryWording = false
  @AppStorage(AramaicSignOfCrossForm.defaultsKey) private var aramaicSignOfCrossForm = AramaicSignOfCrossForm.formA
  @AppStorage("autoAdvanceSeconds") private var autoAdvanceSeconds = 0
  @AppStorage("hapticsOnAdvance") private var hapticsOnAdvance = false
  @AppStorage(PrayerTypography.syriacTypefaceKey) private var syriacTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTranslations.aramaicDefaultScriptKey) private var aramaicDefaultScript = "Hebr"
  @AppStorage(PrayerTypography.hebrewPrayerTypefaceKey) private var hebrewPrayerTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTypography.hebrewScriptureTypefaceKey) private var hebrewScriptureTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTypography.latinPrayerTypefaceKey) private var latinPrayerTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTypography.cyrillicPrayerTypefaceKey) private var cyrillicPrayerTypeface = PrayerTypography.TypefaceValue.default

  @State private var installedCount = PrayerPackStore.installedBundleIds().count
  @State private var downloadedIDs = PrayerPackStore.installedBundleIds()
  @State private var unusedDownloads: Set<String> = []
  @State private var removingDownload: String?
  @State private var removalError: String?
  @State private var isRemovingDownloads = false
  @State private var confirmsRemoveAll = false
  @State private var audioCacheBytes = SettingsMaintenance.audioCacheSize()
  #if !os(macOS)
  @State private var homeOrderIsCustom = !HomeOrder.saved.isEmpty
  #endif
  @State private var showsLanguageFallbackOrder = false

  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var feastCalendarId = ""
  @AppStorage(TodayInfoStore.paschaStyleDefaultsKey) private var easternPaschaStyle = "julian"
  @AppStorage("showTodayFeast") private var showsTodayFeast = true
  @AppStorage("showTodayIntention") private var showsTodayIntention = true
  @AppStorage("showTodayTorahPortion") private var showsTodayTorahPortion = false
  @AppStorage(PrayerNamePresentation.defaultsKey) private var showsPrayerNameInPrayerLanguage = false

  /// Reads through the store so an unset/unknown stored id shows as the registry default.
  private var feastCalendarBinding: Binding<String> {
    Binding(
      get: { TodayInfoStore.selectedCalendarId },
      set: { feastCalendarId = $0 })
  }

  var body: some View {
    settingsContent
    .confirmationDialog(
      String(localized: "settings.removeAllDownloads.title",
             defaultValue: "Remove Unused Downloads?"),
      isPresented: $confirmsRemoveAll, titleVisibility: .visible
    ) {
      Button(role: .destructive) {
        isRemovingDownloads = true
        Task {
          defer { isRemovingDownloads = false }
          do { try await SettingsMaintenance.removeUnusedInstalledPacks(store: services.presetStore) }
          catch { removalError = error.localizedDescription }
          await refreshDownloads()
        }
      } label: {
        Text(String(localized: "settings.removeAllDownloads.confirm", defaultValue: "Remove Unused"))
      }
    } message: {
      Text(String(localized: "settings.removeAllDownloads.message",
                  defaultValue: "Only downloads with no saved copies will be removed from this device. Keep your original files to import them again."))
    }
    .modifier(PrayerDownloadRemovalDialogs(bundleID: $removingDownload, onRemoved: { await refreshDownloads() }))
    .alert(String(localized: "removal.failedTitle", defaultValue: "Could Not Remove Prayer"),
           isPresented: Binding(get: { removalError != nil }, set: { if !$0 { removalError = nil } })) {
      Button("common.ok") { removalError = nil }
    } message: { Text(removalError ?? "") }
    .task { await refreshDownloads() }
    .onAppear {
      installedCount = PrayerPackStore.installedBundleIds().count
      audioCacheBytes = SettingsMaintenance.audioCacheSize()
      #if !os(macOS)
      homeOrderIsCustom = !HomeOrder.saved.isEmpty
      #endif
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      Task { await refreshDownloads() }
    }
    .sheet(isPresented: $showsLanguageFallbackOrder) {
      NavigationStack { LanguageFallbackOrderView() }
    }
  }

  @ViewBuilder
  private var settingsContent: some View {
    #if os(macOS)
    let screenSize = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
    TabView(selection: $selectedPane) {
      MacPrayerEditorForm { languageSettings }
        .tabItem { Label(String(localized: "settings.prayerLanguageHeader", defaultValue: "Prayer Language"), systemImage: "character.bubble") }
        .tag(SettingsPane.language)
      MacPrayerEditorForm { prayingSettings }
        .tabItem { Label(String(localized: "settings.prayingHeader", defaultValue: "Praying"), systemImage: "hands.and.sparkles") }
        .tag(SettingsPane.praying)
      MacPrayerEditorForm { typographySettings }
        .tabItem { Label(String(localized: "settings.typographyHeader", defaultValue: "Typography"), systemImage: "textformat") }
        .tag(SettingsPane.typography)
      MacPrayerEditorForm {
        downloadsSettings
        linksSettings
      }
      .tabItem { Label(String(localized: "settings.downloadsHeader", defaultValue: "Downloads"), systemImage: "arrow.down.circle") }
      .tag(SettingsPane.downloads)
    }
    .accessibilityIdentifier("macSettingsPanes")
    .frame(width: min(640, max(320, screenSize.width - 80)),
           height: min(560, max(280, screenSize.height - 140)))
    .navigationTitle(selectedPane.title)
    #else
    Form {
      languageSettings
      prayingSettings
      typographySettings
      todaySettings
      downloadsSettings
      linksSettings
    }
    .formStyle(.grouped)
    #endif
  }

  #if os(macOS)
  @AppStorage("macSettingsPane") private var selectedPane = SettingsPane.language

  private enum SettingsPane: String {
    case language, praying, typography, downloads

    var title: String {
      switch self {
      case .language: String(localized: "settings.prayerLanguageHeader", defaultValue: "Prayer Language")
      case .praying: String(localized: "settings.prayingHeader", defaultValue: "Praying")
      case .typography: String(localized: "settings.typographyHeader", defaultValue: "Typography")
      case .downloads: String(localized: "settings.downloadsHeader", defaultValue: "Downloads")
      }
    }
  }
  #endif

  private var languageSettings: some View {
    Section(String(localized: "settings.prayerLanguageHeader", defaultValue: "Prayer Language")) {
      PrayerLanguagePicker(label: String(localized: "settings.defaultLanguage", defaultValue: "Default language"), code: $languageCode)
      Toggle(String(localized: "settings.jaffaWording", defaultValue: "Alternative Hail Mary wording"),
             isOn: $usesJaffaHailMaryWording)
        .accessibilityIdentifier("useJaffaHailMaryWording")
      Text(String(localized: "settings.jaffaWording.footer",
                  defaultValue: "Use בְּרוּכַת הַחֶסֶד instead of מְלֵאַת הַחֶסֶד in Vicariate prayers."))
        .font(.caption).foregroundStyle(.secondary)
      Toggle(String(localized: "settings.showPrayerNameInPrayerLanguage",
                    defaultValue: "Show prayer names in the prayer language"),
             isOn: $showsPrayerNameInPrayerLanguage)
        .accessibilityIdentifier("showPrayerNameInPrayerLanguageToggle")
      Text(String(localized: "settings.prayerNameLanguageFooter",
                  defaultValue: "Show the interface-language name underneath when it differs."))
        .font(.caption).foregroundStyle(.secondary)

      Button(String(localized: "settings.languageFallbackOrder", defaultValue: "Language Fallback Order…")) {
        showsLanguageFallbackOrder = true
      }
      .accessibilityIdentifier("languageFallbackOrderButton")

      if (LanguageCatalog.baseLanguage(of: languageCode) ?? languageCode) == "arc" {
        Picker(String(localized: "settings.aramaicSignOfCross",
                      defaultValue: "Aramaic Sign of the Cross"),
               selection: $aramaicSignOfCrossForm) {
          Text(String(localized: "settings.aramaicSignOfCross.formA",
                      defaultValue: "Form A")).tag(AramaicSignOfCrossForm.formA)
          Text(String(localized: "settings.aramaicSignOfCross.formB",
                      defaultValue: "Form B")).tag(AramaicSignOfCrossForm.formB)
        }
      }
    }
  }

  private var prayingSettings: some View {
    Section(String(localized: "settings.prayingHeader", defaultValue: "Praying")) {
      // Mac copies freeze this default when first opened; mobile retains one shared pace.
      Picker(autoAdvanceSettingsTitle,
             selection: $autoAdvanceSeconds) {
        Text(String(localized: "prayerFlow.autoAdvance.off", defaultValue: "Off")).tag(0)
        ForEach([3, 5, 10, 15], id: \.self) { seconds in
          Text(String(localized: "prayerFlow.autoAdvance.everySeconds",
                      defaultValue: "Every \(seconds) Seconds")).tag(seconds)
        }
      }
      #if os(macOS)
      Text(String(localized: "macLibrary.defaultAutoAdvanceHelp",
                  defaultValue: "New prayer copies start at this pace. Each prayer remembers changes made in its window."))
        .font(.caption).foregroundStyle(.secondary)
      #endif
      #if os(iOS)
      // Erez's ask: a felt confirmation that the step turned. iOS-only — a Mac has nothing
      // useful to buzz, so the row would be a lie there.
      Toggle(String(localized: "settings.hapticsOnAdvance",
                    defaultValue: "Vibrate on step change"), isOn: $hapticsOnAdvance)
      #endif

      #if !os(macOS)
      Button(String(localized: "settings.resetHomeOrder", defaultValue: "Reset Home Order")) {
        HomeOrder.reset()
        homeOrderIsCustom = false
      }
      .disabled(!homeOrderIsCustom)
      #endif

    }
  }

  private var autoAdvanceSettingsTitle: String {
    #if os(macOS)
    String(localized: "macLibrary.defaultAutoAdvance", defaultValue: "Default Auto-Advance")
    #else
    String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-Advance")
    #endif
  }

  private var typographySettings: some View {
    Section(String(localized: "settings.typographyHeader", defaultValue: "Typography")) {
      Picker(String(localized: "settings.aramaicDefaultScript", defaultValue: "Default Aramaic script"),
             selection: $aramaicDefaultScript) {
        Text(String(localized: "settings.script.hebrew", defaultValue: "Hebrew Script")).tag("Hebr")
        Text(String(localized: "settings.script.syriac", defaultValue: "Syriac Script")).tag("Syrc")
      }
      .accessibilityIdentifier("aramaicDefaultScriptPicker")
      Picker(String(localized: "settings.syriacTypeface", defaultValue: "Aramaic font"),
             selection: $syriacTypeface) {
        Text(String(localized: "settings.typeface.default", defaultValue: "Default")).tag(PrayerTypography.TypefaceValue.default)
        Text(String(localized: "settings.typeface.westernAramaic", defaultValue: "Western Aramaic")).tag(PrayerTypography.TypefaceValue.western)
        Text(String(localized: "settings.typeface.easternAramaic", defaultValue: "Eastern Aramaic")).tag(PrayerTypography.TypefaceValue.eastern)
      }

      Picker(String(localized: "settings.hebrewPrayerTypeface", defaultValue: "Hebrew font"),
             selection: $hebrewPrayerTypeface) {
        Text(String(localized: "settings.typeface.frankRuhlLibre", defaultValue: "Frank Ruhl Libre")).tag(PrayerTypography.TypefaceValue.default)
        Text(String(localized: "settings.typeface.davidLibre", defaultValue: "David Libre")).tag(PrayerTypography.TypefaceValue.davidLibre)
        Text(String(localized: "settings.typeface.sansSerif", defaultValue: "System Sans Serif")).tag(PrayerTypography.TypefaceValue.sansSerif)
      }

      Picker(String(localized: "settings.hebrewScriptureTypeface", defaultValue: "Hebrew Scripture font"),
             selection: $hebrewScriptureTypeface) {
        Text(String(localized: "settings.typeface.default", defaultValue: "Default")).tag(PrayerTypography.TypefaceValue.default)
        Text(String(localized: "settings.typeface.stamAshkenaz", defaultValue: "Stam Ashkenaz")).tag(PrayerTypography.TypefaceValue.stamAshkenaz)
        Text(String(localized: "settings.typeface.stamSefarad", defaultValue: "Stam Sefarad")).tag(PrayerTypography.TypefaceValue.stamSefarad)
        Text(String(localized: "settings.typeface.rashi", defaultValue: "Rashi")).tag(PrayerTypography.TypefaceValue.rashi)
      }

      Picker(String(localized: "settings.latinPrayerTypeface", defaultValue: "Latin-script prayers"), selection: $latinPrayerTypeface) {
        Text(String(localized: "settings.typeface.systemSerif", defaultValue: "System Serif")).tag(PrayerTypography.TypefaceValue.default)
        Text(String(localized: "settings.typeface.sansSerif", defaultValue: "System Sans Serif")).tag(PrayerTypography.TypefaceValue.sansSerif)
      }
      .accessibilityIdentifier("latinPrayerTypefacePicker")

      Picker(String(localized: "settings.cyrillicPrayerTypeface", defaultValue: "Cyrillic prayers"), selection: $cyrillicPrayerTypeface) {
        Text(String(localized: "settings.typeface.systemSerif", defaultValue: "System Serif")).tag(PrayerTypography.TypefaceValue.default)
        Text(String(localized: "settings.typeface.sansSerif", defaultValue: "System Sans Serif")).tag(PrayerTypography.TypefaceValue.sansSerif)
      }
      .accessibilityIdentifier("cyrillicPrayerTypefacePicker")
    }
  }

  private var todaySettings: some View {
    // The Home "Today" section (Erez's requests): which of its rows show at all, and which
    // calendar's feasts the feast row prays. The calendar choices come from the bundled
    // calendars.json registry, so adding a calendar is a data drop, never a new case here;
    // the picker hides entirely if the registry ever ships a single calendar.
    Section {
      Toggle(String(localized: "settings.showTodayFeast", defaultValue: "Show the day's feast"),
             isOn: $showsTodayFeast)
      Toggle(String(localized: "settings.showTodayIntention",
                    defaultValue: "Show the Pope's intention"),
             isOn: $showsTodayIntention)
      Toggle(String(localized: "settings.showTodayTorahPortion", defaultValue: "Show the weekly Torah portion"),
             isOn: $showsTodayTorahPortion)
        .accessibilityIdentifier("showTodayTorahPortionToggle")
      if showsTodayTorahPortion {
        Text(String(localized: "settings.torahPortionFooter",
                    defaultValue: "The upcoming Sabbath’s Torah reading, following the Eretz Israel schedule."))
          .font(.caption).foregroundStyle(.secondary)
      }
      let calendars = TodayInfoStore.calendars
      if calendars.count > 1 {
        Picker(String(localized: "settings.feastCalendar", defaultValue: "Liturgical calendar"),
               selection: feastCalendarBinding) {
          ForEach(calendars) { calendar in
            Text(calendar.displayName).tag(calendar.id)
          }
        }
        .accessibilityIdentifier("feastCalendarPicker")
      }
      if TodayInfoStore.selectedCalendarId == "ugcc" {
        Picker(String(localized: "settings.easternPaschaStyle", defaultValue: "Byzantine Easter date"),
               selection: Binding(get: { TodayInfoStore.selectedPaschaStyle }, set: { easternPaschaStyle = $0 })) {
          Text(String(localized: "settings.easternPaschaStyle.julian", defaultValue: "Julian Easter")).tag("julian")
          Text(String(localized: "settings.easternPaschaStyle.gregorian", defaultValue: "Gregorian Easter")).tag("gregorian")
        }
        .accessibilityIdentifier("easternPaschaStylePicker")
        Text(String(localized: "settings.easternPaschaStyleFooter",
                    defaultValue: "Changes the Byzantine movable feasts and their appointed readings together. Fixed feasts keep their Gregorian dates."))
          .font(.caption).foregroundStyle(.secondary)
      }
    } header: {
      Text(String(localized: "settings.todayHeader", defaultValue: "Today"))
    } footer: {
      Text(String(localized: "settings.feastCalendarFooter",
                  defaultValue: "Which calendar’s feasts and readings the Today section shows."))
    }
  }

  private var downloadsSettings: some View {
    Section {
      LabeledContent(
        String(localized: "settings.installedDevotions", defaultValue: "Installed devotions"),
        value: "\(installedCount)")

      ForEach(downloadedIDs, id: \.self) { id in
        LabeledContent(PrayerPackStore.info(for: id)?.localizedDisplayName ?? id) {
          Button(String(localized: "removal.removeDownloadAction", defaultValue: "Remove Download…"), role: .destructive) {
            removingDownload = id
          }
          .disabled(isRemovingDownloads || !unusedDownloads.contains(id))
        }
        if !unusedDownloads.contains(id) {
          Text(String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download."))
            .font(.caption).foregroundStyle(.secondary)
        }
      }

      Button(String(localized: "settings.clearAudioCache", defaultValue: "Clear Audio Cache")) {
        SettingsMaintenance.clearAudioCache()
        audioCacheBytes = SettingsMaintenance.audioCacheSize()
      }
      .disabled(audioCacheBytes == 0)
      if audioCacheBytes > 0 {
        Text(ByteCountFormatter.string(fromByteCount: audioCacheBytes, countStyle: .file))
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Button(role: .destructive) {
        confirmsRemoveAll = true
      } label: {
        Text(String(localized: "settings.removeAllDownloads",
                    defaultValue: "Remove Unused Downloads…"))
      }
      .disabled(unusedDownloads.isEmpty || isRemovingDownloads)
    } header: {
      Text(String(localized: "settings.downloadsHeader", defaultValue: "Downloads"))
    } footer: {
      Text(String(localized: "settings.downloadsFooter",
                  defaultValue: "Built-in prayers remain available. Downloads used by saved prayers are kept until their last saved copy is deleted."))
    }
  }

  private func refreshDownloads() async {
    downloadedIDs = PrayerPackStore.installedBundleIds()
    installedCount = downloadedIDs.count
    unusedDownloads = Set((try? await PrayerRemovalService(store: services.presetStore).unusedDownloadIDs()) ?? [])
  }

  private var linksSettings: some View {
    Section(String(localized: "settings.aboutHeader", defaultValue: "Links")) {
      Link(String(localized: "settings.repositorySite", defaultValue: "Community Repository"),
           destination: URL(string: "https://prayers.prosary.app")!)
      Link(String(localized: "settings.composeSite", defaultValue: "Compose a Devotion"),
           destination: URL(string: "https://compose.prosary.app")!)
      Link(String(localized: "settings.privacyPolicy", defaultValue: "Privacy Policy"),
           destination: URL(string: "https://prosary.app/privacy")!)
    }
  }

}

private struct LanguageFallbackOrderView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var order = LanguageCatalog.fallbackLanguageOrder
  @State private var selectedLanguage: String?

  var body: some View {
    #if os(macOS)
    let screenSize = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
    VStack(spacing: 0) {
      List(selection: $selectedLanguage) { rows }
        .accessibilityIdentifier("languageFallbackOrderList")
        .clipped()
      Divider()
      HStack {
        Button(String(localized: "settings.languageFallbackOrder.reset", defaultValue: "Reset")) {
          LanguageCatalog.resetFallbackOrder()
          order = LanguageCatalog.fallbackLanguageOrder
        }
        .accessibilityIdentifier("languageFallbackOrderResetButton")
        Button { moveSelection(by: -1) } label: {
          Label("common.moveUp", systemImage: "arrow.up")
        }
        .labelStyle(.iconOnly)
        .disabled(selectedIndex == nil || selectedIndex == 0)
        .help(Text("common.moveUp"))
        Button { moveSelection(by: 1) } label: {
          Label("common.moveDown", systemImage: "arrow.down")
        }
        .labelStyle(.iconOnly)
        .disabled(selectedIndex == nil || selectedIndex == order.count - 1)
        .help(Text("common.moveDown"))
        Spacer()
        Button("favoriteEditor.done") { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding()
      .background(Color(nsColor: .windowBackgroundColor))
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: min(520, max(320, screenSize.width - 80)),
           height: min(500, max(280, screenSize.height - 140)))
    .onExitCommand { dismiss() }
    .navigationTitle(String(localized: "settings.languageFallbackOrder.title", defaultValue: "Language Fallback Order"))
    #else
    List { rows }
      .accessibilityIdentifier("languageFallbackOrderList")
      #if os(iOS)
      .environment(\.editMode, .constant(.active))
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .navigationTitle(String(localized: "settings.languageFallbackOrder.title", defaultValue: "Language Fallback Order"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "settings.languageFallbackOrder.reset", defaultValue: "Reset")) {
            LanguageCatalog.resetFallbackOrder()
            order = LanguageCatalog.fallbackLanguageOrder
            dismiss()
          }
          .accessibilityIdentifier("languageFallbackOrderResetButton")
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("favoriteEditor.done") { dismiss() }
        }
      }
    #endif
  }

  private var rows: some View {
    Section {
      ForEach(order, id: \.self) { code in
        Text(LanguageCatalog.fallbackDisplayName(code))
          .tag(code)
          .accessibilityIdentifier("languageFallbackOrder.\(code)")
      }
      .onMove { from, to in
        order.move(fromOffsets: from, toOffset: to)
        LanguageCatalog.setFallbackLanguageOrder(order)
      }
    } footer: {
      Text(String(localized: "settings.languageFallbackOrder.footer",
                  defaultValue: "When text is missing, Prosary follows this order after the chosen language. Shared Hebrew, including repository prayers, uses the higher of the two Hebrew positions."))
    }
  }

  private var selectedIndex: Int? {
    selectedLanguage.flatMap { order.firstIndex(of: $0) }
  }

  private func moveSelection(by offset: Int) {
    guard let index = selectedIndex, order.indices.contains(index + offset) else { return }
    order.swapAt(index, index + offset)
    LanguageCatalog.setFallbackLanguageOrder(order)
  }
}

/// The downloads-management actions Settings exposes (v0.7): shared by macOS and iOS.
enum SettingsMaintenance {
  static func removeUnusedInstalledPacks(store: PresetStore) async throws {
    let removal = PrayerRemovalService(store: store)
    for bundleId in try await removal.unusedDownloadIDs() {
      try await removal.removeDownload(bundleID: bundleId)
    }
  }

  private static var audioCacheURL: URL? {
    FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
      .appendingPathComponent("PrayerAudio", isDirectory: true)
  }

  static func audioCacheSize() -> Int64 {
    guard let root = audioCacheURL,
          let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.fileSizeKey])
    else { return 0 }
    var total: Int64 = 0
    for case let url as URL in enumerator {
      total += Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
    }
    return total
  }

  static func clearAudioCache() {
    guard let root = audioCacheURL else { return }
    try? FileManager.default.removeItem(at: root)
  }
}
