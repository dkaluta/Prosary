//
//  HomeView.swift
//  Prosary
//

import SwiftUI

struct HomeView: View {
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services

  @State private var todayMysteryGroup: MysteryGroup? = nil
  @State private var defaultRosary: Prayer? = nil
  @State private var defaultAngelus: Prayer? = nil
  @State private var defaultJesusPrayer: Prayer? = nil

  private var rosaryAccent: Color { todayMysteryGroup?.color ?? Color.brandPrimary }
  private var angelusAccent: Color { .adaptive(light: "#8B6914", dark: "#C49B0D") }
  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }

  private var rosarySubtitle: String {
    var parts: [String] = []
    if let group = todayMysteryGroup {
      parts.append(String(localized: "home.rosaryCard.today", defaultValue: "Today: \(group.displayName)"))
    }
    if let preset = defaultRosary { parts.append(preset.name) }
    return parts.joined(separator: " • ")
  }

  private var angelusSubtitle: String {
    defaultAngelus.map { $0.name } ?? String(localized: "home.angelusCard.tapToPray", defaultValue: "Tap to pray")
  }

  private var jesusPrayerSubtitle: String {
    guard let fav = defaultJesusPrayer else {
      return String(localized: "home.jesusPrayerCard.tapToSetUp", defaultValue: "Tap to set up")
    }
    return "\(fav.name) • \(fav.jesusPrayer.targetDisplayName)"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        VStack(spacing: 6) {
          Text("home.title")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.brandHeadline)
          Text("home.tagline")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)

        VStack(spacing: 12) {
          PrayerCard(
            systemImage: PrayerKind.rosary.systemImage,
            title: PrayerKind.rosary.displayName,
            subtitle: rosarySubtitle,
            accentColor: rosaryAccent
          ) {
            launchRosary()
          }
          .accessibilityIdentifier("rosaryCard")

          PrayerCard(
            systemImage: PrayerKind.angelus.systemImage,
            title: PrayerKind.angelus.displayName,
            subtitle: angelusSubtitle,
            accentColor: angelusAccent
          ) {
            launchAngelus()
          }
          .accessibilityIdentifier("angelusCard")

          PrayerCard(
            systemImage: PrayerKind.jesusPrayer.systemImage,
            title: PrayerKind.jesusPrayer.displayName,
            subtitle: jesusPrayerSubtitle,
            accentColor: jesusPrayerAccent
          ) {
            launchJesusPrayer()
          }
          .accessibilityIdentifier("jesusPrayerCard")
        }

        Divider().padding(.vertical, 4)

        VStack(spacing: 12) {
          NavigationLink(value: AppRoute.favorites) {
            Label("home.myFavorites", systemImage: "star")
              .frame(maxWidth: .infinity)
          }
          .prosarySecondaryButtonStyle()
          .tint(Color.brandPrimary)
          .controlSize(.large)

          #if !os(macOS)
          NavigationLink(value: AppRoute.about) {
            Text("home.about")
              .font(.footnote)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .padding(.top, 4)
          #endif
        }
      }
      .padding(24)
      .frame(maxWidth: 480)
      .frame(maxWidth: .infinity)
    }
    .task { await load() }
  }

  private func load() async {
    todayMysteryGroup = services.calendar.mysteryGroupToday()
    let all = (try? await services.presetStore.all()) ?? []
    defaultRosary = all.first { $0.kind == .rosary && $0.isDefault }
      ?? all.first { $0.kind == .rosary }
    defaultAngelus = all.first { $0.kind == .angelus && $0.isDefault }
      ?? all.first { $0.kind == .angelus }
    defaultJesusPrayer = all.first { $0.kind == .jesusPrayer && $0.isDefault }
      ?? all.first { $0.kind == .jesusPrayer }
  }

  private func launchRosary() {
    guard let prayer = defaultRosary else {
      path.append(AppRoute.favorites)
      return
    }
    path.append(AppRoute.prayer(id: prayer.id))
  }

  private func launchAngelus() {
    if let prayer = defaultAngelus {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.angelus)
    }
  }

  private func launchJesusPrayer() {
    if let prayer = defaultJesusPrayer {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.jesusPrayerSetup)
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
