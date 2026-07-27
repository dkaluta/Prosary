
//
//  FavoritesListView.swift
//  Prosary
//
//  Card-layout list of saved prayer favorites grouped by kind. Replaces PresetsListView.
//

import SwiftUI

struct FavoritesListView: View {
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services

  @State private var prayers: [Prayer] = []
  @State private var editorPrayer: Prayer?
  @State private var isNew = false
  @State private var remindersPrayer: Prayer?

  /// Rosary and Jesus Prayer have real per-favorite options worth naming and saving multiple
  /// variants of, so they keep the full card list + editor. The other 5 kinds have nothing to
  /// configure beyond reminders, so they get a single on/off star row instead — see
  /// `SimpleFavoriteRow`.
  private let configurableKinds: [PrayerKind] = [.rosary, .jesusPrayer]
  private let simplifiedKinds: [PrayerKind] = [.angelus, .stationsOfTheCross, .franciscanCrown, .sevenSorrows, .divineMercyChaplet]

  private var angelusAccent: Color { .adaptive(light: "#8B6914", dark: "#C49B0D") }
  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }
  private var stationsAccent: Color { .adaptive(light: "#5C2D91", dark: "#8756B5") }
  private var franciscanCrownAccent: Color { .adaptive(light: "#6B4226", dark: "#A67C52") }
  private var sevenSorrowsAccent: Color { .adaptive(light: "#6B0F1A", dark: "#B33951") }
  private var divineMercyAccent: Color { .adaptive(light: "#C41E3A", dark: "#E8637A") }

  func accentColor(for kind: PrayerKind) -> Color {
    switch kind {
    case .rosary:             return .brandPrimary
    case .angelus:            return angelusAccent
    case .jesusPrayer:        return jesusPrayerAccent
    case .stationsOfTheCross: return stationsAccent
    case .franciscanCrown:    return franciscanCrownAccent
    case .sevenSorrows:       return sevenSorrowsAccent
    case .divineMercyChaplet: return divineMercyAccent
    // Unreachable in practice — .custom is never in configurableKinds/simplifiedKinds, its rows
    // read the bundle's own accentColorHex instead (see the customDevotionIds ForEach below).
    // Still needed for exhaustiveness.
    case .custom:             return .brandPrimary
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8, pinnedViews: .sectionHeaders) {
        ForEach(configurableKinds, id: \.self) { kind in
          let kindPrayers = prayers.filter { $0.kind == kind }
          Section {
            ForEach(kindPrayers) { prayer in
              FavoriteCard(
                prayer: prayer,
                accentColor: accentColor(for: kind),
                onPray: { path.append(AppRoute.prayer(id: prayer.id)) },
                onEdit: { edit(prayer) },
                onMakeDefault: { makeDefault(prayer) },
                onDelete: { delete(prayer) }
              )
            }

            Button {
              addNew(kind: kind)
            } label: {
              Label(String(localized: "favorites.addKind", defaultValue: "Add \(kind.displayName)"), systemImage: "plus")
                .font(.subheadline)
                .foregroundStyle(accentColor(for: kind))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
          } header: {
            kindHeader(kind)
          }
        }

        Section {
          ForEach(simplifiedKinds, id: \.self) { kind in
            let favorite = prayers.first { $0.kind == kind }
            SimpleFavoriteRow(
              title: kind.displayName,
              systemImage: kind.systemImage,
              accentColor: accentColor(for: kind),
              isFavorited: favorite != nil,
              onToggleFavorite: { toggleSimpleFavorite(kind: kind, existing: favorite) },
              onEditReminders: { favorite.map { remindersPrayer = $0 } }
            )
          }

          // Generic (bundle-driven) devotions — one row per discovered bundle, with no
          // hardcoded PrayerKind case. Only one exists today (Trisagion); a picker across
          // multiple is real future work once a second one exists, not built speculatively.
          ForEach(PrayerPackStore.customDevotionIds(), id: \.self) { bundleId in
            if let info = PrayerPackStore.info(for: bundleId) {
              let favorite = prayers.first { $0.kind == .custom && $0.customDevotionId == bundleId }
              SimpleFavoriteRow(
                title: info.displayName,
                systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
                accentColor: info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary,
                isFavorited: favorite != nil,
                onToggleFavorite: { toggleCustomFavorite(bundleId: bundleId, displayName: info.displayName, existing: favorite) },
                onEditReminders: { favorite.map { remindersPrayer = $0 } }
              )
            }
          }
        } header: {
          HStack(spacing: 8) {
            Image(systemName: "star")
            Text("favorites.moreDevotions")
              .font(.title3.bold())
          }
          .padding(.horizontal, 20)
          .padding(.top, 16)
          .padding(.bottom, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.background)
        }
      }
      .padding(.bottom, 24)
    }
    .navigationTitle("favorites.title")
    #if os(iOS)
    .navigationBarTitleDisplayMode(.large)
    #endif
    .sheet(item: $editorPrayer) { prayer in
      NavigationStack {
        FavoriteEditorView(prayer: prayer, isNew: isNew)
      }
      .onDisappear { Task { await reload() } }
    }
    .sheet(item: $remindersPrayer) { prayer in
      NavigationStack {
        RemindersOnlyEditorView(prayer: prayer)
      }
      .onDisappear { Task { await reload() } }
    }
    .task { await reload() }
  }

  @ViewBuilder
  private func kindHeader(_ kind: PrayerKind) -> some View {
    HStack(spacing: 8) {
      Image(systemName: kind.systemImage)
      Text(kind.displayName)
        .font(.title3.bold())
    }
    .padding(.horizontal, 20)
    .padding(.top, 16)
    .padding(.bottom, 4)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.background)
  }

  private func reload() async {
    prayers = (try? await services.presetStore.all()) ?? []
  }

  private func addNew(kind: PrayerKind) {
    isNew = true
    editorPrayer = Prayer(name: kind.defaultName, kind: kind, isDefault: !prayers.contains { $0.kind == kind })
  }

  private func edit(_ prayer: Prayer) {
    isNew = false
    editorPrayer = prayer
  }

  private func makeDefault(_ prayer: Prayer) {
    var updated = prayer
    updated.isDefault = true
    Task {
      try? await services.presetStore.save(updated)
      await reload()
    }
  }

  private func delete(_ prayer: Prayer) {
    ReminderScheduler.removeAll(for: prayer)
    Task {
      try? await services.presetStore.delete(prayer)
      await reload()
    }
  }

  /// Star toggle for the 5 simplified kinds — at most one `Prayer` row per kind, matched by kind
  /// alone (not language), always saved with the sentinel language (follows the app default).
  private func toggleSimpleFavorite(kind: PrayerKind, existing: Prayer?) {
    Task {
      if let existing {
        ReminderScheduler.removeAll(for: existing)
        try? await services.presetStore.delete(existing)
      } else {
        let newFavorite = Prayer(
          name: kind.defaultName,
          kind: kind,
          isDefault: true,
          languageCode: LanguageCatalog.defaultSentinel
        )
        try? await services.presetStore.save(newFavorite)
      }
      await reload()
    }
  }

  /// Star toggle for a generic (bundle-driven) devotion row — same shape as
  /// `toggleSimpleFavorite`, but always `.custom` + the given bundle id.
  private func toggleCustomFavorite(bundleId: String, displayName: String, existing: Prayer?) {
    Task {
      if let existing {
        ReminderScheduler.removeAll(for: existing)
        try? await services.presetStore.delete(existing)
      } else {
        let newFavorite = Prayer(
          name: displayName,
          kind: .custom,
          isDefault: true,
          languageCode: LanguageCatalog.defaultSentinel,
          customDevotionId: bundleId
        )
        try? await services.presetStore.save(newFavorite)
      }
      await reload()
    }
  }
}

