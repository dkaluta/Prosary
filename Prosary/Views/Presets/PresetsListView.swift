//
//  PresetsListView.swift
//  Prosary
//

import SwiftUI

struct PresetsListView: View {
    @Binding var path: NavigationPath

    @Environment(\.appServices) private var services

    @State private var presets: [RosaryConfig] = []
    @State private var editorConfig: RosaryConfig?
    @State private var isNewConfig = false

    var body: some View {
        List {
            ForEach(presets) { config in
                PresetRow(
                    config: config,
                    canDelete: presets.count > 1,
                    onPray: { path.append(AppRoute.rosary(configId: config.id)) },
                    onEdit: { edit(config) },
                    onMakeDefault: { makeDefault(config) },
                    onDelete: { delete(config) })
            }
        }
        .navigationTitle("My Presets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addNew()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
        }
        .sheet(item: $editorConfig) { config in
            NavigationStack {
                PresetEditorView(config: config, isNew: isNewConfig)
            }
            .onDisappear {
                Task { await reload() }
            }
        }
        .task {
            await reload()
        }
    }

    private func reload() async {
        presets = (try? await services.presetStore.all()) ?? []
    }

    private func addNew() {
        isNewConfig = true
        editorConfig = RosaryConfig(isDefault: presets.isEmpty)
    }

    private func edit(_ config: RosaryConfig) {
        isNewConfig = false
        editorConfig = config
    }

    private func makeDefault(_ config: RosaryConfig) {
        var updated = config
        updated.isDefault = true
        Task {
            try? await services.presetStore.save(updated)
            await reload()
        }
    }

    private func delete(_ config: RosaryConfig) {
        Task {
            try? await services.presetStore.delete(config)
            await reload()
        }
    }
}

private struct PresetRow: View {
    let config: RosaryConfig
    let canDelete: Bool
    let onPray: () -> Void
    let onEdit: () -> Void
    let onMakeDefault: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(config.name)
                    .font(.headline)
                Spacer()
                if config.isDefault {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(Color.brandPrimary)
                }

                // Icon-only accessories rather than another labeled button — these are secondary,
                // low-frequency actions, so a small recognizable glyph next to the title reads as
                // "row options" without competing with the primary "Pray" action below.
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Edit \(config.name)")

                if canDelete {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Delete \(config.name)")
                }
            }

            Text("Mysteries: \(config.mysterySelectionSummary)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Language: \(config.languageNativeName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // "Pray" is the row's primary action, so it gets a real, obviously-tappable glass
            // button instead of a plain "Pray >" navigation label that reads more like text. A
            // `NavigationLink` here would look exactly like that plain label anyway — inside a
            // `List`, its row chrome overrides any button style applied to it — so this pushes
            // onto the shared nav path directly instead of relying on NavigationLink at all.
            HStack(spacing: 8) {
                Button(action: onPray) {
                    Text("Pray")
                        .frame(maxWidth: .infinity)
                }
                .prosaryProminentButtonStyle()
                .tint(.brandPrimary)
                .accessibilityLabel("Pray with \(config.name)")

                if !config.isDefault {
                    Button(action: onMakeDefault) {
                        Text("Make Default")
                            .frame(maxWidth: .infinity)
                    }
                    .prosarySecondaryButtonStyle()
                    .accessibilityLabel("Make \(config.name) the default preset")
                }
            }
            .controlSize(.regular)
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    NavigationStack {
        PresetsListView(path: .constant(NavigationPath()))
    }
}
