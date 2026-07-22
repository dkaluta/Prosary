//
//  MockAngelusEngine.swift
//  Prosary
//
//  A fully-working AngelusEngine used to drive Previews and interactive testing today, built on
//  the ported prayer content in Mocks/Content. Not the production implementation — see
//  Support/Stubs/StubAngelusEngine.swift for the skeleton to replace this with your own rules.
//

import Foundation

struct MockAngelusEngine: AngelusEngine {
    private let calendar: LiturgicalCalendarProviding

    init(calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar()) {
        self.calendar = calendar
    }

    func buildSteps(languageCode: String?) -> [RosaryStep] {
        func text(_ key: PrayerKey) -> String {
            PrayerTranslations.get(languageCode: languageCode, key: key)
        }

        if calendar.isEasterSeasonToday() {
            // During Eastertide the Angelus is traditionally replaced entirely by the Regina
            // Caeli — same composition (antiphon + versicle/response/collect) MockRosaryEngine
            // already builds for the Rosary's own Paschal closing antiphon.
            let body = "\(text(.reginaCaeli))\n\nV. \(text(.versiculumPaschale))\nR. \(text(.responsiumPaschale))\n\n\(text(.collectaPaschale))"
            return [RosaryStep(title: "Regina Caeli", subtitle: nil, body: body, imageOverrideKey: "madonna_and_child")]
        }

        return [
            RosaryStep(
                title: "The Annunciation", subtitle: nil,
                body: "V. \(text(.versiculumAngelusPrimus))\nR. \(text(.responsiumAngelusPrimus))",
                imageOverrideKey: "joyful_01_annunciation"),
            RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

            RosaryStep(
                title: "The Fiat", subtitle: nil,
                body: "V. \(text(.versiculumAngelusSecundus))\nR. \(text(.responsiumAngelusSecundus))",
                imageOverrideKey: "joyful_01_annunciation"),
            RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

            RosaryStep(
                title: "The Incarnation", subtitle: nil,
                body: "V. \(text(.versiculumAngelusTertius))\nR. \(text(.responsiumAngelusTertius))",
                imageOverrideKey: "joyful_01_annunciation"),
            RosaryStep(title: "Hail Mary", subtitle: nil, body: text(.aveMaria), imageOverrideKey: "joyful_01_annunciation"),

            RosaryStep(
                title: "Let Us Pray", subtitle: nil,
                body: "V. \(text(.versiculumStandard))\nR. \(text(.responsiumStandard))\n\n\(text(.collectaAngelus))",
                imageOverrideKey: "joyful_01_annunciation"),
        ]
    }
}
