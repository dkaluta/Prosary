//
//  CategoriesView.swift
//  Prosary
//
//  "View prayers by category": every launchable devotion grouped by its manifest tags —
//  a devotion appears under each of its tags; anything untagged lands under "Other".
//

import SwiftUI

struct CategoriesView: View {
  /// Names on this screen follow the default prayer language, so the screen must re-derive
  /// the moment that setting changes — including from the Mac's Settings window, which never
  /// re-triggers onAppear. Declaring this is NOT enough: SwiftUI only registers the dependency
  /// when body actually reads the value (verified live on the Mac, 2026-08-08 — the Settings
  /// window showed עברית while Pray behind it stayed English), which is what the
  /// `let _ = observedPrayerLanguage` at the top of body is for.
  @AppStorage("defaultLanguageCode") private var observedPrayerLanguage = LanguageCatalog.defaultCode

  @Binding var path: NavigationPath
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
    List {
      ForEach(sections, id: \.tag) { section in
        Section(section.tag.capitalized) {
          ForEach(section.listings) { listing in
            Button {
              path.append(listing.route)
            } label: {
              Label {
                Text(listing.title)
                  .foregroundStyle(.primary)
              } icon: {
                if let glyph = listing.iconGlyph {
                  Text(glyph).foregroundStyle(listing.accentColor)
                } else {
                  Image(systemName: listing.systemImage)
                    .foregroundStyle(listing.accentColor)
                }
              }
            }
            .accessibilityIdentifier("category.\(listing.id)")
          }
        }
      }
    }
    .navigationTitle(String(localized: "categories.title", defaultValue: "Categories"))
    .onAppear { packGeneration += 1 }
  }
}