// MARK: - Favorite Card

private struct FavoriteCard: View {
  let prayer: Prayer
  let accentColor: Color
  let onPray: () -> Void
  let onEdit: () -> Void
  let onMakeDefault: () -> Void
  let onDelete: () -> Void

  private var subtitle: String {
    switch prayer.kind {
    case .rosary:
      return "\(prayer.rosary.mysterySelectionSummary) • \(prayer.languageDisplayName)"
    case .angelus:
      return prayer.languageDisplayName
    case .jesusPrayer:
      return "\(prayer.jesusPrayer.targetDisplayName) • \(prayer.languageDisplayName)"
    case .stationsOfTheCross:
      return prayer.languageDisplayName
    case .franciscanCrown:
      return prayer.languageDisplayName
    case .sevenSorrows:
      return prayer.languageDisplayName
    case .divineMercyChaplet:
      return prayer.languageDisplayName
    case .custom:
      // Unreachable in practice — .custom favorites render via SimpleFavoriteRow, never
      // FavoriteCard (see FavoritesListView.configurableKinds). Still needed for exhaustiveness.
      return prayer.languageDisplayName
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(accentColor)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(prayer.name)
            .font(.headline)
          if prayer.isDefault {
            Image(systemName: "star.fill")
              .font(.caption)
              .foregroundStyle(.yellow)
          }
          Spacer()

          Button(action: onEdit) {
            Label("favorites.edit", systemImage: "pencil")
              .labelStyle(.iconOnly)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.secondary)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel(String(localized: "favorites.editPrayer", defaultValue: "Edit \(prayer.name)"))

          Button(role: .destructive, action: onDelete) {
            Label("favorites.delete", systemImage: "trash")
              .labelStyle(.iconOnly)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.red)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel(String(localized: "favorites.deletePrayer", defaultValue: "Delete \(prayer.name)"))
        }

        Text(subtitle)
          .font(.subheadline)
          .foregroundStyle(.secondary)

        HStack(spacing: 8) {
          Button(action: onPray) {
            Text("favorites.pray")
              .frame(maxWidth: .infinity)
          }
          .prosaryProminentButtonStyle()
          .tint(accentColor)
          .accessibilityLabel(String(localized: "favorites.prayPrayer", defaultValue: "Pray \(prayer.name)"))

          if !prayer.isDefault {
            Button(action: onMakeDefault) {
              Label("favorites.setDefault", systemImage: "star")
                .frame(maxWidth: .infinity)
            }
            .prosarySecondaryButtonStyle()
            .accessibilityLabel(String(localized: "favorites.setPrayerAsDefault", defaultValue: "Set \(prayer.name) as default"))
          }
        }
        .controlSize(.regular)
        .padding(.top, 2)
      }
      .padding(14)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
  }
}

