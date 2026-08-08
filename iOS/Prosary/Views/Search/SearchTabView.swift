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
  /// Names on this screen follow the default prayer language, so the screen must re-derive
  /// the moment that setting changes — including from the Mac's Settings window, which never
  /// re-triggers onAppear. Declaring this is NOT enough: SwiftUI only registers the dependency
  /// when body actually reads the value (verified live on the Mac, 2026-08-08 — the Settings
  /// window showed עברית while Pray behind it stayed English), which is what the
  /// `let _ = observedPrayerLanguage` at the top of body is for.
  @AppStorage("defaultLanguageCode") private var observedPrayerLanguage = LanguageCatalog.defaultCode

  @Binding var path: NavigationPath

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
        || $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
    }
  }

  private var communityMatches: [RepositoryBundle] {
    _ = packGeneration
    let installed = Set(PrayerPackStore.customDevotionIds())
    return repoBundles.filter { bundle in
      guard !installed.contains(bundle.id) else { return false }
      guard !query.isEmpty else { return true }
      return "\(bundle.name) \(bundle.author) \(bundle.description) \(bundle.tags.joined(separator: " "))"
        .localizedCaseInsensitiveContains(query)
    }
  }

  var body: some View {
    List {
      Section(String(localized: "search.onDevice", defaultValue: "On This Device")) {
        ForEach(localMatches) { listing in
          Button {
            path.append(listing.route)
          } label: {
            Label {
              Text(listing.title).foregroundStyle(.primary)
            } icon: {
              if let glyph = listing.iconGlyph {
                Text(glyph).foregroundStyle(listing.accentColor)
              } else {
              Image(systemName: listing.systemImage).foregroundStyle(listing.accentColor)
              }
            }
          }
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
                Text(bundle.name)
                Text(verbatim: "\(bundle.author) · \(bundle.tags.joined(separator: " · "))")
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
