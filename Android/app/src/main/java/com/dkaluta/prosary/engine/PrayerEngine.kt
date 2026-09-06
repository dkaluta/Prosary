package com.dkaluta.prosary.engine

import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.MysteryText
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.prayerpack.CustomDevotionDefinition
import com.dkaluta.prosary.content.prayerpack.CustomDevotionStep
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.Mystery
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryImageStyle
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.typography.HebrewDisplayText

private val ordinals = listOf(
    "1st", "2nd", "3rd", "4th", "5th", "6th", "7th",
    "8th", "9th", "10th", "11th", "12th", "13th", "14th",
)

/** The single production step-builder for every devotion. `buildSteps(prayer)` dispatches on
 * `Prayer.kind`: the Jesus Prayer has no steps at all (a repetition counter — see
 * JesusPrayerFlowScreen); everything else — the Rosary included — is data-driven from a
 * .prosaryprayer bundle's devotion.json via [buildCustomDevotionSteps] (flat "steps" type) and
 * [buildCustomRosarySteps] (decade/bead-structured "rosary" type). The Rosary's
 * option/calendar-driven pieces stay engine-side behind the bundle's
 * `decades.source: "mysteryGroups"` (see [buildMysteryGroupDecades]), with [RosaryOptions]
 * mapped onto the bundle's options.json values by [rosaryOptionValues] — no data migration.
 * The retired hardcoded builder's output was pinned byte-for-byte before deletion
 * (RosaryEngineTest's one-time parity sweep, kept in git history). Calendar injection is
 * preserved via this type's own constructor. */
