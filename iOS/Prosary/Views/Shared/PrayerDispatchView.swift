
//
//  PrayerDispatchView.swift
//  Prosary
//
//  Resolves a Prayer.ID from the store and forwards to the appropriate flow view based on kind.
//  Used by ContentView when navigating to a saved favorite via AppRoute.prayer(id:).
//

import SwiftUI

struct PrayerDispatchView: View {
  let prayerId: Prayer.ID
  @Binding var path: NavigationPath

  @Environment(\.appServices) private var services
  @State private var prayer: Prayer?

  var body: some View {
    Group {
      if let prayer {
        switch prayer.kind {
        case .rosary:
          RosaryFlowView(prayer: prayer)
        case .jesusPrayer:
          JesusPrayerFlowView(path: $path, prayer: prayer)
        case .custom:
          if let devotionId = prayer.customDevotionId {
            CustomDevotionFlowView(devotionId: devotionId, prayer: prayer)
          }
        }
      } else {
        ProgressView()
      }
    }
    .task {
      prayer = try? await services.presetStore.get(id: prayerId)
    }
  }
}
