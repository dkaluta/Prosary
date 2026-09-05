package com.dkaluta.prosary.engine

import androidx.compose.ui.graphics.Color
import com.dkaluta.prosary.calendar.LiturgicalCalendarProviding
import com.dkaluta.prosary.content.prayerpack.CustomDevotionDefinition
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.BasicPrayerCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryStep
import com.dkaluta.prosary.typography.HebrewDisplayText
import java.io.File
import java.util.Date
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

private class FixedLiturgicalCalendar(
    private val isEasterSeasonValue: Boolean = false,
    private val isLentValue: Boolean = false,
    private val seasonalAntiphonValue: MarianAntiphonOption = MarianAntiphonOption.SalveRegina,
) : LiturgicalCalendarProviding {
    override fun mysteryGroup(date: Date): MysteryGroup = MysteryGroup.Joyful
    override fun seasonColor(date: Date): Color = Color.Transparent
    override fun seasonalMarianAntiphon(date: Date): MarianAntiphonOption = seasonalAntiphonValue
    override fun isEasterSeason(date: Date): Boolean = isEasterSeasonValue
    override fun isLent(date: Date): Boolean = isLentValue
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
    fun basicPrayerLanguageOverrideKeepsTheAppDefaultAndScriptPair() {
        val saved = AppSettings.defaultLanguageCode
        try {
            AppSettings.setDefaultLanguageCode("en")
            val selected = BasicPrayerCatalog.step(BasicPrayerCatalog.prayer("ourFather")!!, "arc")
            assertEquals("צלותא מרניתא", selected.title)
            assertNotNull(selected.transliteratedBody)
            assertEquals("en", AppSettings.defaultLanguageCode)
            assertEquals("Holy God", BasicPrayerCatalog.step(BasicPrayerCatalog.prayer("holyGod")!!, "").title)
        } finally {
            AppSettings.setDefaultLanguageCode(saved)
        }
    }

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

    /** The Mission of St. Gamaliel's Trisagion (sent by Erez 2026-08-06) addresses God in the
     * second person where the app's own Hebrew declares of him, and heads the prayer with the
     * Aramaic קדישת. Pinned so their wording — including the ✠▼▲ marks exactly as sent — cannot
     * drift, and so it stays visibly distinct from the plain-Hebrew form beside it. */
    @Test
    fun trisagionInTheMissionsRite() {
        // Explicitly the Byzantine form: the rite's *default* is now the Syriac one (see
        // trisagionDefaultFormFollowsThePrayerLanguage); this test pins the wording overlay.
        val mission = steps("trisagion", language = "he-x-gamliel", variantId = "byzantine")
        val hebrew = steps("trisagion", language = "he")

        assertEquals(
            listOf("קדישת", "קדישת", "קדישת", "השבח לאב", "קדישת", "קדישת"),
            mission.map { it.title },
        )
        assertTrue(mission[0].body.startsWith("אַתָּה ✠▼▲ קָדוֹשׁ – אֱלוֹהִים"))
        assertTrue(mission[0].body.contains("תְּרַחֵם עָלֵינוּ"))
        assertFalse("the short form drops the second acclamation", mission[4].body.contains("חַיִל"))

        assertNotEquals(hebrew[0].body, mission[0].body)
        assertEquals("קדוש האלהים", hebrew[0].title)

        // Not sent by the Mission: the Glory Be itself still reads their wording from the shared
        // table, and everything else falls through to plain Hebrew.
        assertTrue(mission[3].body.contains("הַשֶּׁבַח לָאָב"))
    }

    @Test
    fun trisagionImagesMatchTheDevotionJsonImageKeys() {
        val steps = steps("trisagion")
        assertEquals(
            listOf("jesus_portrait", "jesus_portrait", "jesus_portrait", "glory_be", "jesus_portrait", "jesus_portrait"),
            steps.map { it.imageKey },
        )
    }

    @Test
    fun hebrewHeadingsAreUnpointedWhilePrayerBodiesKeepTheirCanonicalMarks() {
        val hebrew = steps("rosary", language = "he")

        assertTrue(hebrew.all { it.title == HebrewDisplayText.unpoint(it.title) })
        assertTrue(hebrew.all { step ->
            step.subtitle?.let { it == HebrewDisplayText.unpoint(it) } ?: true
        })
        val hailMary = hebrew.first { it.imageKey == "virtue_faith" }
        assertTrue(hailMary.body.contains("שִׂמְחִי מִרְיָם"))
        assertNotEquals(HebrewDisplayText.unpoint(hailMary.body), hailMary.body)
    }


    /** A repeated step's counter is part of the prayer, not the interface: praying in Hebrew, the Divine Mercy decade
     * reads "(1 מִתּוֹךְ 10)" rather than splicing an English word into right-to-left text. */
    /** The decade ordinal is part of the prayer too: "1st Sorrow" in English, "מַכְאוֹב 1" in
     * Hebrew — English is the only one of the six that inflects the number. */
    @Test
    fun decadeOrdinalUsesThePrayerLanguage() {
        assertTrue(steps("sevenSorrows", language = "en")[3].subtitle!!.startsWith("1st Sorrow"))
        assertTrue(steps("sevenSorrows", language = "he")[3].subtitle!!.startsWith("מכאוב 1"))
        assertTrue(steps("sevenSorrows", language = "ru")[3].subtitle!!.startsWith("Скорбь 1"))
    }

    @Test
    fun repeatCounterUsesThePrayerLanguage() {
        assertTrue(steps("divineMercyChaplet", language = "he")[5].title.contains("(1 מתוך 10)"))
        assertTrue(steps("divineMercyChaplet", language = "la")[5].title.contains("(1 ex 10)"))
        assertTrue(steps("divineMercyChaplet", language = "en")[5].title.contains("(1 of 10)"))
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
        assertTrue(steps[1].body.contains("Hail Mary,\nfull of grace"))
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
        assertEquals("ישוע נדון למות", steps[2].title)
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
        assertTrue(steps[2].body.contains("— Mark 14:32–36 (Douay-Rheims)"))
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
        assertEquals("ישוע מתפלל בגת שמנים", steps[2].title)
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
        assertTrue(steps[1].body.contains("— Matthew 28:1–7 (Douay-Rheims)"))
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
        assertTrue(steps[1].body.contains("— Matth. 28:1–7 (Vulgata)"))
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

    // MARK: O Antiphons (days)

    /** The one shipped days-type bundle: seven evenings of Advent Vespers, each a reading, the
     * antiphon, the Magnificat, the Glory Be, and the antiphon again. */
    @Test
    fun oAntiphonsDayIsSelectedByTheDayIndex() {
        fun day(index: Int, language: String = "en"): List<RosaryStep> = PrayerEngine().buildSteps(
            Prayer(
                kind = PrayerKind.Custom, languageCode = language,
                customDevotionId = "oAntiphons", dayIndex = index,
            ),
        )

        assertEquals(
            listOf("A Reading", "O Wisdom", "The Magnificat", "Glory Be", "O Wisdom"),
            day(0).map { it.title },
        )
        assertEquals(
            listOf("A Reading", "O Root of Jesse", "The Magnificat", "Glory Be", "O Root of Jesse"),
            day(2).map { it.title },
        )
        assertEquals("O Emmanuel", day(6)[1].title)
        assertEquals("O Radix Iesse", day(2, language = "la")[1].title)
        assertTrue(day(6)[1].body.contains("come to save us, O Lord our God"))
        // The reading and the canticle are Scripture; the antiphon is not.
        assertTrue(day(0)[0].isScripture)
        assertTrue(day(0)[2].isScripture)
        assertFalse(day(0)[1].isScripture)
        // Past the last day the engine clamps rather than emitting nothing.
        assertEquals("O Emmanuel", day(99)[1].title)
    }

    /** The declarations the Pray row and the resumption logic read. */
    @Test
    fun oAntiphonsDeclaresItselfASeriesOfSevenDays() {
        val definition = PrayerPackStore.definition("oAntiphons")
        assertEquals(7, definition?.days?.size)
        assertEquals("series", definition?.dayProgression)
        assertEquals("12-17", definition?.suggestedStart)
        assertEquals("18:00", definition?.suggestedReminderTime)
        assertEquals("angelus", definition?.suggestedNext)
        assertEquals("17 December", definition?.days?.first()?.period)
        assertEquals("O Sapientia", definition?.days?.first()?.name)
    }

    /** The Divine Mercy chaplet's Hebrew is the Latin Patriarchate's own — approved by Patriarch
     * Michel Sabbah in 2003 — so it is pinned here rather than left to drift. */
    @Test
    fun divineMercyHebrewIsTheApprovedText() {
        val steps = steps("divineMercyChaplet", language = "he")
        assertTrue(steps.any { it.body.startsWith("אב נצחי שבשמים, אני מציע בפניך") })
        assertTrue(steps.any { it.body == "למען אהבתו אותנו בייסוריו רחם עלינו ועל העולם כולו." })
        assertTrue(steps.any { it.body.startsWith("קדוש אלוהינו, קדוש וחזק") })
    }

    // MARK: The invitatory, and the Mission's Hebrew

    /** The Rosary may open with "O God, come to my assistance" — off by default, and the
     * Alleluia leaves it during Lent, which is what the "invitatory & !isLent" gate is for. */
    @Test
    fun invitatoryIsOptionalAndDropsItsAlleluiaInLent() {
        assertFalse(steps("rosary")[1].body.contains("come to my assistance"))

        val on = steps("rosary", customOptions = mapOf("invitatory" to "true"))
        assertEquals("O God, Come to My Assistance", on[1].title)
        assertTrue(on[1].body.contains("O Lord, make haste to help me"))
        assertTrue(on[1].body.contains("Glory be to the Father"))
        assertTrue(on[1].body.endsWith("Alleluia."))

        val inLent = steps(
            "rosary",
            customOptions = mapOf("invitatory" to "true"),
            calendar = FixedLiturgicalCalendar(isLentValue = true),
        )
        assertTrue(inLent[1].body.contains("Glory be to the Father"))
        assertFalse(inLent[1].body.contains("Alleluia"))
    }

    @Test
    fun conjoinedConditionsRequireEveryTerm() {
        val values = mapOf("invitatory" to "true", "isLent" to "false", "antiphon" to "reginaCaeli")
        assertTrue(PrayerEngine.evaluateCondition("invitatory & !isLent", values))
        assertFalse(PrayerEngine.evaluateCondition("invitatory & isLent", values))
        assertTrue(PrayerEngine.evaluateCondition("invitatory & antiphon=reginaCaeli", values))
        assertFalse(PrayerEngine.evaluateCondition("invitatory & antiphon=salveRegina", values))
        // A single term still parses exactly as before.
        assertTrue(PrayerEngine.evaluateCondition("invitatory", values))
    }

    /** The shipped Trisagion was always the Byzantine form; it just never said so. Erez prays
     * the Syriac one — the acclamation thrice, then Lord-have-mercy thrice. Byzantine stays
     * first so the default sequence is byte-identical; plain Hebrew's Kyrie falls back to the
     * bundle's Latin until the Vicariate's wording arrives. */
    @Test
    fun trisagionSyriacVariant() {
        val syriac = steps("trisagion", variantId = "syriac")
        assertEquals(4, syriac.size)
        assertEquals(List(3) { "Holy God" } + "Lord, Have Mercy", syriac.map { it.title })
        // The Kyrie is ONE composed step — the threefold form is a single text, so repeating it
        // would pray nine invocations.
        assertEquals("Lord, have mercy.\nChrist, have mercy.\nLord, have mercy.", syriac[3].body)
        assertFalse(syriac.any { it.body.contains("Glory be") })

        // The Vicariate's Hebrew is the full threefold form in one line, exactly as sent;
        // Erez's rite overlays the same slot with his own line said thrice.
        val hebrewKyrie = steps("trisagion", language = "he", variantId = "syriac")[3]
        assertEquals("יֵשׁוּעַ שְׁמָעֵנוּ, הַמָּשִׁיחַ עָזְרֵנוּ, הָאָדוֹן חָנֵּנוּ.", hebrewKyrie.body)
        assertEquals("ישוע שמענו", hebrewKyrie.title)
        assertEquals("יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא", steps("trisagion", language = "he-x-gamliel", variantId = "syriac")[3].body)
    }

    /** A variant can claim a prayer language as its own (defaultForLanguages), and a favorite
     * with no explicit choice opens in it: the Mission prays the Syriac form, so Erez's rite
     * gets it without touching the variant menu. Exact-code match only — plain Hebrew (the
     * Vicariate, Latin rite) keeps the first-declared default, which per the canonical
     * tradition order (latin → byzantine → west syriac → armenian → alexandrian → east syriac)
     * is the earliest tradition the bundle ships: today the Byzantine. An explicit choice
     * always wins. */
    @Test
    fun trisagionDefaultFormFollowsThePrayerLanguage() {
        val gamliel = steps("trisagion", language = "he-x-gamliel")
        assertEquals("no explicit variant: the rite's own Syriac form", 4, gamliel.size)
        assertEquals("יְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא\nיְהֹוָה רַחֵם־נָא", gamliel[3].body)
        assertEquals("the Vicariate's Hebrew keeps the Byzantine default", 6, steps("trisagion", language = "he").size)
        assertEquals(
            "an explicit choice beats the rite's default",
            6, steps("trisagion", language = "he-x-gamliel", variantId = "byzantine").size,
        )

        // Classical Syriac claims the same form (2026-08-08): the Qadishat thrice, then the
        // Kurielaison the Syriac liturgy keeps in Greek — Aramaic in Hebrew square script, with
        // the same Aramaic in Syriac letters riding in the script-toggle transliteration.
        val aramaic = steps("trisagion", language = "arc")
        assertEquals(4, aramaic.size)
        assertEquals("קדישת אלהא", aramaic[0].title)
        assertEquals(
            "קַדּישַת אַלָהָא\nקַדִישַת חַילתָּנָא\nקַדִישַת לָא מִיותָּא אֶתַרחַמעלִין",
            aramaic[0].body,
        )
        assertEquals(
            "ܩܰܕ݁ܝܫܰܬ݂ ܐܰܠܳܗܳܐ\nܩܰܕܺܝܫܰܬ݂ ܚܰܝܠܬ݁ܳܢܳܐ\nܩܰܕܺܝܫܰܬ݂ ܠܳܐ ܡܺܝܘܬ݁ܳܐ ܐܶܬܰܪܚܰܡܥܠܺܝܢ",
            aramaic[0].transliteratedBody,
        )
        assertEquals("קוריאליסונ\nקוריאליסונ\nקוריאליסונ", aramaic[3].body)
        // Erez supplied the Mission's doxology in both scripts on 2026-08-26. Pin every mark and
        // vowel so the Hebrew-square-script Aramaic and its pointed Syriac rendering cannot drift.
        val glory = steps("trisagion", language = "arc", variantId = "byzantine")[3]
        assertEquals("שובחא לאבא", glory.title)
        assertEquals(
            "שוּבחָא לַאבָא ולַברָא וַלרוּחָא קַדישָא\nמֶן עָלַם וַעדַמָא לעָלַם עָלמִין. אַמִין.",
            glory.body,
        )
        assertEquals(
            "ܫܽܘܒܚܳܐ ܠܰܐܒܳܐ ܘܠܰܒܪܳܐ ܘܰܠܪܽܘܚܳܐ ܩܰܕܝܫܳܐ\nܡܶܢ ܥܳܠܰܡ ܘܰܥܕܰܡܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ. ܐܰܡܺܝܢ.",
            glory.transliteratedBody,
        )
    }

    /** Erez's Aramaic Nicene Creed (2026-08-31), in Hebrew square and pointed Syriac scripts. */
    @Test
    fun aramaicNiceneCreedPreservesBothSuppliedScripts() {
        val rosary = steps("rosary", language = "arc")
        val creed = rosary.firstOrNull { it.title == "מהימנינן" }
        assertNotNull("Aramaic Rosary titles: ${rosary.map { it.title }}", creed)
        creed!!
        assertEquals(
            "מהַימנִינַן בחד אַלָהָא, אַבָּא אַחִיד כֻּל, עָבוּדָא דַּשמַיָא ודַארעָא וַדכֻלהֶין אַיללין דמֶתחַזין וַדלָא מֶתחַזיָן, וַבחַד מָריָא יֶשוּע משיחָא יַחחָדָיֶא ברא דַּאַלָהָא, הַו דּמֶן אַבָּא אֶתִילֶד קדדם כלהון עָלמֶא, אַלָהָא מֶן אַלָהָא, נוּהרָא מֶן נוּהרָא, אַלָהָא שַרִירא מֶן אַלָהָא שַרִירָא, יַלִידא ולָא עבִידא, וַשוֶא בֻּאוסִיא לַאבּוּהי, הַו דבּאִידֶה הוֹא כַּל מֶדֶם, הַו דּמֶטֻלָתַן בּנַינשָא, ומֶטֻל פּוּרקָנַן נחֶת מֶן שמַיָא ואֶתגַשַם מֶן רוּחָא קַדִישָא, מֶן מַריַם בּתוּלתָא וַהוֹא בַּרננשֶא, ואֶצטלֶב חלָפִין ביומי פַּנטִיָוס פִילַטָוס, חַש ומִית וְאתקבַר, קם לַתלָתָא יַוַמִין אַיך דַכתִיב, וַסלֶק לַשמַיָא וִיתֶב מֶן יָמִין אַבּוּהי, ותוב אִתֶּא בשוּבחֶה רַבָא לַמן ליַיֶא וַלמִיָתֶא, הַו דַּלמַלכּוּתֶּה שוּלָמָא לָאאית, וַבחַד רוּחָא קַדִישָא דאַיָתַוהי מָריָא מַחינָא דכֻל, הַו דּמֶן אַבָא ובא ננפֶק, ועַם אַבָא ועַם ברא מֶסתגֶד ומֶשתַבַח, הַו דּמַלֶל בַנכָיֶא, ובַחדָא עִדתָא קַדִישתָא קָתוּלִיקִי וַשלִיחָיתָא, ומַודֶינַן דַחדָא הי מַעמַודָיתָא לשוּבקָנָא דּחַטָהֶא, וַמסַכֶינַן לַקיָמתָא דמִיתֶא וַלִיֶא חַדתֶא דבעָלמָא דַעתִיד. אַמִין.",
            creed.body,
        )
        assertEquals(
            "ܡܗܰܝܡܢܺܝܢܰܢ ܒܚܕ ܐܰܠܳܗܳܐ. ܐܰܒ݁ܳܐ ܐܰܚܺܝܕ݂ ܟ݁ܽܠ. ܥܳܒܽܘܕܳܐ ܕ݁ܰܫܡܰܝܳܐ ܘܕ݂ܰܐܪܥܳܐ ܘܰܕ݂ܟܽܠܗܶܝܢ ܐܰܝܠܠ̈ܝܢ ܕܡܶܬ݂ܚܰܙܝܢ ܘܰܕ݂ܠܳܐ ܡܶܬ݂ܚܰܙܝܳܢ. ܘܰܒ݂ܚܰܕ݂ ܡܳܪܝܳܐ ܝܶܫܽܘܥ ܡܫܝܚܳܐ ܝܰܚܚܳܕ݂ܳܝܶܐ ܒܪܐ ܕ݁ܰܐܰܠܳܗܳܐ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒ݁ܳܐ ܐܶܬܺܝܠܶܕ݂ ܩ݀ܕܕܡ ܟܠܗ݇ܘܢ ܥܳܠܡ̈ܶܐ. ܐܰܠܳܗܳܐ ܡܶܢ ܐܰܠܳܗܳܐ. ܢܽܘܗܪܳܐ ܡܶܢ ܢܽܘܗܪܳܐ. ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܐ ܡܶܢ ܐܰܠܳܗܳܐ ܫܰܪܺܝܪܳܐ. ܝܰܠܺܝܕܐ ܘܠܳܐ ܥܒܿܺܝܕܐ. ܘܰܫܘܶܐ ܒ݁ܽܐܘܣܺܝܐ ܠܰܐܒ݁ܽܘܗ̄ܝ. ܗܰܘ ܕܒ݁ܐܺܝܕ݂ܶܗ ܗ݈ܘܳܐ ܟ݁ܰܠ ܡܶܕܶܡ. ܗܰܘ ܕ݁ܡܶܛܽܠܳܬ݂ܰܢ ܒ݁ܢܰܝ̈ܢܫܳܐ. ܘܡܶܛܽܠ ܦ݁ܽܘܪܩܳܢܰܢ ܢܚܶܬ݂ ܡܶܢ ܫܡܰܝܳܐ ܘܐܶܬ݂ܓܰܫܰܡ ܡܶܢ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ. ܡܶܢ ܡܰܪܝܰܡ ܒ݁ܬ݂ܽܘܠܬ݂ܳܐ ܘܰܗ݈ܘܳܐ ܒ݁ܰܪܢܢܫܶܐ. ܘܐܶܨܛܠܶܒ݂ ܚܠܳܦ݂ܺܝܢ ܒܝܵܘ̈ܡ̇ܝ ܦ݁ܰܢܛܺܝܳܘܣ ܦܺܝܠܰܛܳܘܣ. ܚܰܫ ܘܡܺܝܬ ܘܶܐܬܩܒܰܪ. ܩܿܡ ܠܰܬ݂ܠܳܬ݂ܳܐ ܝܰܘܰܡܺܝܢ ܐܰܝܟ݂ ܕܰܟܬܺܝܒ. ܘܰܣܠܶܩ ܠܰܫܡܰܝܳܐ ܘܺܝܬ݂ܶܒ݂ ܡܶܢ ܝܳܡܺܝܢ ܐܰܒ݁ܽܘܗ̄ܝ. ܘܬܘܒ ܐܺܬ݁ܶܐ ܒܫܽܘܒ݂ܚܶܗ ܪܰܒܳܐ ܠܰܡܢ ܠܝܰܝܶܐ ܘܰܠܡܺܝܳܬ݂ܶܐ. ܗܰܘ ܕ݁ܰܠܡܰܠܟ݁ܽܘܬ݁ܶܗ ܫܽܘܠܳܡܳܐ ܠܳܐܐܝܬ. ܘܰܒ݂ܚܰܕ݂ ܪܽܘܚܳܐ ܩܰܕܺܝܫܳܐ ܕܐܰܝܳܬ݂ܰܘܗ݈ܝ ܡܳܪܝܳܐ ܡܰܚܝܢܳܐ ܕܟܽܠ. ܗܰܘ ܕ݁ܡܶܢ ܐܰܒܳܐ ܘܒܐ ܢܢܦܶܩ. ܘܥܰܡ ܐܰܒ݂ܳܐ ܘܥܰܡ ܒܪܐ ܡܶܣܬܓܶܕ ܘܡܶܫܬ݂ܰܒ݂ܰܚ. ܗܰܘ ܕ݁ܡܰܠܶܠ ܒܰܢ̈ܟܿܳܝܶܐ. ܘܒ݂ܰܚܕܳܐ ܥܺܕܬ݂ܳܐ ܩܰܕܺܝܫܬ݂ܳܐ ܩܳܬ݂ܽܘܠܺܝܩܺܝ ܘܰܫܠܺܝܚܳܝܬ݂ܳܐ. ܘܡܰܘܕ݂ܶܝܢܰܢ ܕܰܚܕ݂ܳܐ ܗ̄ܝ ܡܰܥܡܰܘܕ݂ܳܝܬܳܐ ܠܫܽܘܒܩܳܢܳܐ ܕ݁ܚܰܛܳܗܶܐ. ܘܰܡܣܰܟܶܝܢܰܢ ܠܰܩ݀ܝܳܡܬܳܐ ܕܡܺܝ̈ܬ݂ܶܐ ܘܰܠܺܝ̈ܶܐ ܚܰܕ̈ܬ݂ܶܐ ܕܒ݂ܥܳܠܡܳܐ ܕܰܥܬ݂ܺܝܕ݂. ܐܰܡܺܝܢ.",
            creed.transliteratedBody,
        )
    }

    /** Erez's Aramaic Our Father (2026-08-31), in Hebrew square and pointed Syriac scripts. */
    @Test
    fun aramaicOurFatherPreservesBothSuppliedScripts() {
        val rosary = steps("rosary", language = "arc")
        val abun = rosary.firstOrNull { it.title == "צלותא מרניתא" }
        assertNotNull("Aramaic Rosary titles: ${rosary.map { it.title }}", abun)
        abun!!
        assertEquals(
            "אַבוּן דבַשמַיָא נֶתקַדַש שמָך תִאתֶא מַלכוּתָך נֶהוֶא צֶביָנָך, " +
                "אַיכַנָא דבַשמַיָא אָף בַארעָא, הַבלַן לַחמָא דסוּנקָנַן יַומָנָא, " +
                "וַשבוּק לַן חַובַין וַחטָהַין אַיכַנָא דָאף חנַן שבַקן לחַיָבַין, " +
                "ולָא תַעלַן לנֶסיוּנָא אֶלָא פַצָא לַן מֶן בִישָא, מֶטֻל דדִילָך הִי " +
                "מַלכוּתָא וחַילָא ותֶשבוּחתָא לעָלַם עָלמִין אַמִין.",
            abun.body.replace('\n', ' '),
        )
        assertEquals(
            "ܐܰܒ݁ܽܘܢ ܕܒܰܫܡܰܝܳܐ ܢܶܬܩܰܕܰܫ ܫܡܳܟ ܬܺܐܬܶܐ ܡܰܠܟܽܘܬܳܟ ܢܶܗܘܶܐ ܨܶܒܝܳܢܳܟ. " +
                "ܐܰܝܟܰܢܳܐ ܕܒܰܫܡܰܝܳܐ ܐܳܦ ܒܰܐܪܥܳܐ. ܗܰܒܠܰܢ ܠܰܚܡܳܐ ܕܣܽܘܢܩܳܢܰܢ ܝܰܘܡܳܢܳܐ. " +
                "ܘܰܫܒܽܘܩ ܠܰܢ ܚܰܘܒܰܝ̈ܢ ܘܰܚܛܳܗܰܝ̈ܢ ܐܰܝܟܰܢܳܐ ܕܳܐܦ ܚܢܰܢ ܫܒܰܩܢ ܠܚܰܝܳܒܰܝ̈ܢ. " +
                "ܘܠܳܐ ܬܰܥܠܰܢ ܠܢܶܣܝܽܘܢܳܐ ܐܶܠܳܐ ܦܰܨܳܐ ܠܰܢ ܡܶܢ ܒܺܝܫܳܐ. " +
                "ܡܶܛܽܠ ܕܕܺܝܠܳܟ ܗܺܝ ܡܰܠܟܽܘܬܳܐ ܘܚܰܝܠܳܐ ܘܬܶܫܒܽܘܚܬܳܐ ܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ܀",
            abun.transliteratedBody?.replace('\n', ' '),
        )
        assertEquals(9, abun.body.lines().size)
        assertEquals(abun.body.lines().size, abun.transliteratedBody?.lines()?.size)
    }

    /** Erez's Aramaic Hail Mary (2026-08-31), in Hebrew square and pointed Syriac scripts. */
    @Test
    fun aramaicHailMaryPreservesBothSuppliedScripts() {
        val rosary = steps("rosary", language = "arc")
        val hailMary = rosary.firstOrNull { it.title.startsWith("שלם לך מרים") }
        assertNotNull("Aramaic Rosary titles: ${rosary.map { it.title }}", hailMary)
        hailMary!!
        assertEquals(
            "שלָם לֶך מַריַם מַליַת טַיבוּתָא, מָרַן עַמֶך מבַרַכתָא אַנת בנֶשָא " +
                "וַמבַרַך הוּ פִירָא דַבכַרסֶך מָרַן יֶשוּע משִיחָא, מָרַת מַריַם יָלדַת " +
                "אַלָהָא אַפִיס חלָפַין חנַן חַטָיָא, הָשָא וַבכֻלזבַן וַלעָלַם עָלמִין אַמִין.",
            hailMary.body.replace('\n', ' '),
        )
        assertEquals(
            "ܫܠܳܡ ܠܶܟ ܡܰܪܝܰܡ ܡܰܠܝܰܬ ܛܰܝܒܽܘܬܳܐ, ܡܳܪܰܢ ܥܰܡܶܟ ܡܒܰܪܰܟܬܳܐ ܐܰܢܬ ܒܢܶܫܳܐ " +
                "ܘܰܡܒܰܪܰܟ ܗܽܘ ܦܺܝܪܳܐ ܕܰܒܟܰܪܣܶܟ ܡܳܪܰܢ ܝܶܫܽܘܥ ܡܫܺܝܚܳܐ, ܡܳܪܰܬ ܡܰܪܝܰܡ ܝܳܠܕܰܬ " +
                "ܐܰܠܳܗܳܐ ܐܰܦܺܝܣ ܚܠܳܦܰܝܢ ܚܢܰܢ ܚܰܛܳܝܳܐ, ܗܳܫܳܐ ܘܰܒܟܽܠܙܒܰܢ ܘܰܠܥܳܠܰܡ ܥܳܠܡܺܝܢ ܐܰܡܺܝܢ.",
            hailMary.transliteratedBody?.replace('\n', ' '),
        )
        assertEquals(7, hailMary.body.lines().size)
        assertEquals(hailMary.body.lines().size, hailMary.transliteratedBody?.lines()?.size)
    }

    /** The Vicariate's Hebrew prayerbook leads each of the three acclamations with a cross, and
     * gives the short form none. The asymmetry is the point: it is exactly what an editor would
     * "tidy up" later, so both halves are pinned. Hebrew only — the other languages keep the
     * plain text until someone has seen a prayerbook in those. */
    @Test
    fun trisagionCrossesFollowTheVicariatesPrayerbook() {
        val hebrew = steps("trisagion", language = "he")
        assertEquals(3, hebrew[0].body.count { it == '\u2720' })
        assertTrue(hebrew[0].body.startsWith("\u2720 \u05E7\u05B8\u05D3\u05D5\u05B9\u05E9\u05C1"))
        assertFalse("the short form takes no cross", hebrew[4].body.contains("\u2720"))

        for (language in listOf("la", "en", "ar", "ru", "tl")) {
            assertFalse(
                "$language has no prayerbook behind it yet",
                steps("trisagion", language = language)[0].body.contains("\u2720"),
            )
        }
    }

    /** The Mission of St. Gamaliel's wording overlays plain Hebrew key by key — their Creed is
     * the Nicene one, and anything they have not sent still reads in the app's Hebrew. */
    @Test
    fun gamalielVariantOverlaysHebrew() {
        val variant = steps("rosary", language = "he-x-gamliel", customOptions = mapOf("apostlesCreed" to "true"))
        assertTrue("the Creed is the Nicene one", variant[1].body.contains("אָנוּ מַאֲמִינִים"))
        assertEquals("מאמינים של ניקאה", variant[1].title)
        assertTrue("their Hail Mary", variant.any { it.body.contains("שָׁלוֹם לָךְ מִרְיָם") })

        // Headings belong to the rite that uses them: the Mission's in the Mission's rite, the
        // app's own in plain Hebrew.
        val hebrew = steps("rosary", language = "he", customOptions = mapOf("apostlesCreed" to "true"))
        assertEquals("אות הצלב", variant.first().title)
        assertEquals("סימן הצלב", hebrew.first().title)
        assertEquals("אני מאמין", hebrew[1].title)
        assertTrue(variant.any { it.title.startsWith("שלום לך מרים") })
        assertTrue(hebrew.any { it.title.startsWith("שמחי מרים") })
        assertTrue(variant.any { it.title == "השבח לאב" })
        assertTrue(hebrew.any { it.title == "כבוד לאב" })

        // Not sent by the Mission: the Fatima prayer still reads in the app's Hebrew.
        fun fatima(list: List<RosaryStep>) = list.firstOrNull { it.title.contains("הו ישוע") }?.body
        assertEquals(fatima(hebrew), fatima(variant))

        // The mysteries are announced in Hebrew too. The Mission ships no mystery texts of its
        // own, and the announcement is the one step whose body is quoted Scripture — before the
        // base language step in MysteryTranslations.get it fell past plain Hebrew all the way to
        // Latin, so the rite prayed its Rosary in Hebrew but heard every mystery announced in
        // Latin.
        fun announcement(list: List<RosaryStep>) = list.firstOrNull { it.mystery != null }
        assertNotNull(announcement(variant))
        assertEquals(announcement(hebrew)?.title, announcement(variant)?.title)
        assertEquals(announcement(hebrew)?.body, announcement(variant)?.body)
        assertNotEquals(
            "the rite must not fall through to Latin while its prayers read Hebrew",
            announcement(steps("rosary", language = "la"))?.body,
            announcement(variant)?.body,
        )
    }

    /** Both sourced Hebrew uses stay visible as separate prayer-language choices. */
    @Test
    fun ritesAreListedUnderTheirLanguage() {
        assertEquals(listOf("he", "he-x-gamliel"), LanguageCatalog.all.filter {
            it.code.startsWith("he")
        }.map { it.code })
        assertEquals(
            listOf("la", "en", "he", "he-x-gamliel"),
            LanguageCatalog.availableOptions(listOf("la", "he", "en")).map { it.code },
        )
        assertEquals(listOf("he", "he-x-gamliel"), LanguageCatalog.rites("he").map { it.code })
        assertEquals(listOf("he", "he-x-gamliel"), LanguageCatalog.rites("he-x-gamliel").map { it.code })
        assertTrue(LanguageCatalog.rites("la").isEmpty())

        // A rite resolves as its language for display, keeps its own code, and reads right-to-left.
        val resolved = LanguageCatalog.resolve("he-x-gamliel")
        assertEquals("he-x-gamliel", resolved.code)
        assertEquals("עברית — נוסח השליחות", resolved.nativeName)
        assertTrue(resolved.isRightToLeft)
    }

    @Test
    fun languageFallbackOrderKeepsBaseFirstAndLatinLast() {
        val original = AppSettings.languageFallbackOrder
        try {
            AppSettings.setLanguageFallbackOrder(listOf("ru", "en", "ar", "he", "he-x-gamliel", "arc", "el", "es", "tl", "la"))
            val chain = LanguageCatalog.fallbackChain("he-x-gamliel")
            assertEquals(listOf("he-x-gamliel", "he", "ru", "en"), chain.take(4))
            assertEquals("la", chain.last())
        } finally {
            AppSettings.setLanguageFallbackOrder(original)
        }
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
