//
//  SettingsView.swift
//  Prosary
//
//  The app's settings — shown on macOS via the Settings scene (Cmd+,) and on iOS as a sheet
//  from Home's gear (v0.7: populated with the app-wide controls that used to hide in flow
//  toolbars, plus downloads management — user request).
//

import SwiftUI

struct SettingsView: View {
  @AppStorage("defaultLanguageCode") private var languageCode = LanguageCatalog.defaultCode
  @AppStorage(AramaicSignOfCrossForm.defaultsKey) private var aramaicSignOfCrossForm = AramaicSignOfCrossForm.formA
  @AppStorage("autoAdvanceSeconds") private var autoAdvanceSeconds = 0
  @AppStorage("hapticsOnAdvance") private var hapticsOnAdvance = false
  @AppStorage(PrayerTypography.syriacTypefaceKey) private var syriacTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTypography.hebrewPrayerTypefaceKey) private var hebrewPrayerTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(PrayerTypography.hebrewScriptureTypefaceKey) private var hebrewScriptureTypeface = PrayerTypography.TypefaceValue.default
  @AppStorage(BasicPrayerFavorites.moveToTopKey) private var favoriteBasicPrayersFirst = false

  @State private var installedCount = PrayerPackStore.installedBundleIds().count
  @State private var confirmsRemoveAll = false
  @State private var audioCacheBytes = SettingsMaintenance.audioCacheSize()
  @State private var homeOrderIsCustom = !HomeOrder.saved.isEmpty
  @State private var showsLanguageFallbackOrder = false

  @AppStorage(TodayInfoStore.calendarDefaultsKey) private var feastCalendarId = ""
  @AppStorage("showTodayFeast") private var showsTodayFeast = true
  @AppStorage("showTodayIntention") private var showsTodayIntention = true

  /// Reads through the store so an unset/unknown stored id shows as the registry default.
  private var feastCalendarBinding: Binding<String> {
    Binding(
      get: { TodayInfoStore.selectedCalendarId },
      set: { feastCalendarId = $0 })
  }

  var body: some View {
    Form {
      Section(String(localized: "settings.prayerLanguageHeader", defaultValue: "Prayer Language")) {
        Picker(String(localized: "settings.defaultLanguage", defaultValue: "Default language"),
               selection: $languageCode) {
          ForEach(LanguageCatalog.all) { lang in
            Text(lang.nativeName).tag(lang.code)
          }
        }

        Button(String(localized: "settings.languageFallbackOrder", defaultValue: "Language fallback order…")) {
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

      Section(String(localized: "settings.prayingHeader", defaultValue: "Praying")) {
        // The same app-wide setting the flow toolbars offer — surfaced here so it's
        // discoverable outside a session.
        Picker(String(localized: "prayerFlow.autoAdvance", defaultValue: "Auto-advance"),
               selection: $autoAdvanceSeconds) {
          Text(String(localized: "prayerFlow.autoAdvance.off", defaultValue: "Off")).tag(0)
          ForEach([3, 5, 10, 15], id: \.self) { seconds in
            Text(String(localized: "prayerFlow.autoAdvance.everySeconds",
                        defaultValue: "Every \(seconds) seconds")).tag(seconds)
          }
        }
        #if os(iOS)
        // Erez's ask: a felt confirmation that the step turned. iOS-only — a Mac has nothing
        // useful to buzz, so the row would be a lie there.
        Toggle(String(localized: "settings.hapticsOnAdvance",
                      defaultValue: "Vibrate on step change"), isOn: $hapticsOnAdvance)
        #endif

        Button(String(localized: "settings.resetHomeOrder", defaultValue: "Reset Home Order")) {
          HomeOrder.reset()
          homeOrderIsCustom = false
        }
        .disabled(!homeOrderIsCustom)

        Toggle(String(localized: "settings.favoriteBasicPrayersFirst",
                      defaultValue: "Move favorite basic prayers to top"),
               isOn: $favoriteBasicPrayersFirst)
      }

      Section(String(localized: "settings.typographyHeader", defaultValue: "Typography")) {
        Picker(String(localized: "settings.syriacTypeface", defaultValue: "Syriac Aramaic"),
               selection: $syriacTypeface) {
          Text(String(localized: "settings.typeface.default", defaultValue: "Default")).tag(PrayerTypography.TypefaceValue.default)
          Text(String(localized: "settings.typeface.westernAramaic", defaultValue: "Western Aramaic")).tag(PrayerTypography.TypefaceValue.western)
          Text(String(localized: "settings.typeface.easternAramaic", defaultValue: "Eastern Aramaic")).tag(PrayerTypography.TypefaceValue.eastern)
        }

        Picker(String(localized: "settings.hebrewPrayerTypeface", defaultValue: "Hebrew prayers"),
               selection: $hebrewPrayerTypeface) {
          Text(String(localized: "settings.typeface.default", defaultValue: "Default")).tag(PrayerTypography.TypefaceValue.default)
          Text(String(localized: "settings.typeface.davidLibre", defaultValue: "David Libre")).tag(PrayerTypography.TypefaceValue.davidLibre)
          Text(String(localized: "settings.typeface.sansSerif", defaultValue: "System sans-serif")).tag(PrayerTypography.TypefaceValue.sansSerif)
        }

        Picker(String(localized: "settings.hebrewScriptureTypeface", defaultValue: "Hebrew Scripture"),
               selection: $hebrewScriptureTypeface) {
          Text(String(localized: "settings.typeface.default", defaultValue: "Default")).tag(PrayerTypography.TypefaceValue.default)
          Text(String(localized: "settings.typeface.stamAshkenaz", defaultValue: "Stam Ashkenaz")).tag(PrayerTypography.TypefaceValue.stamAshkenaz)
          Text(String(localized: "settings.typeface.stamSefarad", defaultValue: "Stam Sefarad")).tag(PrayerTypography.TypefaceValue.stamSefarad)
          Text(String(localized: "settings.typeface.rashi", defaultValue: "Rashi")).tag(PrayerTypography.TypefaceValue.rashi)
        }
      }

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
      } header: {
        Text(String(localized: "settings.todayHeader", defaultValue: "Today"))
      } footer: {
        Text(String(localized: "settings.feastCalendarFooter",
                    defaultValue: "Which calendar’s feasts and readings the Today section shows."))
      }

      Section {
        LabeledContent(
          String(localized: "settings.installedDevotions", defaultValue: "Installed devotions"),
          value: "\(installedCount)")

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
                      defaultValue: "Remove All Downloaded Devotions…"))
        }
        .disabled(installedCount == 0)
      } header: {
        Text(String(localized: "settings.downloadsHeader", defaultValue: "Downloads"))
      } footer: {
        Text(String(localized: "settings.downloadsFooter",
                    defaultValue: "Built-in devotions are never removed. Removing a downloaded devotion also removes its favorite."))
      }

      Section(String(localized: "settings.aboutHeader", defaultValue: "Links")) {
        Link(String(localized: "settings.repositorySite", defaultValue: "Community repository"),
             destination: URL(string: "https://prayers.prosary.app")!)
        Link(String(localized: "settings.composeSite", defaultValue: "Compose a devotion"),
             destination: URL(string: "https://compose.prosary.app")!)
        Link(String(localized: "settings.privacyPolicy", defaultValue: "Privacy policy"),
             destination: URL(string: "https://prosary.app/privacy")!)
      }
    }
    .formStyle(.grouped)
    #if os(macOS)
    .frame(width: 460)
    #endif
    .confirmationDialog(
      String(localized: "settings.removeAllDownloads.title",
             defaultValue: "Remove all downloaded devotions?"),
      isPresented: $confirmsRemoveAll, titleVisibility: .visible
    ) {
      Button(role: .destructive) {
        SettingsMaintenance.removeAllInstalledPacks()
        installedCount = PrayerPackStore.installedBundleIds().count
      } label: {
        Text(String(localized: "settings.removeAllDownloads.confirm", defaultValue: "Remove All"))
      }
    } message: {
      Text(String(localized: "settings.removeAllDownloads.message",
                  defaultValue: "Devotions from the repository can be downloaded again; hand-imported files cannot."))
    }
    .onAppear {
      installedCount = PrayerPackStore.installedBundleIds().count
      audioCacheBytes = SettingsMaintenance.audioCacheSize()
      homeOrderIsCustom = !HomeOrder.saved.isEmpty
    }
    .sheet(isPresented: $showsLanguageFallbackOrder) {
      NavigationStack { LanguageFallbackOrderView() }
    }
  }
}

