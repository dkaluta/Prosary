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
import Combine
#if os(macOS)
import AppKit
#endif

struct HomeView: View {
  /// Names here follow the default prayer language; the monitor is the one mechanism
  /// that survives the Mac's Settings menu — see PrayerLanguageMonitor's header for the
  /// graveyard of simpler attempts. Reading `.code` in body registers the dependency.
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared

  @Binding var path: [AppRoute]

  @Environment(\.appServices) private var services
  @Environment(\.scenePhase) private var scenePhase

  @State private var prayers: [Prayer] = []
  @State private var deletingPrayer: Prayer?
  @State private var reminderSaveError: String?
  @State private var isOpeningReminders = false
  @State private var todayMysteryGroup: MysteryGroup? = nil
  private var showsPrayerNameInPrayerLanguage: Bool { prayerLanguage.showsPrayerNameInPrayerLanguage }
  @AppStorage(BasicPrayerCatalog.languageDefaultsKey) private var basicPrayerLanguageCode = LanguageCatalog.defaultSentinel

  @State private var editorPrayer: Prayer?
  @State private var isNew = false
  @State private var remindersPrayer: Prayer?
  @State private var showsQuickSetup = false
  @State private var showsOrderEditor = false
  @State private var showsSettings = false
  /// Bumped whenever the saved order changes so the list re-derives.
  @State private var orderGeneration = 0
  @State private var selectedHomeRow: String?

  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }

  /// One row per pinned devotion, in the user's own order. A devotion is implied-pinned when
  /// it already has a preset, so a fresh install shows the seeded Rosary without anyone having
  /// starred anything.
  private var pinnedDevotions: [DevotionRow] {
    _ = orderGeneration
    // Re-derive when iCloud delivers a pin or an order from another device.
    _ = CloudPreferencesGeneration.shared.value
    let implied = impliedPinnedIds
    var rows = allDevotions.filter { FavoriteDevotions.contains($0.id, defaultingTo: implied) }
    let language = LanguageCatalog.resolve(basicPrayerLanguageCode)
    for prayer in BasicPrayersOrder.apply(BasicPrayerCatalog.all) where BasicPrayerFavorites.contains(prayer.id) {
      let name = PrayerNamePresentation.basicPrayer(prayer, languageCode: language.code,
                                                    showPrayerLanguage: showsPrayerNameInPrayerLanguage)
      rows.append(DevotionRow(
        id: BasicPrayerFavorites.homeRowID(prayer.id),
        title: name.title, translatedTitle: name.translation,
        systemImage: "text.book.closed", iconGlyph: nil, accent: .appAccent,
        subtitle: String(localized: "basicPrayers.title", defaultValue: "Basic Prayers", bundle: UILanguage.bundle, locale: UILanguage.locale), presetsRoute: nil,
        route: .basicPrayer(id: prayer.id)))
    }
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
        id: "rosary", title: rosaryName.title, translatedTitle: rosaryName.translation,
        systemImage: PrayerKind.rosary.systemImage, iconGlyph: nil,
        accent: todayMysteryGroup?.color ?? .appAccent,
        // The whole row leads to the presets screen, so no separate disclosure button: the
        // card's own chevron says it goes somewhere.
        subtitle: rosarySubtitle, presetsRoute: nil,
        route: .rosaryPresets),
    ]
    for bundleId in PrayerPackStore.customDevotionIds() {
      guard let info = PrayerPackStore.info(for: bundleId) else { continue }
      let accent: Color
      if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
        accent = .adaptive(light: light, dark: dark)
      } else {
        accent = info.accentColorHex.map { Color(hex: $0) } ?? .appAccent
      }
      rows.append(DevotionRow(
        id: bundleId, title: nameForBundle(info, bundleId: bundleId).title,
        translatedTitle: nameForBundle(info, bundleId: bundleId).translation,
        systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
        iconGlyph: info.iconGlyph, accent: accent,
        // A tracked series says where you are, or when it begins — that is the whole reason a
        // pinned novena is worth pinning before its first day.
        subtitle: MultiDayStatus.subtitle(for: bundleId)
          ?? savedPreset(forBundle: bundleId)?.languageDisplayName
          ?? String(localized: "home.customCard.tapToPray", defaultValue: "Tap to pray", bundle: UILanguage.bundle, locale: UILanguage.locale),
        presetsRoute: nil,
        route: savedPreset(forBundle: bundleId).map { .prayer(id: $0.id) }
          ?? .custom(devotionId: bundleId)))
    }
    rows.append(DevotionRow(
      id: "jesusPrayer", title: jesusPrayerName.title, translatedTitle: jesusPrayerName.translation,
      systemImage: PrayerKind.jesusPrayer.systemImage, iconGlyph: nil,
      accent: jesusPrayerAccent, subtitle: jesusPrayerSubtitle,
      presetsRoute: nil,
      route: defaultJesusPrayer.map { .prayer(id: $0.id) } ?? .jesusPrayerSetup))
    return rows
  }

  private var rosaryName: PrayerNamePresentation {
    PrayerKind.rosary.namePresentation(prayerCode: LanguageCatalog.resolve(defaultRosary?.languageCode).code,
                                      showPrayerLanguage: showsPrayerNameInPrayerLanguage)
  }

  private var jesusPrayerName: PrayerNamePresentation {
    PrayerKind.jesusPrayer.namePresentation(prayerCode: LanguageCatalog.resolve(defaultJesusPrayer?.languageCode).code,
                                           showPrayerLanguage: showsPrayerNameInPrayerLanguage)
  }

  private func nameForBundle(_ info: CustomDevotionInfo, bundleId: String) -> PrayerNamePresentation {
    info.namePresentation(prayerCode: LanguageCatalog.resolve(savedPreset(forBundle: bundleId)?.languageCode).code,
                          showPrayerLanguage: showsPrayerNameInPrayerLanguage)
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
      parts.append(String(localized: "home.rosaryCard.today", defaultValue: "Today: \(group.displayName)", bundle: UILanguage.bundle, locale: UILanguage.locale))
    }
    if let preset = defaultRosary { parts.append(preset.name) }
    return parts.joined(separator: " • ")
  }

  private var jesusPrayerSubtitle: String {
    guard let fav = defaultJesusPrayer else {
      return String(localized: "home.jesusPrayerCard.tapToSetUp", defaultValue: "Tap to set up", bundle: UILanguage.bundle, locale: UILanguage.locale)
    }
    return "\(fav.name) • \(fav.jesusPrayer.targetDisplayName)"
  }




  var body: some View {
    let _ = prayerLanguage.code  // dependency registration — see the property's comment
    Group {
      #if os(macOS)
      macPrayerList
      #else
      ScrollView {
      VStack(spacing: 16) {
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
                translatedTitle: row.translatedTitle,
                subtitle: row.subtitle,
                accentColor: row.accent,
                // One tap prays the default; the disclosure is the way into the presets, so
                // the common case stays a single tap.
                onDisclosure: row.presetsRoute.map { route in { path.push(route) } }
              ) {
                path.push(row.route)
              }
              .accessibilityIdentifier("\(row.id)Card")
              .contextMenu { rowMenu(for: row) }
            }
          }
        }

        basicPrayersSection
      }
      .padding(20)
      .frame(maxWidth: 1000)
      .frame(maxWidth: .infinity)
      }
      #endif
    }
    .navigationTitle(String(localized: "tabs.pray", defaultValue: "Pray", bundle: UILanguage.bundle, locale: UILanguage.locale))
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
        path.push(AppRoute.rosaryQuickPray(prayer: prayer))
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
          .navigationTitle(String(localized: "settings.title", defaultValue: "Settings", bundle: UILanguage.bundle, locale: UILanguage.locale))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .confirmationAction) {
              Button(String(localized: "favoriteEditor.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { showsSettings = false }
            }
          }
      }
      // Home stays alive under the sheet, so nothing else re-reads the Today row after a
      // liturgical-calendar change — without this the new calendar shows only on relaunch.
      .onDisappear { Task { await load() } }
    }
    #endif
    .task { await load() }
    .modifier(PrayerRemovalDialogs(prayer: $deletingPrayer, onDeleted: { await load() }))
    .alert("favoriteEditor.saveFailed", isPresented: Binding(get: { reminderSaveError != nil }, set: { if !$0 { reminderSaveError = nil } })) {
      Button("common.ok") { reminderSaveError = nil }
    } message: { Text(reminderSaveError ?? "") }
    .onAppear { Task { await load() } }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      Task { await load() }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active {
        refreshTodayMysteries()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
      refreshTodayMysteries()
    }
    .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
      refreshTodayMysteries()
    }
  }

  // MARK: - Pieces

  #if os(macOS)
  private var macPrayerList: some View {
    List(selection: $selectedHomeRow) {
      if pinnedDevotions.isEmpty {
        emptyState
      } else {
        ForEach(pinnedDevotions) { row in
          Button {
            selectedHomeRow = row.id
            path.push(row.route)
          } label: {
            HStack(spacing: 12) {
              if let glyph = row.iconGlyph {
                Text(glyph).frame(width: 28)
              } else {
                Image(systemName: row.systemImage).frame(width: 28)
              }
              VStack(alignment: .leading, spacing: 3) {
                Text(HebrewDisplayText.unpointed(row.title)).font(.headline)
                if let translation = row.translatedTitle {
                  Text(HebrewDisplayText.unpointed(translation))
                    .font(.subheadline).foregroundStyle(.secondary)
                }
                if !row.subtitle.isEmpty {
                  Text(HebrewDisplayText.unpointed(row.subtitle))
                    .font(.subheadline).foregroundStyle(.secondary)
                }
              }
              Spacer()
              Image(systemName: "chevron.forward").foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .tag(row.id)
          .accessibilityIdentifier("\(row.id)Card")
          .contextMenu { rowMenu(for: row) }
        }
        .onMove { from, to in
          var ids = pinnedDevotions.map(\.id)
          ids.move(fromOffsets: from, toOffset: to)
          HomeOrder.save(ids)
          orderGeneration += 1
        }
      }
      basicPrayersSection.tag("basicPrayers")
    }
    .listStyle(.inset)
    .macListActivation {
      if selectedHomeRow == "basicPrayers" {
        path.push(.basicPrayers)
        return true
      }
      guard let row = pinnedDevotions.first(where: { $0.id == selectedHomeRow }) else { return false }
      path.push(row.route)
      return true
    }
  }
  #endif

  /// The basic prayers on their own (Erez, 2026-08-07) — a fixed quiet row below the cards, not
  /// a pinnable card: it is a reference shelf, not a devotion, so it neither reorders nor
  /// unpins. Always present, which is the point of the ask.
  private var basicPrayersSection: some View {
    Button {
      path.push(AppRoute.basicPrayers)
    } label: {
      HStack {
        Image(systemName: "text.book.closed")
        Text(String(localized: "basicPrayers.title", defaultValue: "Basic Prayers", bundle: UILanguage.bundle, locale: UILanguage.locale))
        Spacer()
        Image(systemName: "chevron.forward")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .prosarySpatialTarget(alignment: .leading)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
    .buttonStyle(.plain)
    .prosarySpatialHoverEffect(in: RoundedRectangle(cornerRadius: 12))
    .accessibilityIdentifier("basicPrayersRow")
  }


  /// Only reachable by deleting every favorite — the store seeds one on first run — so it
  /// points at the tabs that find devotions rather than apologising.
  private var emptyState: some View {
    VStack(spacing: 10) {
      Image(systemName: "star")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text(String(localized: "home.empty.title", defaultValue: "No saved prayers yet", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .font(.headline)
      Text(String(
        localized: "home.empty.detail",
        defaultValue: "Find a devotion in Categories or Search and pin it here.", bundle: UILanguage.bundle, locale: UILanguage.locale))
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
    if BasicPrayerFavorites.prayerID(homeRowID: row.id) == nil {
      Button { openReminders(for: row) } label: {
        Label(String(localized: "favorites.reminders", defaultValue: "Reminders…", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "bell")
      }
    }
    Button {
      HomeOrder.moveToTop(row.id, allIdsInDisplayOrder: pinnedDevotions.map(\.id))
      orderGeneration += 1
    } label: {
      Label(String(localized: "home.moveToTop", defaultValue: "Move to Top", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "arrow.up.to.line")
    }
    Button {
      showsOrderEditor = true
    } label: {
      Label(String(localized: "home.editOrder", defaultValue: "Edit Order…", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "arrow.up.arrow.down")
    }
    Divider()
    // Unpinning is not deletion: the presets underneath stay exactly where they are, which is
    // the whole reason pinning is stored separately from them.
    Button {
      if let prayerId = BasicPrayerFavorites.prayerID(homeRowID: row.id) {
        BasicPrayerFavorites.toggle(prayerId)
      } else {
        FavoriteDevotions.toggle(row.id, defaultingTo: impliedPinnedIds)
      }
      orderGeneration += 1
    } label: {
      if BasicPrayerFavorites.prayerID(homeRowID: row.id) != nil {
        Label(String(localized: "basicPrayers.unpin", defaultValue: "Remove from Pray", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "pin.slash")
      } else {
        Label(String(localized: "home.unpin", defaultValue: "Remove from Pray", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "star.slash")
      }
    }
  }

  private func openReminders(for row: DevotionRow) {
    guard !isOpeningReminders else { return }
    isOpeningReminders = true
    Task {
      defer { isOpeningReminders = false }
      if let existing = savedPrayer(for: row) { remindersPrayer = existing; return }
      let kind: PrayerKind = row.id == "rosary" ? .rosary : row.id == "jesusPrayer" ? .jesusPrayer : .custom
      let prayer = Prayer(name: row.title, kind: kind, isDefault: true,
                          customDevotionId: kind == .custom ? row.id : nil)
      do {
        try await services.presetStore.save(prayer)
        await load()
        remindersPrayer = prayer
      } catch { reminderSaveError = error.localizedDescription }
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .primaryAction) {
      Menu {
        Button {
          showsQuickSetup = true
        } label: {
          Label("rosaryPicker.anyRosaryAction", systemImage: "sparkles")
        }
        Divider()
        Button { addNew(kind: .rosary) } label: {
          Label(String(localized: "favorites.addKind", defaultValue: "Add \(PrayerKind.rosary.displayName)…", bundle: UILanguage.bundle, locale: UILanguage.locale),
                systemImage: "circle.hexagongrid")
        }
        Button { addNew(kind: .jesusPrayer) } label: {
          Label(String(localized: "favorites.addJesusPrayer", defaultValue: "Add Jesus Prayer…", bundle: UILanguage.bundle, locale: UILanguage.locale),
                systemImage: "heart")
        }

        // Anything currently off the Pray list, so unpinning is never a one-way door — the
        // Rosary and the Jesus Prayer have no bundle flow to carry a star.
        let unpinned = allDevotions.filter { row in
          !FavoriteDevotions.contains(row.id, defaultingTo: impliedPinnedIds)
        }
        if !unpinned.isEmpty {
          Section(String(localized: "home.addToPray", defaultValue: "Add to Pray", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
            ForEach(unpinned) { row in
              Button {
                FavoriteDevotions.pin(row.id, defaultingTo: impliedPinnedIds)
                orderGeneration += 1
              } label: {
                Label(HebrewDisplayText.unpointed(row.title), systemImage: row.systemImage)
              }
            }
          }
        }
      } label: {
        Image(systemName: "plus")
      }
      .accessibilityLabel(String(localized: "home.addFavorite", defaultValue: "Add a Prayer", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .help(String(localized: "home.addFavorite", defaultValue: "Add a Prayer", bundle: UILanguage.bundle, locale: UILanguage.locale))
      .accessibilityIdentifier("addFavoriteButton")
    }
    if !pinnedDevotions.isEmpty {
      ToolbarItem(placement: .primaryAction) {
        Button { showsOrderEditor = true } label: {
          Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "home.editOrder", defaultValue: "Edit Order…", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .help(String(localized: "home.editOrder", defaultValue: "Edit Order…", bundle: UILanguage.bundle, locale: UILanguage.locale))
        .accessibilityIdentifier("editOrderButton")
      }
    }
    #if !os(macOS)
    ToolbarItem(placement: .primaryAction) {
      Button { showsSettings = true } label: {
        Image(systemName: "gearshape")
      }
      .accessibilityLabel(String(localized: "settings.title", defaultValue: "Settings", bundle: UILanguage.bundle, locale: UILanguage.locale))
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
    refreshTodayMysteries()
    prayers = (try? await services.presetStore.all()) ?? []
    HomeOrder.dropOrderIfUnrelated(to: allDevotions.map(\.id) + BasicPrayerCatalog.all.map { BasicPrayerFavorites.homeRowID($0.id) })
  }

  private func refreshTodayMysteries() {
    todayMysteryGroup = services.calendar.mysteryGroupToday()
  }

  private func addNew(kind: PrayerKind) {
    isNew = true
    editorPrayer = Prayer(name: kind.defaultName, kind: kind, isDefault: !prayers.contains { $0.kind == kind })
  }

  private func makeDefault(_ prayer: Prayer) {
    var updated = prayer
    updated.isDefault = true
    Task {
      _ = try? await services.presetStore.updateIfPresent(updated)
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
      orderContent
      .navigationTitle(String(localized: "home.editOrder.title", defaultValue: "Home Order", bundle: UILanguage.bundle, locale: UILanguage.locale))
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      #if !os(macOS)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(String(localized: "home.editOrder.reset", defaultValue: "Reset", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
            reset()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(String(localized: "favoriteEditor.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { dismiss() }
        }
      }
      #endif
      .onAppear {
        ids = rows.map(\.id)
        names = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.title) })
      }
    }
  }

  @ViewBuilder private var orderContent: some View {
    #if os(macOS)
    let screenSize = (NSApp.keyWindow?.screen ?? NSScreen.main)?.visibleFrame.size ?? CGSize(width: 1024, height: 768)
    VStack(spacing: 0) {
      orderList.clipped()
      Divider()
      HStack {
        Button(String(localized: "home.editOrder.reset", defaultValue: "Reset", bundle: UILanguage.bundle, locale: UILanguage.locale)) { reset() }
        Spacer()
        Button(String(localized: "favoriteEditor.done", defaultValue: "Done", bundle: UILanguage.bundle, locale: UILanguage.locale)) { dismiss() }
          .keyboardShortcut(.defaultAction)
      }
      .padding()
      .background(Color(nsColor: .windowBackgroundColor))
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(width: min(420, max(320, screenSize.width - 80)),
           height: min(480, max(280, screenSize.height - 140)))
    .onExitCommand { dismiss() }
    #else
    orderList
      #if os(iOS)
      .environment(\.editMode, .constant(.active))
      #endif
    #endif
  }

  private var orderList: some View {
    List {
      ForEach(ids, id: \.self) { id in
        Text(HebrewDisplayText.unpointed(names[id] ?? id))
      }
      .onMove { from, to in
        ids.move(fromOffsets: from, toOffset: to)
        HomeOrder.save(ids)
        onChange()
      }
    }
  }

  private func reset() {
    HomeOrder.reset()
    ids = rows.map(\.id)
    onChange()
    dismiss()
  }
}

/// One pinned devotion's rendering state. `presetsRoute` is nil for devotions with nothing to
/// choose between — a bundle devotion has at most one saved configuration.
private struct DevotionRow: Identifiable {
  let id: String
  let title: String
  var translatedTitle: String? = nil
  let systemImage: String
  let iconGlyph: String?
  let accent: Color
  let subtitle: String
  let presetsRoute: AppRoute?
  let route: AppRoute
}

#Preview {
  NavigationStack {
    HomeView(path: .constant([]))
  }
}
