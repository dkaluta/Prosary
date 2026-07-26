
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
    }
  }

  var body: some View {
    ScrollView {
      LazyVStack(alignment: .leading, spacing: 8, pinnedViews: .sectionHeaders) {
        ForEach(PrayerKind.allCases, id: \.self) { kind in
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
    .task { await reload() }
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

#Preview {
  NavigationStack {
    FavoritesListView(path: .constant(NavigationPath()))
  }
}
