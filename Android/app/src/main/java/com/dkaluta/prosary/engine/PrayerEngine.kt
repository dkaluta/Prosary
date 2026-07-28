package com.dkaluta.prosary.engine

import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.prayerpack.CustomDevotionDefinition
import com.dkaluta.prosary.content.prayerpack.CustomDevotionStep
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.Mystery
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.models.RosaryStep

private val ordinals = listOf(
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
)

private val virtues: List<Pair<PrayerKey, String>> = listOf(
    PrayerKey.AveMariaProFide to "virtue_faith",
    PrayerKey.AveMariaProSpe to "virtue_hope",
    PrayerKey.AveMariaProCaritate to "virtue_charity",
)

/** The single production step-builder for every devotion. `buildSteps(prayer)` dispatches on
 * `Prayer.kind`: the Rosary keeps its own hardcoded, options/calendar-driven builder (it is the
 * one deeply configurable devotion); the Jesus Prayer has no steps at all (a repetition counter
 * — see JesusPrayerFlowScreen); and every other devotion is Custom — fully data-driven from its
 * .prosaryprayer bundle's devotion.json via [buildCustomDevotionSteps] (flat "steps" type) and
 * [buildCustomRosarySteps] (decade/bead-structured "rosary" type). [buildDecadeSteps] and
 * [buildMarianAntiphonStep] remain as the Rosary's own helpers; the generic rosary-type builder
 * mirrors their emission so bead tracks behave identically everywhere. Calendar injection is
 * preserved via this type's own constructor. */