private struct LanguageFallbackOrderView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var order = LanguageCatalog.fallbackOrder

  var body: some View {
    List {
      Section {
        ForEach(order, id: \.self) { code in
          Text(LanguageCatalog.all.first(where: { $0.code == code })?.nativeName ?? code)
        }
        .onMove { from, to in
          order.move(fromOffsets: from, toOffset: to)
          LanguageCatalog.setFallbackOrder(order)
        }
      } footer: {
        Text(String(localized: "settings.languageFallbackOrder.footer",
                    defaultValue: "When a prayer is missing, Prosary tries these languages from top to bottom after the chosen language and its own variation."))
      }
    }
    .accessibilityIdentifier("languageFallbackOrderList")
    #if os(iOS)
    .environment(\.editMode, .constant(.active))
    #endif
    #if os(macOS)
    .frame(minWidth: 340, minHeight: 420)
    #endif
    .navigationTitle(String(localized: "settings.languageFallbackOrder.title", defaultValue: "Language fallback order"))
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(String(localized: "settings.languageFallbackOrder.reset", defaultValue: "Reset")) {
          LanguageCatalog.resetFallbackOrder()
          order = LanguageCatalog.fallbackOrder
          dismiss()
        }
        .accessibilityIdentifier("languageFallbackOrderResetButton")
      }
      ToolbarItem(placement: .confirmationAction) {
        Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { dismiss() }
      }
    }
  }
}

/// The downloads-management actions Settings exposes (v0.7): shared by macOS and iOS.
enum SettingsMaintenance {
  static func removeAllInstalledPacks() {
    for bundleId in PrayerPackStore.installedBundleIds() {
      PrayerPackStore.removeInstalledPack(id: bundleId)
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
