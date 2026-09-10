
//
//  FavoriteEditorView.swift
//  Prosary
//
//  Editor for any kind of saved prayer favorite. Replaces PresetEditorView.
//  Kind-specific options appear conditionally based on prayer.kind.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct FavoriteEditorView: View {
  @State var prayer: Prayer
  let isNew: Bool
  @State private var isSaving = false
  @State private var saveError: String?

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss
  @AppStorage("defaultLanguageCode") private var appDefaultCode = LanguageCatalog.defaultCode

  var body: some View {
    editorLayout
    #if os(macOS)
    .navigationTitle(String(localized: "macLibrary.settingsTitle", defaultValue: "Prayer Settings"))
    #else
    .navigationTitle(isNew ? "favoriteEditor.newFavoriteTitle" : "favoriteEditor.editFavoriteTitle")
    #endif
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    #if !os(macOS)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("favoriteEditor.cancel") { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("favoriteEditor.save") { save() }
      }
    }
    #endif
    .interactiveDismissDisabled(isSaving)
    .alert(
      String(localized: "favoriteEditor.saveFailed", defaultValue: "Could Not Save Favorite"),
      isPresented: .init(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    ) {
      Button("common.ok") { saveError = nil }
        .keyboardShortcut(.defaultAction)
    } message: {
      Text(saveError ?? "")
    }
  }

  @ViewBuilder private var editorLayout: some View {
    #if os(macOS)
    MacPrayerEditorSheet(preferredSize: CGSize(width: 600, height: 620)) {
      editorSections
    } actions: {
      Button("favoriteEditor.cancel") { dismiss() }
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier("favoriteEditorCancelButton")
      Button("favoriteEditor.save") { save() }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("favoriteEditorSaveButton")
    }
    .disabled(isSaving)
    #else
    Form { editorSections }
      .formStyle(.grouped)
    #endif
  }

  @ViewBuilder private var editorSections: some View {
    // MARK: Common fields
    Section {
      TextField("favoriteEditor.name", text: $prayer.name, prompt: Text("favoriteEditor.namePlaceholder"))
      #if !os(macOS)
      Toggle(String(localized: "favoriteEditor.setAsDefault", defaultValue: "Set as default for \(prayer.kind.displayName)"), isOn: $prayer.isDefault)
      #endif
    }

    Section {
      let defaultName = LanguageCatalog.resolve(LanguageCatalog.pickerLanguageCode(appDefaultCode)).nativeName
      PrayerLanguagePicker(
        label: String(localized: "favoriteEditor.language", defaultValue: "Language"),
        code: $prayer.languageCode,
        defaultLabel: String(localized: "favoriteEditor.defaultLanguageOption", defaultValue: "Default — \(defaultName)"))

      let prayerBase = prayer.languageCode == LanguageCatalog.defaultSentinel
        ? prayer.languageCode
        : (LanguageCatalog.baseLanguage(of: prayer.languageCode) ?? prayer.languageCode)
      let defaultBase = LanguageCatalog.baseLanguage(of: appDefaultCode) ?? appDefaultCode
      if prayer.kind == .rosary && prayerBase == "arc" && defaultBase != "arc" {
        Picker(String(localized: "settings.aramaicSignOfCross",
                      defaultValue: "Aramaic Sign of the Cross"),
               selection: $prayer.rosary.aramaicSignOfCrossForm) {
          Text(String(localized: "settings.aramaicSignOfCross.formA",
                      defaultValue: "Form A")).tag(AramaicSignOfCrossForm.formA)
          Text(String(localized: "settings.aramaicSignOfCross.formB",
                      defaultValue: "Form B")).tag(AramaicSignOfCrossForm.formB)
        }
      }
    } header: {
      Text("favoriteEditor.prayerLanguageHeader")
    } footer: {
      #if os(iOS)
      Text("favoriteEditor.languageFooter")
      #endif
    }

    // MARK: Rosary options
    if prayer.kind == .rosary {
      #if os(macOS)
      RosaryOptionsSections(
        rosary: $prayer.rosary,
        languageCode: LanguageCatalog.resolve(prayer.languageCode).code)
      #else
      Section {
        NavigationLink {
          RosaryOptionsEditorView(
            rosary: $prayer.rosary,
            languageCode: LanguageCatalog.resolve(prayer.languageCode).code)
        } label: {
          LabeledContent("favoriteEditor.rosaryOptions", value: prayer.rosary.mysterySelectionSummary)
        }
      }
      #endif
    }

    // MARK: Jesus Prayer options
    if prayer.kind == .jesusPrayer {
      Section("favoriteEditor.target") {
        Picker("favoriteEditor.repetitions", selection: $prayer.jesusPrayer.target) {
          Text("jesusPrayerTarget.33").tag(JesusPrayerTarget.count(33))
          Text("jesusPrayerTarget.66").tag(JesusPrayerTarget.count(66))
          Text("jesusPrayerTarget.99").tag(JesusPrayerTarget.count(99))
          Text("jesusPrayerOptions.unbounded").tag(JesusPrayerTarget.unbounded)
        }
        #if os(macOS)
        .pickerStyle(.menu)
        #else
        .pickerStyle(.segmented)
        #endif
      }
    }

    // MARK: Reminders
    RemindersSection(reminders: $prayer.reminders)
  }

  // MARK: - Save

  private func save() {
    guard !isSaving else { return }
    isSaving = true
    var toSave = prayer
    if toSave.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      toSave.name = toSave.kind.defaultName
    }
    Task {
      defer { isSaving = false }
      if !toSave.reminders.filter(\.isEnabled).isEmpty {
        await ReminderScheduler.requestPermission()
      }
      do {
        if isNew {
          try await services.presetStore.save(toSave)
        } else {
          guard try await services.presetStore.updateIfPresent(toSave) else {
            throw PrayerRemovalService.RemovalError.prayerRemoved
          }
        }
        NotificationCenter.default.post(name: .prayerConfigurationDidChange, object: toSave.id)
        ReminderScheduler.schedule(for: toSave)
        dismiss()
      } catch {
        saveError = error.localizedDescription
      }
    }
  }
}

