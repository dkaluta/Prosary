//
//  MockRosaryEngine.swift
//  Prosary
//
//  A fully-working RosaryEngine used to drive Previews and interactive testing today, built on
//  the ported prayer/mystery content in Mocks/Content. Not the production implementation — see
//  Support/Stubs/StubRosaryEngine.swift for the skeleton to replace this with your own rules.
//

import Foundation

struct MockRosaryEngine: RosaryEngine {
    private static let ordinals = ["1st", "2nd", "3rd", "4th", "5th"]

    private static let virtues: [(key: PrayerKey, imageKey: String)] = [
        (.aveMariaProFide, "virtue_faith"),
        (.aveMariaProSpe, "virtue_hope"),
        (.aveMariaProCaritate, "virtue_charity"),
    ]

    private let calendar: LiturgicalCalendarProviding

    init(calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar()) {
        self.calendar = calendar
    }

    /// Resolves which mystery group(s) a config points to, in the order they should be prayed.
    func resolveMysteryGroups(for config: RosaryConfig) -> [MysteryGroup] {
        switch config.mysterySelectionMode {
        case .specific:
            return [config.specificMysteryGroup]
        case .fifteenMystery:
            return [.joyful, .sorrowful, .glorious]
        case .twentyMystery:
            // Chronological order of Christ's life: infancy/hidden life, public ministry, passion, glory.
            return [.joyful, .luminous, .sorrowful, .glorious]
        case .todaysMysteries:
            return [calendar.mysteryGroupToday()]
        }
    }

