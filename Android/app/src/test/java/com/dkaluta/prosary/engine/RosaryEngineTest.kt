package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysteryImageStyle
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.io.File
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

/** Tests that [PrayerEngine] builds the expected step sequences for a range of
 * [RosaryOptions] configurations — mirrors iOS's RosaryEngineTests. */
class RosaryEngineTest {
    @Test
    fun aramaicCountersFollowTheDisplayedScript() {
        val opening = engine().buildSteps(prayer(language = "arc")).filter { it.imageOverrideKey?.startsWith("virtue_") == true }
        assertEquals(3, opening.size)
        assertTrue(opening[0].title.endsWith("(1 מן 3)"))
        assertTrue(PrayerTranslations.flowTitle(opening[0].title, "arc", true).endsWith("(1 ܡܶܢ 3)"))
        assertEquals("1 מֶן 75", PrayerTranslations.aramaicProgress(1, 75, "arc", false))
        assertEquals("1 ܡܶܢ 75", PrayerTranslations.aramaicProgress(1, 75, "arc", true))
        assertEquals(null, PrayerTranslations.aramaicProgress(1, 75, "en", true))
    }

    @Test
    fun aramaicScriptPreferenceFindsTheRequestedWritingSystem() {
        for (script in listOf("Hebr", "Syrc")) {
            assertEquals(script == "Syrc", PrayerTranslations.initialTransliteration("arc", "שלם", "ܫܠܡ", script))
            assertEquals(script == "Hebr", PrayerTranslations.initialTransliteration("arc", "ܫܠܡ", "שלם", script))
        }
        assertEquals(false, PrayerTranslations.initialTransliteration("arc", "שלם", null, "Syrc"))
        assertEquals(null, PrayerTranslations.initialTransliteration("he", "שלום", "Shalom", "Syrc"))
        val saved = AppSettings.aramaicDefaultScript
        try {
            AppSettings.setAramaicDefaultScript("Syrc")
            assertEquals("Syrc", AppSettings.aramaicDefaultScript)
            AppSettings.setAramaicDefaultScript("invalid")
            assertEquals("Hebr", AppSettings.aramaicDefaultScript)
        } finally { AppSettings.setAramaicDefaultScript(saved) }
    }

