package com.dkaluta.prosary.content.today

import com.dkaluta.prosary.models.AppSettings
import java.io.File
import java.io.ByteArrayInputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Exercises the bundled Shared/data datasets behind the Home "Today" section: fixed and
 * movable feasts (incl. the Latin Patriarchate of Jerusalem propers overlaid on the General
 * Roman Calendar), the switchable-calendar registry, the Pope's monthly intention, and the
 * graceful out-of-range null that hides the row. Mirrors iOS's TodayInfoStoreTests.swift. */
class TodayInfoStoreTest {
    /** The store resolves the selection live on every lookup, so pinning the setting back to
     * "follow the registry default" is the whole reset. */
    @Before
    fun resetCalendarSelection() {
        AppSettings.feastCalendarId = ""
        TodayInfoStore.resetForTesting()
        TodayInfoStore.initialize { name ->
            val file = File("src/main/assets/data/$name.json")
            if (file.exists()) file.inputStream() else null
        }
    }

    private fun date(string: String): Date =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(string)!!

    @Test
    fun todayTranslationDefaultsFollowHebrewLanguageVariants() {
        assertTrue(TodayTranslationLanguage.defaultsToHebrew("he"))
        assertTrue(TodayTranslationLanguage.defaultsToHebrew("he-x-gamliel"))
        assertFalse(TodayTranslationLanguage.defaultsToHebrew("en"))
        assertFalse(TodayTranslationLanguage.defaultsToHebrew("arc"))
    }

    @Test
    fun fixedSolemnityResolves() {
        val feast = TodayInfoStore.feast(date("2026-12-25"))
        assertEquals("Christmas", feast?.title)
        assertEquals("Solemnity", feast?.rank)
    }

    @Test
    fun movableFeastIsBakedInPerYear() {
        // Easter falls on April 5 in 2026; Good Friday 2027 is March 26 — both must resolve.
        assertEquals("Solemnity", TodayInfoStore.feast(date("2026-04-05"))?.rank)
        assertNotNull(TodayInfoStore.feast(date("2027-03-26")))
    }

    /** The Holy Land calendar's own principal feast overlays the General Roman Calendar — in
     * 2026 October 25 is a Sunday of Ordinary Time in the GRC, but the diocese's patronal
     * solemnity takes precedence. */
    @Test
    fun latinPatriarchatePropersOverlayTheGeneralCalendar() {
        val feast = TodayInfoStore.feast(date("2026-10-25"))
        assertEquals("Our Lady, Queen of Palestine and of the Holy Land", feast?.title)
        assertEquals("Solemnity", feast?.rank)

        assertEquals(
            "Dedication of the Basilica of the Holy Sepulchre",
            TodayInfoStore.feast(date("2026-07-15"))?.title,
        )
    }

    @Test
    fun ferialDayHasNoFeast() {
        assertNull(TodayInfoStore.feast(date("2026-07-27")))
    }

    @Test
    fun dateOutsideTheGeneratedYearsHasNoFeast() {
        assertNull(TodayInfoStore.feast(date("2031-12-25")))
    }

    // Switchable calendars

    @Test
    fun calendarRegistryListsTheShippedCalendarsInPickerOrder() {
        assertEquals(
            listOf("lpj", "roman", "roman1962", "ugcc", "syriac"),
            TodayInfoStore.calendars.map { it.id },
        )
        assertEquals("lpj", TodayInfoStore.selectedCalendarId)
    }

    /** v0.10 folds the old Hebrew pseudo-calendar into General Roman. Its persisted id resolves
     * to Roman while sourced Hebrew titles remain available on each matching feast. */
    @Test
    fun legacyHebrewRomanSelectionUsesLocalizedGeneralRomanCalendar() {
        AppSettings.feastCalendarId = "roman-he"
        assertEquals("roman", TodayInfoStore.selectedCalendarId)
        val bartholomew = TodayInfoStore.feast(date("2026-08-24"))
        assertEquals("Saint Bartholomew, Apostle", bartholomew?.title)
        assertEquals("חג בר־תלמי השליח", bartholomew?.localizedTitle("he"))
        assertEquals("Feast", bartholomew?.rank)
        val sunday = TodayInfoStore.feast(date("2026-08-30"))
        assertEquals("22nd Sunday of Ordinary Time", sunday?.title)
        assertEquals("יום א ה־22 של הזמן הרגיל", sunday?.localizedTitle("he"))
        assertEquals("Sunday", sunday?.rank)
    }

