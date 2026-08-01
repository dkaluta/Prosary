//
//  RepositoryBrowserView.swift
//  Prosary
//
//  The in-app browser for prayers.prosary.app: fetches the catalog, filters by search text
//  and tag, and installs a bundle through the exact same PrayerPackStore.installPack pipeline
//  as a manual file import — so an installed community devotion behaves identically (star row,
//  "Repository" tag, remove affordance).
//

import SwiftUI

struct RepositoryBrowserView: View {
  /// True when presented as a sheet from Favorites (Done button, explicit macOS frame);
  /// false when living inside the Browse tab's own NavigationStack.
  var presentedAsSheet = true

  @Environment(\.dismiss) private var dismiss

  @State private var bundles: [RepositoryBundle] = []
  @State private var isLoading = true
  @State private var loadError: String?
  @State private var searchText = ""
  @State private var selectedTag: String?
  @State private var busyBundleIds: Set<String> = []
  @State private var installedIds: Set<String> = []
  @State private var installError: String?

  private var allTags: [String] {
    Array(Set(bundles.flatMap(\.tags))).sorted()
  }

  private var filteredBundles: [RepositoryBundle] {
    bundles.filter { bundle in
      if let selectedTag, !bundle.tags.contains(selectedTag) { return false }
      guard !searchText.isEmpty else { return true }
      let haystack = "\(bundle.name) \(bundle.author) \(bundle.description) \(bundle.id)"
      return haystack.localizedCaseInsensitiveContains(searchText)
    }
  }

  var body: some View {
    Group {
      Group {
        if isLoading {
          ProgressView()
        } else if let loadError {
          ContentUnavailableView {
            Label(
              String(localized: "repository.unavailable", defaultValue: "Repository Unavailable"),
              systemImage: "wifi.slash")
          } description: {
            Text(loadError)
          } actions: {
            Button(String(localized: "repository.retry", defaultValue: "Try Again")) {
              Task { await load() }
            }
          }
        } else {
          list
        }
      }
      .navigationTitle(String(localized: "repository.title", defaultValue: "Community Devotions"))
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        if presentedAsSheet {
          ToolbarItem(placement: .cancellationAction) {
            Button(String(localized: "favoriteEditor.done", defaultValue: "Done")) { dismiss() }
          }
        }
      }
      .alert(
        String(localized: "repository.installFailed", defaultValue: "Could Not Install Devotion"),
        isPresented: .init(get: { installError != nil }, set: { if !$0 { installError = nil } })
      ) {
        Button("favoriteEditor.cancel", role: .cancel) {}
      } message: {
        Text(installError ?? "")
      }
    }
    #if os(macOS)
    // A macOS sheet sizes to its content's ideal height, and a List has none — without an
    // explicit frame the whole content area collapses to zero (iOS sheets are unaffected;
    // the Browse tab fills its window and needs none).
    .frame(minWidth: presentedAsSheet ? 560 : nil, minHeight: presentedAsSheet ? 460 : nil)
    #endif
    .task { await load() }
  }

  private var list: some View {
    List {
      if allTags.count > 1 {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            tagChip(nil, label: String(localized: "repository.allTags", defaultValue: "All"))
            ForEach(allTags, id: \.self) { tag in
              tagChip(tag, label: tag)
            }
          }
        }
        .listRowSeparator(.hidden)
      }

      ForEach(filteredBundles) { bundle in
        bundleRow(bundle)
      }

      if filteredBundles.isEmpty {
        Text(String(localized: "repository.noMatches", defaultValue: "No devotions match."))
          .foregroundStyle(.secondary)
      }
    }
    .listStyle(.plain)
    .searchable(text: $searchText)
    .refreshable { await load() }
  }

  private func tagChip(_ tag: String?, label: String) -> some View {
    Button {
      selectedTag = tag
    } label: {
      Text(label)
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Capsule().fill(selectedTag == tag ? Color.brandPrimary : Color.secondary.opacity(0.15)))
        .foregroundStyle(selectedTag == tag ? Color(uiColorInverse: ()) : .primary)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func bundleRow(_ bundle: RepositoryBundle) -> some View {
    let isInstalled = installedIds.contains(bundle.id) || PrayerPackStore.customDevotionIds().contains(bundle.id)
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text(bundle.name)
            .font(.headline)
          Text(verbatim: "\(bundle.author) · \(languageNames(bundle.languages))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        if isInstalled {
          Label(String(localized: "repository.installed", defaultValue: "Installed"), systemImage: "checkmark")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        } else if busyBundleIds.contains(bundle.id) {
          ProgressView()
        } else {
          Button(String(localized: "repository.install", defaultValue: "Install")) {
            install(bundle)
          }
          .buttonStyle(.borderedProminent)
          .tint(.brandPrimary)
        }
      }
      if !bundle.description.isEmpty {
        Text(bundle.description)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      if !bundle.tags.isEmpty {
        Text(bundle.tags.joined(separator: " · "))
          .font(.caption2)
          .foregroundStyle(Color.brandPrimary)
      }
    }
    .padding(.vertical, 4)
  }

  private func languageNames(_ codes: [String]) -> String {
    codes
      .compactMap { code in LanguageCatalog.all.first { $0.code == code }?.nativeName }
      .joined(separator: ", ")
  }

  private func load() async {
    isLoading = true
    loadError = nil
    do {
      bundles = try await RepositoryClient.fetchCatalog()
    } catch {
      loadError = error.localizedDescription
    }
    isLoading = false
  }

  private func install(_ bundle: RepositoryBundle) {
    busyBundleIds.insert(bundle.id)
    Task {
      defer { busyBundleIds.remove(bundle.id) }
      do {
        let data = try await RepositoryClient.downloadBundle(bundle)
        try PrayerPackStore.installPack(from: data)
        installedIds.insert(bundle.id)
      } catch {
        installError = error.localizedDescription
      }
    }
  }
}

/// The chip's on-brand text color: white over the deep maroon in light mode, near-black over
/// the pale rose in dark — mirroring the websites' --on-primary token.
private extension Color {
  init(uiColorInverse: ()) {
    #if canImport(UIKit)
    self.init(uiColor: .systemBackground)
    #else
    self.init(nsColor: .windowBackgroundColor)
    #endif
  }
}
