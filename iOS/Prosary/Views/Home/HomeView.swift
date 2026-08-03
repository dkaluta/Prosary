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
  @State private var defaultJesusPrayer: Prayer? = nil
  /// One entry per discovered generic devotion (bundle id -> its favorite, if any).
  @State private var defaultCustomDevotions: [String: Prayer] = [:]
  @State private var todayFeast: FeastDay? = nil
  @State private var monthIntention: PopeIntention? = nil

  /// Bumped on every appearance — see devotionCards.
  @State private var packGeneration = 0

  private var rosaryAccent: Color { todayMysteryGroup?.color ?? Color.brandPrimary }
  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }

  private var rosarySubtitle: String {
    var parts: [String] = []
    if let group = todayMysteryGroup {
      parts.append(String(localized: "home.rosaryCard.today", defaultValue: "Today: \(group.displayName)"))
    }
    if let preset = defaultRosary { parts.append(preset.name) }
    return parts.joined(separator: " • ")
  }

  private var jesusPrayerSubtitle: String {
    guard let fav = defaultJesusPrayer else {
      return String(localized: "home.jesusPrayerCard.tapToSetUp", defaultValue: "Tap to set up")
    }
    return "\(fav.name) • \(fav.jesusPrayer.targetDisplayName)"
  }

  private func customDevotionSubtitle(bundleId: String) -> String {
    defaultCustomDevotions[bundleId].map { $0.name } ?? String(localized: "home.customCard.tapToPray", defaultValue: "Tap to pray")
  }

  /// Accent color for a generic devotion's card, honoring the manifest's light/dark pair.
  private func customAccent(_ info: CustomDevotionInfo) -> Color {
    if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
      return .adaptive(light: light, dark: dark)
    }
    return info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary
  }

  /// One card per devotion: the Rosary first (the app's namesake), then every generic
  /// (bundle-driven) devotion in pack-load order — icon/title/accent read from each bundle's own
  /// manifest, nothing hardcoded here — and the Jesus Prayer (the counter-based odd one out)
  /// last. Adding a devotion means shipping a bundle; this view doesn't change.
  /// Bumped whenever the saved order changes so the grid re-derives.
  @State private var orderGeneration = 0
  @State private var showsOrderEditor = false

  private var devotionCards: [DevotionCard] {
    _ = orderGeneration
    // Read the generation so installing a bundle elsewhere (Browse/Search/Favorites)
    // invalidates this body and the new card appears without a relaunch.
    _ = packGeneration
    var cards = [
      DevotionCard(
        id: PrayerKind.rosary.rawValue, systemImage: PrayerKind.rosary.systemImage, title: PrayerKind.rosary.displayName,
        accentColor: rosaryAccent, subtitle: rosarySubtitle,
        accessibilityIdentifier: "rosaryCard", action: launchRosary),
    ]

    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let info = PrayerPackStore.info(for: bundleId) else { continue }
      cards.append(DevotionCard(
        id: "custom.\(bundleId)",
        systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
        iconGlyph: info.iconGlyph,
        title: info.localizedDisplayName,
        accentColor: customAccent(info),
        subtitle: customDevotionSubtitle(bundleId: bundleId),
        accessibilityIdentifier: "\(bundleId)Card",
        action: { launchCustomDevotion(bundleId: bundleId) }))
    }

    cards.append(DevotionCard(
      id: PrayerKind.jesusPrayer.rawValue, systemImage: PrayerKind.jesusPrayer.systemImage, title: PrayerKind.jesusPrayer.displayName,
      accentColor: jesusPrayerAccent, subtitle: jesusPrayerSubtitle,
      accessibilityIdentifier: "jesusPrayerCard", action: launchJesusPrayer))

    return HomeOrder.apply(cards, id: \.id)
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // "Today" — the day's feast per the Holy Land (Latin Patriarchate of Jerusalem)
        // calendar and the Pope's monthly prayer intention. Rows hide when the bundled
        // datasets have no entry (ferial days; dates past the generated years).
        if todayFeast != nil || monthIntention != nil {
          VStack(alignment: .leading, spacing: 10) {
            if let feast = todayFeast {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "calendar")
                  .foregroundStyle(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                  Text(feast.title)
                    .font(.subheadline.weight(feast.rank == "Solemnity" ? .bold : .semibold))
                  Text(feast.rank)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
            if let intention = monthIntention {
              HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "hands.sparkles")
                  .foregroundStyle(Color.brandPrimary)
                VStack(alignment: .leading, spacing: 2) {
                  Text(String(
                    localized: "home.today.popesIntention",
                    defaultValue: "The Pope’s intention: \(intention.title)"))
                    .font(.subheadline.weight(.semibold))
                  Text(intention.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
          .accessibilityIdentifier("todaySection")
        }

        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 12, alignment: .top)],
          spacing: 12
        ) {
          ForEach(devotionCards) { card in
            PrayerCard(
              systemImage: card.systemImage,
              iconGlyph: card.iconGlyph,
              title: card.title,
              subtitle: card.subtitle,
              accentColor: card.accentColor
            ) {
              card.action()
            }
            .accessibilityIdentifier(card.accessibilityIdentifier)
            .contextMenu {
              Button {
                HomeOrder.moveToTop(card.id, allIdsInDisplayOrder: devotionCards.map(\.id))
                orderGeneration += 1
              } label: {
                Label(String(localized: "home.moveToTop", defaultValue: "Move to Top"),
                      systemImage: "arrow.up.to.line")
              }
              Button {
                showsOrderEditor = true
              } label: {
                Label(String(localized: "home.editOrder", defaultValue: "Edit Order…"),
                      systemImage: "arrow.up.arrow.down")
              }
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: 1000)
      .frame(maxWidth: .infinity)
    }
    // The tab shell carries the app's identity now — the bar shows the section name, and the
    // old bottom Favorites button / About link become toolbar icons.
    .navigationTitle(String(localized: "tabs.pray", defaultValue: "Pray"))
    .sheet(isPresented: $showsOrderEditor) {
      HomeOrderEditor(cards: devotionCards) { orderGeneration += 1 }
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { showsOrderEditor = true } label: {
          Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "home.editOrder", defaultValue: "Edit Order…"))
        .accessibilityIdentifier("editOrderButton")
      }
      ToolbarItem(placement: .primaryAction) {
        NavigationLink(value: AppRoute.favorites) {
          Image(systemName: "star")
        }
        .accessibilityLabel(Text("home.myFavorites"))
        .accessibilityIdentifier("favoritesButton")
      }
      #if !os(macOS)
      ToolbarItem(placement: .primaryAction) {
        NavigationLink(value: AppRoute.about) {
          Image(systemName: "info.circle")
        }
        .accessibilityLabel(Text("home.about"))
      }
      #endif
    }
    .task { await load() }
    .onAppear {
      packGeneration += 1
      Task { await load() }
    }
  }

  private func load() async {
    todayMysteryGroup = services.calendar.mysteryGroupToday()
    todayFeast = TodayInfoStore.feast()
    monthIntention = TodayInfoStore.intention()
    let all = (try? await services.presetStore.all()) ?? []
    defaultRosary = all.first { $0.kind == .rosary && $0.isDefault }
      ?? all.first { $0.kind == .rosary }
    defaultJesusPrayer = all.first { $0.kind == .jesusPrayer && $0.isDefault }
      ?? all.first { $0.kind == .jesusPrayer }

    defaultCustomDevotions = Dictionary(
      uniqueKeysWithValues: PrayerPackStore.customDevotionIds().compactMap { bundleId -> (String, Prayer)? in
        let favorite = all.first { $0.kind == .custom && $0.customDevotionId == bundleId && $0.isDefault }
          ?? all.first { $0.kind == .custom && $0.customDevotionId == bundleId }
        return favorite.map { (bundleId, $0) }
      })
  }

  private func launchRosary() {
    // The picker handles every case itself (default preset up top, ad-hoc quick pray, the
    // remaining presets) — including having no presets at all.
    path.append(AppRoute.rosaryPicker)
  }

  private func launchJesusPrayer() {
    if let prayer = defaultJesusPrayer {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.jesusPrayerSetup)
    }
  }

  private func launchCustomDevotion(bundleId: String) {
    if let prayer = defaultCustomDevotions[bundleId] {
      path.append(AppRoute.prayer(id: prayer.id))
    } else {
      path.append(AppRoute.custom(devotionId: bundleId))
    }
  }
}

