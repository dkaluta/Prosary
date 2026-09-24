//
//  RosaryPresetsView.swift
//  Prosary
//
//  The Rosary's saved presets, opened from its row on Pray. Tapping the row prays the default
//  straight away; this is where the other presets live, so someone with four saved Rosaries has
//  one Pray row instead of four.
//

import SwiftUI

struct RosaryPresetsView: View {
  @Binding var path: [AppRoute]

  @Environment(\.appServices) private var services

  @State private var presets: [Prayer] = []
  @State private var deletingPrayer: Prayer?
  @State private var showsQuickSetup = false
  // Preset management lives here now that the separate Favorites screen is gone.
  @State private var editorPreset: Prayer?
  @State private var isNew = false
  @State private var remindersPreset: Prayer?

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
              Text("rosaryPicker.anyRosaryAction")
                .font(.headline)
              Text("rosaryPicker.anyRosaryDetail")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.forward")
              .foregroundStyle(.secondary)
          }
          .padding(14)
          .frame(maxWidth: .infinity, alignment: .leading)
          .prosarySpatialTarget(alignment: .leading)
          .prosaryContentCardBackground()
        }
        .buttonStyle(.plain)
        .prosarySpatialHoverEffect(in: RoundedRectangle(cornerRadius: 14))
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
    .sheet(item: $editorPreset) { preset in
      NavigationStack { FavoriteEditorView(prayer: preset, isNew: isNew) }
        .onDisappear { Task { await reload() } }
    }
    .sheet(item: $remindersPreset) { preset in
      NavigationStack { RemindersOnlyEditorView(prayer: preset) }
        .onDisappear { Task { await reload() } }
    }
    .sheet(isPresented: $showsQuickSetup) {
      RosaryQuickSetupView(
        seed: defaultPreset?.rosary ?? RosaryOptions(),
        hasPresets: !presets.isEmpty
      ) { prayer in
        showsQuickSetup = false
        path.push(AppRoute.rosaryQuickPray(prayer: prayer))
      } onSaved: {
        Task { await reload() }
      }
    }
    .task { await reload() }
    .modifier(PrayerRemovalDialogs(prayer: $deletingPrayer, onDeleted: { await reload() }))
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      Task { await reload() }
    }
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
    presetCardBody(preset, prominent: prominent)
      // Keep the lifted context-menu preview clipped to the actual card. The horizontal page
      // gutter belongs outside that preview; when it was part of the preview bounds, iPhone
      // made the card itself disappear into a wide transparent cutout while pressed.
      .rosaryPresetContextMenuShape()
      .contextMenu {
        Button { isNew = false; editorPreset = preset } label: {
          Label("favorites.edit", systemImage: "pencil")
        }
        Button { remindersPreset = preset } label: {
          Label("favorites.reminders", systemImage: "bell")
        }
        if !preset.isDefault {
          Button { makeDefault(preset) } label: {
            Label("favorites.setDefault", systemImage: "star")
          }
        }
        Divider()
        Button(role: .destructive) { deletingPrayer = preset } label: {
          Label(String(localized: "removal.deleteAction", defaultValue: "Delete Saved Prayer…", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "trash")
        }
      }
      .padding(.horizontal, 16)
  }

  @ViewBuilder
  private func presetCardBody(_ preset: Prayer, prominent: Bool) -> some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(Color.brandPrimary)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(HebrewDisplayText.unpointed(preset.name))
            .font(prominent ? .title3.bold() : .headline)
          if preset.isDefault {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(.yellow)
          }
          Spacer()
        }
        Text(HebrewDisplayText.unpointed(
          "\(preset.rosary.mysterySelectionSummary) • \(preset.languageDisplayName)"))
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Button {
          path.push(AppRoute.prayer(id: preset.id))
        } label: {
          Text("favorites.pray")
            .frame(maxWidth: .infinity)
            .prosarySpatialTarget()
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.brandPrimary)
        .padding(.top, 2)
        .accessibilityLabel(String(localized: "favorites.prayPrayer", defaultValue: "Pray \(preset.name)", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .accessibilityIdentifier(preset.isDefault ? "prayDefaultPreset" : "prayPreset")
      }
      .padding(14)
    }
    .prosaryContentCardBackground()
    .clipShape(RoundedRectangle(cornerRadius: 14))
  }

  private func makeDefault(_ preset: Prayer) {
    var updated = preset
    updated.isDefault = true
    Task {
      _ = try? await services.presetStore.updateIfPresent(updated)
      await reload()
    }
  }


  private func reload() async {
    presets = ((try? await services.presetStore.all()) ?? [])
      .filter { $0.kind == .rosary }
  }
}

private extension View {
  @ViewBuilder
  func rosaryPresetContextMenuShape() -> some View {
    #if os(iOS)
    contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 14))
    #else
    self
    #endif
  }
}


#Preview {
  NavigationStack {
    RosaryPresetsView(path: .constant([]))
  }
}
