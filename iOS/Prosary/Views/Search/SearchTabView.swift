//
//  SearchTabView.swift
//  Prosary
//
//  One search across everything prayable: devotions on this device (opened in place) and the
//  prayers.prosary.app catalog (installed in place) — the repository half loads once per
//  appearance and degrades silently offline, leaving local search fully working.
//

import SwiftUI

struct SearchTabView: View {
  /// Names here follow the default prayer language; the monitor is the one mechanism
  /// that survives the Mac's Settings menu — see PrayerLanguageMonitor's header for the
  /// graveyard of simpler attempts. Reading `.code` in body registers the dependency.
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  @AppStorage(PrayerNamePresentation.defaultsKey) private var showsPrayerNameInPrayerLanguage = false

  @Binding var path: [AppRoute]

  @State private var query = ""
  @State private var repoBundles: [RepositoryBundle] = []
  @State private var busyBundleIds: Set<String> = []
  @State private var installError: String?
  @State private var packGeneration = 0
  @State private var selectedListing: String?
  @State private var selectedCategory: String?
  @State private var removingDownload: String?
  @State private var unusedDownloads: Set<String> = []
  @Environment(\.appServices) private var services

  private var categories: [String] {
    _ = packGeneration
    return PrayerSearchCategory.available(in: DevotionDirectory.all().map(\.tags) + repoBundles.map(\.tags))
      .sorted { UILanguage.tag($0).localizedStandardCompare(UILanguage.tag($1)) == .orderedAscending }
  }

  private var desktopSelection: Binding<String?>? {
    #if os(macOS)
    $selectedListing
    #else
    nil
    #endif
  }

