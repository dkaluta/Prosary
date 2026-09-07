package com.dkaluta.prosary.models

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.prayerTranslationsHebrewGamaliel
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.io.File
import org.junit.Assert.*
import org.junit.BeforeClass
import org.junit.Test

class HebrewLanguageSelectionTests {
    private val mission = "he-x-gamliel"

    companion object {
        @BeforeClass @JvmStatic fun loadPacks() {
            PrayerPackStore.initialize { name ->
                File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream()
            }
        }
    }

    private fun withOrder(order: List<String>, check: () -> Unit) {
        val previous = AppSettings.languageFallbackOrder
        try {
            AppSettings.setLanguageFallbackOrder(order)
            check()
        } finally { AppSettings.setLanguageFallbackOrder(previous) }
    }

    @Test fun enteringHebrewUsesFirstSavedTraditionFromOtherLanguagesAndAppSetting() {
        for (order in listOf(listOf(mission, "arc", "he"), listOf("he", "arc", mission))) withOrder(order) {
            for (current in LanguageCatalog.all.map { it.code }.filter { it != "he" && it != mission } + "") {
                assertEquals(current, order.first(), LanguageCatalog.selectingLanguage("he", current))
            }
            assertEquals(order, AppSettings.languageFallbackOrder)
        }
    }

    @Test fun alreadySelectedHebrewTraditionRemainsExplicitInEitherOrder() {
        for (order in listOf(listOf(mission, "arc", "he"), listOf("he", "arc", mission))) withOrder(order) {
            for (current in listOf("he", mission)) assertEquals(current, LanguageCatalog.selectingLanguage("he", current))
        }
    }

    @Test fun leavingHebrewAndReturningUsesPriorityAgain() {
        for ((order, previous) in listOf(listOf(mission, "arc", "he") to "he", listOf("he", "arc", mission) to mission)) withOrder(order) {
            val english = LanguageCatalog.selectingLanguage("en", previous)
            assertEquals("en", english)
            assertEquals(order.first(), LanguageCatalog.selectingLanguage("he", english))
        }
    }

    @Test fun otherLanguageAndEmptyChoicesArePassedThrough() = withOrder(listOf(mission, "arc", "he")) {
        for (next in LanguageCatalog.all.map { it.code }.filter { it != "he" } + listOf("", "unknown")) {
            for (current in listOf("he", mission, "en", "")) assertEquals(next, LanguageCatalog.selectingLanguage(next, current))
        }
    }

    @Test fun emptyAndDamagedSavedOrdersUseOnlyKnownDistinctTraditions() {
        for ((order, expected) in listOf(
            emptyList<String>() to "he", listOf("unknown") to "he",
            listOf("unknown", LanguageCatalog.hebrewVicariateContentCode, mission, mission, "arc", "he") to mission,
            listOf("unknown", "he", "he", "arc", mission) to "he",
        )) withOrder(order) {
            assertEquals(expected, LanguageCatalog.selectingLanguage("he", ""))
            assertEquals(1, LanguageCatalog.fallbackOrder.count { it == expected })
            assertFalse("unknown" in LanguageCatalog.fallbackOrder)
            assertFalse(LanguageCatalog.hebrewVicariateContentCode in LanguageCatalog.fallbackOrder)
        }
    }

    @Test fun selectedMissionCodeReachesItsRealPrayerTextAndAppDefault() = withOrder(listOf(mission, "arc", "he")) {
        val previousDefault = AppSettings.defaultLanguageCode
        try {
            val prayer = requireNotNull(BasicPrayerCatalog.prayer("ourFather"))
            val expected = prayerTranslationsHebrewGamaliel.getValue(PrayerKey.PaterNoster)
            val selected = LanguageCatalog.selectingLanguage("he", "en")
            val step = BasicPrayerCatalog.step(prayer, selected)
            assertEquals(expected, step.body)
            assertEquals("תפילת האדון", step.title)
            assertNotEquals(step.body, BasicPrayerCatalog.step(prayer, "he").body)
            AppSettings.setDefaultLanguageCode(selected)
            assertEquals(expected, BasicPrayerCatalog.step(prayer, "").body)
            assertEquals(mission, LanguageCatalog.resolve("").code)
        } finally { AppSettings.setDefaultLanguageCode(previousDefault) }
    }
}