class PrayerEngine(
    private val calendar: LiturgicalCalendarProviding = MockLiturgicalCalendar(),
) {
    fun buildSteps(prayer: Prayer): List<RosaryStep> {
        val steps = when (prayer.kind) {
            // The Rosary builds from the rosary bundle's devotion.json like every other devotion —
            // RosaryOptions stays the persisted shape (no data migration; the bespoke editor keeps
            // writing it) and is mapped onto the bundle's option values here.
            PrayerKind.Rosary -> buildCustomDevotionSteps(
                "rosary", prayer.resolvedLanguageCode,
                optionOverrides = rosaryOptionValues(prayer.rosary), rosaryOptions = prayer.rosary,
            )
            // The Jesus Prayer has no engine — every repetition prays the same fixed line, so a
            // single synthesized step plus a JesusPrayerProgress counter is the whole model; see
            // JesusPrayerFlowScreen, which never calls this engine at all.
            PrayerKind.JesusPrayer -> emptyList()
            PrayerKind.Custom -> {
                val bundleId = prayer.customDevotionId
                if (bundleId != null) {
                    buildCustomDevotionSteps(
                        bundleId,
                        PrayerPackStore.effectiveLanguage(bundleId, prayer.languageCode),
                        prayer.variantId, prayer.customOptions,
                        dayIndex = prayer.dayIndex ?: 0,
                    )
                } else {
                    emptyList()
                }
            }
        }
        // Titles and subtitles are display chrome, not the prayer itself. Preserve canonical
        // pointed Hebrew in bodies/acclamations/Scripture while presenting every heading in the
        // app's unpointed Hebrew style.
        return steps.map { step ->
            step.copy(
                title = HebrewDisplayText.unpoint(step.title),
                subtitle = step.subtitle?.let(HebrewDisplayText::unpoint),
            )
        }
    }

    // MARK: Rosary

    /** Resolves which mystery group(s) a prayer's Rosary options point to, in the order they
     * should be prayed. */
    fun resolveMysteryGroups(prayer: Prayer): List<MysteryGroup> = resolveMysteryGroups(prayer.rosary)

    fun resolveMysteryGroups(rosary: RosaryOptions): List<MysteryGroup> = when (rosary.mysterySelectionMode) {
        MysterySelectionMode.Specific, MysterySelectionMode.SingleMystery -> listOf(rosary.specificMysteryGroup)
        MysterySelectionMode.FifteenMystery -> listOf(MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        MysterySelectionMode.TwentyMystery ->
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious)
        MysterySelectionMode.TodaysMysteries -> listOf(calendar.mysteryGroupToday())
    }

    /** Maps the persisted [RosaryOptions] onto the rosary bundle's options.json values — the
     * no-data-migration seam: favorites keep their typed columns and bespoke editor, while the
     * engine speaks the bundle's generic option encoding. */
    fun rosaryOptionValues(rosary: RosaryOptions): Map<String, String> {
        val savedAramaicForm = if (
            rosary.aramaicSignOfCrossForm == AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B
        ) AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B else AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A
        val effectiveAramaicForm = if (AppSettings.usesSystemWideAramaicSignOfCrossForm) {
            AppSettings.aramaicSignOfCrossForm
        } else {
            savedAramaicForm
        }
        return mapOf(
        "apostlesCreed" to rosary.includeApostlesCreed.toString(),
        "aramaicSignOfCrossForm" to effectiveAramaicForm,
        "openingPrayers" to rosary.includeOpeningPrayers.toString(),
        "openingFatimaPrayer" to rosary.includeOpeningFatimaPrayer.toString(),
        "presenterMode" to rosary.presenterMode.toString(),
        "fatimaPrayer" to rosary.includeFatimaPrayer.toString(),
        "eternalRest" to rosary.eternalRestForDeceased.name.replaceFirstChar { it.lowercaseChar() },
        "antiphon" to rosary.marianAntiphon.name.replaceFirstChar { it.lowercaseChar() },
        "closingPopeIntention" to rosary.effectiveClosingPopeIntention.toString(),
        "closingBishopIntention" to rosary.effectiveClosingBishopIntention.toString(),
        "closingDepartedIntention" to rosary.effectiveClosingDepartedIntention.toString(),
        "closingIntentions" to rosary.includeClosingIntentions.toString(),
        "stMichael" to rosary.includeStMichaelPrayer.toString(),
        "finalSignOfCross" to rosary.includeFinalSignOfCross.toString(),
        "imageStyle" to rosary.mysteryImageStyle.name.replaceFirstChar { it.lowercaseChar() },
        )
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

        val step = RosaryStep(title = text(marianAntiphonHeaderKey(antiphon)), body = body)
        step.isAntiphon = true
        step.imageOverrideKey = "madonna_and_child"
        return step
    }

    /** The heading names the antiphon in the language being prayed, not in Latin — the same
     * choice the step's body already makes. */
    private fun marianAntiphonHeaderKey(antiphon: MarianAntiphonOption): PrayerKey = when (antiphon) {
        MarianAntiphonOption.SalveRegina -> PrayerKey.SalveReginaTitle
        MarianAntiphonOption.AlmaRedemptorisMater -> PrayerKey.AlmaRedemptorisMaterTitle
        MarianAntiphonOption.AveReginaCaelorum -> PrayerKey.AveReginaCaelorumTitle
        MarianAntiphonOption.ReginaCaeli -> PrayerKey.ReginaCaeliTitle
        MarianAntiphonOption.SubTuumPraesidium -> PrayerKey.SubTuumPraesidiumTitle
        // Unreachable: both resolve to a concrete antiphon before this is called.
        MarianAntiphonOption.None, MarianAntiphonOption.Seasonal -> PrayerKey.SalveReginaTitle
    }

    /** A decade's ordinal in the language being prayed: "1st Mystery" in English, "רז 1" in
     * Hebrew. English is the only one of the six languages that inflects the number itself,
     * so it alone takes an ordinal word; the rest read the plain digit. */
    private fun decadeOrdinal(
        index: Int,
        decades: CustomDevotionDefinition.Decades,
        bundleId: String,
        languageCode: String?,
    ): String {
        val noun = decades.ordinalNounKey?.let {
            PrayerPackStore.resolveBodyText(bundleId, languageCode, it)
        } ?: decades.ordinalNoun.orEmpty()
        val isEnglish = (languageCode?.let { LanguageCatalog.baseLanguage(it) ?: it }) == "en"
        val number = if (isEnglish && index < ordinals.size) ordinals[index] else "${index + 1}"
        return PrayerTranslations.get(languageCode, PrayerKey.DecadeOrdinalFormat)
            .replace("{n}", number)
            .replace("{noun}", noun)
    }

    /** "(3 of 10)" for a repeated step, connector translated into the prayer's own language. */
    private fun counter(index: Int, total: Int, languageCode: String?): String {
        val connector = PrayerTranslations.get(languageCode, PrayerKey.RepetitionCounterConnector)
        return "($index $connector $total)"
    }

    /** Primary and alternate-script readings keep their independently resolved fruit text,
     * with a label in the matching script. The alternate is emitted only for the description chosen by
     * [MysteryTranslations], never synthesized from another fallback source. */
    private fun mysteryAnnouncementBodies(
        mysteryText: MysteryText,
        fruitLabel: String,
        alternateFruitLabel: String,
    ): Pair<String, String?> {
        fun appendFruit(description: String, label: String): String = if (mysteryText.fruit.isEmpty()) {
            description
        } else {
            "$description\n\n$label: ${mysteryText.fruit}"
        }
        return appendFruit(mysteryText.description, fruitLabel) to
            mysteryText.transliteratedDescription?.let { appendFruit(it, alternateFruitLabel) }
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
        optionOverrides: Map<String, String> = emptyMap(),
        rosaryOptions: RosaryOptions? = null,
        dayIndex: Int = 0,
    ): List<RosaryStep> {
        val definition = PrayerPackStore.definition(bundleId) ?: return emptyList()
        // No explicit variant on the favorite → the form the prayer language declares as its
        // own (the Mission's rite opens the Trisagion Syriac), else the first.
        @Suppress("NAME_SHADOWING")
        val variantId = definition.effectiveVariantId(variantId, languageCode)
        // Effective option values: the bundle's declared defaults overlaid with the favorite's
        // stored choices. Overrides for keys the bundle no longer declares are ignored, so a
        // stale favorite can't gate on options that stopped existing.
        val optionValues = PrayerPackStore.options(bundleId).associate { option ->
            option.key to (optionOverrides[option.key] ?: option.defaultValue)
        } + mapOf(
            // Calendar facts an entry may gate on beside the user's own choices — the Alleluia
            // that leaves the invitatory during Lent is the first of them. Added after the
            // declared options and reserved by the validator, so a bundle cannot declare an
            // option of the same name and shadow the season.
            "isLent" to calendar.isLentToday().toString(),
            "isEasterSeason" to calendar.isEasterSeasonToday().toString(),
        )
        return when (definition.type) {
            CustomDevotionDefinition.DevotionType.Steps -> {
                val (baseSteps, eastertideSteps) = definition.resolvedSteps(variantId)
                val entries = (if (calendar.isEasterSeasonToday()) eastertideSteps else null)
                    ?: baseSteps
                entries.flatMap { expand(it, bundleId, languageCode, optionValues) }
            }
            CustomDevotionDefinition.DevotionType.Rosary ->
                buildCustomRosarySteps(
                    definition, bundleId, languageCode, optionValues, rosaryOptions, variantId,
                )
            CustomDevotionDefinition.DevotionType.Days -> {
                // Multi-day devotions: shared opening + the day's own steps + shared closing.
                // dayIndex is clamped, so a finished novena keeps praying its last day; the
                // per-favorite progress that will drive it is a planned follow-up (see
                // ARCHITECTURE.markdown) — until it lands, sessions pray day 1.
                val days = definition.days.orEmpty()
                if (days.isEmpty()) return emptyList()
                val day = days[dayIndex.coerceIn(0, days.size - 1)]
                (definition.opening.orEmpty() + day.steps + definition.closing.orEmpty())
                    .flatMap { expand(it, bundleId, languageCode, optionValues) }
            }
        }
    }

    companion object {
        /** Evaluates an entry's `"if"` gate against the effective option values: `"key"` —
         * toggle on; `"!key"` — toggle off; `"key=caseId"` — choice equals. The validator
         * guarantees every authored expression references a declared option, so a missing key
         * (impossible for shipped bundles) simply reads as "not on". */
        /** `"key"` — toggle on; `"!key"` — toggle off; `"key=caseId"` — choice equals; and
         * `"a & b"` — every term must hold, which is how a step gates on a choice *and* the
         * season ("invitatory & !isLent"). */
        fun evaluateCondition(expression: String, values: Map<String, String>): Boolean =
            expression.split('&').all { evaluateTerm(it.trim(), values) }

        private fun evaluateTerm(term: String, values: Map<String, String>): Boolean {
            val equals = term.indexOf('=')
            if (equals >= 0) {
                return values[term.substring(0, equals)] == term.substring(equals + 1)
            }
            if (term.startsWith("!")) {
                return values[term.substring(1)] != "true"
            }
            return values[term] == "true"
        }
    }

    /** Expands one `devotion.json` entry into its step(s): resolves the title (literal or
     * translated `titleKey`) and body, and unrolls `repeat` into "(h of n)"-suffixed copies —
     * deliberately without bead fields, matching the hardcoded devotions' closing Hail Marys. */
    private fun expand(
        entry: CustomDevotionStep,
        bundleId: String,
        languageCode: String?,
        optionValues: Map<String, String> = emptyMap(),
    ): List<RosaryStep> {
        val condition = entry.condition
        if (condition != null && !evaluateCondition(condition, optionValues)) {
            return emptyList()
        }
        if (entry.kind == CustomDevotionStep.SpecialKind.SeasonalMarianAntiphon) {
            return listOf(buildMarianAntiphonStep(calendar.seasonalMarianAntiphonToday(), languageCode))
        }
        if (entry.kind == CustomDevotionStep.SpecialKind.MarianAntiphon) {
            // Option-selected antiphon (the Rosary): the named choice's value is an antiphon id,
            // "seasonal" (calendar-resolved) or "none" (no step).
            val value = optionValues[entry.optionKey] ?: "seasonal"
            val chosen = runCatching {
                MarianAntiphonOption.valueOf(value.replaceFirstChar { it.uppercaseChar() })
            }.getOrNull() ?: return emptyList()
            if (chosen == MarianAntiphonOption.None) return emptyList()
            val antiphon = if (chosen == MarianAntiphonOption.Seasonal) {
                calendar.seasonalMarianAntiphonToday()
            } else {
                chosen
            }
            return listOf(buildMarianAntiphonStep(antiphon, languageCode))
        }
        val title = entry.titleKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }
            ?: entry.title.orEmpty()
        val subtitle = entry.subtitleKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }
            ?: entry.subtitle
        val body = entry.bodyKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }.orEmpty()

        val isScripture = languageCode?.let { entry.isScriptureByLanguage?.get(it) }
            ?: entry.isScripture ?: false
        val acclamation = entry.acclamationKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }
        val transliteratedBody = entry.bodyKey?.let { PrayerPackStore.transliteration(bundleId, languageCode, it) }
        val count = entry.repeatCount
        val singleTitle = if (entry.counterIndex != null && entry.counterTotal != null) {
            "$title ${counter(entry.counterIndex, entry.counterTotal, languageCode)}"
        } else {
            title
        }
        if (count == null || count <= 1) {
            return listOf(
                RosaryStep(
                    title = singleTitle, subtitle = subtitle, body = body, acclamation = acclamation,
                    isScripture = isScripture, transliteratedBody = transliteratedBody,
                    imageOverrideKey = entry.imageKey,
                ),
            )
        }
        return (1..count).map { h ->
            RosaryStep(
                title = "$title ${counter(h, count, languageCode)}", subtitle = subtitle, body = body, acclamation = acclamation,
                isScripture = isScripture, transliteratedBody = transliteratedBody,
                imageOverrideKey = entry.imageKey,
            )
        }
    }

    /** The decade/bead-structured generic builder ("rosary" type) — announcement → major → N
     * minors (dense global `decadeIndex`, `hailMaryIndexInDecade` on minors only,
     * "ordinal — title" subtitles), matching the retired hardcoded decade devotions' emission
     * exactly so the bead track and step chrome behave identically everywhere. */
    private fun buildCustomRosarySteps(
        definition: CustomDevotionDefinition,
        bundleId: String,
        languageCode: String?,
        optionValues: Map<String, String> = emptyMap(),
        rosaryOptions: RosaryOptions? = null,
        variantId: String? = null,
    ): List<RosaryStep> {
        val form = definition.resolvedRosary(variantId)
        val decades = form.decades ?: return emptyList()
        fun resolve(key: String): String = PrayerPackStore.resolveBodyText(bundleId, languageCode, key)
        fun fixedTitle(step: CustomDevotionDefinition.Decades.FixedStep): String =
            step.titleKey?.let { resolve(it) } ?: step.title.orEmpty()

        val steps = mutableListOf<RosaryStep>()
        for (entry in form.opening) {
            steps.addAll(expand(entry, bundleId, languageCode, optionValues))
        }

        if (decades.source == "mysteryGroups") {
            steps.addAll(
                buildMysteryGroupDecades(
                    decades, bundleId, languageCode, optionValues, rosaryOptions ?: RosaryOptions(),
                ),
            )
        } else {
            val fruitLabel = PrayerTranslations.get(languageCode, PrayerKey.FructusMysteriiLabel)
            val alternateFruitLabel = PrayerPackStore.transliteration(bundleId, languageCode, "fructusMysteriiLabel") ?: fruitLabel
            val majorBody = resolve(decades.majorStep.bodyKey)
            val minorBody = resolve(decades.minorStep.bodyKey)
            val majorTransliteration = PrayerPackStore.transliteration(bundleId, languageCode, decades.majorStep.bodyKey)
            val minorTransliteration = PrayerPackStore.transliteration(bundleId, languageCode, decades.minorStep.bodyKey)
            val decadeCount = decades.entries?.size ?: decades.count ?: 0

            for (d in 0 until decadeCount) {
                val entry = decades.entries?.get(d)
                val imageKey = entry?.imageKey ?: decades.fixedImageKey
                val ordinalLabel = decadeOrdinal(d, decades, bundleId, languageCode)
                var decadeSubtitle = ordinalLabel

                // Said before the sorrow is named, not after its beads — see the format's
                // decades.preAnnouncement. Carries the decade's subtitle so the chrome reads as
                // part of that decade, but no decadeIndex: it is not a bead.
                for (pre in decades.preAnnouncement.orEmpty()) {
                    for (step in expand(pre, bundleId, languageCode, optionValues)) {
                        steps.add(step.copy(subtitle = step.subtitle ?: decadeSubtitle))
                    }
                }

                if (decades.announceMystery && entry != null) {
                    val mysteryText = MysteryTranslations.get(languageCode, entry.imageKey)
                    val (body, transliteratedBody) = mysteryAnnouncementBodies(mysteryText, fruitLabel, alternateFruitLabel)
                    steps.add(
                        RosaryStep(
                            title = mysteryText.title, subtitle = ordinalLabel, body = body,
                            transliteratedBody = transliteratedBody,
                            isScripture = entry.isScripture ?: true, decadeIndex = d,
                            imageOverrideKey = entry.imageKey,
                        ),
                    )
                    decadeSubtitle = "$ordinalLabel — ${mysteryText.title}"
                }

                steps.add(
                    RosaryStep(
                        title = fixedTitle(decades.majorStep), subtitle = decadeSubtitle, body = majorBody,
                        transliteratedBody = majorTransliteration,
                        decadeIndex = d, imageOverrideKey = decades.majorStep.imageKey ?: imageKey,
                    ),
                )

                for (h in 1..decades.minorCount) {
                    steps.add(
                        RosaryStep(
                            title = "${fixedTitle(decades.minorStep)} ${counter(h, decades.minorCount, languageCode)}",
                            subtitle = decadeSubtitle, body = minorBody,
                            transliteratedBody = minorTransliteration,
                            decadeIndex = d, hailMaryIndexInDecade = h, imageOverrideKey = imageKey,
                        ),
                    )
                }

                steps.addAll(postMinorSteps(decades, bundleId, languageCode, optionValues, decadeSubtitle, d))
            }
        }

        for (entry in form.closing) {
            steps.addAll(expand(entry, bundleId, languageCode, optionValues))
        }
        return steps
    }

    /** The Rosary's decade section — driven by the bundle's decades block but cataloged by the
     * mystery-group machinery (`source: "mysteryGroups"`: selection mode + liturgical calendar)
     * instead of bundle entries. Reproduces the retired hardcoded builder byte-for-byte: real
     * [Mystery] values on announcement/minor steps (no image overrides), group-labelled ordinals
     * when multiple groups are prayed, the single-mystery mode's true ordinal, and presenter
     * mode's combined minors step with `hailMaryIndexInDecade = minorCount` for the bead
     * track. */
    private fun buildMysteryGroupDecades(
        decades: CustomDevotionDefinition.Decades,
        bundleId: String,
        languageCode: String?,
        optionValues: Map<String, String>,
        rosary: RosaryOptions,
    ): List<RosaryStep> {
        fun resolve(key: String): String = PrayerPackStore.resolveBodyText(bundleId, languageCode, key)
        fun fixedTitle(step: CustomDevotionDefinition.Decades.FixedStep): String =
            step.titleKey?.let { resolve(it) } ?: step.title.orEmpty()

        // The alternate-artwork seam: an eastern-style favorite stamps every Mystery-carrying step
        // with the parallel "eastern_" image key, leaving Mystery.imageKey (identity + translation
        // lookup) untouched.
        fun variantKey(mystery: Mystery): String? =
            if (rosary.mysteryImageStyle == MysteryImageStyle.Eastern) "eastern_${mystery.imageKey}" else null

        val groups = resolveMysteryGroups(rosary)
        val fruitLabel = PrayerTranslations.get(languageCode, PrayerKey.FructusMysteriiLabel)
        val alternateFruitLabel = PrayerPackStore.transliteration(bundleId, languageCode, "fructusMysteriiLabel") ?: fruitLabel
        val majorBody = resolve(decades.majorStep.bodyKey)
        val minorBody = resolve(decades.minorStep.bodyKey)
        val majorTransliteration = PrayerPackStore.transliteration(bundleId, languageCode, decades.majorStep.bodyKey)
        val minorTransliteration = PrayerPackStore.transliteration(bundleId, languageCode, decades.minorStep.bodyKey)
        val presenterOn = optionValues["presenterMode"] == "true"
        val showGroupName = groups.size > 1

        val steps = mutableListOf<RosaryStep>()
        var decadeIndex = 0
        for (group in groups) {
            val mysteries = MysteryCatalog.forGroup(group)
            val indices = if (rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery) {
                listOf(rosary.specificMysteryOrder - 1)
            } else {
                mysteries.indices.toList()
            }

            for (d in indices) {
                val mystery = mysteries[d]
                val mysteryText = MysteryTranslations.get(languageCode, mystery.imageKey)
                val ordinal = decadeOrdinal(d, decades, bundleId, languageCode)
                // The group prefix is still English — MysteryGroup has no per-prayer-language
                // name yet.
                val ordinalLabel = if (showGroupName) "${group.displayName} — $ordinal" else ordinal
                val decadeSubtitle = "$ordinalLabel — ${mysteryText.title}"
                val presenter = decades.presenter
                val (announcementBody, transliteratedAnnouncementBody) =
                    mysteryAnnouncementBodies(mysteryText, fruitLabel, alternateFruitLabel)

                steps.add(
                    RosaryStep(
                        title = mysteryText.title, subtitle = ordinalLabel,
                        body = announcementBody,
                        transliteratedBody = transliteratedAnnouncementBody,
                        mystery = mystery, isScripture = true, decadeIndex = decadeIndex,
                        imageVariantKey = variantKey(mystery),
                    ),
                )
                steps.add(
                    RosaryStep(
                        title = fixedTitle(decades.majorStep), subtitle = decadeSubtitle, body = majorBody,
                        transliteratedBody = majorTransliteration,
                        decadeIndex = decadeIndex, imageOverrideKey = decades.majorStep.imageKey,
                    ),
                )

                if (presenterOn && presenter != null) {
                    val transliterations = presenter.bodyKeys.map {
                        PrayerPackStore.transliteration(bundleId, languageCode, it)
                    }
                    steps.add(
                        RosaryStep(
                            title = presenter.combinedTitleKey?.let { resolve(it) } ?: presenter.combinedTitle.orEmpty(),
                            subtitle = decadeSubtitle,
                            body = presenter.bodyKeys.joinToString("\n\n") { resolve(it) },
                            transliteratedBody = transliterations.takeIf { it.all { text -> text != null } }
                                ?.filterNotNull()?.joinToString("\n\n"),
                            mystery = mystery, decadeIndex = decadeIndex, hailMaryIndexInDecade = decades.minorCount,
                            imageVariantKey = variantKey(mystery),
                        ),
                    )
                } else {
                    for (h in 1..decades.minorCount) {
                        steps.add(
                            RosaryStep(
                                title = "${fixedTitle(decades.minorStep)} ${counter(h, decades.minorCount, languageCode)}",
                                subtitle = decadeSubtitle, body = minorBody,
                                transliteratedBody = minorTransliteration,
                                mystery = mystery, decadeIndex = decadeIndex, hailMaryIndexInDecade = h,
                                imageVariantKey = variantKey(mystery),
                            ),
                        )
                    }
                }

                steps.addAll(postMinorSteps(decades, bundleId, languageCode, optionValues, decadeSubtitle, decadeIndex))
                decadeIndex += 1
            }
        }
        return steps
    }

    /** Expands the decades' `postMinor` entries for one decade — the same option gating as
     * [expand], but every emitted step carries the decade's subtitle and index (the Rosary's
     * per-decade Glory Be / Fatima Prayer / eternal rest). */
    private fun postMinorSteps(
        decades: CustomDevotionDefinition.Decades,
        bundleId: String,
        languageCode: String?,
        optionValues: Map<String, String>,
        decadeSubtitle: String,
        decadeIndex: Int,
    ): List<RosaryStep> = decades.postMinor.orEmpty().mapNotNull { entry ->
        val condition = entry.condition
        if (condition != null && !evaluateCondition(condition, optionValues)) {
            return@mapNotNull null
        }
        val title = entry.titleKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }
            ?: entry.title.orEmpty()
        val body = entry.bodyKey?.let { PrayerPackStore.resolveBodyText(bundleId, languageCode, it) }.orEmpty()
        RosaryStep(
            title = title, subtitle = decadeSubtitle, body = body,
            transliteratedBody = entry.bodyKey?.let { PrayerPackStore.transliteration(bundleId, languageCode, it) },
            decadeIndex = decadeIndex, imageOverrideKey = entry.imageKey,
        )
    }
}
