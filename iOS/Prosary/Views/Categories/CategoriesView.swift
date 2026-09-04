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

  @Binding var path: [AppRoute]
  /// Bumped on every appearance so a devotion installed in another tab shows up here without
  /// a relaunch (same trick as HomeView's card list).
  @State private var packGeneration = 0

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
    List {
      ForEach(sections, id: \.tag) { section in
        Section(section.tag.capitalized) {
          ForEach(section.listings) { listing in
            Button {
              path.push(listing.route)
            } label: {
              Label {
                Text(HebrewDisplayText.unpointed(listing.title))
                  .foregroundStyle(.primary)
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
            .accessibilityIdentifier("category.\(listing.id)")
          }
        }
      }
    }
    .navigationTitle(String(localized: "categories.title", defaultValue: "Categories"))
    .onAppear { packGeneration += 1 }
  }
}