    companion object {
        @BeforeClass
        @JvmStatic
        fun loadPacks() {
            // The Rosary now builds from the rosary bundle's devotion.json, so the packs must
            // be loaded exactly as CustomDevotionEngineTest does.
            PrayerPackStore.initialize { packName ->
                val file = File("src/main/assets/$packName.prosaryprayer")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    private class FixedCalendar(private val group: MysteryGroup) : LiturgicalCalendarProviding {
        override fun mysteryGroup(date: Date) = group
        override fun seasonColor(date: Date) = Color.Transparent
        override fun seasonalMarianAntiphon(date: Date) = MarianAntiphonOption.SalveRegina
        override fun isEasterSeason(date: Date) = false
        override fun isLent(date: Date) = false
    }

    private fun engine(group: MysteryGroup = MysteryGroup.Joyful) = PrayerEngine(calendar = FixedCalendar(group))

    private fun prayer(
        group: MysteryGroup = MysteryGroup.Joyful,
        mode: MysterySelectionMode = MysterySelectionMode.Specific,
        order: Int = 1,
        includeCreed: Boolean = true,
        includeOpening: Boolean = true,
        includeOpeningFatima: Boolean = false,
        includeFatima: Boolean = true,
        eternalRest: EternalRestPlacement = EternalRestPlacement.None,
        antiphon: MarianAntiphonOption = MarianAntiphonOption.SalveRegina,
        closingIntentions: Boolean = false,
        includeMichael: Boolean = false,
        includeFinalCross: Boolean = true,
        presenterMode: Boolean = false,
        imageStyle: MysteryImageStyle = MysteryImageStyle.Classic,
        language: String = LanguageCatalog.defaultSentinel,
        aramaicSignOfCrossForm: String = AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A,
    ) = Prayer(
        languageCode = language,
        rosary = RosaryOptions(
            mysterySelectionMode = mode,
            specificMysteryGroup = group,
            specificMysteryOrder = order,
            includeApostlesCreed = includeCreed,
            includeOpeningPrayers = includeOpening,
            includeOpeningFatimaPrayer = includeOpeningFatima,
            includeFatimaPrayer = includeFatima,
            eternalRestForDeceased = eternalRest,
            marianAntiphon = antiphon,
            includeClosingIntentions = closingIntentions,
            includeStMichaelPrayer = includeMichael,
            includeFinalSignOfCross = includeFinalCross,
            presenterMode = presenterMode,
            mysteryImageStyle = imageStyle,
            aramaicSignOfCrossForm = aramaicSignOfCrossForm,
        ),
    )

    // MARK: - Step count

    @Test
    fun aramaicMainPrayerHeadingsUseTheSourcedAramaicTitles() {
        val steps = engine().buildSteps(prayer(language = "arc"))
        for (bodyKey in listOf("signumCrucis", "symbolumApostolorum", "paterNoster", "aveMaria", "gloriaPatri")) {
            val body = PrayerPackStore.resolveBodyText("rosary", "arc", bodyKey)
            val expected = com.dkaluta.prosary.typography.HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText("rosary", "arc", "${bodyKey}Title"))
            val step = steps.firstOrNull { it.body == body }
            assertNotNull(bodyKey, step)
            assertTrue("$bodyKey heading should be sourced Aramaic", step!!.title.startsWith(expected))
            assertFalse(expected.any { it in 'A'..'Z' || it in 'a'..'z' })
        }
    }

    @Test
    fun aramaicReadingAidsSurviveEveryDecadeAndPresenterMode() {
        val steps = engine().buildSteps(prayer(language = "arc"))
        for ((key, expectedCount) in listOf("paterNoster" to 5, "aveMaria" to 50, "gloriaPatri" to 5)) {
            val body = PrayerPackStore.resolveBodyText("rosary", "arc", key)
            val readingAid = PrayerPackStore.transliteration("rosary", "arc", key)
            assertNotNull(key, readingAid)
            val beads = steps.filter { it.decadeIndex != null && it.body == body }
            assertEquals(key, expectedCount, beads.size)
            assertTrue(key, beads.all { it.transliteratedBody == readingAid })
        }
        val combined = engine().buildSteps(prayer(presenterMode = true, language = "arc"))
            .filter { it.hailMaryIndexInDecade != null }
        val readingAid = listOf("aveMaria", "gloriaPatri").joinToString("\n\n") {
            requireNotNull(PrayerPackStore.transliteration("rosary", "arc", it))
        }
        assertEquals(5, combined.size)
        assertTrue(combined.all { it.transliteratedBody == readingAid })
    }

    @Test
    fun fiveDecadeStepCountDefaultConfig() {
        val steps = engine().buildSteps(prayer())
        // 1 sign of cross + 1 creed + 1 OurFather + 3 HailMarys + 1 GloryBe = 7 opening
        // Per decade: 1 mystery + 1 OurFather + 10 HailMarys + 1 GloryBe + 1 Fatima = 14
        // 5 decades = 70
        // 1 antiphon + 1 closing cross = 2
        // Total = 7 + 70 + 2 = 79
        assertEquals(79, steps.size)
    }

    @Test
    fun noOpeningPrayersReducesCount() {
        val withOpening = engine().buildSteps(prayer(includeOpening = true)).size
        val withoutOpening = engine().buildSteps(prayer(includeOpening = false)).size
        assertEquals(withOpening - 5, withoutOpening)
    }

    @Test
    fun noApostlesCreedReducesCount() {
        val with = engine().buildSteps(prayer(includeCreed = true)).size
        val without = engine().buildSteps(prayer(includeCreed = false)).size
        assertEquals(with - 1, without)
    }

    @Test
    fun noFatimaPrayerReducesCountByFiveDecades() {
        val with = engine().buildSteps(prayer(includeFatima = true)).size
        val without = engine().buildSteps(prayer(includeFatima = false)).size
        assertEquals(with - 5, without)
    }

    @Test
    fun openingFatimaPrayerFollowsTheFaithHopeAndCharityPrayers() {
        val steps = engine().buildSteps(
            prayer(includeOpeningFatima = true, language = "en"),
        )
        val firstMystery = steps.indexOfFirst { it.decadeIndex != null }

        assertTrue(firstMystery > 1)
        assertEquals("Fatima Prayer", steps[firstMystery - 2].title)
        assertEquals("Glory Be", steps[firstMystery - 1].title)
        assertEquals(null, steps[firstMystery - 2].decadeIndex)
        assertEquals(6, steps.count { it.title == "Fatima Prayer" })
    }

    @Test
    fun openingFatimaPrayerRequiresTheOpeningPrayers() {
        val steps = engine().buildSteps(
            prayer(includeOpening = false, includeOpeningFatima = true, language = "en"),
        )
        assertEquals(5, steps.count { it.title == "Fatima Prayer" })
    }

    @Test
    fun faithHopeAndCharityHailMaryTitlesCarryTheirLocalizedThreePartCount() {
        fun openingTitles(language: String) = engine().buildSteps(prayer(language = language))
            .filter { it.imageKey in setOf("virtue_faith", "virtue_hope", "virtue_charity") }
            .map { it.title }

        assertEquals(
            listOf("Hail Mary (1 of 3)", "Hail Mary (2 of 3)", "Hail Mary (3 of 3)"),
            openingTitles("en"),
        )
        assertEquals(
            listOf("שמחי מרים (1 מתוך 3)", "שמחי מרים (2 מתוך 3)", "שמחי מרים (3 מתוך 3)"),
            openingTitles("he"),
        )
    }

    @Test
    fun noFinalCrossReducesCountByOne() {
        val with = engine().buildSteps(prayer(includeFinalCross = true)).size
        val without = engine().buildSteps(prayer(includeFinalCross = false)).size
        assertEquals(with - 1, without)
    }

    @Test
    fun aramaicSignOfCrossUsesPerRosaryFormUntilAramaicBecomesTheAppDefault() {
        val savedDefault = AppSettings.defaultLanguageCode
        val savedForm = AppSettings.aramaicSignOfCrossForm
        try {
            AppSettings.setDefaultLanguageCode("en")
            AppSettings.setAramaicSignOfCrossForm(AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B)

            val formA = engine().buildSteps(prayer(
                language = "arc",
                aramaicSignOfCrossForm = AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A,
            ))
            assertEquals(
                "בשמָא דַאבָא ✠ ודַברָא ודרוּחָא קַדִישָא, חַד אַלָהָא שַרִירָא. אַמִין.",
                formA.first().body,
            )
            assertEquals(
                "ܒܫܡܳܐ ܕܰܐܒܳܐ ✠ ܘܕܰܒܪܳܐ ܘܕܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.",
                formA.first().transliteratedBody,
            )
            assertEquals(formA.first().body, formA.last().body)

            val formB = engine().buildSteps(prayer(
                language = "arc",
                aramaicSignOfCrossForm = AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B,
            ))
            assertEquals(
                "בשֶם אַבָא ✠ ובַרָא ורוּחָא קַדִישָא، חַד אַלָהָא שַרִירָא. אַמִין.",
                formB.first().body,
            )
            assertEquals(
                "ܒܫܶܡ ܐܰܒܳܐ ✠ ܘܒܰܪܳܐ ܘܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ، ܚܰܕ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܐܰܡܺܝܢ.",
                formB.first().transliteratedBody,
            )

            AppSettings.setDefaultLanguageCode("arc")
            val systemWide = engine().buildSteps(prayer(
                language = "arc",
                aramaicSignOfCrossForm = AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A,
            ))
            assertEquals(formB.first().body, systemWide.first().body)
        } finally {
            AppSettings.setDefaultLanguageCode(savedDefault)
            AppSettings.setAramaicSignOfCrossForm(savedForm)
        }
    }

    @Test
    fun stMichaelPrayerAddsOneStep() {
        val without = engine().buildSteps(prayer(includeMichael = false)).size
        val with = engine().buildSteps(prayer(includeMichael = true)).size
        assertEquals(without + 1, with)
    }

    @Test
    fun eternalRestAfterEachDecadeAddsOnePerDecade() {
        val without = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.None)).size
        val perDecade = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.AfterEachDecade)).size
        assertEquals(without + 5, perDecade)
    }

    @Test
    fun eternalRestAtEndAddsOneTotal() {
        val without = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.None)).size
        val atEnd = engine().buildSteps(prayer(eternalRest = EternalRestPlacement.AtEndOnly)).size
        assertEquals(without + 1, atEnd)
    }

    // MARK: - Closing intentions

    @Test
    fun closingIntentionsAddThirteenSteps() {
        val without = engine().buildSteps(prayer(closingIntentions = false)).size
        val with = engine().buildSteps(prayer(closingIntentions = true)).size
        // 3 intentions x (introduction + Our Father + Hail Mary + Glory Be), then Requiescant.
        assertEquals(without + 13, with)
    }

    @Test
    fun closingIntentionsFollowTheAntiphonDirectly() {
        val steps = engine().buildSteps(prayer(closingIntentions = true).copy(languageCode = "la"))
        val antiphonIndex = steps.indexOfFirst { it.isAntiphon }
        assertTrue(antiphonIndex >= 0)
        val intentions = steps.subList(antiphonIndex + 1, antiphonIndex + 14)
        assertEquals("Pater Noster", intentions[1].title)
        assertEquals(
            "Pro intentionibus Summi Pontificis et necessitatibus Ecclesiae et patriae.",
            intentions.first().body,
        )
        assertEquals("Requiescant in pace.\n**Amen.**", intentions.last().body)
    }

    @Test
    fun closingIntentionsPrayThePatriarchInHebrewAndTheExarchInTheGamlielRite() {
        val vicariate = engine().buildSteps(prayer(closingIntentions = true).copy(languageCode = "he"))
        assertTrue(vicariate.any { com.dkaluta.prosary.typography.HebrewDisplayText.unpoint(it.body).contains("הפטריארך") })
        val gamliel = engine().buildSteps(prayer(closingIntentions = true).copy(languageCode = "he-x-gamliel"))
        assertTrue(gamliel.any { com.dkaluta.prosary.typography.HebrewDisplayText.unpoint(it.body).contains("ההגמון") })
        assertFalse(gamliel.any { com.dkaluta.prosary.typography.HebrewDisplayText.unpoint(it.body).contains("הפטריארך") })
    }

    @Test
    fun closingIntentionGroupsCanBeEnabledSeparatelyAndOverrideLegacyChoice() {
        val baseline = prayer(closingIntentions = false)
        val count = engine().buildSteps(baseline).size
        for ((options, added) in listOf(
            baseline.rosary.copy(includeClosingPopeIntention = true) to 4,
            baseline.rosary.copy(includeClosingBishopIntention = true) to 4,
            baseline.rosary.copy(includeClosingDepartedIntention = true) to 5,
            baseline.rosary.copy(includeClosingIntentions = true, includeClosingBishopIntention = false) to 9,
        )) {
            assertEquals(count + added, engine().buildSteps(baseline.copy(rosary = options)).size)
        }
        val popeOnly = engine().buildSteps(baseline.copy(rosary = baseline.rosary.copy(includeClosingPopeIntention = true)))
        assertFalse(popeOnly.any { it.body.contains("Requiescant in pace") })
    }

    // MARK: - Mystery artwork

    @Test
    fun easternImageStyleSwapsOnlyMysteryImagery() {
        val classic = engine().buildSteps(prayer())
        assertFalse(classic.any { it.imageKey.startsWith("eastern_") })
        val eastern = engine().buildSteps(prayer(imageStyle = MysteryImageStyle.Eastern))
        assertEquals(classic.size, eastern.size)
        for ((c, e) in classic.zip(eastern)) {
            val mystery = c.mystery
            if (mystery != null) {
                assertEquals("eastern_${mystery.imageKey}", e.imageKey)
            } else {
                assertEquals(c.imageKey, e.imageKey)
            }
        }
    }

    @Test
    fun easternImageStyleAppliesToPresenterCombinedStep() {
        val steps = engine().buildSteps(prayer(presenterMode = true, imageStyle = MysteryImageStyle.Eastern))
        val combined = steps.filter { it.hailMaryIndexInDecade == 10 }
        assertEquals(5, combined.size)
        assertTrue(combined.all { it.imageKey.startsWith("eastern_") })
    }

    @Test
    fun everyEasternMysteryImageShipsInTheRosaryPack() {
        for (mystery in MysteryCatalog.all) {
            assertNotNull(
                "missing eastern image for ${mystery.imageKey}",
                PrayerPackStore.imageData("eastern_${mystery.imageKey}"),
            )
        }
    }

    // MARK: - Twenty mysteries

    @Test
    fun twentyMysteryDecadeCount() {
        val steps = engine().buildSteps(prayer(mode = MysterySelectionMode.TwentyMystery))
        val mysteries = steps.filter { it.isScripture }
        assertEquals(20, mysteries.size)
    }

    // MARK: - Step titles & content

    @Test
    fun firstStepIsSignOfCross() {
        val steps = engine().buildSteps(prayer().copy(languageCode = "en"))
        assertEquals("Sign of the Cross", steps.first().title)
    }

    @Test
    fun lastStepIsSignOfCrossWhenEnabled() {
        val steps = engine().buildSteps(prayer(includeFinalCross = true).copy(languageCode = "en"))
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun stepsContainHailMarys() {
        val steps = engine().buildSteps(prayer().copy(languageCode = "en"))
        val hailMarys = steps.filter { it.title.startsWith("Hail Mary") }
        // 3 opening + 50 decade = 53
        assertEquals(53, hailMarys.size)
    }

    @Test
    fun antiphonStepIsMarkedIsAntiphon() {
        val steps = engine().buildSteps(prayer())
        assertTrue(steps.any { it.isAntiphon })
    }

    @Test
    fun noAntiphonOptionProducesNoAntiphonStep() {
        val steps = engine().buildSteps(prayer(antiphon = MarianAntiphonOption.None))
        assertFalse(steps.any { it.isAntiphon })
    }

    // MARK: - Language passthrough

    @Test
    fun englishBodyContainsEnglishText() {
        val p = prayer().copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val creed = steps.firstOrNull { it.title == "Apostles' Creed" }
        assertNotNull(creed)
        assertTrue(creed!!.body.contains("I believe in God"))
    }

    @Test
    fun latinBodyContainsLatinText() {
        val p = prayer().copy(languageCode = "la")
        val steps = engine().buildSteps(p)
        val creed = steps.firstOrNull { it.title == "Symbolum Apostolorum" }
        assertTrue(creed!!.body.contains("Credo in Deum"))
    }

    // MARK: - resolveMysteryGroups

    @Test
    fun resolveSpecificReturnsOneGroup() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.Specific)
        assertEquals(listOf(MysteryGroup.Sorrowful), engine().resolveMysteryGroups(p))
    }

    @Test
    fun resolveFifteenReturnsTraditionalThree() {
        val p = prayer(mode = MysterySelectionMode.FifteenMystery)
        assertEquals(listOf(MysteryGroup.Joyful, MysteryGroup.Sorrowful, MysteryGroup.Glorious), engine().resolveMysteryGroups(p))
    }

    @Test
    fun resolveTwentyReturnsFourGroups() {
        val p = prayer(mode = MysterySelectionMode.TwentyMystery)
        assertEquals(
            listOf(MysteryGroup.Joyful, MysteryGroup.Luminous, MysteryGroup.Sorrowful, MysteryGroup.Glorious),
            engine().resolveMysteryGroups(p),
        )
    }

    @Test
    fun resolveTodaysMysteriesUsesCalendar() {
        val e = PrayerEngine(calendar = FixedCalendar(MysteryGroup.Luminous))
        val p = prayer(mode = MysterySelectionMode.TodaysMysteries)
        assertEquals(listOf(MysteryGroup.Luminous), e.resolveMysteryGroups(p))
    }

    @Test
    fun resolveSingleMysteryReturnsOneGroup() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3)
        assertEquals(listOf(MysteryGroup.Sorrowful), engine().resolveMysteryGroups(p))
    }

    // MARK: - Single Mystery

    @Test
    fun singleMysteryProducesExactlyOneDecade() {
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3)
        val steps = engine().buildSteps(p)
        val decadeIndices = steps.mapNotNull { it.decadeIndex }.toSet()
        assertEquals(setOf(0), decadeIndices)
    }

    @Test
    fun singleMysteryAnnouncesTheChosenMysteryNotTheFirst() {
        // Every step title is translated per-language now, so the language is pinned
        // explicitly rather than relying on the app-level default.
        val p = prayer(group = MysteryGroup.Sorrowful, mode = MysterySelectionMode.SingleMystery, order = 3).copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val announcement = steps.first { it.isScripture }
        // 3rd Sorrowful Mystery is the Crowning with Thorns, not the 1st (Agony in the Garden).
        assertEquals("The Crowning with Thorns", announcement.title)
        assertEquals("3rd Mystery", announcement.subtitle)
    }

    @Test
    fun hebrewMysteryCitationUsesGematriaChapterAndArabicVersesWithoutAColon() {
        val announcement = engine().buildSteps(
            prayer(group = MysteryGroup.Joyful, mode = MysterySelectionMode.SingleMystery, language = "he"),
        ).first { it.isScripture }

        assertTrue(announcement.body.contains("— לוּקָס א׳ 26–38 (דליטש)"))
        assertFalse(announcement.body.contains("א׳:"))
    }

    @Test
    fun aramaicMysteryUsesPeshittaAndCarriesItsSyriacScriptReadingAid() {
        val imageKey = "joyful_01_annunciation"
        val partial = PrayerPackStore.mysteryOverride("arc", imageKey)
        assertNotNull(partial)
        assertEquals(null, partial?.title)
        assertEquals(null, partial?.fruit)

        val resolved = com.dkaluta.prosary.content.MysteryTranslations.get("arc", imageKey)
        assertEquals(partial?.description, resolved.description)
        assertEquals(partial?.transliteratedDescription, resolved.transliteratedDescription)
        assertTrue(resolved.title.isNotBlank())
        assertTrue(resolved.fruit.isNotBlank())
        assertTrue(resolved.description.contains("— לוקא א׳ 26–38 (פשיטתא)"))
        assertFalse(resolved.description.contains("א׳:"))

        val announcement = engine().buildSteps(
            prayer(group = MysteryGroup.Joyful, mode = MysterySelectionMode.SingleMystery, language = "arc"),
        ).first { it.isScripture }
        val fruitLine =
            "${PrayerTranslations.get("arc", PrayerKey.FructusMysteriiLabel)}: ${resolved.fruit}"
        assertTrue(announcement.body.startsWith(resolved.description))
        assertTrue(announcement.body.endsWith(fruitLine))
        assertTrue(announcement.transliteratedBody?.startsWith(resolved.transliteratedDescription!!) == true)
        val alternateFruitLine = "${PrayerPackStore.transliteration("rosary", "arc", "fructusMysteriiLabel")}: ${resolved.fruit}"
        assertTrue(announcement.transliteratedBody?.endsWith(alternateFruitLine) == true)
    }

    // MARK: - Presenter Mode

    @Test
    fun presenterModeOffReproducesExistingStepCount() {
        val steps = engine().buildSteps(prayer(presenterMode = false))
        assertEquals(79, steps.size)
    }

    @Test
    fun presenterModeCollapsesHailMaryAndGloryBeIntoOneStepPerDecade() {
        val steps = engine().buildSteps(prayer(presenterMode = true).copy(languageCode = "en"))

        for (d in 0 until 5) {
            val hailMarySteps = steps.filter { it.decadeIndex == d && it.hailMaryIndexInDecade != null }
            assertEquals(1, hailMarySteps.size)
            assertEquals(10, hailMarySteps.first().hailMaryIndexInDecade)
            assertEquals("Hail Mary & Glory Be", hailMarySteps.first().title)
        }
    }

    @Test
    fun presenterModeCombinedStepBodyContainsBothPrayers() {
        val p = prayer(presenterMode = true).copy(languageCode = "en")
        val steps = engine().buildSteps(p)
        val combined = steps.first { it.title == "Hail Mary & Glory Be" }
        assertTrue(combined.body.contains("Hail Mary,\nfull of grace"))
        assertTrue(combined.body.contains("Glory be to the Father"))
    }

    @Test
    fun presenterModeStillIncludesFatimaPrayerPerDecade() {
        val steps = engine().buildSteps(prayer(includeFatima = true, presenterMode = true).copy(languageCode = "en"))
        assertEquals(5, steps.count { it.title == "Fatima Prayer" })
    }

    @Test
    fun presenterModeKeepsAnnouncementAndOurFatherAsSeparateSteps() {
        val steps = engine().buildSteps(prayer(presenterMode = true).copy(languageCode = "en"))
        val decadeZeroSteps = steps.filter { it.decadeIndex == 0 }
        // Announcement, Our Father, Hail Mary & Glory Be, Fatima Prayer = 4 (default config includes Fatima).
        assertEquals(4, decadeZeroSteps.size)
        assertTrue(decadeZeroSteps[0].isScripture)
        assertEquals("Our Father", decadeZeroSteps[1].title)
        assertEquals("Hail Mary & Glory Be", decadeZeroSteps[2].title)
    }
}
