//
//  RemindersOnlyEditorView.swift
//  Prosary
//
//  The compact editor for an existing Prayer row. Generic bundle rows expose their schema-driven
//  `options.json` choices plus reminders; Rosary/Jesus rows use it for reminder-only actions.
//  This view never creates a row. Bundle display names and traditional reminder presets come
//  from the manifest.
//

import SwiftUI

struct RemindersOnlyEditorView: View {
  @State var prayer: Prayer
  @State private var isSaving = false
  @State private var saveError: String?

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  init(prayer: Prayer) {
    var prayer = prayer
    prayer.customOptions = RosaryOptions.normalizedCustomOptions(
      prayer.customOptions, bundleId: prayer.customDevotionId ?? "")
    _prayer = State(initialValue: prayer)
  }

  /// `prayer.kind.displayName` is only a generic fallback (a single `PrayerKind` case can't
  /// carry per-bundle text) — read the real name from the bundle's own manifest.
  private var info: CustomDevotionInfo? {
    prayer.customDevotionId.flatMap { PrayerPackStore.info(for: $0) }
  }

  private var options: [CustomDevotionOption] {
    guard let id = prayer.customDevotionId else { return [] }
    return CustomDevotionOption.normalizedForEditing(PrayerPackStore.options(for: id), bundleId: id)
  }

  var body: some View {
    editorLayout
    #if os(macOS)
    .navigationTitle(String(localized: "macLibrary.settingsTitle", defaultValue: "Prayer Settings", bundle: UILanguage.bundle, locale: UILanguage.locale))
    #else
    .navigationTitle(info?.localizedDisplayName ?? prayer.kind.displayName)
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
      String(localized: "favoriteEditor.saveFailed", defaultValue: "Could Not Save Favorite", bundle: UILanguage.bundle, locale: UILanguage.locale),
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
    MacPrayerEditorSheet(preferredSize: CGSize(width: 580, height: 520)) {
      editorSections
    } actions: {
      Button("favoriteEditor.cancel") { dismiss() }
        .keyboardShortcut(.cancelAction)
        .accessibilityIdentifier("remindersEditorCancelButton")
      Button("favoriteEditor.save") { save() }
        .keyboardShortcut(.defaultAction)
        .accessibilityIdentifier("remindersEditorSaveButton")
    }
    .disabled(isSaving)
    #else
    Form { editorSections }
      .formStyle(.grouped)
    #endif
  }

  @ViewBuilder private var editorSections: some View {
    #if os(macOS)
    Section {
      TextField("favoriteEditor.name", text: $prayer.name)
      PrayerLanguagePicker(
        label: String(localized: "favoriteEditor.language", defaultValue: "Language", bundle: UILanguage.bundle, locale: UILanguage.locale),
        code: $prayer.languageCode,
        defaultLabel: String(localized: "macLibrary.default", defaultValue: "Default", bundle: UILanguage.bundle, locale: UILanguage.locale))
      if let id = prayer.customDevotionId,
         CustomDevotionLaunch.allowsVariantChoice(id),
         let definition = PrayerPackStore.definition(for: id),
         let variants = definition.variants, variants.count > 1 {
        Picker(String(localized: "macLibrary.form", defaultValue: "Form", bundle: UILanguage.bundle, locale: UILanguage.locale), selection: Binding<String>(
          get: { prayer.variantId ?? "" },
          set: { prayer.variantId = $0.isEmpty ? nil : $0 })) {
          Text(String(localized: "macLibrary.default", defaultValue: "Default", bundle: UILanguage.bundle, locale: UILanguage.locale)).tag("")
          ForEach(variants, id: \.id) { variant in Text(variant.localizedName).tag(variant.id) }
        }
      }
    }
    #endif
    if !options.isEmpty {
      Section("favoriteEditor.options") {
        ForEach(options, id: \.key) { option in
          switch option.kind {
          case .toggle:
            Toggle(option.localizedName, isOn: toggleBinding(for: option))
          case .choice:
            Picker(option.localizedName, selection: choiceBinding(for: option)) {
              ForEach(option.cases ?? [], id: \.id) { optionCase in
                Text(optionCase.localizedName).tag(optionCase.id)
              }
            }
          }
        }
      }
    }
    RemindersSection(
      reminders: $prayer.reminders,
      presetHours: info?.reminderPresetHours ?? [],
      presetFooter: info?.localizedReminderPresetFooter)
  }

  // Bindings read through to the option's declared default so the rows show the effective
  // value even before the user has ever touched them; writes store an explicit override.
  private func toggleBinding(for option: CustomDevotionOption) -> Binding<Bool> {
    Binding(
      get: { (prayer.customOptions[option.key] ?? option.defaultValue) == "true" },
      set: { prayer.customOptions[option.key] = $0 ? "true" : "false" })
  }

  private func choiceBinding(for option: CustomDevotionOption) -> Binding<String> {
    Binding(
      get: { prayer.customOptions[option.key] ?? option.defaultValue },
      set: { prayer.customOptions[option.key] = $0 })
  }

  private func save() {
    guard !isSaving else { return }
    isSaving = true
    var toSave = prayer
    if toSave.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      toSave.name = info?.localizedDisplayName ?? toSave.kind.defaultName
    }
    Task {
      defer { isSaving = false }
      if !toSave.reminders.filter(\.isEnabled).isEmpty {
        await ReminderScheduler.requestPermission()
      }
      do {
        guard try await services.presetStore.updateIfPresent(toSave) else {
          throw PrayerRemovalService.RemovalError.prayerRemoved
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

#Preview("Angelus") {
  NavigationStack {
    RemindersOnlyEditorView(prayer: Prayer(
      name: "Angelus",
      kind: .custom,
      isDefault: true,
      customDevotionId: "angelus",
      reminders: [PrayerReminder(hour: 6), PrayerReminder(hour: 18)]
    ))
  }
}

#Preview("Stations — no reminders yet") {
  NavigationStack {
    RemindersOnlyEditorView(prayer: Prayer(
      name: "Stations of the Cross",
      kind: .custom,
      isDefault: true,
      customDevotionId: "stationsOfTheCross"
    ))
  }
}
