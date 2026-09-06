package com.dkaluta.prosary.typography

import androidx.compose.runtime.derivedStateOf
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.LayoutDirection
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.shared.PrayerNavigation
import java.io.File
import org.junit.After
import org.junit.Assert.*
import org.junit.Test

class PrayerTypographyTest {
    @After fun reset() {
        AppSettings.setSyriacTypeface(AppSettings.TYPEFACE_DEFAULT)
        AppSettings.setHebrewPrayerTypeface(AppSettings.TYPEFACE_DEFAULT)
        AppSettings.setHebrewScriptureTypeface(AppSettings.TYPEFACE_DEFAULT)
        AppSettings.setLatinPrayerTypeface(AppSettings.TYPEFACE_DEFAULT)
        AppSettings.setCyrillicPrayerTypeface(AppSettings.TYPEFACE_DEFAULT)
    }

    @Test fun scriptUsesLettersAndDistinguishesCyrillic() {
        assertEquals(PrayerTypography.Script.Syriac, PrayerTypography.scriptOf("ܐܒܘܢ ܕܒܫܡܝܐ — 123:4–5"))
        assertEquals(PrayerTypography.Script.Hebrew, PrayerTypography.scriptOf("אבון דבשמיא"))
        assertEquals(PrayerTypography.Script.Cyrillic, PrayerTypography.scriptOf("Господи Иисусе Христе"))
        assertEquals(PrayerTypography.Script.Greek, PrayerTypography.scriptOf("Κύριε Ἰησοῦ Χριστέ"))
        assertEquals(PrayerTypography.Script.Arabic, PrayerTypography.scriptOf("أبانا الذي في السماوات"))
        assertEquals(PrayerTypography.Script.Latin, PrayerTypography.scriptOf("Éééééé אב"))
        assertEquals(PrayerTypography.Script.Latin, PrayerTypography.scriptOf("123 — **"))
        assertEquals(PrayerTypography.Script.Latin, PrayerTypography.scriptOf("ééé אֱֽ֑֤֖֗֙"))
    }

    @Test fun customSyriacBodyRespondsToTheAramaicFaceImmediately() {
        val liveStyle = derivedStateOf { PrayerTypography.styleForText("ܐܒܘܢ ܕܒܫܡܝܐ", false) }
        val initial = liveStyle.value.fontFamily
        AppSettings.setSyriacTypeface(AppSettings.TYPEFACE_WESTERN)
        val western = liveStyle.value.fontFamily
        AppSettings.setSyriacTypeface(AppSettings.TYPEFACE_EASTERN)
        assertNotEquals(initial, western)
        assertNotEquals(western, liveStyle.value.fontFamily)
        // Hebrew-script Aramaic still uses the Hebrew prayer face.
        assertEquals(PrayerTypography.style("arc", false).fontFamily,
            PrayerTypography.styleForText("אבון דבשמיא", false).fontFamily)
    }

    @Test fun separateLatinAndCyrillicFacesPreserveScriptureAndBundledChoices() {
        val latin = derivedStateOf { PrayerTypography.styleForText("Notre Père", false) }
        val cyrillic = derivedStateOf { PrayerTypography.styleForText("Отче наш", false) }
        val scripture = PrayerTypography.styleForText("In principio", true).fontFamily
        val cyrillicScripture = PrayerTypography.styleForText("В начале", true).fontFamily
        AppSettings.setLatinPrayerTypeface(AppSettings.TYPEFACE_SANS_SERIF)
        assertEquals(FontFamily.SansSerif, latin.value.fontFamily)
        assertEquals(FontFamily.Serif, cyrillic.value.fontFamily)
        AppSettings.setCyrillicPrayerTypeface(AppSettings.TYPEFACE_SANS_SERIF)
        assertEquals(FontFamily.SansSerif, cyrillic.value.fontFamily)
        assertEquals(scripture, PrayerTypography.styleForText("In principio", true).fontFamily)
        assertEquals(cyrillicScripture, PrayerTypography.styleForText("В начале", true).fontFamily)
        assertEquals(FontFamily.Serif, PrayerTypography.styleForText("Κύριε Ἰησοῦ Χριστέ", false).fontFamily)
        AppSettings.setHebrewPrayerTypeface(AppSettings.TYPEFACE_SANS_SERIF)
        assertEquals(FontFamily.SansSerif, PrayerTypography.styleForText("אבינו", false).fontFamily)
        AppSettings.setHebrewPrayerTypeface(AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)
        assertNotEquals(FontFamily.SansSerif, PrayerTypography.styleForText("אבינו", false).fontFamily)
        assertEquals(AppSettings.TYPEFACE_BUNDLED_SANS_SERIF, AppSettings.migratedHebrewTypeface("sansSerif"))
        assertEquals("davidLibre", AppSettings.migratedHebrewTypeface("davidLibre"))
    }

    @Test fun renderedBodiesAndAcclamationsUseActualText() {
        val source = File("src/main/java/com/dkaluta/prosary/ui/shared/PrayerStepFlowScreen.kt").readText()
        assertTrue(source.contains("PrayerTypography.styleForText(acclamation, isScripture = false)"))
        assertTrue(source.contains("PrayerTypography.styleForText(step.body, isScripture = step.isScripture)"))
        assertTrue(source.contains("text = if (showsTransliteration) step.transliteratedBody!! else step.body"))
    }

    @Test fun navigationMirrorsTheInterfaceOnceAndPreservesCommandMeanings() {
        assertEquals(LayoutDirection.Rtl, PrayerNavigation.direction("iw-IL"))
        assertEquals(LayoutDirection.Rtl, PrayerNavigation.direction("ar"))
        assertEquals(LayoutDirection.Ltr, PrayerNavigation.direction("en"))
        assertEquals(-1f, PrayerNavigation.iconScale(PrayerNavigation.direction("he")))
        assertEquals(1f, PrayerNavigation.iconScale(PrayerNavigation.direction("ru")))
        val source = File("src/main/java/com/dkaluta/prosary/ui/rosaryflow/RosaryFlowScreen.kt").readText()
        assertTrue(source.contains("InterfaceNavigation {"))
        assertTrue(source.contains("onClick = { previousMystery?.let { currentIndex = it } }"))
        assertTrue(source.contains("onClick = { nextMystery?.let { currentIndex = it } }"))
    }
}
