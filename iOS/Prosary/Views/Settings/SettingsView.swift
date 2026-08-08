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
  @AppStorage("autoAdvanceSeconds") private var autoAdvanceSeconds = 0
  @AppStorage("hapticsOnAdvance") private var hapticsOnAdvance = false

  @State private var installedCount = PrayerPackStore.installedBundleIds().count
  @State private var confirmsRemoveAll = false
  @State private var audioCacheBytes = SettingsMaintenance.audioCacheSize()
  @State private var homeOrderIsCustom = !HomeOrder.saved.isEmpty

  /// Choosing a language keeps the rite when that language has one, and drops it otherwise —
  /// so switching Hebrew → Latin → Hebrew does not silently forget whose Hebrew you pray.
  private var languageBinding: Binding<String> {
    Binding(
      get: { LanguageCatalog.baseLanguage(of: languageCode) ?? languageCode },
      set: { newBase in
        languageCode = LanguageCatalog.rites(of: newBase).first?.code ?? newBase
      })
  }

  var body: some View {
    Form {
      Section(String(localized: "settings.prayerLanguageHeader", defaultValue: "Prayer Language")) {
        // The stored code may name a rite ("he-x-gamliel"), so the language row binds to its
        // base and the rite row below chooses among that language's uses.
        Picker(String(localized: "settings.defaultLanguage", defaultValue: "Default language"),
               selection: languageBinding) {
          ForEach(LanguageCatalog.all) { lang in
            Text(lang.nativeName).tag(lang.code)
          }
        }

        // Only for a language prayed in more than one use — everywhere else there is nothing
        // to choose, so nothing is shown.
        let rites = LanguageCatalog.rites(of: languageCode)
        if rites.count > 1 {
          Picker(String(localized: "settings.rite", defaultValue: "Rite"), selection: $languageCode) {
            ForEach(rites) { rite in
              Text(rite.nativeName).tag(rite.code)
            }
          }
          .accessibilityIdentifier("ritePicker")
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
