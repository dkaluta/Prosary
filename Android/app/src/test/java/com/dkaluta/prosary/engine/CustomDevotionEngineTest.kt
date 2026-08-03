package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.content.prayerpack.CustomDevotionDefinition
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import java.io.File
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

private class FixedLiturgicalCalendar(
    private val isEasterSeasonValue: Boolean = false,
    private val seasonalAntiphonValue: MarianAntiphonOption = MarianAntiphonOption.SalveRegina,
) : LiturgicalCalendarProviding {
    override fun mysteryGroup(date: Date): MysteryGroup = MysteryGroup.Joyful
    override fun seasonColor(date: Date): Color = Color.Transparent
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = seasonalAntiphonValue
    override fun isEasterSeason(date: Date): Boolean = isEasterSeasonValue
}

/** [PrayerEngine.buildCustomDevotionSteps] is the one generic builder behind every
 * PrayerKind.Custom devotion. These tests exercise it via the real shipped bundles (produced by
 * Shared/tools/make-prosaryprayer.sh from Shared/content/) and carry over the per-devotion
 * assertions from the five deleted hardcoded-engine test files — the step sequences must be
 * byte-for-byte what the hardcoded builders used to emit. Mirrors iOS's
 * CustomDevotionEngineTests.swift. */
class CustomDevotionEngineTest {
    companion object {
        @BeforeClass
        @JvmStatic
        fun loadPacks() {
            PrayerPackStore.initialize { packName ->
                val file = File("src/main/assets/$packName.prosaryprayer")
                if (file.exists()) file.inputStream() else null
            }
        }
    }

    private fun steps(
        bundleId: String,
        language: String = "en",
        variantId: String? = null,
        customOptions: Map<String, String> = emptyMap(),
        calendar: FixedLiturgicalCalendar = FixedLiturgicalCalendar(),
    ): List<RosaryStep> = PrayerEngine(calendar).buildSteps(
        Prayer(
            kind = PrayerKind.Custom, languageCode = language,
            customDevotionId = bundleId, variantId = variantId, customOptions = customOptions,
        ),
    )

    // MARK: Trisagion (flat)

    @Test
    fun trisagionProducesTheSixStepSequence() {
        val steps = steps("trisagion")
        assertEquals(
            listOf("Holy God", "Holy God", "Holy God", "Glory Be", "Holy God", "Holy God"),
            steps.map { it.title },
        )
        assertTrue(steps[0].body.contains("Holy God, Holy Mighty One, Holy Immortal One"))
        assertTrue(steps[3].body.contains("Glory be to the Father"))
        assertFalse(steps[4].body.contains("Holy Mighty One"))
    }

    @Test
    fun trisagionImagesMatchTheDevotionJsonImageKeys() {
        val steps = steps("trisagion")
        assertEquals(
            listOf("jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait"),
            steps.map { it.imageKey },
        )
    }

    // MARK: Angelus (flat + Eastertide swap)

    @Test
    fun angelusStandardFormOutsideEastertide() {
        val steps = steps("angelus")
        assertEquals(7, steps.size)
        assertEquals(
            listOf(
                "The Annunciation", "Hail Mary",
                "The Fiat", "Hail Mary",
                "The Incarnation", "Hail Mary",
                "Let Us Pray",
            ),
            steps.map { it.title },
        )
        assertTrue(steps[0].body.contains("The Angel of the Lord declared unto Mary"))
        assertTrue(steps[0].body.contains("**And she conceived of the Holy Spirit.**"))
        assertTrue(steps[1].body.contains("Hail Mary, full of grace"))
        assertTrue(steps.last().body.contains("Pour forth, we beseech Thee"))
        assertFalse(steps.any { it.body.contains("Queen of Heaven") })
        assertTrue(steps.all { it.imageKey == "joyful_01_annunciation" })
    }

