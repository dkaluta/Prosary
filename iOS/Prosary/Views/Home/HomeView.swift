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
  @State private var defaultStations: Prayer? = nil
  @State private var defaultFranciscanCrown: Prayer? = nil
  @State private var defaultSevenSorrows: Prayer? = nil
  @State private var defaultDivineMercy: Prayer? = nil

  private var rosaryAccent: Color { todayMysteryGroup?.color ?? Color.brandPrimary }
  private var angelusAccent: Color { .adaptive(light: "#8B6914", dark: "#C49B0D") }
  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }
  private var stationsAccent: Color { .adaptive(light: "#5C2D91", dark: "#8756B5") }
  private var franciscanCrownAccent: Color { .adaptive(light: "#6B4226", dark: "#A67C52") }
  private var sevenSorrowsAccent: Color { .adaptive(light: "#6B0F1A", dark: "#B33951") }
  private var divineMercyAccent: Color { .adaptive(light: "#C41E3A", dark: "#E8637A") }

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

  private var stationsSubtitle: String {
    defaultStations.map { $0.name } ?? String(localized: "home.stationsCard.tapToPray", defaultValue: "Tap to pray")
  }

  private var franciscanCrownSubtitle: String {
    defaultFranciscanCrown.map { $0.name } ?? String(localized: "home.franciscanCrownCard.tapToPray", defaultValue: "Tap to pray")
  }

  private var sevenSorrowsSubtitle: String {
    defaultSevenSorrows.map { $0.name } ?? String(localized: "home.sevenSorrowsCard.tapToPray", defaultValue: "Tap to pray")
  }

  private var divineMercySubtitle: String {
    defaultDivineMercy.map { $0.name } ?? String(localized: "home.divineMercyCard.tapToPray", defaultValue: "Tap to pray")
  }

  /// One entry per devotion card shown on Home. Adding a new devotion means adding one entry
  /// here — the accent/subtitle/launch logic for each kind can still be as bespoke as it needs
  /// to be (e.g. Rosary's mystery-of-the-day accent color), but the view body itself no longer
  /// hand-rolls a `PrayerCard` block per kind.
  private var devotionCards: [DevotionCard] {
    [
      DevotionCard(
        kind: .rosary, accentColor: rosaryAccent, subtitle: rosarySubtitle,
        accessibilityIdentifier: "rosaryCard", action: launchRosary),
      DevotionCard(
        kind: .angelus, accentColor: angelusAccent, subtitle: angelusSubtitle,
        accessibilityIdentifier: "angelusCard", action: launchAngelus),
      DevotionCard(
        kind: .jesusPrayer, accentColor: jesusPrayerAccent, subtitle: jesusPrayerSubtitle,
        accessibilityIdentifier: "jesusPrayerCard", action: launchJesusPrayer),
      DevotionCard(
        kind: .stationsOfTheCross, accentColor: stationsAccent, subtitle: stationsSubtitle,
        accessibilityIdentifier: "stationsOfTheCrossCard", action: launchStationsOfTheCross),
      DevotionCard(
        kind: .franciscanCrown, accentColor: franciscanCrownAccent, subtitle: franciscanCrownSubtitle,
        accessibilityIdentifier: "franciscanCrownCard", action: launchFranciscanCrown),
      DevotionCard(
        kind: .sevenSorrows, accentColor: sevenSorrowsAccent, subtitle: sevenSorrowsSubtitle,
        accessibilityIdentifier: "sevenSorrowsCard", action: launchSevenSorrows),
      DevotionCard(
        kind: .divineMercyChaplet, accentColor: divineMercyAccent, subtitle: divineMercySubtitle,
        accessibilityIdentifier: "divineMercyCard", action: launchDivineMercy),
    ]
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
          ForEach(devotionCards) { card in
            PrayerCard(
              systemImage: card.kind.systemImage,
              title: card.kind.displayName,
              subtitle: card.subtitle,
              accentColor: card.accentColor
            ) {
              card.action()
            }
            .accessibilityIdentifier(card.accessibilityIdentifier)
          }
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
    defaultStations = all.first { $0.kind == .stationsOfTheCross && $0.isDefault }
      ?? all.first { $0.kind == .stationsOfTheCross }
    defaultFranciscanCrown = all.first { $0.kind == .franciscanCrown && $0.isDefault }
      ?? all.first { $0.kind == .franciscanCrown }
    defaultSevenSorrows = all.first { $0.kind == .sevenSorrows && $0.isDefault }
      ?? all.first { $0.kind == .sevenSorrows }
    defaultDivineMercy = all.first { $0.kind == .divineMercyChaplet && $0.isDefault }
      ?? all.first { $0.kind == .divineMercyChaplet }
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

  private func launchStationsOfTheCross() {
    if let prayer = defaultStations {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.stationsOfTheCross)
    }
  }

  private func launchFranciscanCrown() {
    if let prayer = defaultFranciscanCrown {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.franciscanCrown)
    }
  }

  private func launchSevenSorrows() {
    if let prayer = defaultSevenSorrows {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.sevenSorrows)
    }
  }

  private func launchDivineMercy() {
    if let prayer = defaultDivineMercy {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.divineMercyChaplet)
    }
  }
}

/// One devotion's rendering state for a Home card. See `HomeView.devotionCards`.
private struct DevotionCard: Identifiable {
  var id: PrayerKind { kind }
  let kind: PrayerKind
  let accentColor: Color
  let subtitle: String
  let accessibilityIdentifier: String
  let action: () -> Void
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
