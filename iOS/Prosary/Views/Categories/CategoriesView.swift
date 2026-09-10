//
//  CategoriesView.swift
//  Prosary
//
//  "View prayers by category": every launchable devotion grouped by its manifest tags —
//  a devotion appears under each of its tags; anything untagged lands under "Other".
//

import SwiftUI

struct CategoriesView: View {
  /// Names here follow the default prayer language; the monitor is the one mechanism
  /// that survives the Mac's Settings menu — see PrayerLanguageMonitor's header for the
  /// graveyard of simpler attempts. Reading `.code` in body registers the dependency.
  @ObservedObject private var prayerLanguage = PrayerLanguageMonitor.shared
  @AppStorage(PrayerNamePresentation.defaultsKey) private var showsPrayerNameInPrayerLanguage = false

  @Binding var path: [AppRoute]
  /// Bumped on every appearance so a devotion installed in another tab shows up here without
  /// a relaunch (same trick as HomeView's card list).
  @State private var packGeneration = 0
  @State private var selectedListing: String?
  @State private var removingDownload: String?
  @State private var unusedDownloads: Set<String> = []
  @Environment(\.appServices) private var services

  private var desktopSelection: Binding<String?>? {
    #if os(macOS)
    $selectedListing
    #else
    nil
    #endif
  }

  private var sections: [(tag: String, listings: [DevotionListing])] {
    _ = packGeneration
    let listings = DevotionDirectory.all()
    var byTag: [String: [DevotionListing]] = [:]
    for listing in listings {
      if listing.tags.isEmpty {
        byTag["other", default: []].append(listing)
      }
      for tag in listing.tags {
        byTag[tag, default: []].append(listing)
      }
    }
    return byTag.keys.sorted().map { ($0, byTag[$0]!) }
  }

  var body: some View {
    let _ = prayerLanguage.code  // dependency registration — see the property's comment
    let _ = showsPrayerNameInPrayerLanguage
    List(selection: desktopSelection) {
      ForEach(sections, id: \.tag) { section in
        Section(UILanguage.tag(section.tag)) {
          ForEach(section.listings) { listing in
            Button {
              selectedListing = "\(section.tag)|\(listing.id)"
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
                  Image(systemName: listing.systemImage)
                    .foregroundStyle(listing.accentColor)
                }
              }
              // A List does not automatically stretch a custom Button label on macOS. The
              // old intrinsic-width label left most of the visible row inert; make the whole
              // semantic row the target while retaining single-top programmatic navigation.
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tag("\(section.tag)|\(listing.id)")
            .accessibilityIdentifier("category.\(listing.id)")
            .contextMenu {
              if PrayerPackStore.installedBundleIds().contains(listing.id) {
                Button(role: .destructive) { removingDownload = listing.id } label: {
                  Label(String(localized: "removal.removeDownloadAction", defaultValue: "Remove Download…"), systemImage: "trash")
                }
                .disabled(!unusedDownloads.contains(listing.id))
                .help(String(localized: "removal.downloadInUse", defaultValue: "Delete all saved copies of this prayer before removing its download."))
              }
            }
          }
        }
      }
    }
    .navigationTitle(String(localized: "categories.title", defaultValue: "Categories"))
    .modifier(PrayerDownloadRemovalDialogs(bundleID: $removingDownload, onRemoved: { await refreshDownloads() }))
    .task { await refreshDownloads() }
    .onAppear { packGeneration += 1 }
    .onReceive(NotificationCenter.default.publisher(for: .prayerLibraryDidChange)) { _ in
      packGeneration += 1
      Task { await refreshDownloads() }
    }
    .macListActivation {
      for section in sections {
        if let listing = section.listings.first(where: { "\(section.tag)|\($0.id)" == selectedListing }) {
          path.push(listing.route)
          return true
        }
      }
      return false
    }
  }

  private func refreshDownloads() async {
    unusedDownloads = Set((try? await PrayerRemovalService(store: services.presetStore).unusedDownloadIDs()) ?? [])
    packGeneration += 1
  }
}