    @Test
    fun angelusReginaCaeliSubstitutionDuringEastertide() {
        val steps = steps("angelus", calendar = FixedLiturgicalCalendar(isEasterSeasonValue = true))
        assertEquals(1, steps.size)
        assertEquals("Regina Caeli", steps[0].title)
        assertTrue(steps[0].body.contains("Queen of Heaven, rejoice"))
        assertTrue(steps[0].body.contains("Rejoice and be glad, O Virgin Mary"))
        assertFalse(steps[0].body.contains("Pour forth, we beseech Thee"))
        assertEquals("madonna_and_child", steps[0].imageKey)
    }

    @Test
    fun angelusFallsBackToLatinWhenLanguageIsUnknown() {
        val steps = steps("angelus", language = "xx")
        assertTrue(steps[0].body.contains("Angelus Domini nuntiavit Mariae"))
    }

    // MARK: Stations of the Cross (flat, translated titles)

    @Test
    fun stationsProducesEighteenStepsWithTranslatedTitlesAndOrdinals() {
        val steps = steps("stationsOfTheCross")
        assertEquals(18, steps.size)
        assertEquals("Sign of the Cross", steps.first().title)
        assertEquals("Opening Prayer", steps[1].title)
        assertEquals("Jesus is Condemned to Death", steps[2].title)
        assertEquals("1st Station", steps[2].subtitle)
        assertEquals("14th Station", steps[15].subtitle)
        assertEquals("Closing Prayer", steps[16].title)
        // Anima Christi closes the Way of the Cross — a shared "main" prayer (hardcoded in all
        // six languages), so the bundle references it without shipping its own text.
        assertEquals("Anima Christi", steps.last().title)
        assertTrue(steps.last().body.contains("Soul of Christ, sanctify me"))
        assertTrue(steps[2].acclamation?.contains("We adore You, O Christ") == true)
        assertFalse(steps[2].body.contains("We adore You"))
        assertTrue(steps[2].acclamation?.contains("**Because by Your holy Cross You have redeemed the world.**") == true)
        assertEquals("station_01_condemned_to_death", steps[2].imageKey)
        // No bead fields anywhere — Stations is a flat devotion.
        assertTrue(steps.all { it.decadeIndex == null && it.hailMaryIndexInDecade == null })
    }

    /** The Hebrew Stations (user-provided, Hebrew-Catholic usage) carry scriptural meditations
     * instead of the Liguori texts — spot-check the translated title and the Isaiah 53:8 body. */
    @Test
    fun stationsHebrewUsesTheScripturalMeditations() {
        val steps = steps("stationsOfTheCross", language = "he")
        assertEquals("יֵשׁוּעַ נִדּוֹן לַמָּוֶת", steps[2].title)
        assertTrue(steps[2].body.contains("מֵעֹ֤צֶר וּמִמִּשְׁפָּט֙ לֻקָּ֔ח"))
        assertTrue(steps.last().body.contains("נֶפֶשׁ הַמָּשִׁיחַ קַדְּשִׁינִי"))
    }

    // MARK: Stations variants (traditional vs. scriptural)

    /** An unknown/null variantId resolves to the default (first) variant — the traditional set. */
    @Test
    fun stationsDefaultVariantIsTheTraditionalSet() {
        assertEquals(
            steps("stationsOfTheCross", variantId = null).map { it.title },
            steps("stationsOfTheCross", variantId = "traditional").map { it.title },
        )
        assertEquals(18, steps("stationsOfTheCross", variantId = "no-such-variant").size)
    }

    /** The scriptural (St. John Paul II) variant — same 18-step frame (shared opening/closing/
     * Anima Christi), fourteen different scenes with scriptural meditations. */
    @Test
    fun stationsScripturalVariantSequence() {
        val steps = steps("stationsOfTheCross", variantId = "scriptural")
        assertEquals(18, steps.size)
        assertEquals("Jesus Prays in the Garden of Gethsemane", steps[2].title)
        assertEquals("1st Station", steps[2].subtitle)
        assertEquals("sorrowful_01_agony_in_the_garden", steps[2].imageKey)
        assertTrue(steps[2].acclamation?.contains("We adore You, O Christ") == true)
        assertFalse(steps[2].body.contains("We adore You"))
        assertTrue(steps[2].body.contains("— Mark 14:32-36 (Douay-Rheims)"))
        assertEquals("scriptural_02_kiss_of_judas", steps[3].imageKey)
        assertEquals("Jesus Promises His Kingdom to the Good Thief", steps[12].title)
        assertEquals("seven_sorrows_05_crucifixion", steps[13].imageKey)
        assertEquals("Anima Christi", steps.last().title)
        // The fourteen station bodies are quoted Gospel passages, so they render in the
        // scripture typeface; the shared opening/closing prayers do not.
        assertTrue(steps.subList(2, 16).all { it.isScripture })
        assertFalse(steps[1].isScripture)
        assertFalse(steps[16].isScripture)
    }

