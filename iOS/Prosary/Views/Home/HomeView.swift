//
//  HomeView.swift
//  Prosary
//
//  The Pray tab *is* the favorites list: every saved session, one tap each. It used to be a
//  catalog with one card per devotion, which duplicated what Categories and Search already do
//  — and left "my Rosary" (a favorite) and "the Rosary" (a devotion) competing for the same
//  screen. Discovery now lives in Categories/Search/Browse; praying something you have not
//  saved starts there and the flow's own star brings it here.
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

  /// Saved sessions in the user's own order. A Rosary favorite takes the day's mystery color,
  /// a generic devotion its bundle's accent, so the list keeps the visual identity the
  /// devotion cards had.
  private var orderedFavorites: [Prayer] {
    _ = orderGeneration
    return HomeOrder.apply(prayers) { $0.id.uuidString }
  }

  private func accent(for prayer: Prayer) -> Color {
    switch prayer.kind {
    case .rosary: return todayMysteryGroup?.color ?? .brandPrimary
    case .jesusPrayer: return jesusPrayerAccent
    case .custom:
      guard let id = prayer.customDevotionId, let info = PrayerPackStore.info(for: id) else {
        return .brandPrimary
      }
      if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
        return .adaptive(light: light, dark: dark)
      }
      return info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary
    }
  }

  private func icon(for prayer: Prayer) -> (systemImage: String, glyph: String?) {
    guard prayer.kind == .custom, let id = prayer.customDevotionId,
          let info = PrayerPackStore.info(for: id) else {
      return (prayer.kind.systemImage, nil)
    }
    return (info.iconSystemName ?? PrayerKind.custom.systemImage, info.iconGlyph)
  }

  /// The second line: what this session actually is. A Rosary favorite names today's mysteries
  /// when it follows the calendar, so the row still answers "what will I pray today?".
  private func subtitle(for prayer: Prayer) -> String {
    switch prayer.kind {
    case .rosary:
      var parts = [prayer.rosary.mysterySelectionSummary]
      if prayer.rosary.mysterySelectionMode == .todaysMysteries, let group = todayMysteryGroup {
        parts = [String(localized: "home.rosaryCard.today", defaultValue: "Today: \(group.displayName)")]
      }
      parts.append(prayer.languageDisplayName)
      return parts.joined(separator: " • ")
    case .jesusPrayer:
      return "\(prayer.jesusPrayer.targetDisplayName) • \(prayer.languageDisplayName)"
    case .custom:
      guard let id = prayer.customDevotionId, let info = PrayerPackStore.info(for: id) else {
        return prayer.languageDisplayName
      }
      return "\(info.localizedDisplayName) • \(prayer.languageDisplayName)"
    }
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        todaySection

        if orderedFavorites.isEmpty {
          emptyState
        } else {
          LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 12, alignment: .top)],
            spacing: 12
          ) {
            ForEach(orderedFavorites) { prayer in
              let art = icon(for: prayer)
              PrayerCard(
                systemImage: art.systemImage,
                iconGlyph: art.glyph,
                title: prayer.name,
                subtitle: subtitle(for: prayer),
                accentColor: accent(for: prayer)
              ) {
                path.append(AppRoute.prayer(id: prayer.id))
              }
              .accessibilityIdentifier(identifier(for: prayer))
              .contextMenu { rowMenu(for: prayer) }
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
      HomeOrderEditor(favorites: orderedFavorites) { orderGeneration += 1 }
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
        defaultValue: "Find a devotion in Categories or Search, then tap the star while praying it to keep it here."))
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 40)
    .frame(maxWidth: 420)
    .accessibilityIdentifier("noFavoritesState")
  }

  @ViewBuilder
  private func rowMenu(for prayer: Prayer) -> some View {
    Button {
      isNew = false
      editorPrayer = prayer
    } label: {
      Label("favorites.edit", systemImage: "pencil")
    }
    Button {
      remindersPrayer = prayer
    } label: {
      Label("favorites.reminders", systemImage: "bell")
    }
    if !prayer.isDefault {
      Button {
        makeDefault(prayer)
      } label: {
        Label("favorites.setDefault", systemImage: "star")
      }
    }
    Divider()
    Button {
      HomeOrder.moveToTop(prayer.id.uuidString, allIdsInDisplayOrder: orderedFavorites.map { $0.id.uuidString })
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
    Button(role: .destructive) {
      delete(prayer)
    } label: {
      Label("favorites.delete", systemImage: "trash")
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
      } label: {
        Image(systemName: "plus")
      }
      .accessibilityLabel(String(localized: "home.addFavorite", defaultValue: "Add a prayer"))
      .accessibilityIdentifier("addFavoriteButton")
    }
    if !orderedFavorites.isEmpty {
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

  /// Stable per-row identifiers for the UI tests: a devotion favorite is named for its bundle
  /// ("trisagionCard"), the two configurable kinds for their kind.
  private func identifier(for prayer: Prayer) -> String {
    switch prayer.kind {
    case .rosary: return "rosaryCard"
    case .jesusPrayer: return "jesusPrayerCard"
    case .custom: return "\(prayer.customDevotionId ?? "custom")Card"
    }
  }

  private func load() async {
    todayMysteryGroup = services.calendar.mysteryGroupToday()
    todayFeast = TodayInfoStore.feast()
    monthIntention = TodayInfoStore.intention()
    prayers = (try? await services.presetStore.all()) ?? []
    HomeOrder.dropOrderIfUnrelated(to: prayers.map { $0.id.uuidString })
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
  let favorites: [Prayer]
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
            ids = favorites.map { $0.id.uuidString }
            onChange()
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { dismiss() }
        }
      }
      .onAppear {
        ids = favorites.map { $0.id.uuidString }
        names = Dictionary(uniqueKeysWithValues: favorites.map { ($0.id.uuidString, $0.name) })
      }
    }
  }
}

#Preview {
  NavigationStack {
    HomeView(path: .constant(NavigationPath()))
  }
}
