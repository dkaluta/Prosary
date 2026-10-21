package com.dkaluta.prosary.models

import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.ui.rosaryflow.BeadLayout
import java.io.File
import java.util.Locale
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class RosaryRiteLabelsTest {
    private lateinit var savedDefault: String
    private var savedFallback = emptyList<String>()
    private var savedFilioque: Boolean? = null

    @Before fun setUp() {
        savedDefault = AppSettings.defaultLanguageCode
        savedFallback = AppSettings.languageFallbackOrder
        savedFilioque = AppSettings.includeFilioqueChoice
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream() }
    }

    @After fun tearDown() {
        AppSettings.setDefaultLanguageCode(savedDefault)
        AppSettings.setLanguageFallbackOrder(savedFallback)
        AppSettings.restoreFilioqueForTesting(savedFilioque)
    }

    @Test fun editorLabelsUseTheirOwnRiteDespiteTheOppositeDefaultAndFallbackPriority() {
        for ((selected, other, ourFather, hailMary, gloryBe) in listOf(
            listOf("he", "he-x-gamliel", "אבינו שבשמים", "שמחי מרים", "כבוד לאב"),
            listOf("he-x-gamliel", "he", "תפילת האדון", "שלום לך מרים", "השבח לאב"),
        )) {
            AppSettings.setDefaultLanguageCode(other)
            AppSettings.setLanguageFallbackOrder(listOf(other, "en", selected, "la"))
            val opening = label("openingPrayers", selected)!!
            assertEquals("“$ourFather” ו־3 “$hailMary” בפתיחה", opening)
            assertTrue(label("openingFatimaPrayer", selected)!!.contains("“$gloryBe”"))
            val presenter = label("presenterHint", selected)!!
            assertTrue(presenter.contains("“$hailMary”"))
            assertTrue(presenter.contains("“$gloryBe”"))
            assertEquals(label("openingPrayers", selected), label("openingPrayers", selected, "iw-IL"))
            assertEquals(if (selected == "he") "אני מאמין" else "מאמינים של ניקאה",
                label("apostlesCreed", selected))
            assertEquals(RosaryRiteLabels.title("oratioFatimaeTitle", selected, "he"),
                label("fatimaPrayer", selected)!!.substringAfter('“').substringBefore('”'))
        }
    }

    @Test fun inheritedRiteFollowsThePrayerDefaultWhileOtherInterfacesKeepTheirOwnLabels() {
        AppSettings.setDefaultLanguageCode("he-x-gamliel")
        AppSettings.setLanguageFallbackOrder(listOf("he", "en", "he-x-gamliel", "la"))
        assertTrue(label("openingPrayers", "")!!.contains("שלום לך מרים"))
        for (ui in listOf("en", "ru", "ar")) {
            assertNull(label("openingPrayers", "he-x-gamliel", ui))
            assertNull(RosaryRiteLabels.title("aveMariaTitle", "he", ui))
        }
        assertNull(label("openingPrayers", "en"))
        assertEquals("תפילות פתיחה", localized(R.string.ro_opening_prayers, emptyList()))
        assertEquals("תפילת פאטימה הנוספת בפתיחה", localized(R.string.ro_opening_fatima, emptyList()))
        assertFalse(localized(R.string.ro_presenter_hint, emptyList()).contains("שלום לך"))
        assertNull(RosaryRiteLabels.antiphonTitle("seasonal", "he", "he"))
        assertNull(RosaryRiteLabels.antiphonTitle("none", "he-x-gamliel", "he"))
    }

    @Test fun spokenBeadProgressTracksTheSessionRiteAndKeepsEnglishInterfaceSpeech() {
        for ((rite, expected, excluded) in listOf(
            Triple("he", "שמחי מרים", "שלום לך מרים"),
            Triple("he-x-gamliel", "שלום לך מרים", "שמחי מרים"),
        )) {
            AppSettings.setDefaultLanguageCode(if (rite == "he") "he-x-gamliel" else "he")
            AppSettings.setLanguageFallbackOrder(listOf(AppSettings.defaultLanguageCode, "en", rite, "la"))
            val steps = PrayerEngine().buildSteps(Prayer(languageCode = rite))
            val index = steps.indexOfFirst { it.decadeIndex == 0 && it.hailMaryIndexInDecade == 3 }
            assertTrue(index >= 0)
            val layout = BeadLayout.build(steps, index, hasClosingCross = true)
            val spoken = layout.accessibilityDescription(rite, "rosary", "he", ::localized)
            assertEquals("רז 1 מתוך 5, $expected 3 מתוך 10", spoken)
            assertFalse(spoken.contains(excluded))
            val english = layout.accessibilityDescription(rite, "rosary", "en") { id, arguments ->
                localized(id, arguments, "values")
            }
            assertEquals("Decade 1 of 5, Hail Mary 3 of 10", english)
            assertEquals("רז 1 מתוך 5, תפילה 3 מתוך 10",
                layout.accessibilityDescription("en", "rosary", "he", ::localized))
        }
    }

    private fun label(key: String, language: String, ui: String = "he") =
        RosaryRiteLabels.optionLabel(key, language, ui, ::localized)

    private fun localized(resource: Int, arguments: List<Any>): String = localized(resource, arguments, "values-iw")

    private fun localized(resource: Int, arguments: List<Any>, folder: String): String {
        val name = R.string::class.java.fields.first { it.getInt(null) == resource }.name
        val nodes = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/$folder/strings.xml")).getElementsByTagName("string")
        val template = (0 until nodes.length).map { nodes.item(it) }
            .single { it.attributes.getNamedItem("name").nodeValue == name }.textContent.trim('"')
        return String.format(Locale.ROOT, template, *arguments.toTypedArray())
    }
}