    /** The traditional stations' meditations are quoted scripture in ar/he/ru/tl but Liguori
     * prose in la/en — isScriptureByLanguage picks the typeface per session language. */
    @Test
    fun traditionalStationsScriptureFlagFollowsTheLanguage() {
        assertTrue(steps("stationsOfTheCross", language = "he")[2].isScripture)
        assertFalse(steps("stationsOfTheCross", language = "en")[2].isScripture)
    }

    @Test
    fun stationsScripturalVariantHebrewTitles() {
        val steps = steps("stationsOfTheCross", language = "he", variantId = "scriptural")
        assertEquals("יֵשׁוּעַ מִתְפַּלֵּל בְּגַת שְׁמָנִים", steps[2].title)
        assertTrue(steps[2].body.contains("(דליטש)"))
    }

    // MARK: Via Lucis (flat, 14 scriptural stations)

    /** Cross + 14 stations + Regina Caeli + closing cross — mirrors iOS's
     * testViaLucisSeventeenStepSequence. */
    @Test
    fun viaLucisSeventeenStepSequence() {
        val steps = steps("viaLucis")
        assertEquals(17, steps.size)
        assertEquals("Sign of the Cross", steps.first().title)
        assertEquals("Jesus Rises from the Dead", steps[1].title)
        assertEquals("1st Station", steps[1].subtitle)
        assertEquals("glorious_01_resurrection", steps[1].imageKey)
        assertTrue(steps[1].acclamation?.contains("Because by Your holy Cross and Resurrection") == true)
        assertTrue(steps[1].body.contains("— Matthew 28:1-7 (Douay-Rheims)"))
        assertTrue(steps.subList(1, 15).all { it.isScripture })
        assertTrue(steps[4].body.contains("[…]"))
        assertEquals("Jesus Strengthens the Faith of Thomas", steps[8].title)
        assertEquals("The Holy Spirit Descends at Pentecost", steps[14].title)
        assertEquals("Regina Caeli", steps[15].title)
        assertTrue(steps[15].body.contains("Queen of Heaven, rejoice"))
        // Once clipped mid-sentence by a bad authoring-time extraction — endings pinned.
        assertTrue(steps[15].body.contains("Pray for us to God, alleluia."))
        assertTrue(steps[15].body.endsWith("through the same Christ our Lord. Amen."))
        assertEquals("Sign of the Cross", steps.last().title)
    }

    @Test
    fun viaLucisLatinBodiesComeFromTheVulgate() {
        val steps = steps("viaLucis", language = "la")
        assertEquals("Iesus a mortuis resurgit", steps[1].title)
        assertTrue(steps[1].body.contains("— Matth. 28:1-7 (Vulgata)"))
        assertTrue(steps[15].body.contains("Regina caeli, laetare, alleluia."))
    }

    // MARK: Franciscan Crown (rosary type, 7×10 + antiphon)

