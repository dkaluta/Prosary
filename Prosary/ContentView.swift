//
//  ContentView.swift
//  Prosary
//
//  Created by David Kaluta on 21/07/2026.
//

import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    private var coordinator = NavigationCoordinator.shared

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .rosary(let configId):
                        RosaryFlowView(configId: configId)
                    case .presets:
                        PresetsListView(path: $path)
                    case .about:
                        AboutView()
                    case .angelus:
                        AngelusFlowView()
                    case .jesusPrayerSetup:
                        JesusPrayerSetupView(path: $path)
                    case .jesusPrayer(let target):
                        JesusPrayerFlowView(path: $path, target: target)
                    }
                }
        }
        // App Intents (e.g. the "Pray the Rosary" Shortcut) run outside the view hierarchy and
        // request navigation by setting this shared coordinator's pendingRoute instead.
        .onChange(of: coordinator.pendingRoute) { _, newValue in
            guard let newValue else { return }
            path.append(newValue)
            coordinator.pendingRoute = nil
        }
        .task {
            if let pending = coordinator.pendingRoute {
                path.append(pending)
                coordinator.pendingRoute = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