#if os(macOS)
/// One scroll container for the fields, with the actions occupying their own opaque row.
/// A grouped Form already scrolls; nesting its inset footer let content paint beneath Save.
struct MacPrayerEditorSheet<Fields: View, Actions: View>: View {
  let preferredSize: CGSize
  private let fields: Fields
  private let actions: Actions

  init(preferredSize: CGSize, @ViewBuilder fields: () -> Fields, @ViewBuilder actions: () -> Actions) {
    self.preferredSize = preferredSize
    self.fields = fields()
    self.actions = actions()
  }

  var body: some View {
    let screenSize = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
    VStack(spacing: 0) {
      MacPrayerEditorForm { fields }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      VStack(spacing: 0) {
        Divider()
        HStack(spacing: 12) {
          Spacer(minLength: 0)
          actions
        }
        .controlSize(.regular)
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
      }
      .background(Color(nsColor: .windowBackgroundColor))
      .fixedSize(horizontal: false, vertical: true)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier("prayerEditorActions")
    }
    .background(Color(nsColor: .windowBackgroundColor))
    .frame(width: min(preferredSize.width, max(320, screenSize.width - 80)),
           height: min(preferredSize.height, max(280, screenSize.height - 140)))
  }
}

/// ColumnsFormStyle is deliberately non-scrolling and uses compact native Mac controls.
/// The surrounding ScrollView makes every row, including the final reminders, reachable.
struct MacPrayerEditorForm<Fields: View>: View {
  private let fields: Fields

  init(@ViewBuilder content: () -> Fields) { fields = content() }

  var body: some View {
    ScrollView {
      Form { fields }
        .formStyle(.columns)
        .toggleStyle(.checkbox)
        .pickerStyle(.menu)
        .textFieldStyle(.roundedBorder)
        .controlSize(.regular)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
    }
    .clipped()
    .accessibilityIdentifier("prayerEditorFields")
  }
}
#endif

#Preview("New Rosary") {
  NavigationStack {
    FavoriteEditorView(prayer: Prayer(kind: .rosary), isNew: true)
  }
}

#Preview("New Jesus Prayer") {
  NavigationStack {
    FavoriteEditorView(
      prayer: Prayer(
        name: "Jesus Prayer",
        kind: .jesusPrayer,
        reminders: [PrayerReminder(hour: 6), PrayerReminder(hour: 12), PrayerReminder(hour: 18)]
      ),
      isNew: true
    )
  }
}

#Preview("Edit Rosary") {
  NavigationStack {
    FavoriteEditorView(
      prayer: Prayer(
        name: "Evening Rosary for the Departed",
        kind: .rosary,
        languageCode: "en",
        rosary: RosaryOptions(
          mysterySelectionMode: .specific,
          specificMysteryGroup: .sorrowful,
          includeOpeningPrayers: false,
          eternalRestForDeceased: .afterEachDecade,
          includeStMichaelPrayer: true
        ),
        reminders: [PrayerReminder(hour: 21, minute: 0)]
      ),
      isNew: false)
  }
}
