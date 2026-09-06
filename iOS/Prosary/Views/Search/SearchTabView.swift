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

  private var localMatches: [DevotionListing] {
    _ = packGeneration
    let listings = DevotionDirectory.all()
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
      guard !query.isEmpty else { return true }
      return "\(bundle.name) \(bundle.author) \(bundle.description) \(bundle.tags.joined(separator: " ")) \(bundle.tags.map { UILanguage.tag($0) }.joined(separator: " "))"
        .localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    let _ = prayerLanguage.code  // dependency registration — see the property's comment
    let _ = showsPrayerNameInPrayerLanguage
    List {
      Section(String(localized: "search.onDevice", defaultValue: "On This Device")) {
        ForEach(localMatches) { listing in
          Button {
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
            // Match Categories: the entire visible List row is clickable on Mac, rather
            // than only the icon-and-title's intrinsic pill-sized bounds.
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier("search.local.\(listing.id)")
        }
        if localMatches.isEmpty {
          Text(String(localized: "search.noLocalMatches", defaultValue: "Nothing on this device matches."))
            .foregroundStyle(.secondary)
        }
      }

      if !communityMatches.isEmpty {
        Section(String(localized: "search.community", defaultValue: "From the Community")) {
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
                Button(String(localized: "repository.install", defaultValue: "Install")) {
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
    .navigationTitle(String(localized: "search.title", defaultValue: "Search"))
    .searchable(text: $query, prompt: String(localized: "search.prompt", defaultValue: "Devotions, categories, authors"))
    .onAppear { packGeneration += 1 }
    .task {
      repoBundles = (try? await RepositoryClient.fetchCatalog()) ?? []
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