    @Test
    fun franciscanCrownNinetyStepSequence() {
        val steps = steps("franciscanCrown")
        assertEquals(90, steps.size)
        assertEquals("Sign of the Cross", steps.first().title)
        // 7 decades of announce + Our Father + 10 Hail Marys.
        assertEquals((0..6).toSet(), steps.mapNotNull { it.decadeIndex }.toSet())
        assertEquals(10, steps.mapNotNull { it.hailMaryIndexInDecade }.max())
        // Joy 1 announcement reuses the shared Rosary mystery text/image cross-bundle.
        assertEquals("The Annunciation", steps[1].title)
        assertEquals("1st Joy", steps[1].subtitle)
        assertTrue(steps[1].isScripture)
        assertEquals("joyful_01_annunciation", steps[1].imageKey)
        // Joy 4 is the Crown's own Adoration of the Magi.
        val joy4 = steps.first { it.subtitle == "4th Joy" }
        assertEquals("The Adoration of the Magi", joy4.title)
        assertEquals("franciscan_04_adoration_of_the_magi", joy4.imageKey)
        // The Our Father inside a decade uses the decade's own art (unlike the Rosary).
        assertEquals("Our Father", steps[2].title)
        assertEquals("joyful_01_annunciation", steps[2].imageKey)
        // Closing (opening 1 + 7×12 decades = indices 0…84): 2 Hail Marys + Our Father +
        // seasonal antiphon + cross.
        assertEquals("Hail Mary (1 of 2)", steps[85].title)
        assertEquals("For the years of Our Lady's life", steps[85].subtitle)
        assertNull(steps[85].decadeIndex)
        assertNull(steps[85].hailMaryIndexInDecade)
        assertEquals("Our Father", steps[87].title)
        assertEquals("For the intentions of the Holy Father", steps[87].subtitle)
        assertTrue(steps[88].isAntiphon)
        assertEquals("madonna_and_child", steps[88].imageKey)
        assertEquals("Sign of the Cross", steps.last().title)
    }

    /** The Crown's two optional closing devotions (the 72-completion Hail Marys, the Our Father
     * for the Pope's intentions) default ON — the untouched 90-step sequence above is the proof
     * that adding options.json changed nothing. Turning them off drops exactly those steps. */
    @Test
    fun franciscanCrownOptionsDropTheirClosingSteps() {
        val noSeventyTwo = steps("franciscanCrown", customOptions = mapOf("seventyTwoHailMarys" to "false"))
        assertEquals(88, noSeventyTwo.size)
        assertFalse(noSeventyTwo.any { it.subtitle == "For the years of Our Lady's life" })

        val neither = steps(
            "franciscanCrown",
            customOptions = mapOf("seventyTwoHailMarys" to "false", "popeIntentions" to "false"),
        )
        assertEquals(87, neither.size)
        assertFalse(neither.any { it.subtitle == "For the intentions of the Holy Father" })

        // An override for a key the bundle doesn't declare is ignored, not an error.
        assertEquals(90, steps("franciscanCrown", customOptions = mapOf("noSuchOption" to "false")).size)
    }

    @Test
    fun conditionExpressionEvaluation() {
        val values = mapOf("fatima" to "true", "creed" to "false", "antiphon" to "reginaCaeli")
        assertTrue(PrayerEngine.evaluateCondition("fatima", values))
        assertFalse(PrayerEngine.evaluateCondition("creed", values))
        assertFalse(PrayerEngine.evaluateCondition("!fatima", values))
        assertTrue(PrayerEngine.evaluateCondition("!creed", values))
        assertTrue(PrayerEngine.evaluateCondition("antiphon=reginaCaeli", values))
        assertFalse(PrayerEngine.evaluateCondition("antiphon=salveRegina", values))
        assertFalse(PrayerEngine.evaluateCondition("missing", values))
    }

    @Test
    fun franciscanCrownAntiphonFollowsTheSeason() {
        val paschal = steps(
            "franciscanCrown",
            calendar = FixedLiturgicalCalendar(seasonalAntiphonValue = MarianAntiphonOption.ReginaCaeli),
        )
        assertEquals("Regina Caeli", paschal[88].title)
        assertTrue(paschal[88].isAntiphon)
    }

    // MARK: Seven Sorrows (rosary type, 7×7)