  private var localMatches: [DevotionListing] {
    _ = packGeneration
    let listings = DevotionDirectory.all().filter {
      PrayerSearchCategory.matches($0.tags, selected: selectedCategory)
    }
    guard !query.isEmpty else { return listings }
    return listings.filter {
      $0.title.localizedCaseInsensitiveContains(query)
        || ($0.translatedTitle?.localizedCaseInsensitiveContains(query) ?? false)
        || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) || UILanguage.tag($0).localizedCaseInsensitiveContains(query) }
    }
  }

  private var communityMatches: [RepositoryBundle] {
    _ = packGeneration
    let installed = Set(PrayerPackStore.customDevotionIds())
    return repoBundles.filter { bundle in
      guard !installed.contains(bundle.id) else { return false }
      guard PrayerSearchCategory.matches(bundle.tags, selected: selectedCategory) else { return false }
      guard !query.isEmpty else { return true }
      return "\(bundle.name) \(bundle.author) \(bundle.description) \(bundle.tags.joined(separator: " ")) \(bundle.tags.map { UILanguage.tag($0) }.joined(separator: " "))"
        .localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    let _ = prayerLanguage.code  // dependency registration — see the property's comment
    let _ = showsPrayerNameInPrayerLanguage
    List(selection: desktopSelection) {
      Section(String(localized: "categories.title", defaultValue: "Categories", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            categoryButton(nil, title: String(localized: "search.allCategories", defaultValue: "All", bundle: UILanguage.bundle, locale: UILanguage.locale))
            ForEach(categories, id: \.self) { category in
              categoryButton(category, title: UILanguage.tag(category))
            }
          }
          .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("search.categories")
      }
      Section(String(localized: "search.onDevice", defaultValue: "On This Device", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
        ForEach(localMatches) { listing in
          Button {
            selectedListing = listing.id
            path.push(listing.route)
          } label: {
            Label {
              VStack(alignment: .leading, spacing: 3) {
                Text(HebrewDisplayText.unpointed(listing.title)).foregroundStyle(.primary)
                if let translation = listing.translatedTitle {
                  Text(translation).font(.subheadline).foregroundStyle(.secondary)
                }
              }
            } icon: {
              if let glyph = listing.iconGlyph {
                Text(glyph).foregroundStyle(listing.accentColor)
              } else {
              Image(systemName: listing.systemImage).foregroundStyle(listing.accentColor)
              }
            }
            // The entire visible List row remains a native activation target.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .tag(listing.id)
          .accessibilityIdentifier("search.local.\(listing.id)")
          .contextMenu {
            if PrayerPackStore.installedBundleIds().contains(listing.id) {
              Button(role: .destructive) { removingDownload = listing.id } label: {
                Label(String(localized: "removal.removeDownloadAction", defaultValue: "Remove Download…", bundle: UILanguage.bundle, locale: UILanguage.locale), systemImage: "trash")
              }
              .disabled(!unusedDownloads.contains(listing.id))
              .help(String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            }
          }
        }
        if localMatches.isEmpty {
          Text(String(localized: "search.noLocalMatches", defaultValue: "Nothing on this device matches.", bundle: UILanguage.bundle, locale: UILanguage.locale))
            .foregroundStyle(.secondary)
        }
      }

      if !communityMatches.isEmpty {
        Section(String(localized: "search.community", defaultValue: "From the Community", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
          ForEach(communityMatches) { bundle in
            HStack {
              VStack(alignment: .leading, spacing: 2) {
                Text(HebrewDisplayText.unpointed(bundle.name))
                Text(verbatim: HebrewDisplayText.unpointed(
                  "\(bundle.author) · \(bundle.tags.map { UILanguage.tag($0) }.joined(separator: " · "))"))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if busyBundleIds.contains(bundle.id) {
                ProgressView()
              } else {
                Button(String(localized: "repository.install", defaultValue: "Install", bundle: UILanguage.bundle, locale: UILanguage.locale)) {
                  install(bundle)
                }
                .buttonStyle(.borderedProminent)
                .tint(.brandPrimary)
              }
            }
          }
        }
      }
    }
    .navigationTitle(String(localized: "search.title", defaultValue: "Search", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .searchable(text: $query, prompt: String(localized: "search.prompt", defaultValue: "Devotions, categories, authors", bundle: UILanguage.bundle, locale: UILanguage.locale))
    .modifier(PrayerDownloadRemovalDialogs(bundleID: $removingDownload, onRemoved: { await refreshDownloads() }))
    .task { await refreshDownloads() }
    .onAppear { packGeneration += 1 }
    .onChange(of: categories) { _, available in
      if let selectedCategory, !available.contains(selectedCategory) { self.selectedCategory = nil }
    }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      packGeneration += 1
      Task { await refreshDownloads() }
    }
    .macListActivation {
      guard let listing = localMatches.first(where: { $0.id == selectedListing }) else { return false }
      path.push(listing.route)
      return true
    }
    .task {
      repoBundles = (try? await RepositoryClient.fetchCatalog()) ?? []
    }
    .alert(
      String(localized: "repository.installFailed", defaultValue: "Could Not Install Devotion", bundle: UILanguage.bundle, locale: UILanguage.locale),
      isPresented: .init(get: { installError != nil }, set: { if !$0 { installError = nil } })
    ) {
      Button(String(localized: "common.ok", defaultValue: "OK", bundle: UILanguage.bundle, locale: UILanguage.locale), role: .cancel) {}
        .keyboardShortcut(.defaultAction)
    } message: {
      Text(installError ?? "")
    }
  }

  private func categoryButton(_ category: String?, title: String) -> some View {
    Button {
      selectedCategory = category
      selectedListing = nil
    } label: {
      HStack(spacing: 4) {
        if selectedCategory == category { Image(systemName: "checkmark") }
        Text(title)
      }
    }
    .buttonStyle(.bordered)
    .buttonBorderShape(.capsule)
    .tint(selectedCategory == category ? .accentColor : .secondary)
    .accessibilityLabel(title)
    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
    .accessibilityIdentifier("search.category.\(category ?? "all")")
  }

  private func refreshDownloads() async {
    unusedDownloads = Set((try? await PrayerRemovalService(store: services.presetStore).unusedDownloadIDs()) ?? [])
    packGeneration += 1
  }

  private func install(_ bundle: RepositoryBundle) {
    busyBundleIds.insert(bundle.id)
    Task {
      defer { busyBundleIds.remove(bundle.id) }
      do {
        let data = try await RepositoryClient.downloadBundle(bundle)
        try PrayerPackStore.installPack(from: data)
        packGeneration += 1
      } catch {
        installError = error.localizedDescription
      }
    }
  }
}