    @Test
    fun everyCalendarLocalizesItsOwnFeastWithoutChangingItsTitleOrRank() {
        val expected = listOf(
            Triple("lpj", "Exaltation of the Holy Cross", "Feast"),
            Triple("roman", "Exaltation of the Holy Cross", "Feast"),
            Triple("roman1962", "Exaltation of the Holy Cross", "2nd Class"),
            Triple("ugcc", "The Exaltation of the Precious and Life-Giving Cross", "Great Feast"),
            Triple("syriac", "Exaltation of the Holy Cross—Feast", "Feast"),
        )
        for ((calendarId, title, rank) in expected) {
            AppSettings.feastCalendarId = calendarId
            val feast = TodayInfoStore.feast(date("2026-09-14"))
            assertNotNull(calendarId, feast)
            assertEquals(calendarId, title, feast?.title)
            assertEquals(calendarId, rank, feast?.rank)
            assertEquals(calendarId, "חג תפארת הצלב", feast?.localizedTitle("he"))
            assertEquals(calendarId, "חג תפארת הצלב", feast?.localizedTitle("he-x-gamliel"))
            assertEquals(calendarId, title, feast?.localizedTitle("en"))
        }
    }

    @Test
    fun feastWithoutATranslationKeepsItsOwnTitle() {
        val feast = FeastDay(title = "Untranslated feast", rank = "Feast")
        assertEquals("Untranslated feast", feast.localizedTitle("he"))
        assertEquals("Untranslated feast", feast.localizedTitle("he-x-gamliel"))
    }

    @Test
    fun teresaOfCalcuttaLocalizesWithoutReplacingAnotherCalendarsDay() {
        for (calendarId in listOf("lpj", "roman")) {
            AppSettings.feastCalendarId = calendarId
            val feast = TodayInfoStore.feast(date("2026-09-05"))
            assertNotNull(calendarId, feast)
            assertEquals(calendarId, "Saint Teresa of Calcutta, Virgin", feast?.title)
            assertEquals(calendarId, "Optional Memorial", feast?.rank)
            assertEquals(calendarId, "תרזה הקדושה מקלקוטה, בתולה", feast?.localizedTitle("he"))
            assertEquals(calendarId, "תרזה הקדושה מקלקוטה, בתולה", feast?.localizedTitle("he-x-gamliel"))
            assertEquals(calendarId, "Saint Teresa of Calcutta, Virgin", feast?.localizedTitle("en"))

            // September 5 falls on Sunday in 2027; translating a saint must not change precedence.
            val sunday = TodayInfoStore.feast(date("2027-09-05"))
            assertEquals(calendarId, "23rd Sunday of Ordinary Time", sunday?.title)
            assertEquals(calendarId, "Sunday", sunday?.rank)
        }

        AppSettings.feastCalendarId = "roman1962"
        val vetus = TodayInfoStore.feast(date("2026-09-05"))
        assertEquals("St. Lawrence Justinian", vetus?.title)
        assertEquals("3rd Class", vetus?.rank)
        for (calendarId in listOf("ugcc", "syriac")) {
            AppSettings.feastCalendarId = calendarId
            assertNull(calendarId, TodayInfoStore.feast(date("2026-09-05")))
        }
    }

