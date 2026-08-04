//
//  RosaryPresetPickerView.swift
//  Prosary
//
//  Home → Rosary lands here instead of launching a session directly: the default preset up
//  top (one tap to pray), then "Pray any Rosary" (an ad-hoc quick-setup sheet whose options
//  seed from the default preset and can be saved as a new preset), then the remaining presets.
//  Preset management (rename/delete/set-default) stays in Favorites.
//

import SwiftUI

struct RosaryPresetPickerView: View {
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services

  @State private var presets: [Prayer] = []
  @State private var showsQuickSetup = false

  private var defaultPreset: Prayer? { presets.first { $0.isDefault } }
  private var otherPresets: [Prayer] { presets.filter { !$0.isDefault } }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if let preset = defaultPreset {
          sectionHeader("rosaryPicker.defaultHeader", systemImage: "star.fill")
          presetCard(preset, prominent: true)
        }

        sectionHeader("rosaryPicker.anyRosaryHeader", systemImage: "slider.horizontal.3")
        Button {
          showsQuickSetup = true
        } label: {
          HStack(spacing: 12) {
            Image(systemName: "sparkles")
              .foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: 2) {
              Text("rosaryPicker.anyRosary")
                .font(.headline)
              Text("rosaryPicker.anyRosaryDetail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityIdentifier("prayAnyRosary")

        if !otherPresets.isEmpty {
          sectionHeader("rosaryPicker.presetsHeader", systemImage: "bookmark")
          ForEach(otherPresets) { preset in
            presetCard(preset, prominent: false)
          }
        }
      }
      .padding(.vertical, 12)
    }
    .navigationTitle("rosaryPicker.title")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("rosaryPicker.managePresets") { path.append(AppRoute.favorites) }
      }
    }
    .sheet(isPresented: $showsQuickSetup) {
      RosaryQuickSetupView(
        seed: defaultPreset?.rosary ?? RosaryOptions(),
        hasPresets: !presets.isEmpty
      ) { prayer in
        showsQuickSetup = false
        path.append(AppRoute.rosaryQuickPray(prayer: prayer))
      } onSaved: {
        Task { await reload() }
      }
    }
    .task { await reload() }
  }

  @ViewBuilder
  private func sectionHeader(_ key: LocalizedStringKey, systemImage: String) -> some View {
    Label { Text(key).font(.subheadline.bold()) } icon: { Image(systemName: systemImage) }
      .foregroundStyle(.secondary)
      .padding(.horizontal, 20)
      .padding(.top, 8)
  }

  @ViewBuilder
  private func presetCard(_ preset: Prayer, prominent: Bool) -> some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(Color.brandPrimary)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(preset.name)
            .font(prominent ? .title3.bold() : .headline)
          if preset.isDefault {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(.yellow)
          }
          Spacer()
        }
        Text("\(preset.rosary.mysterySelectionSummary) • \(preset.languageDisplayName)")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Button {
          path.append(AppRoute.prayer(id: preset.id))
        } label: {
          Text("favorites.pray")
            .frame(maxWidth: .infinity)
        }
        .prosaryProminentButtonStyle()
        .tint(Color.brandPrimary)
        .padding(.top, 2)
        .accessibilityLabel(String(localized: "favorites.prayPrayer", defaultValue: "Pray \(preset.name)"))
      }
      .padding(14)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
  }

  private func reload() async {
    presets = ((try? await services.presetStore.all()) ?? [])
      .filter { $0.kind == .rosary }
  }
}

/// The "Pray any Rosary" quick setup: the full Rosary options editor over a scratch Prayer —
/// pray it without saving anything, or keep it as a new preset (never stealing the default
/// slot unless it's the first preset).
struct RosaryQuickSetupView: View {
  let seed: RosaryOptions
  let hasPresets: Bool
  let onPray: (Prayer) -> Void
  let onSaved: () -> Void

  @Environment(\.appServices) private var services
  @Environment(\.dismiss) private var dismiss

  @State private var options = RosaryOptions()
  @State private var showsSaveNamePrompt = false
  @State private var presetName = ""
  @State private var didSeed = false

  var body: some View {
    NavigationStack {
      Form {
        RosaryOptionsSections(rosary: $options)

        Section {
          Button {
            showsSaveNamePrompt = true
          } label: {
            Label("rosaryPicker.saveAsPreset", systemImage: "bookmark")
          }
        }
      }
      .formStyle(.grouped)
      .navigationTitle("rosaryPicker.anyRosary")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("favoriteEditor.cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("favorites.pray") {
            onPray(Prayer(name: "", kind: .rosary, rosary: options))
          }
        }
      }
      .alert("rosaryPicker.saveAsPreset", isPresented: $showsSaveNamePrompt) {
        TextField(
          String(localized: "rosaryPicker.presetNamePlaceholder", defaultValue: "Preset name"),
          text: $presetName)
        Button("favoriteEditor.save") { save() }
        Button("favoriteEditor.cancel", role: .cancel) {}
      }
      .onAppear {
        guard !didSeed else { return }
        didSeed = true
        options = seed
      }
    }
  }

  private func save() {
    let name = presetName.trimmingCharacters(in: .whitespaces)
    let preset = Prayer(
      name: name.isEmpty ? PrayerKind.rosary.defaultName : name,
      kind: .rosary,
      isDefault: !hasPresets,
      rosary: options)
    Task {
      try? await services.presetStore.save(preset)
      onSaved()
      dismiss()
    }
  }
}

#Preview {
  NavigationStack {
    RosaryPresetPickerView(path: .constant(NavigationPath()))
  }
}