/// One devotion's rendering state for a Home card. See `HomeView.devotionCards`.
private struct DevotionCard: Identifiable {
  let id: String
  let systemImage: String
    var iconGlyph: String? = nil
  let title: String
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


/// The approved reorder pattern (not jiggle): a plain List in permanent edit mode — drag
/// handles appear, rows move, order persists on every change. Reset returns to directory
/// order. Presented as a sheet so the Home grid itself stays a grid.
private struct HomeOrderEditor: View {
  let cards: [DevotionCard]
  let onChange: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var ids: [String] = []
  @State private var titles: [String: String] = [:]

  var body: some View {
    NavigationStack {
      List {
        ForEach(ids, id: \.self) { id in
          Text(titles[id] ?? id)
        }
        .onMove { from, to in
          ids.move(fromOffsets: from, toOffset: to)
          HomeOrder.save(ids)
          onChange()
        }
      }
      #if os(iOS)
      .environment(\.editMode, .constant(.active)) // drag handles; macOS Lists drag natively
      #endif
      #if os(macOS)
      .frame(minWidth: 340, minHeight: 420)
      #endif
      .navigationTitle(String(localized: "home.editOrder.title", defaultValue: "Home Order"))
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "home.editOrder.reset", defaultValue: "Reset")) {
            HomeOrder.reset()
            ids = cards.map(\.id) // cards arrive already ordered; reset shows directory order next open
            onChange()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { dismiss() }
        }
      }
      .onAppear {
        ids = cards.map(\.id)
        titles = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0.title) })
      }
    }
  }
}
