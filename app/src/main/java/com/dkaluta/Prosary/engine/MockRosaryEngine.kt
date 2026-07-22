package com.dkaluta.Prosary.engine

import com.dkaluta.Prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.Prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.Prosary.content.PrayerKey
import com.dkaluta.Prosary.content.PrayerTranslations
import com.dkaluta.Prosary.content.MysteryTranslations
import com.dkaluta.Prosary.models.EternalRestPlacement
import com.dkaluta.Prosary.models.MarianAntiphonOption
import com.dkaluta.Prosary.models.MysteryCatalog
import com.dkaluta.Prosary.models.MysteryGroup
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.RosaryConfig
import com.dkaluta.Prosary.models.RosaryStep

/** A fully-working [RosaryEngine] used to drive the app today, built on the ported prayer/mystery
 * content in [com.dkaluta.Prosary.content]. Not necessarily the final production implementation. */
class MockRosaryEngine(
    private val calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar(),
) : RosaryEngine {

    /** Resolves which mystery group(s) a config points to, in the order they should be prayed. */
    fun resolveMysteryGroups(config: RosaryConfig): List<MysteryGroup> = when (config.mysterySelectionMode) {
        MysterySelectionMode.Specific -> listOf(config.specificMysteryGroup)
        MysterySelectionMode.FifteenMystery -> listOf(MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        // Chronological order of Christ's life: infancy/hidden life, public ministry, passion, glory.
        MysterySelectionMode.TwentyMystery ->
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        MysterySelectionMode.TodaysMysteries -> listOf(calendar.mysteryGroupToday())
    }

    override fun buildSteps(config: RosaryConfig): List<RosaryStep> {
        val lang = config.languageCode
        val groups = resolveMysteryGroups(config)
        val steps = mutableListOf<RosaryStep>()

        fun text(key: PrayerKey): String = PrayerTranslations.get(lang, key)

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        if (config.includeApostlesCreed) {
            steps.add(RosaryStep(title = "Apostles' Creed", body = text(PrayerKey.SymbolumApostolorum), imageOverrideKey = "crucifix"))
        }

        if (config.includeOpeningPrayers) {
            steps.add(RosaryStep(title = "Our Father", body = text(PrayerKey.PaterNoster), imageOverrideKey = "our_father"))
            for ((key, imageKey) in virtues) {
                steps.add(RosaryStep(title = "Hail Mary", subtitle = text(key), body = text(PrayerKey.AveMaria), imageOverrideKey = imageKey))
            }
            steps.add(RosaryStep(title = "Glory Be", body = text(PrayerKey.GloriaPatri), imageOverrideKey = "glory_be"))
        }

        val fruitLabel = text(PrayerKey.FructusMysteriiLabel)

        // A session spanning more than one group (15/20-mystery) needs the group name in each
        // decade's label so it's clear which set you're in as you move from one to the next.
        val showGroupName = groups.size > 1

        // Global decade counter (0-based), continuing across group boundaries in a 15/20-mystery
        // session — this is what the bead progress indicator uses to tell decades apart, so it
        // must NOT reset per group.
        var decadeIndex = 0

        for (group in groups) {
            val mysteries = MysteryCatalog.forGroup(group)

            for ((d, mystery) in mysteries.withIndex()) {
                val mysteryText = MysteryTranslations.get(lang, mystery.imageKey)
                val ordinalLabel = if (showGroupName) {
                    "${group.displayName} — ${ordinals[d]} Mystery"
                } else {
                    "${ordinals[d]} Mystery"
                }
                val decadeSubtitle = "$ordinalLabel — ${mysteryText.title}"
                val thisDecade = decadeIndex

                steps.add(
                    RosaryStep(
                        title = mysteryText.title, subtitle = ordinalLabel,
                        body = "${mysteryText.description}\n\n$fruitLabel: ${mysteryText.fruit}",
                        mystery = mystery, isScripture = true, decadeIndex = thisDecade,
                    ),
                )

                // "Our Father" gets its own dedicated image (Dürer's Praying Hands) rather than
                // staying anchored to the current decade's mystery image, same reasoning as the
                // Fatima Prayer step below.
                steps.add(
                    RosaryStep(
                        title = "Our Father", subtitle = decadeSubtitle, body = text(PrayerKey.PaterNoster),
                        decadeIndex = thisDecade, imageOverrideKey = "our_father",
                    ),
                )

                for (h in 1..10) {
                    steps.add(
                        RosaryStep(
                            title = "Hail Mary ($h of 10)", subtitle = decadeSubtitle, body = text(PrayerKey.AveMaria),
                            mystery = mystery, decadeIndex = thisDecade, hailMaryIndexInDecade = h,
                        ),
                    )
                }

                // Same reasoning as Our Father/Fatima Prayer above: a dedicated Trinity image
                // ("Glory be to the Father, and to the Son, and to the Holy Spirit...") rather
                // than the current decade's mystery image.
                steps.add(
                    RosaryStep(
                        title = "Glory Be", subtitle = decadeSubtitle, body = text(PrayerKey.GloriaPatri),
                        decadeIndex = thisDecade, imageOverrideKey = "glory_be",
                    ),
                )

                if (config.includeFatimaPrayer) {
                    // "O my Jesus..." — a portrait of Christ fits better than staying anchored to
                    // the current decade's mystery image, hence no mystery argument here.
                    steps.add(
                        RosaryStep(
                            title = "Fatima Prayer", subtitle = decadeSubtitle, body = text(PrayerKey.OratioFatimae),
                            decadeIndex = thisDecade, imageOverrideKey = "jesus_portrait",
                        ),
                    )
                }

                if (config.eternalRestForDeceased == EternalRestPlacement.AfterEachDecade) {
                    steps.add(
                        RosaryStep(
                            title = "For the Faithful Departed", subtitle = decadeSubtitle, body = text(PrayerKey.RequiemAeternam),
                            decadeIndex = thisDecade, imageOverrideKey = "eternal_rest",
                        ),
                    )
                }

                decadeIndex += 1
            }
        }

        val antiphon = resolveMarianAntiphon(config)
        if (antiphon != null) {
            val antiphonStep = buildAntiphonStep(antiphon, ::text)
            antiphonStep.isAntiphon = true
            antiphonStep.imageOverrideKey = "madonna_and_child"
            steps.add(antiphonStep)
        }

        if (config.includeStMichaelPrayer) {
            steps.add(RosaryStep(title = "St. Michael the Archangel", body = text(PrayerKey.SanctusMichael), imageOverrideKey = "st_michael"))
        }

        // Prayed last, immediately before the closing Sign of the Cross — after the antiphon
        // (and St. Michael prayer, if included), matching common communal-recitation practice.
        if (config.eternalRestForDeceased == EternalRestPlacement.AtEndOnly) {
            steps.add(RosaryStep(title = "For the Faithful Departed", body = text(PrayerKey.RequiemAeternam), imageOverrideKey = "eternal_rest"))
        }

        if (config.includeFinalSignOfCross) {
            steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))
        }

        return steps
    }

    private fun resolveMarianAntiphon(config: RosaryConfig): MarianAntiphonOption? = when (config.marianAntiphon) {
        MarianAntiphonOption.None -> null
        MarianAntiphonOption.Seasonal -> calendar.seasonalMarianAntiphonToday()
        else -> config.marianAntiphon
    }

    private enum class AntiphonStyle { Standard, Paschal, Standalone }

    private fun buildAntiphonStep(antiphon: MarianAntiphonOption, text: (PrayerKey) -> String): RosaryStep {
        val (titleKey, style) = when (antiphon) {
            MarianAntiphonOption.SalveRegina -> PrayerKey.SalveRegina to AntiphonStyle.Standard
            MarianAntiphonOption.AlmaRedemptorisMater -> PrayerKey.AlmaRedemptorisMater to AntiphonStyle.Standard
            MarianAntiphonOption.AveReginaCaelorum -> PrayerKey.AveReginaCaelorum to AntiphonStyle.Standard
            MarianAntiphonOption.ReginaCaeli -> PrayerKey.ReginaCaeli to AntiphonStyle.Paschal
            // Sub Tuum Praesidium is the Church's oldest known Marian prayer and is traditionally
            // prayed on its own, without the versicle/response/collect used after the four Office antiphons.
            MarianAntiphonOption.SubTuumPraesidium -> PrayerKey.SubTuumPraesidium to AntiphonStyle.Standalone
            MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> PrayerKey.SalveRegina to AntiphonStyle.Standard
        }

        val body = when (style) {
            AntiphonStyle.Standalone -> text(titleKey)
            AntiphonStyle.Standard ->
                "${text(titleKey)}\n\nV. ${text(PrayerKey.VersiculumStandard)}\nR. ${text(PrayerKey.ResponsiumStandard)}\n\n" +
                    text(PrayerKey.CollectaStandard)
            AntiphonStyle.Paschal ->
                "${text(titleKey)}\n\nV. ${text(PrayerKey.VersiculumPaschale)}\nR. ${text(PrayerKey.ResponsiumPaschale)}\n\n" +
                    text(PrayerKey.CollectaPaschale)
        }

        return RosaryStep(title = antiphonHeader(antiphon), body = body)
    }

    private fun antiphonHeader(antiphon: MarianAntiphonOption): String = when (antiphon) {
        MarianAntiphonOption.SalveRegina -> "Salve Regina"
        MarianAntiphonOption.AlmaRedemptorisMater -> "Alma Redemptoris Mater"
        MarianAntiphonOption.AveReginaCaelorum -> "Ave Regina Caelorum"
        MarianAntiphonOption.ReginaCaeli -> "Regina Caeli"
        MarianAntiphonOption.SubTuumPraesidium -> "Sub Tuum Praesidium"
        MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> "Marian Antiphon"
    }

    companion object {
        private val ordinals = listOf("1st", "2nd", "3rd", "4th", "5th")

        private val virtues: List<Pair<PrayerKey, String>> = listOf(
            PrayerKey.AveMariaProFide to "virtue_faith",
            PrayerKey.AveMariaProSpe to "virtue_hope",
            PrayerKey.AveMariaProCaritate to "virtue_charity",
        )
    }
}
