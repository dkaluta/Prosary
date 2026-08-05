//
//  HomeView.swift
//  Prosary
//
//  The Pray tab is the devotions you have pinned — not every saved preset. Tapping a row prays
//  its default straight away; the disclosure opens the presets underneath it, so four saved
//  Rosaries are one row rather than four. Pinning is separate from presets (see
//  FavoriteDevotions), so removing something from Pray never deletes its configurations.
//  Discovery lives in Categories/Search/Browse.
//

import SwiftUI

struct HomeView: View {
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services

  @State private var prayers: [Prayer] = []
  @State private var todayMysteryGroup: MysteryGroup? = nil
  @State private var todayFeast: FeastDay? = nil
  @State private var monthIntention: PopeIntention? = nil

  @State private var editorPrayer: Prayer?
  @State private var isNew = false
  @State private var remindersPrayer: Prayer?
  @State private var showsQuickSetup = false
  @State private var showsOrderEditor = false
  @State private var showsSettings = false
  /// Bumped whenever the saved order changes so the list re-derives.
  @State private var orderGeneration = 0

  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }

  /// One row per pinned devotion, in the user's own order. A devotion is implied-pinned when
  /// it already has a preset, so a fresh install shows the seeded Rosary without anyone having
  /// starred anything.
  private var pinnedDevotions: [DevotionRow] {
    _ = orderGeneration
    // Re-derive when iCloud delivers a pin or an order from another device.
    _ = CloudPreferencesGeneration.shared.value
    let implied = impliedPinnedIds
    let rows = allDevotions.filter { FavoriteDevotions.contains($0.id, defaultingTo: implied) }
    return HomeOrder.apply(rows) { $0.id }
  }

  private var impliedPinnedIds: [String] {
    var ids = Set<String>()
    for prayer in prayers {
      switch prayer.kind {
      case .rosary: ids.insert("rosary")
      case .jesusPrayer: ids.insert("jesusPrayer")
      case .custom: if let id = prayer.customDevotionId { ids.insert(id) }
      }
    }
    return Array(ids)
  }

  /// Every devotion the app knows: the Rosary, each loaded bundle, the Jesus Prayer.
  private var allDevotions: [DevotionRow] {
    var rows: [DevotionRow] = [
      DevotionRow(
        id: "rosary", title: PrayerKind.rosary.displayName,
        systemImage: PrayerKind.rosary.systemImage, iconGlyph: nil,
        accent: todayMysteryGroup?.color ?? .brandPrimary,
        // The whole row leads to the presets screen, so no separate disclosure button: the
        // card's own chevron says it goes somewhere.
        subtitle: rosarySubtitle, presetsRoute: nil,
        prayAction: { path.append(AppRoute.rosaryPresets) }),
    ]
    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let info = PrayerPackStore.info(for: bundleId) else { continue }
      let accent: Color
      if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
        accent = .adaptive(light: light, dark: dark)
      } else {
        accent = info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary
      }
      rows.append(DevotionRow(
        id: bundleId, title: info.localizedDisplayName,
        systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
        iconGlyph: info.iconGlyph, accent: accent,
        // A tracked series says where you are, or when it begins — that is the whole reason a
        // pinned novena is worth pinning before its first day.
        subtitle: MultiDayStatus.subtitle(for: bundleId)
          ?? savedPreset(forBundle: bundleId)?.languageDisplayName
          ?? String(localized: "home.customCard.tapToPray", defaultValue: "Tap to pray"),
        presetsRoute: nil,
        prayAction: { prayCustom(bundleId) }))
    }
    rows.append(DevotionRow(
      id: "jesusPrayer", title: PrayerKind.jesusPrayer.displayName,
      systemImage: PrayerKind.jesusPrayer.systemImage, iconGlyph: nil,
      accent: jesusPrayerAccent, subtitle: jesusPrayerSubtitle,
      presetsRoute: nil, prayAction: { prayJesusPrayer() }))
    return rows
  }

  private var defaultRosary: Prayer? {
    prayers.first { $0.kind == .rosary && $0.isDefault } ?? prayers.first { $0.kind == .rosary }
  }

  private var defaultJesusPrayer: Prayer? {
    prayers.first { $0.kind == .jesusPrayer && $0.isDefault } ?? prayers.first { $0.kind == .jesusPrayer }
  }

  private func savedPreset(forBundle bundleId: String) -> Prayer? {
    prayers.first { $0.kind == .custom && $0.customDevotionId == bundleId && $0.isDefault }
      ?? prayers.first { $0.kind == .custom && $0.customDevotionId == bundleId }
  }

  /// The row still answers "what will I pray today?" — today's mysteries plus the preset that
  /// one tap would start.
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




  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        todaySection

        if pinnedDevotions.isEmpty {
          emptyState
        } else {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 12, alignment: .top)],
            spacing: 12
          ) {
            ForEach(pinnedDevotions) { row in
              PrayerCard(
                systemImage: row.systemImage,
                iconGlyph: row.iconGlyph,
                title: row.title,
                subtitle: row.subtitle,
                accentColor: row.accent,
                // One tap prays the default; the disclosure is the way into the presets, so
                // the common case stays a single tap.
                onDisclosure: row.presetsRoute.map { route in { path.append(route) } }
              ) {
                row.prayAction()
              }
              .accessibilityIdentifier("\(row.id)Card")
              .contextMenu { rowMenu(for: row) }
            }
          }
        }
      }
      .padding(20)
      .frame(maxWidth: 1000)
      .frame(maxWidth: .infinity)
    }
    .navigationTitle(String(localized: "tabs.pray", defaultValue: "Pray"))
    .toolbar { toolbarContent }
    .sheet(item: $editorPrayer) { prayer in
      NavigationStack { FavoriteEditorView(prayer: prayer, isNew: isNew) }
        .onDisappear { Task { await load() } }
    }
    .sheet(item: $remindersPrayer) { prayer in
      NavigationStack { RemindersOnlyEditorView(prayer: prayer) }
        .onDisappear { Task { await load() } }
    }
    .sheet(isPresented: $showsQuickSetup) {
      RosaryQuickSetupView(
        seed: prayers.first { $0.kind == .rosary && $0.isDefault }?.rosary ?? RosaryOptions(),
        hasPresets: prayers.contains { $0.kind == .rosary }
      ) { prayer in
        showsQuickSetup = false
        path.append(AppRoute.rosaryQuickPray(prayer: prayer))
      } onSaved: {
        Task { await load() }
      }
    }
    .sheet(isPresented: $showsOrderEditor) {
      HomeOrderEditor(rows: pinnedDevotions) { orderGeneration += 1 }
    }
    #if !os(macOS)
    .sheet(isPresented: $showsSettings) {
      NavigationStack {
        SettingsView()
          .navigationTitle(String(localized: "settings.title", defaultValue: "Settings"))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { showsSettings = false }
            }
          }
      }
    }
    #endif
    .task { await load() }
    .onAppear { Task { await load() } }
  }

  // MARK: - Pieces

  /// "Today" — the day's feast per the Holy Land (Latin Patriarchate of Jerusalem) calendar and
  /// the Pope's monthly prayer intention. Rows hide when the bundled datasets have no entry
  /// (ferial days; dates past the generated years).
  @ViewBuilder
  private var todaySection: some View {
    if todayFeast != nil || monthIntention != nil {
      VStack(alignment: .leading, spacing: 10) {
        if let feast = todayFeast {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "calendar").foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: 2) {
              Text(feast.title)
                .font(.subheadline.weight(feast.rank == "Solemnity" ? .bold : .semibold))
              Text(feast.rank).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        if let intention = monthIntention {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "hands.sparkles").foregroundStyle(Color.brandPrimary)
            VStack(alignment: .leading, spacing: 2) {
              Text(String(
                localized: "home.today.popesIntention",
                defaultValue: "The Pope’s intention: \(intention.title)"))
                .font(.subheadline.weight(.semibold))
              Text(intention.text).font(.caption).foregroundStyle(.secondary)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
      .accessibilityIdentifier("todaySection")
    }
  }

  /// Only reachable by deleting every favorite — the store seeds one on first run — so it
  /// points at the tabs that find devotions rather than apologising.
  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "star")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(String(localized: "home.empty.title", defaultValue: "No saved prayers yet"))
        .font(.headline)
      Text(String(
        localized: "home.empty.detail",
        defaultValue: "Find a devotion in Categories or Search and pin it here."))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 40)
    .frame(maxWidth: 420)
    .accessibilityIdentifier("noFavoritesState")
  }

  /// The saved configuration behind a pinned row, when it has one — what its reminders belong
  /// to. Nil for a devotion pinned without ever being configured.
  private func savedPrayer(for row: DevotionRow) -> Prayer? {
    switch row.id {
    case "rosary": return defaultRosary
    case "jesusPrayer": return defaultJesusPrayer
    default: return prayers.first { $0.kind == .custom && $0.customDevotionId == row.id }
    }
  }

  @ViewBuilder
  private func rowMenu(for row: DevotionRow) -> some View {
    if let prayer = savedPrayer(for: row) {
      Button { remindersPrayer = prayer } label: {
        Label(String(localized: "favorites.reminders", defaultValue: "Reminders…"), systemImage: "bell")
      }
    }
    Button {
      HomeOrder.moveToTop(row.id, allIdsInDisplayOrder: pinnedDevotions.map(\.id))
      orderGeneration += 1
    } label: {
      Label(String(localized: "home.moveToTop", defaultValue: "Move to Top"), systemImage: "arrow.up.to.line")
    }
    Button {
      showsOrderEditor = true
    } label: {
      Label(String(localized: "home.editOrder", defaultValue: "Edit Order…"), systemImage: "arrow.up.arrow.down")
    }
    Divider()
    // Unpinning is not deletion: the presets underneath stay exactly where they are, which is
    // the whole reason pinning is stored separately from them.
    Button {
      FavoriteDevotions.toggle(row.id, defaultingTo: impliedPinnedIds)
      orderGeneration += 1
    } label: {
      Label(String(localized: "home.unpin", defaultValue: "Remove from Pray"), systemImage: "star.slash")
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Menu {
        Button {
          showsQuickSetup = true
        } label: {
          Label("rosaryPicker.anyRosary", systemImage: "sparkles")
        }
        Divider()
        Button { addNew(kind: .rosary) } label: {
          Label(String(localized: "favorites.addKind", defaultValue: "Add \(PrayerKind.rosary.displayName)"),
                systemImage: "circle.hexagongrid")
        }
        Button { addNew(kind: .jesusPrayer) } label: {
          Label(String(localized: "favorites.addJesusPrayer", defaultValue: "Add Jesus Prayer"),
                systemImage: "heart")
        }

        // Anything currently off the Pray list, so unpinning is never a one-way door — the
        // Rosary and the Jesus Prayer have no bundle flow to carry a star.
        let unpinned = allDevotions.filter { row in
          !FavoriteDevotions.contains(row.id, defaultingTo: impliedPinnedIds)
        }
        if !unpinned.isEmpty {
          Section(String(localized: "home.addToPray", defaultValue: "Add to Pray")) {
            ForEach(unpinned) { row in
              Button {
                FavoriteDevotions.pin(row.id, defaultingTo: impliedPinnedIds)
                orderGeneration += 1
              } label: {
                Label(row.title, systemImage: row.systemImage)
              }
            }
          }
        }
      } label: {
        Image(systemName: "plus")
      }
      .accessibilityLabel(String(localized: "home.addFavorite", defaultValue: "Add a prayer"))
      .accessibilityIdentifier("addFavoriteButton")
    }
    if !pinnedDevotions.isEmpty {
      ToolbarItem(placement: .primaryAction) {
        Button { showsOrderEditor = true } label: {
          Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "home.editOrder", defaultValue: "Edit Order…"))
        .accessibilityIdentifier("editOrderButton")
      }
    }
    #if !os(macOS)
    ToolbarItem(placement: .primaryAction) {
      Button { showsSettings = true } label: {
        Image(systemName: "gearshape")
      }
      .accessibilityLabel(String(localized: "settings.title", defaultValue: "Settings"))
      .accessibilityIdentifier("settingsButton")
    }
    ToolbarItem(placement: .primaryAction) {
      NavigationLink(value: AppRoute.about) {
        Image(systemName: "info.circle")
      }
      .accessibilityLabel(Text("home.about"))
    }
    #endif
  }

  // MARK: - Actions


  private func load() async {
    todayMysteryGroup = services.calendar.mysteryGroupToday()
    todayFeast = TodayInfoStore.feast()
    monthIntention = TodayInfoStore.intention()
    prayers = (try? await services.presetStore.all()) ?? []
    HomeOrder.dropOrderIfUnrelated(to: allDevotions.map(\.id))
  }

  private func prayJesusPrayer() {
    if let preset = defaultJesusPrayer {
      path.append(AppRoute.prayer(id: preset.id))
    } else {
      path.append(AppRoute.jesusPrayerSetup)
    }
  }

  private func prayCustom(_ bundleId: String) {
    if let preset = savedPreset(forBundle: bundleId) {
      path.append(AppRoute.prayer(id: preset.id))
    } else {
      path.append(AppRoute.custom(devotionId: bundleId))
    }
  }

  private func addNew(kind: PrayerKind) {
    isNew = true
    editorPrayer = Prayer(name: kind.defaultName, kind: kind, isDefault: !prayers.contains { $0.kind == kind })
  }

  private func makeDefault(_ prayer: Prayer) {
    var updated = prayer
    updated.isDefault = true
    Task {
      try? await services.presetStore.save(updated)
      await load()
    }
  }

  private func delete(_ prayer: Prayer) {
    ReminderScheduler.removeAll(for: prayer)
    Task {
      try? await services.presetStore.delete(prayer)
      await load()
    }
  }
}

/// The approved reorder pattern (not jiggle): a plain List in permanent edit mode — drag
/// handles appear, rows move, order persists on every change. Reset returns to save order.
private struct HomeOrderEditor: View {
  let rows: [DevotionRow]
  let onChange: () -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var ids: [String] = []
  @State private var names: [String: String] = [:]

  var body: some View {
    NavigationStack {
      List {
        ForEach(ids, id: \.self) { id in
          Text(names[id] ?? id)
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
            ids = rows.map(\.id)
            onChange()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { dismiss() }
        }
      }
      .onAppear {
        ids = rows.map(\.id)
        names = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.title) })
      }
    }
  }
}

/// One pinned devotion's rendering state. `presetsRoute` is nil for devotions with nothing to
/// choose between — a bundle devotion has at most one saved configuration.
private struct DevotionRow: Identifiable {
  let id: String
  let title: String
  let systemImage: String
  let iconGlyph: String?
  let accent: Color
  let subtitle: String
  let presetsRoute: AppRoute?
  let prayAction: () -> Void
}

#Preview {
  NavigationStack {
    HomeView(path: .constant(NavigationPath()))
  }
}