    @Test
    fun sevenSorrowsSixtyNineStepSequence() {
        val steps = steps("sevenSorrows")
        assertEquals(69, steps.size)
        assertEquals((0..6).toSet(), steps.mapNotNull { it.decadeIndex }.toSet())
        assertEquals(7, steps.mapNotNull { it.hailMaryIndexInDecade }.max())
        assertEquals("The Prophecy of Simeon", steps[1].title)
        assertEquals("1st Sorrow", steps[1].subtitle)
        // The Meeting on the Way (4th sorrow) is the one traditional non-Gospel scene.
        val announcements = steps.filter { it.decadeIndex != null && it.hailMaryIndexInDecade == null && it.title != "Our Father" }
        assertEquals(7, announcements.size)
        assertFalse(announcements[3].isScripture)
        assertTrue(announcements.withIndex().all { (i, step) -> i == 3 || step.isScripture })
        // Closing: 3 Hail Marys for the tears, the composed Our Lady of Sorrows body, cross.
        assertEquals("Hail Mary (1 of 3)", steps[64].title)
        assertEquals("For the tears of Our Lady", steps[64].subtitle)
        assertEquals("Our Lady of Sorrows", steps[67].title)
        assertTrue(steps[67].body.contains("**That we may be made worthy of the promises of Christ.**"))
        assertFalse(steps.any { it.isAntiphon })
        assertEquals("Sign of the Cross", steps.last().title)
    }

    /** The sorrow texts live only in the bundle (they were deleted from the hardcoded tables) —
     * a language the bundle doesn't declare must fall back to the bundle's Latin mysteries, not
     * leak raw imageKeys as titles. */
    @Test
    fun sevenSorrowsFallsBackToBundleLatinForAnUndeclaredLanguage() {
        val steps = steps("sevenSorrows", language = "xx")
        assertEquals("Simeonis Prophetia", steps[1].title)
    }

    // MARK: Divine Mercy Chaplet (rosary type, no announcements, fixed image)

    @Test
    fun divineMercySixtyThreeStepSequence() {
        val steps = steps("divineMercyChaplet")
        assertEquals(63, steps.size)
        assertEquals(
            listOf("Sign of the Cross", "Our Father", "Hail Mary", "Apostles' Creed"),
            steps.take(4).map { it.title },
        )
        assertEquals((0..4).toSet(), steps.mapNotNull { it.decadeIndex }.toSet())
        assertEquals("Eternal Father, I Offer You...", steps[4].title)
        assertEquals("1st Decade", steps[4].subtitle)
        assertEquals("For the Sake of His Sorrowful Passion (1 of 10)", steps[5].title)
        assertEquals("Holy God, Holy Mighty One, Holy Immortal One (1 of 3)", steps[59].title)
        assertNull(steps[59].decadeIndex)
        assertEquals("Sign of the Cross", steps.last().title)
        // Every step reuses the single Divine Mercy image.
        assertTrue(steps.all { it.imageKey == "divine_mercy_image" })
    }

    // MARK: Structural guards

    @Test
    fun missingCustomDevotionIdProducesNoSteps() {
        val steps = PrayerEngine().buildSteps(Prayer(kind = PrayerKind.Custom, languageCode = "en"))
        assertTrue(steps.isEmpty())
    }

    /** The bead track assumes the closing cross is the literal last step and decade indices are
     * dense — guard every shipped rosary-type bundle at once. */
    @Test
    fun everyRosaryTypeBundleSatisfiesTheBeadTrackInvariants() {
        for (bundleId in PrayerPackStore.customDevotionIds()) {
            val definition = PrayerPackStore.definition(bundleId)
            assertNotNull("$bundleId: missing definition", definition)
            if (definition?.type != CustomDevotionDefinition.DevotionType.Rosary) continue
            val steps = steps(bundleId)
            assertEquals("$bundleId: opening cross must be step 0", "Sign of the Cross", steps.first().title)
            if (definition.hasClosingCross == true) {
                assertEquals("$bundleId: closing cross must be last", "Sign of the Cross", steps.last().title)
            }
            val indices = steps.mapNotNull { it.decadeIndex }
            assertEquals(
                "$bundleId: decadeIndex must be dense",
                (0 until ((indices.maxOrNull() ?: -1) + 1)).toSet(), indices.toSet(),
            )
            assertTrue("$bundleId: at most one antiphon", steps.count { it.isAntiphon } <= 1)
            // Minors carry indices; announcements/majors never do.
            for (step in steps) {
                if (step.hailMaryIndexInDecade != null) {
                    assertNotNull("$bundleId: minor steps must sit inside a decade", step.decadeIndex)
                }
            }
        }
    }
}