class PrayerEngine(
    private val calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar(),
) {
    fun buildSteps(prayer: Prayer): List<RosaryStep> = when (prayer.kind) {
        PrayerKind.Rosary -> buildRosarySteps(prayer)
        // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
        // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
        // JesusPrayerFlowScreen, which never calls this engine at all.
        PrayerKind.JesusPrayer -> emptyList()
        PrayerKind.Custom -> {
            val bundleId = prayer.customDevotionId
            if (bundleId != null) {
                buildCustomDevotionSteps(bundleId, prayer.languageCode, prayer.variantId)
            } else {
                emptyList()
            }
        }
    }

    // MARK: Rosary

    /** Resolves which mystery group(s) a prayer's Rosary options point to, in the order they
     * should be prayed. */
    fun resolveMysteryGroups(prayer: Prayer): List<MysteryGroup> = when (prayer.rosary.mysterySelectionMode) {
        MysterySelectionMode.Specific, MysterySelectionMode.SingleMystery -> listOf(prayer.rosary.specificMysteryGroup)
        MysterySelectionMode.FifteenMystery -> listOf(MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        MysterySelectionMode.TwentyMystery ->
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        MysterySelectionMode.TodaysMysteries -> listOf(calendar.mysteryGroupToday())
    }

    private fun buildRosarySteps(prayer: Prayer): List<RosaryStep> {
        val options = prayer.rosary
        val lang = prayer.resolvedLanguageCode
        val groups = resolveMysteryGroups(prayer)
        val steps = mutableListOf<RosaryStep>()

        fun text(key: PrayerKey): String = PrayerTranslations.get(lang, key)

        steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))

        if (options.includeApostlesCreed) {
            steps.add(RosaryStep(title = "Apostles' Creed", body = text(PrayerKey.SymbolumApostolorum), imageOverrideKey = "crucifix"))
        }

        if (options.includeOpeningPrayers) {
            steps.add(RosaryStep(title = "Our Father", body = text(PrayerKey.PaterNoster), imageOverrideKey = "our_father"))
            for ((key, imageKey) in virtues) {
                steps.add(RosaryStep(title = "Hail Mary", subtitle = text(key), body = text(PrayerKey.AveMaria), imageOverrideKey = imageKey))
            }
            steps.add(RosaryStep(title = "Glory Be", body = text(PrayerKey.GloriaPatri), imageOverrideKey = "glory_be"))
        }

        val fruitLabel = text(PrayerKey.FructusMysteriiLabel)
        val showGroupName = groups.size > 1
        var decadeIndex = 0

        for (group in groups) {
            val mysteries = MysteryCatalog.forGroup(group)
            val indices = if (options.mysterySelectionMode == MysterySelectionMode.SingleMystery) {
                listOf(options.specificMysteryOrder - 1)
            } else {
                mysteries.indices.toList()
            }

            for (d in indices) {
                val mystery = mysteries[d]
                val mysteryText = MysteryTranslations.get(lang, mystery.imageKey)
                val ordinalLabel = if (showGroupName) "${group.displayName} — ${ordinals[d]} Mystery" else "${ordinals[d]} Mystery"
                val thisDecade = decadeIndex
                val decadeSubtitle = "$ordinalLabel — ${mysteryText.title}"

                if (options.presenterMode) {
                    steps.add(
                        RosaryStep(
                            title = mysteryText.title, subtitle = ordinalLabel,
                            body = "${mysteryText.description}\n\n$fruitLabel: ${mysteryText.fruit}",
                            mystery = mystery, isScripture = true, decadeIndex = thisDecade,
                        ),
                    )
                    steps.add(
                        RosaryStep(
                            title = "Our Father", subtitle = decadeSubtitle, body = text(PrayerKey.PaterNoster),
                            decadeIndex = thisDecade, imageOverrideKey = "our_father",
                        ),
                    )
                    steps.add(
                        RosaryStep(
                            title = "Hail Mary & Glory Be", subtitle = decadeSubtitle,
                            body = "${text(PrayerKey.AveMaria)}\n\n${text(PrayerKey.GloriaPatri)}",
                            mystery = mystery, decadeIndex = thisDecade, hailMaryIndexInDecade = 10,
                        ),
                    )
                } else {
                    steps.addAll(
                        buildDecadeSteps(
                            decadeIndex = thisDecade,
                            announcementTitle = mysteryText.title, ordinalLabel = ordinalLabel,
                            announcementBody = "${mysteryText.description}\n\n$fruitLabel: ${mysteryText.fruit}",
                            mystery = mystery, decadeImageKey = null, isScripture = true,
                            ourFatherImageKey = "our_father", hailMarysPerDecade = 10, languageCode = lang,
                        ),
                    )

                    steps.add(
                        RosaryStep(
                            title = "Glory Be", subtitle = decadeSubtitle, body = text(PrayerKey.GloriaPatri),
                            decadeIndex = thisDecade, imageOverrideKey = "glory_be",
                        ),
                    )
                }

                if (options.includeFatimaPrayer) {
                    steps.add(
                        RosaryStep(
                            title = "Fatima Prayer", subtitle = decadeSubtitle, body = text(PrayerKey.OratioFatimae),
                            decadeIndex = thisDecade, imageOverrideKey = "jesus_portrait",
                        ),
                    )
                }

                if (options.eternalRestForDeceased == EternalRestPlacement.AfterEachDecade) {
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

        val antiphon = resolveMarianAntiphon(options)
        if (antiphon != null) {
            steps.add(buildMarianAntiphonStep(antiphon, lang))
        }

        if (options.includeStMichaelPrayer) {
            steps.add(RosaryStep(title = "St. Michael the Archangel", body = text(PrayerKey.SanctusMichael), imageOverrideKey = "st_michael"))
        }

        if (options.eternalRestForDeceased == EternalRestPlacement.AtEndOnly) {
            steps.add(RosaryStep(title = "For the Faithful Departed", body = text(PrayerKey.RequiemAeternam), imageOverrideKey = "eternal_rest"))
        }

        if (options.includeFinalSignOfCross) {
            steps.add(RosaryStep(title = "Sign of the Cross", body = text(PrayerKey.SignumCrucis), imageOverrideKey = "crucifix"))
        }

        return steps
    }

    private fun resolveMarianAntiphon(options: RosaryOptions): MarianAntiphonOption? = when (options.marianAntiphon) {
        MarianAntiphonOption.None -> null
        MarianAntiphonOption.Seasonal -> calendar.seasonalMarianAntiphonToday()
        else -> options.marianAntiphon
    }

    // MARK: Shared decade-building helper (Rosary's inner loop, Franciscan Crown, Seven Sorrows)

    /** Builds one decade: an announcement step, an Our Father step, and [hailMarysPerDecade] Hail
     * Mary steps. [mystery]/[decadeImageKey] together control each step's illustration — pass a
     * real [Mystery] (Rosary) to let steps fall through to its own imageKey, or a null mystery
     * plus an explicit [decadeImageKey] (Franciscan Crown/Seven Sorrows, whose catalogs are plain
     * imageKey strings, not Mystery-typed). [ourFatherImageKey] is separate from
     * [decadeImageKey] because the Rosary's Our Father step always shows a fixed generic icon
     * ("our_father") between mystery-specific images, while Franciscan Crown/Seven Sorrows keep
     * showing that decade's own illustration straight through — a real, deliberate difference
     * between how these devotions render, not an inconsistency to paper over. */
    private fun buildDecadeSteps(
        decadeIndex: Int,
        announcementTitle: String, ordinalLabel: String, announcementBody: String,
        mystery: Mystery?, decadeImageKey: String?, isScripture: Boolean,
        ourFatherImageKey: String?, hailMarysPerDecade: Int, languageCode: String?,
    ): List<RosaryStep> {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val decadeSubtitle = "$ordinalLabel — $announcementTitle"
        val steps = mutableListOf(
            RosaryStep(
                title = announcementTitle, subtitle = ordinalLabel, body = announcementBody,
                mystery = mystery, isScripture = isScripture, decadeIndex = decadeIndex, imageOverrideKey = decadeImageKey,
            ),
            RosaryStep(
                title = "Our Father", subtitle = decadeSubtitle, body = text(PrayerKey.PaterNoster),
                decadeIndex = decadeIndex, imageOverrideKey = ourFatherImageKey,
            ),
        )

        for (h in 1..hailMarysPerDecade) {
            steps.add(
                RosaryStep(
                    title = "Hail Mary ($h of $hailMarysPerDecade)", subtitle = decadeSubtitle, body = text(PrayerKey.AveMaria),
                    mystery = mystery, decadeIndex = decadeIndex, hailMaryIndexInDecade = h, imageOverrideKey = decadeImageKey,
                ),
            )
        }

        return steps
    }

    // MARK: Marian antiphon (shared by the Rosary and generic rosary-type devotions)

    private enum class AntiphonStyle { Standard, Paschal, Standalone }

    private fun buildMarianAntiphonStep(antiphon: MarianAntiphonOption, languageCode: String?): RosaryStep {
        fun text(key: PrayerKey): String = PrayerTranslations.get(languageCode, key)

        val (titleKey, style) = when (antiphon) {
            MarianAntiphonOption.SalveRegina -> PrayerKey.SalveRegina to AntiphonStyle.Standard
            MarianAntiphonOption.AlmaRedemptorisMater -> PrayerKey.AlmaRedemptorisMater to AntiphonStyle.Standard
            MarianAntiphonOption.AveReginaCaelorum -> PrayerKey.AveReginaCaelorum to AntiphonStyle.Standard
            MarianAntiphonOption.ReginaCaeli -> PrayerKey.ReginaCaeli to AntiphonStyle.Paschal
            MarianAntiphonOption.SubTuumPraesidium -> PrayerKey.SubTuumPraesidium to AntiphonStyle.Standalone
            MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> PrayerKey.SalveRegina to AntiphonStyle.Standard
        }

        val body = when (style) {
            AntiphonStyle.Standalone -> text(titleKey)
            AntiphonStyle.Standard ->
                "${text(titleKey)}\n\n${text(PrayerKey.VersiculumStandard)}\n**${text(PrayerKey.ResponsiumStandard)}**\n\n" +
                    text(PrayerKey.CollectaStandard)
            AntiphonStyle.Paschal ->
                "${text(titleKey)}\n\n${text(PrayerKey.VersiculumPaschale)}\n**${text(PrayerKey.ResponsiumPaschale)}**\n\n" +
                    text(PrayerKey.CollectaPaschale)
        }

        val step = RosaryStep(title = marianAntiphonHeader(antiphon), body = body)
        step.isAntiphon = true
        step.imageOverrideKey = "madonna_and_child"
        return step
    }

    private fun marianAntiphonHeader(antiphon: MarianAntiphonOption): String = when (antiphon) {
        MarianAntiphonOption.SalveRegina -> "Salve Regina"
        MarianAntiphonOption.AlmaRedemptorisMater -> "Alma Redemptoris Mater"
        MarianAntiphonOption.AveReginaCaelorum -> "Ave Regina Caelorum"
        MarianAntiphonOption.ReginaCaeli -> "Regina Caeli"
        MarianAntiphonOption.SubTuumPraesidium -> "Sub Tuum Praesidium"
        MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> "Marian Antiphon"
    }

    // MARK: Custom (bundle-driven) devotions

    /** The only builder for every [PrayerKind.Custom] devotion — reads [bundleId]'s parsed
     * `devotion.json` and produces the full step sequence with no devotion-specific code. The
     * flat "steps" type covers Angelus/Stations/Trisagion-shaped devotions (including the
     * Angelus's Eastertide whole-sequence swap); the decade/bead-structured "rosary" type covers
     * Franciscan Crown/Seven Sorrows/Divine Mercy-shaped ones. */
    private fun buildCustomDevotionSteps(
        bundleId: String,
        languageCode: String?,
        variantId: String? = null,
    ): List<RosaryStep> {
        val definition = PrayerPackStore.definition(bundleId) ?: return emptyList()
        return when (definition.type) {
            CustomDevotionDefinition.DevotionType.Steps -> {
                val (baseSteps, eastertideSteps) = definition.resolvedSteps(variantId)
                val entries = (if (calendar.isEasterSeasonToday()) eastertideSteps else null)
                    ?: baseSteps
                entries.flatMap { expand(it, bundleId, languageCode) }
            }
            CustomDevotionDefinition.DevotionType.Rosary ->
                buildCustomRosarySteps(definition, bundleId, languageCode)
        }
    }

    /** Expands one `devotion.json` entry into its step(s): resolves the title (literal or
     * translated `titleKey`) and body, and unrolls `repeat` into "(h of n)"-suffixed copies —
     * deliberately without bead fields, matching the hardcoded devotions' closing Hail Marys. */
    private fun expand(entry: CustomDevotionStep, bundleId: String, languageCode: String?): List<RosaryStep> {
        if (entry.kind == CustomDevotionStep.SpecialKind.SeasonalMarianAntiphon) {
            return listOf(buildMarianAntiphonStep(calendar.seasonalMarianAntiphonToday(), languageCode))
        }
        val title = entry.titleKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }
            ?: entry.title.orEmpty()
        val body = entry.bodyKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }.orEmpty()

        val count = entry.repeatCount
        if (count == null || count <= 1) {
            return listOf(RosaryStep(title = title, subtitle = entry.subtitle, body = body, imageOverrideKey = entry.imageKey))
        }
        return (1..count).map { h ->
            RosaryStep(
                title = "$title ($h of $count)", subtitle = entry.subtitle, body = body,
                imageOverrideKey = entry.imageKey,
            )
        }
    }

    /** The decade/bead-structured generic builder ("rosary" type) — mirrors [buildDecadeSteps]'s
     * emission exactly (announcement → major → N minors, dense global `decadeIndex`,
     * `hailMaryIndexInDecade` on minors only, "ordinal — title" subtitles) so the bead track and
     * step chrome behave identically to the previously hardcoded decade devotions. */
    private fun buildCustomRosarySteps(
        definition: CustomDevotionDefinition,
        bundleId: String,
        languageCode: String?,
    ): List<RosaryStep> {
        val decades = definition.decades ?: return emptyList()
        fun resolve(key: String): String = PrayerPackStore.resolveBodyText(bundleId, languageCode, key)

        val steps = mutableListOf<RosaryStep>()
        for (entry in definition.opening.orEmpty()) {
            steps.addAll(expand(entry, bundleId, languageCode))
        }

        val fruitLabel = PrayerTranslations.get(languageCode, PrayerKey.FructusMysteriiLabel)
        val majorBody = resolve(decades.majorStep.bodyKey)
        val minorBody = resolve(decades.minorStep.bodyKey)
        val decadeCount = decades.entries?.size ?: decades.count ?: 0

        for (d in 0 until decadeCount) {
            val entry = decades.entries?.get(d)
            val imageKey = entry?.imageKey ?: decades.fixedImageKey
            val ordinalLabel = "${ordinals[d]} ${decades.ordinalNoun}"
            var decadeSubtitle = ordinalLabel

            if (decades.announceMystery && entry != null) {
                val mysteryText = MysteryTranslations.get(languageCode, entry.imageKey)
                var body = mysteryText.description
                if (mysteryText.fruit.isNotEmpty()) {
                    body += "\n\n$fruitLabel: ${mysteryText.fruit}"
                }
                steps.add(
                    RosaryStep(
                        title = mysteryText.title, subtitle = ordinalLabel, body = body,
                        isScripture = entry.isScripture ?: true, decadeIndex = d, imageOverrideKey = entry.imageKey,
                    ),
                )
                decadeSubtitle = "$ordinalLabel — ${mysteryText.title}"
            }

            steps.add(
                RosaryStep(
                    title = decades.majorStep.title, subtitle = decadeSubtitle, body = majorBody,
                    decadeIndex = d, imageOverrideKey = imageKey,
                ),
            )

            for (h in 1..decades.minorCount) {
                steps.add(
                    RosaryStep(
                        title = "${decades.minorStep.title} ($h of ${decades.minorCount})",
                        subtitle = decadeSubtitle, body = minorBody,
                        decadeIndex = d, hailMaryIndexInDecade = h, imageOverrideKey = imageKey,
                    ),
                )
            }
        }

        for (entry in definition.closing.orEmpty()) {
            steps.addAll(expand(entry, bundleId, languageCode))
        }
        return steps
    }
}
