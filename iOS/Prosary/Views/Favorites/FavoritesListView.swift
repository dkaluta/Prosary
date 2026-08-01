
//
//  FavoritesListView.swift
//  Prosary
//
//  Card-layout list of saved prayer favorites grouped by kind. Replaces PresetsListView.
//

import SwiftUI
import UniformTypeIdentifiers

struct FavoritesListView: View {
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services

  @State private var prayers: [Prayer] = []
  @State private var editorPrayer: Prayer?
  @State private var isNew = false
  @State private var remindersPrayer: Prayer?
  @State private var showsImporter = false
  @State private var importError: String?
  // Bumped after install/remove so the customDevotionIds ForEach re-evaluates.
  @State private var installedGeneration = 0

  /// Rosary and Jesus Prayer have real per-favorite options worth naming and saving multiple
  /// variants of, so they keep the full card list + editor. Every generic (bundle-driven)
  /// devotion has nothing to configure beyond reminders, so each gets a single on/off star row
  /// instead — see `SimpleFavoriteRow`.
  private let configurableKinds: [PrayerKind] = [.rosary, .jesusPrayer]

  private var jesusPrayerAccent: Color { .adaptive(light: "#8B1A1A", dark: "#C62828") }

  func accentColor(for kind: PrayerKind) -> Color {
    switch kind {
    case .rosary:      return .brandPrimary
    case .jesusPrayer: return jesusPrayerAccent
    // Unreachable in practice — .custom rows read their bundle's own accent colors instead (see
    // the customDevotionIds ForEach below). Still needed for exhaustiveness.
    case .custom:      return .brandPrimary
    }
  }

  /// Accent color for a generic devotion's row, honoring the manifest's light/dark pair.
  private func customAccent(_ info: CustomDevotionInfo) -> Color {
    if let light = info.accentColorHex, let dark = info.accentColorDarkHex {
      return .adaptive(light: light, dark: dark)
    }
    return info.accentColorHex.map { Color(hex: $0) } ?? .brandPrimary
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
          // One star-row per generic (bundle-driven) devotion, in pack-load order — nothing
          // devotion-specific hardcoded here.
          ForEach(PrayerPackStore.customDevotionIds(), id: \.self) { bundleId in
            if let info = PrayerPackStore.info(for: bundleId) {
              let favorite = prayers.first { $0.kind == .custom && $0.customDevotionId == bundleId }
              SimpleFavoriteRow(
                title: info.localizedDisplayName,
                systemImage: info.iconSystemName ?? PrayerKind.custom.systemImage,
                accentColor: customAccent(info),
                isFavorited: favorite != nil,
                onToggleFavorite: { toggleCustomFavorite(bundleId: bundleId, displayName: info.localizedDisplayName, existing: favorite) },
                onEditReminders: { favorite.map { remindersPrayer = $0 } },
                badge: bundleId.hasPrefix("repo.")
                  ? String(localized: "favorites.repositoryTag", defaultValue: "Repository") : nil
              )
              .contextMenu {
                if PrayerPackStore.installedBundleIds().contains(bundleId) {
                  Button(role: .destructive) {
                    removeInstalledBundle(bundleId, favorite: favorite)
                  } label: {
                    Label(String(localized: "favorites.removeBundle", defaultValue: "Remove Imported Devotion"), systemImage: "trash")
                  }
                }
              }
            }
          }

          // Anyone can author a .prosaryprayer bundle (see Shared/ARCHITECTURE.md) — imported
          // devotions get the same star row as the shipped ones.
          Button {
            showsImporter = true
          } label: {
            Label("favorites.importBundle", systemImage: "square.and.arrow.down")
              .font(.subheadline)
          }
          .buttonStyle(.plain)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 20)
          .padding(.vertical, 4)
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
    .fileImporter(
      isPresented: $showsImporter,
      allowedContentTypes: [UTType(filenameExtension: "prosaryprayer") ?? .zip, .zip]
    ) { result in
      importBundle(result)
    }
    .alert(
      String(localized: "favorites.importFailed", defaultValue: "Could Not Import Devotion"),
      isPresented: .init(get: { importError != nil }, set: { if !$0 { importError = nil } })
    ) {
      Button("favoriteEditor.cancel", role: .cancel) {}
    } message: {
      Text(importError ?? "")
    }
    .id(installedGeneration)
  }

  private func importBundle(_ result: Result<URL, Error>) {
    guard case .success(let url) = result else { return }
    do {
      try PrayerPackStore.installPack(fromUserSelected: url)
      installedGeneration += 1
    } catch {
      importError = error.localizedDescription
    }
  }

  private func removeInstalledBundle(_ bundleId: String, favorite: Prayer?) {
    Task {
      if let favorite {
        ReminderScheduler.removeAll(for: favorite)
        try? await services.presetStore.delete(favorite)
      }
      PrayerPackStore.removeInstalledPack(id: bundleId)
      installedGeneration += 1
      await reload()
    }
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

  /// Star toggle for a generic (bundle-driven) devotion row — at most one `Prayer` row per
  /// bundle id, always saved with the sentinel language (follows the app default).
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
    case .jesusPrayer:
      return "\(prayer.jesusPrayer.targetDisplayName) • \(prayer.languageDisplayName)"
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
/// `systemImage` come from the devotion's own bundle manifest.
private struct SimpleFavoriteRow: View {
  let title: String
  let systemImage: String
  let accentColor: Color
  let isFavorited: Bool
  let onToggleFavorite: () -> Void
  let onEditReminders: () -> Void
  /// Small capsule after the title — "Repository" for bundles installed from
  /// prayers.prosary.app (ids prefixed "repo.", see ARCHITECTURE.md). Nil hides it.
  var badge: String? = nil

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

        if let badge {
          Text(badge)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(accentColor.opacity(0.15)))
            .foregroundStyle(accentColor)
        }

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
