package com.dkaluta.prosary.models

import androidx.compose.runtime.derivedStateOf
import java.io.File
import org.junit.Assert.*
import org.junit.Test

class PrayerPreferencesTest {
    @Test fun oneHebrewLanguageRetainsTraditionAndExistingCodes() {
        assertEquals(listOf("he"), LanguageCatalog.publicOptions.filter { it.code.startsWith("he") }.map { it.code })
        assertEquals("he", LanguageCatalog.pickerLanguageCode("he-x-gamliel"))
        assertEquals("he-x-gamliel", LanguageCatalog.selectingLanguage("he", "he-x-gamliel"))
        assertEquals("he", LanguageCatalog.selectingLanguage("he", "fr"))
        assertEquals("", LanguageCatalog.selectingLanguage("", "he-x-gamliel"))
        assertEquals("ܐܪܡܐܝܬ / ארמית", LanguageCatalog.resolve("arc").nativeName)
        assertEquals("he-x-gamliel", LanguageCatalog.resolve("he-x-gamliel").code)
    }

    @Test fun oldBasicFavoritesAreHomePinsWithoutChangingManualListOrder() {
        val old = AppSettings.favoriteBasicPrayerIds
        val id = BasicPrayerCatalog.all.first().id
        val livePins = derivedStateOf { BasicPrayerCatalog.all.filter { it.id in AppSettings.favoriteBasicPrayerIds } }
        try {
            if (id !in AppSettings.favoriteBasicPrayerIds) AppSettings.toggleFavoriteBasicPrayer(id)
            assertTrue(livePins.value.any { it.id == id })
            AppSettings.toggleFavoriteBasicPrayer(id)
            assertFalse(livePins.value.any { it.id == id })
            val home = File("src/main/java/com/dkaluta/prosary/ui/home/HomeScreen.kt").readText()
            assertTrue(home.contains("BasicPrayerCatalog.all.filter { it.id in AppSettings.favoriteBasicPrayerIds }"))
            assertTrue(home.contains("onOpenBasicPrayer(prayer.id)"))
            assertTrue(home.contains("basic:"))
            val list = File("src/main/java/com/dkaluta/prosary/ui/shared/BasicPrayersScreen.kt").readText()
            assertFalse(list.contains("applyFavorites"))
            assertTrue(list.contains("R.string.basic_prayers_pin"))
        } finally {
            if ((id in AppSettings.favoriteBasicPrayerIds) != (id in old)) AppSettings.toggleFavoriteBasicPrayer(id)
        }
    }

    @Test fun rosaryLitanyHandoffRetainsTheLanguageAndExplicitClosingForm() {
        val flow = File("src/main/java/com/dkaluta/prosary/ui/rosaryflow/RosaryFlowScreen.kt").readText()
        assertTrue(flow.contains("onOpenDevotion(\"litanyOfLoreto\", \"afterRosary\", languageCode)"))
        val destination = File("src/main/java/com/dkaluta/prosary/ui/shared/CustomDevotionFlowScreen.kt").readText()
        assertTrue(destination.contains("DevotionEntryContext.initialVariant(devotionId, initialVariantId, prayer?.variantId)"))
        assertTrue(destination.contains("initialLanguageCode ?: prayer?.languageCode"))
        assertTrue(destination.contains("initialVariantId == null && initialLanguageCode == null"))
        assertTrue(destination.contains("initialLanguageCode == null || it.languageCode == configuredLanguage"))
    }

    @Test fun litanyEndingFollowsEntryEvenWhenFavoriteSavedAfterRosary() {
        assertEquals("standard", DevotionEntryContext.initialVariant("litanyOfLoreto", null, "afterRosary"))
        assertEquals("standard", DevotionEntryContext.initialVariant("litanyOfLoreto", null, null))
        assertEquals("afterRosary", DevotionEntryContext.initialVariant("litanyOfLoreto", "afterRosary", "standard"))
        assertEquals("scriptural", DevotionEntryContext.initialVariant("stations", null, "scriptural"))
        val flow = File("src/main/java/com/dkaluta/prosary/ui/shared/CustomDevotionFlowScreen.kt").readText()
        assertTrue(flow.contains("if (!variantFollowsEntry && variants != null"))
        assertTrue(flow.contains("if (!variantFollowsEntry && variantId == null"))
    }

    @Test fun closingOverridesPreserveLegacyDefaultsAndSavedRunIdentity() {
        val legacy = RosaryOptions(includeClosingIntentions = true)
        assertTrue(legacy.effectiveClosingPopeIntention)
        assertTrue(legacy.effectiveClosingBishopIntention)
        assertTrue(legacy.effectiveClosingDepartedIntention)
        assertEquals(PrayerRunSignatures.rosary(legacy), PrayerRunSignatures.rosary(legacy.copy(
            includeClosingPopeIntention = true, includeClosingBishopIntention = true, includeClosingDepartedIntention = true)))
        assertNotEquals(PrayerRunSignatures.rosary(legacy), PrayerRunSignatures.rosary(legacy.copy(includeClosingBishopIntention = false)))
        assertFalse(RosaryOptions().effectiveClosingPopeIntention)
        val persistence = File("src/main/java/com/dkaluta/prosary/persistence/PresetEntity.kt").readText()
        val migration = File("src/main/java/com/dkaluta/prosary/persistence/AppDatabase.kt").readText()
        for (name in listOf("Pope", "Bishop", "Departed")) {
            assertTrue(persistence.contains("val includeClosing${name}Intention: Boolean? = null"))
            assertTrue(persistence.contains("includeClosing${name}Intention = prayer.rosary.includeClosing${name}Intention"))
            assertTrue(migration.contains("ADD COLUMN includeClosing${name}Intention INTEGER DEFAULT NULL"))
        }
    }
}
