//
//  HomeView.swift
//  Prosary
//

import SwiftUI

struct HomeView: View {
    @Binding var path: NavigationPath

    @Environment(\.appServices) private var services

    @State private var todayMysteryGroupName = ""
    @State private var seasonColor = Color.clear
    @State private var defaultPresetName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Prosary")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.brandHeadline)

                Text("A companion for praying the Rosary and other Catholic devotions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Divider().padding(.vertical, 8)

                if !todayMysteryGroupName.isEmpty {
                    HStack(spacing: 4) {
                        Text("Today's Mysteries:")
                        Text(todayMysteryGroupName).fontWeight(.bold)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(seasonColor, in: Capsule())
                    .accessibilityElement(children: .combine)
                }

                if !defaultPresetName.isEmpty {
                    Text("Preset: \(defaultPresetName)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    prayWithDefaultPreset()
                } label: {
                    Text("Pray the Rosary")
                        .frame(maxWidth: .infinity)
                }
                .prosaryProminentButtonStyle()
                .tint(Color.brandPrimary)
                .controlSize(.large)
                .padding(.top, 16)

                NavigationLink(value: AppRoute.presets) {
                    Text("My Presets")
                        .frame(maxWidth: .infinity)
                }
                .prosarySecondaryButtonStyle()
                .tint(Color.brandPrimary)
                .controlSize(.large)

                #if !os(macOS)
                // On Mac, "About Prosary" is reachable only from the app menu bar — the native
                // convention every Mac app follows. Everywhere else there's no menu bar, so an
                // in-app entry point is needed instead.
                NavigationLink(value: AppRoute.about) {
                    Text("About")
                        .font(.footnote)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                #endif
            }
            .padding(24)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .task {
            await loadTodayInfo()
        }
    }

    private func loadTodayInfo() async {
        todayMysteryGroupName = services.calendar.mysteryGroupToday().displayName
        seasonColor = services.calendar.seasonColorToday()
        if let preset = try? await services.presetStore.defaultPreset() {
            defaultPresetName = preset.name
        }
    }

    private func prayWithDefaultPreset() {
        Task {
            guard let preset = try? await services.presetStore.defaultPreset() else { return }
            path.append(AppRoute.rosary(configId: preset.id))
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(path: .constant(NavigationPath()))
    }
}

#Preview("Dark Mode") {
    NavigationStack {
        HomeView(path: .constant(NavigationPath()))
    }
    .preferredColorScheme(.dark)
}