    func buildSteps(for config: RosaryConfig) -> [RosaryStep] {
        let lang = config.languageCode
        let groups = resolveMysteryGroups(for: config)
        var steps: [RosaryStep] = []

        func text(_ key: PrayerKey) -> String {
            PrayerTranslations.get(languageCode: lang, key: key)
        }

        steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))

        if config.includeApostlesCreed {
            steps.append(RosaryStep(title: "Apostles' Creed", subtitle: nil, body: text(.symbolumApostolorum), imageOverrideKey: "crucifix"))
        }

        if config.includeOpeningPrayers {
            steps.append(RosaryStep(title: "Our Father", subtitle: nil, body: text(.paterNoster), imageOverrideKey: "our_father"))
            for virtue in Self.virtues {
                steps.append(RosaryStep(title: "Hail Mary", subtitle: text(virtue.key), body: text(.aveMaria), imageOverrideKey: virtue.imageKey))
            }
            steps.append(RosaryStep(title: "Glory Be", subtitle: nil, body: text(.gloriaPatri), imageOverrideKey: "glory_be"))
        }

        let fruitLabel = text(.fructusMysteriiLabel)

        // A session spanning more than one group (15/20-mystery) needs the group name in each
        // decade's label so it's clear which set you're in as you move from one to the next.
        let showGroupName = groups.count > 1

        // Global decade counter (0-based), continuing across group boundaries in a 15/20-mystery
        // session — this is what the bead progress indicator uses to tell decades apart, so it
        // must NOT reset per group.
        var decadeIndex = 0

        for group in groups {
            let mysteries = MysteryCatalog.forGroup(group)

            for (d, mystery) in mysteries.enumerated() {
                let mysteryText = MysteryTranslations.get(languageCode: lang, imageKey: mystery.imageKey)
                let ordinalLabel = showGroupName ? "\(group.displayName) — \(Self.ordinals[d]) Mystery" : "\(Self.ordinals[d]) Mystery"
                let decadeSubtitle = "\(ordinalLabel) — \(mysteryText.title)"
                let thisDecade = decadeIndex

                steps.append(RosaryStep(
                    title: mysteryText.title, subtitle: ordinalLabel,
                    body: "\(mysteryText.description)\n\n\(fruitLabel): \(mysteryText.fruit)",
                    mystery: mystery, isScripture: true, decadeIndex: thisDecade))

                // "Our Father" gets its own dedicated image (Dürer's Praying Hands) rather than
                // staying anchored to the current decade's mystery image, same reasoning as the
                // Fatima Prayer step below.
                steps.append(RosaryStep(
                    title: "Our Father", subtitle: decadeSubtitle, body: text(.paterNoster),
                    decadeIndex: thisDecade, imageOverrideKey: "our_father"))

                for h in 1...10 {
                    steps.append(RosaryStep(
                        title: "Hail Mary (\(h) of 10)", subtitle: decadeSubtitle, body: text(.aveMaria),
                        mystery: mystery, decadeIndex: thisDecade, hailMaryIndexInDecade: h))
                }

                // Same reasoning as Our Father/Fatima Prayer above: a dedicated Trinity image
                // ("Glory be to the Father, and to the Son, and to the Holy Spirit...") rather
                // than the current decade's mystery image.
                steps.append(RosaryStep(
                    title: "Glory Be", subtitle: decadeSubtitle, body: text(.gloriaPatri),
                    decadeIndex: thisDecade, imageOverrideKey: "glory_be"))

                if config.includeFatimaPrayer {
                    // "O my Jesus..." — a portrait of Christ fits better than staying anchored to
                    // the current decade's mystery image, hence no mystery argument here.
                    steps.append(RosaryStep(
                        title: "Fatima Prayer", subtitle: decadeSubtitle, body: text(.oratioFatimae),
                        decadeIndex: thisDecade, imageOverrideKey: "jesus_portrait"))
                }

                if config.eternalRestForDeceased == .afterEachDecade {
                    steps.append(RosaryStep(
                        title: "For the Faithful Departed", subtitle: decadeSubtitle, body: text(.requiemAeternam),
                        decadeIndex: thisDecade, imageOverrideKey: "eternal_rest"))
                }

                decadeIndex += 1
            }
        }

        if let antiphon = resolveMarianAntiphon(for: config) {
            var antiphonStep = buildAntiphonStep(antiphon, text: text)
            antiphonStep.isAntiphon = true
            antiphonStep.imageOverrideKey = "madonna_and_child"
            steps.append(antiphonStep)
        }

        if config.includeStMichaelPrayer {
            steps.append(RosaryStep(title: "St. Michael the Archangel", subtitle: nil, body: text(.sanctusMichael), imageOverrideKey: "st_michael"))
        }

        // Prayed last, immediately before the closing Sign of the Cross — after the antiphon
        // (and St. Michael prayer, if included), matching common communal-recitation practice.
        if config.eternalRestForDeceased == .atEndOnly {
            steps.append(RosaryStep(title: "For the Faithful Departed", subtitle: nil, body: text(.requiemAeternam), imageOverrideKey: "eternal_rest"))
        }

        if config.includeFinalSignOfCross {
            steps.append(RosaryStep(title: "Sign of the Cross", subtitle: nil, body: text(.signumCrucis), imageOverrideKey: "crucifix"))
        }

        return steps
    }

    private func resolveMarianAntiphon(for config: RosaryConfig) -> MarianAntiphonOption? {
        switch config.marianAntiphon {
        case .none: return nil
        case .seasonal: return calendar.seasonalMarianAntiphonToday()
        case let chosen: return chosen
        }
    }

    private enum AntiphonStyle { case standard, paschal, standalone }

    private func buildAntiphonStep(_ antiphon: MarianAntiphonOption, text: (PrayerKey) -> String) -> RosaryStep {
        let (titleKey, style): (PrayerKey, AntiphonStyle) = {
            switch antiphon {
            case .salveRegina: return (.salveRegina, .standard)
            case .almaRedemptorisMater: return (.almaRedemptorisMater, .standard)
            case .aveReginaCaelorum: return (.aveReginaCaelorum, .standard)
            case .reginaCaeli: return (.reginaCaeli, .paschal)
            case .subTuumPraesidium: return (.subTuumPraesidium, .standalone)
            case .none, .seasonal: return (.salveRegina, .standard)
            }
        }()

        // Sub Tuum Praesidium is the Church's oldest known Marian prayer and is traditionally
        // prayed on its own, without the versicle/response/collect used after the four Office antiphons.
        let body: String
        switch style {
        case .standalone:
            body = text(titleKey)
        case .standard:
            body = "\(text(titleKey))\n\nV. \(text(.versiculumStandard))\nR. \(text(.responsiumStandard))\n\n\(text(.collectaStandard))"
        case .paschal:
            body = "\(text(titleKey))\n\nV. \(text(.versiculumPaschale))\nR. \(text(.responsiumPaschale))\n\n\(text(.collectaPaschale))"
        }

        return RosaryStep(title: antiphonHeader(for: antiphon), subtitle: nil, body: body)
    }

    private func antiphonHeader(for antiphon: MarianAntiphonOption) -> String {
        switch antiphon {
        case .salveRegina: return "Salve Regina"
        case .almaRedemptorisMater: return "Alma Redemptoris Mater"
        case .aveReginaCaelorum: return "Ave Regina Caelorum"
        case .reginaCaeli: return "Regina Caeli"
        case .subTuumPraesidium: return "Sub Tuum Praesidium"
        case .none, .seasonal: return "Marian Antiphon"
        }
    }
}