// MARK: - Simple Favorite Row

/// One row per non-configurable devotion — a star toggle and, once favorited, a reminders
/// button. No name/language editing and no "+ Add another" — see FavoritesListView. `title`/
/// `systemImage` are passed in rather than derived from a `PrayerKind` so this same row can
/// render either one of the 5 hardcoded simplified kinds or a generic bundle-driven devotion.
private struct SimpleFavoriteRow: View {
  let title: String
  let systemImage: String
  let accentColor: Color
  let isFavorited: Bool
  let onToggleFavorite: () -> Void
  let onEditReminders: () -> Void

  var body: some View {
    HStack(spacing: 0) {
      Rectangle()
        .fill(accentColor)
        .frame(width: 4)

      HStack(spacing: 12) {
        Button(action: onToggleFavorite) {
          Image(systemName: isFavorited ? "star.fill" : "star")
            .foregroundStyle(isFavorited ? .yellow : .secondary)
        }
        .buttonStyle(.borderless)
        .frame(minWidth: 44, minHeight: 44)
        .accessibilityLabel(isFavorited
          ? String(localized: "favorites.removeKindFromFavorites", defaultValue: "Remove \(title) from Favorites")
          : String(localized: "favorites.addKindToFavorites", defaultValue: "Add \(title) to Favorites"))

        Image(systemName: systemImage)
          .foregroundStyle(accentColor)
        Text(title)
          .font(.headline)

        Spacer()

        if isFavorited {
          Button(action: onEditReminders) {
            Label("favorites.reminders", systemImage: "bell")
              .labelStyle(.iconOnly)
          }
          .buttonStyle(.borderless)
          .foregroundStyle(.secondary)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityLabel(String(localized: "favorites.editKindReminders", defaultValue: "Edit \(title) reminders"))
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .padding(.horizontal, 16)
  }
}

#Preview {
  NavigationStack {
    FavoritesListView(path: .constant(NavigationPath()))
  }
}