    @Test
    fun saintTitlesRetainTheirRolesAcrossCalendarAliases() {
        val expected = listOf(
            listOf("roman", "2026-05-26", "Saint Philip Neri, Priest", "Memorial", "פיליפוס נרי, כהן"),
            listOf("roman", "2026-10-22", "Saint John Paul II, Pope", "Optional Memorial", "יוחנן פאולוס השני, אפיפיור"),
            listOf("roman", "2026-07-15", "Saint Bonaventure, Bishop and Doctor of the Church", "Memorial", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
            listOf("roman1962", "2026-07-14", "St. Bonaventure", "3rd Class", "בונבנטורה הקדוש, הגמון ודוקטור הכנסייה"),
            listOf("roman", "2026-07-03", "Saint Thomas the Apostle", "Feast", "תאמא השליח"),
            listOf("syriac", "2026-10-06", "Feast of Saint Thomas the Apostle", "Feast", "תאמא השליח"),
            listOf("roman1962", "2026-12-21", "St. Thomas", "2nd Class", "תאמא השליח"),
            listOf("roman", "2026-01-28", "Saint Thomas Aquinas, Priest and Doctor of the Church", "Memorial", "תומאס אקווינס, כהן ודוקטור הכנסייה"),
        )
        for ((calendarId, feastDate, title, rank, hebrew) in expected) {
            AppSettings.feastCalendarId = calendarId
            val feast = TodayInfoStore.feast(date(feastDate))
            assertNotNull(title, feast)
            assertEquals(title, feast?.title)
            assertEquals(rank, feast?.rank)
            assertEquals(title, hebrew, feast?.localizedTitle("he"))
            assertEquals(title, hebrew, feast?.localizedTitle("he-x-gamliel"))
            assertEquals(title, feast?.localizedTitle("en"))
        }
    }

    @Test
    fun feastRanksFollowTodayLanguageWithoutChangingCanonicalValues() {
        val expected = listOf(
            "Solemnity" to "מועד",
            "Feast" to "חג",
            "Memorial" to "זיכרון",
            "Optional Memorial" to "זיכרון רשות",
            "Sunday" to "יום ראשון",
            "Great Feast" to "חג גדול",
            "Holy Week" to "השבוע הקדוש",
            "Fast" to "צום",
            "1st Class" to "דרגה ראשונה",
            "2nd Class" to "דרגה שנייה",
            "3rd Class" to "דרגה שלישית",
        )
        for ((rank, hebrew) in expected) {
            val feast = FeastDay(title = "Feast", rank = rank)
            assertEquals(rank, hebrew, feast.localizedRank("he"))
            assertEquals(rank, hebrew, feast.localizedRank("he-x-gamliel"))
            assertEquals(rank, feast.localizedRank("en"))
            assertEquals(rank, feast.localizedRank("fr"))
            assertEquals(rank, feast.rank)
        }
        val unknown = FeastDay(title = "Feast", rank = "Future rank")
        assertEquals("Future rank", unknown.localizedRank("he"))
    }

    /** The Syriac Catholic table comes from Evangelizo.org's Daily Gospel (credited on the
     * About screen): the Antiochene year names its Sundays from the season's anchor feasts,
     * and Evangelizo's plain-date ferial titles are omitted like ferial days everywhere else. */
    @Test
    fun syriacCalendarNamesTheAntiocheneSeasons() {
        AppSettings.feastCalendarId = "syriac"
        val sunday = TodayInfoStore.feast(date("2026-10-25"))
        assertEquals("Sixth Sunday after the Feast of the Cross", sunday?.title)
        assertEquals("Sunday", sunday?.rank)
        assertEquals(
            "Assumption of the Mother of God",
            TodayInfoStore.feast(date("2026-08-15"))?.title,
        )
        assertNull(TodayInfoStore.feast(date("2026-07-27")))
    }

    /** October 25, 2026 wears four different faces: the LPJ's patronal solemnity, a plain
     * Sunday of Ordinary Time in the general calendar, Christ the King in the 1962 books
     * (which place the feast on October's last Sunday), and a numbered Sunday after Pentecost
     * in the Byzantine reckoning. */
    @Test
    fun switchingCalendarsResolvesEachCalendarsOwnFeast() {
        assertEquals(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )

        AppSettings.feastCalendarId = "roman"
        assertEquals(
            "30th Sunday of Ordinary Time",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )

        AppSettings.feastCalendarId = "roman1962"
        val vetus = TodayInfoStore.feast(date("2026-10-25"))
        assertEquals("Christ the King", vetus?.title)
        assertEquals("1st Class", vetus?.rank)

        AppSettings.feastCalendarId = "ugcc"
        assertEquals("22nd Sunday after Pentecost", TodayInfoStore.feast(date("2026-10-25"))?.title)
    }

    /** The UGCC dataset is the diasporic (fully Gregorian) usage prayed in the Holy Land:
     * Pascha falls with the Gregorian computus (April 5, 2026 — the same day as the Roman
     * Easter), and a fixed Great Feast landing in Holy Week is joined, never displaced — in
     * 2027 the Annunciation falls on Great and Holy Thursday. */
    @Test
    fun ukrainianCalendarPraysTheGregorianPascha() {
        AppSettings.feastCalendarId = "ugcc"
        val pascha = TodayInfoStore.feast(date("2026-04-05"))
        assertEquals("The Resurrection of Our Lord — Holy Pascha", pascha?.title)
        assertEquals("Great Feast", pascha?.rank)
        assertEquals(
            "The Protection of the Most Holy Theotokos (Pokrov)",
            TodayInfoStore.feast(date("2026-10-01"))?.title,
        )
        assertEquals(
            "The Annunciation of the Most Holy Theotokos; Great and Holy Thursday",
            TodayInfoStore.feast(date("2027-03-25"))?.title,
        )
    }

    @Test
    fun unknownCalendarIdFallsBackToTheDefault() {
        AppSettings.feastCalendarId = "narnia"
        assertEquals("lpj", TodayInfoStore.selectedCalendarId)
        assertEquals(
            "Our Lady, Queen of Palestine and of the Holy Land",
            TodayInfoStore.feast(date("2026-10-25"))?.title,
        )
    }

    @Test
    fun vetusOrdoKeepsSeptuagesimaAndClassRanks() {
        AppSettings.feastCalendarId = "roman1962"
        val septuagesima = TodayInfoStore.feast(date("2026-02-01"))
        assertEquals("Septuagesima Sunday", septuagesima?.title)
        assertEquals("2nd Class", septuagesima?.rank)
        assertEquals("1st Class", TodayInfoStore.feast(date("2026-12-25"))?.rank)
    }

    @Test
    fun monthIntentionResolves() {
        val intention = TodayInfoStore.intention(date("2026-07-27"))
        assertEquals("For respect for human life", intention?.title)
        assertTrue(intention?.text?.contains("human life in all its stages") ?: false)
        assertEquals("למען כבוד לחיי אדם", intention?.localizedTitle("he"))
        assertTrue(intention?.localizedText("he")?.contains("בכל שלביהם") ?: false)
    }

    @Test
    fun romanReadingsAndLiturgicalDayResolve() {
        val readings = TodayInfoStore.readings(date("2026-08-31"))
        assertEquals(listOf("1 Cor. 2", "Ps. 119", "Lk. 4"), readings.map { it.short })
        assertEquals("Luke 4:16–30", readings.last().full)
        assertEquals("לוקס ד׳", readings.last().localizedShort("he"))
        assertEquals("הבשורה על־פי לוקס ד׳ 16–30", readings.last().localizedFull("he"))
        assertEquals("לוקס ד׳", readings.last().localizedShort("he-x-gamliel"))
        assertEquals("הבשורה על־פי לוקס ד׳ 16–30", readings.last().localizedFull("he-x-gamliel"))

        val day = TodayInfoStore.liturgicalDayInfo(date("2026-08-31"))
        assertTrue(day.english.startsWith("Monday · Week "))
        assertTrue(day.english.endsWith(" of Ordinary Time"))
        assertTrue(day.hebrew.contains("בזמן הרגיל"))
        assertTrue(day.hebrew.contains("השבוע ה־"))
        assertFalse(day.hebrew.contains("ה-"))
    }

    @Test
    fun hebrewEpistleShorthandPreservesFullSourceCitation() {
        val corinthians = TodayInfoStore.readings(date("2026-09-04")).first()
        assertEquals("הראשונה אל הקורינתים ד׳", corinthians.localizedShort("he"))
        assertEquals(
            "אגרת שאול הראשונה אל הקורינתים ד׳ 1–5",
            corinthians.localizedFull("he"),
        )

        val petrine = ReadingCitation(
            type = "reading",
            short = "2 Pet. 2",
            full = "2 Peter 2:1–3",
            shortByLanguage = mapOf("he" to "השנייה של כיפא ב׳"),
            fullByLanguage = mapOf("he" to "אגרת כיפא השניה ב׳ 1–3"),
        )
        assertEquals("השנייה של כיפא ב׳", petrine.localizedShort("he"))
        assertEquals("אגרת כיפא השניה ב׳ 1–3", petrine.localizedFull("he"))
    }

    @Test
    fun localizedDisplayTitlesLoseHebrewPointsWithoutChangingBodyText() {
        val feast = FeastDay(
            title = "Saint John",
            rank = "Memorial",
            titleByLanguage = mapOf("he" to "יוֹחָנָן הַקָּדוֹשׁ"),
        )
        val intention = PopeIntention(
            title = "Peace",
            text = "Pray for peace.",
            titleByLanguage = mapOf("he" to "שָׁלוֹם"),
            textByLanguage = mapOf("he" to "נִתְפַּלֵּל לְשָׁלוֹם."),
        )

        assertEquals("יוחנן הקדוש", feast.localizedTitle("he-x-gamliel"))
        assertEquals("שלום", intention.localizedTitle("he"))
        assertEquals("נִתְפַּלֵּל לְשָׁלוֹם.", intention.localizedText("he"))
    }

    @Test
    fun otherCalendarsLocalizeTheirOwnAppointedReadingsInHebrew() {
        AppSettings.feastCalendarId = "roman1962"
        val vetus = TodayInfoStore.readings(date("2026-09-03"))
        assertEquals("הראשונה אל התסלוניקים ב׳", vetus.first().localizedShort("he"))
        assertEquals("הבשורה  על־פי יוחנן כ״א 15–17", vetus.last().localizedFull("he"))

        AppSettings.feastCalendarId = "ugcc"
        val byzantine = TodayInfoStore.readings(date("2026-09-03"))
        assertEquals("אל הגלטים ג׳", byzantine.first().localizedShort("he"))
        assertEquals("אגרת שאול אל הגלטים ג׳ 23–ד׳ 5", byzantine.first().localizedFull("he"))
        assertEquals("השנייה של כיפא א׳", TodayInfoStore.readings(date("2026-08-06")).first().localizedShort("he"))

        AppSettings.feastCalendarId = "syriac"
        val syriac = TodayInfoStore.readings(date("2026-09-03"))
        assertEquals("אל הפיליפים א׳", syriac.first().localizedShort("he-x-gamliel"))
        assertEquals("אגרת שאול אל הפיליפים א׳ 12–21", syriac.first().localizedFull("he"))
        assertEquals("השנייה אל טימותיאוס ב׳", TodayInfoStore.readings(date("2026-08-08")).first().localizedShort("he"))
        assertTrue(TodayInfoStore.readings(date("2026-08-01")).isEmpty())
    }

    @Test
    fun switchingCalendarSwitchesReadingsWithoutLeakingThePreviousTable() {
        val target = date("2026-08-31")
        assertEquals(listOf("1 Cor. 2", "Ps. 119", "Lk. 4"), TodayInfoStore.readings(target).map { it.short })

        AppSettings.feastCalendarId = "roman1962"
        assertEquals(listOf("Lk. 12"), TodayInfoStore.readings(target).map { it.short })

        AppSettings.feastCalendarId = "ugcc"
        assertEquals(listOf("Heb. 9", "Lk. 10"), TodayInfoStore.readings(target).map { it.short })

        AppSettings.feastCalendarId = "syriac"
        assertEquals(listOf("Rom. 7", "Lk. 17"), TodayInfoStore.readings(target).map { it.short })

        AppSettings.feastCalendarId = "roman"
        assertEquals(listOf("1 Cor. 2", "Ps. 119", "Lk. 4"), TodayInfoStore.readings(target).map { it.short })
    }

    @Test
    fun missingReadingsFileProducesAnEmptyRow() {
        TodayInfoStore.resetForTesting()
        val files = mapOf(
            "calendars" to """{
                "default":"test",
                "calendars":[{
                    "id":"test", "file":"feasts", "readingsFile":"not-shipped",
                    "name":"Test"
                }]
            }""",
            "feasts" to """{"days":{}}""",
        )
        TodayInfoStore.initialize { name ->
            files[name]?.let { ByteArrayInputStream(it.toByteArray()) }
        }

        assertTrue(TodayInfoStore.readings(date("2026-08-31")).isEmpty())
    }

    @Test
    fun monthOutsideThePublishedListHasNoIntention() {
        assertNull(TodayInfoStore.intention(date("2031-05-01")))
    }
}
