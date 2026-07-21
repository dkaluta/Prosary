//
//  ProsaryShortcuts.swift
//  Prosary
//
//  Surfaces the app's intents in the Shortcuts app, Siri, and Spotlight on iPhone and Mac.
//

import AppIntents

struct ProsaryShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: PrayRosaryIntent(),
            phrases: [
                "Pray the Rosary in \(.applicationName)",
                "Start my Rosary in \(.applicationName)",
            ],
            shortTitle: "Pray the Rosary",
            systemImageName: "arrow.triangle.turn.up.right.circle"
        )

        AppShortcut(
            intent: TodaysMysteryIntent(),
            phrases: [
                "What are today's mysteries in \(.applicationName)",
                "Today's mysteries in \(.applicationName)",
            ],
            shortTitle: "Today's Mysteries",
            systemImageName: "calendar"
        )
    }
}
