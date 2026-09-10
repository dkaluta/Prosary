package com.dkaluta.prosary.models

import androidx.compose.runtime.derivedStateOf
import com.dkaluta.prosary.ui.shared.CustomDevotionPrayerSession
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
        val old = AppSettings.pinnedBasicPrayerIds
        val id = BasicPrayerCatalog.all.first().id
        val livePins = derivedStateOf { BasicPrayerCatalog.all.filter { it.id in AppSettings.pinnedBasicPrayerIds } }
        try {
            AppSettings.setBasicPrayerPinned(id, true)
            assertTrue(livePins.value.any { it.id == id })
            AppSettings.setBasicPrayerPinned(id, false)
            assertFalse(livePins.value.any { it.id == id })
            val home = File("src/main/java/com/dkaluta/prosary/ui/home/HomeScreen.kt").readText()
            assertTrue(home.contains("BasicPrayerCatalog.all.filter { it.id in AppSettings.pinnedBasicPrayerIds }"))
            assertTrue(home.contains("onOpenBasicPrayer(prayer.id)"))
            assertTrue(home.contains("basic:"))
            val list = File("src/main/java/com/dkaluta/prosary/ui/shared/BasicPrayersScreen.kt").readText()
            assertFalse(list.contains("applyFavorites"))
            assertTrue(list.contains("R.string.basic_prayers_pin"))
        } finally {
            AppSettings.setBasicPrayerPinned(id, id in old)
        }
    }

    @Test fun publicDownloadedLanguageNamesDoNotAssignAHebrewTradition() {
        for (code in listOf("he", "iw", "he-IL", "iw_IL", "he-x-vicariate")) {
            assertEquals(code, "עברית", LanguageCatalog.publicLanguageName(code))
        }
        assertEquals("עברית, עברית — נוסח השליחות, Tagalog, Français", LanguageCatalog.publicLanguageNames(
            listOf("he", "he-x-gamliel", "iw", "fil", "tl", "fr-FR")))
        assertEquals("de", LanguageCatalog.publicLanguageName("de-DE"))
        assertEquals("עברית", Prayer(languageCode = "he-x-gamliel").languageNativeName)
        assertEquals(listOf("he", "he-x-gamliel"), LanguageCatalog.rites("he").map { it.code })
        assertNotEquals(LanguageCatalog.rites("he")[0].nativeName, LanguageCatalog.rites("he")[1].nativeName)
    }

    @Test fun explicitMissionDownloadKeepsItsLocalizedIdentityWhilePickerStaysOneHebrew() {
        for (label in listOf("Mission of St. Gamaliel", "נוסח השליחות", "إرسالية القديس غمالائيل",
            "Миссия святого Гамалиила", "Misyon ni San Gamaliel", "Mission Saint-Gamaliel", "Missione di San Gamaliele")) {
            assertEquals("עברית — $label", LanguageCatalog.publicLanguageName("he-x-gamliel", label))
            assertEquals("עברית, עברית — $label", LanguageCatalog.publicLanguageNames(
                listOf("he", "iw", "he-x-gamliel", "iw-x-gamliel"), label))
            assertEquals("עברית — $label, עברית", LanguageCatalog.publicLanguageNames(
                listOf("he-x-gamliel", "he", "iw"), label))
        }
        assertEquals("עברית", LanguageCatalog.pickerLanguageName("he-x-gamliel"))
        assertEquals(listOf("he"), LanguageCatalog.availableOptions(listOf("he", "he-x-gamliel")).map { it.code })
    }

    @Test fun rosaryLitanyHandoffRetainsTheLanguageAndExplicitClosingForm() {
        val flow = File("src/main/java/com/dkaluta/prosary/ui/rosaryflow/RosaryFlowScreen.kt").readText()
        assertTrue(flow.contains("onOpenDevotion(\"litanyOfLoreto\", \"afterRosary\", languageCode)"))
        val destination = File("src/main/java/com/dkaluta/prosary/ui/shared/CustomDevotionFlowScreen.kt").readText()
        val favorite = Prayer(kind = PrayerKind.Custom, customDevotionId = "litanyOfLoreto",
            variantId = "standard", languageCode = "en")
        val handoff = CustomDevotionPrayerSession("litanyOfLoreto", favorite, "afterRosary", "he")
        assertEquals("afterRosary", handoff.variantId.value)
        assertEquals("he", handoff.chosenLanguage.value)
        val ordinary = CustomDevotionPrayerSession("litanyOfLoreto", favorite, null, null)
        assertEquals("standard", ordinary.variantId.value)
        assertEquals("en", ordinary.chosenLanguage.value)
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

    @Test fun closingOverridesResolveToOneGroupAndShareItsSavedRunIdentity() {
        val legacy = RosaryOptions(includeClosingIntentions = true)
        assertTrue(legacy.effectiveClosingPopeIntention)
        assertTrue(legacy.effectiveClosingBishopIntention)
        assertTrue(legacy.effectiveClosingDepartedIntention)
        assertEquals(PrayerRunSignatures.rosary(legacy), PrayerRunSignatures.rosary(legacy.copy(
            includeClosingPopeIntention = true, includeClosingBishopIntention = true, includeClosingDepartedIntention = true)))
        for (partial in listOf(
            legacy.copy(includeClosingBishopIntention = false),
            RosaryOptions(includeClosingPopeIntention = true),
            RosaryOptions(includeClosingBishopIntention = true),
            RosaryOptions(includeClosingDepartedIntention = true),
        )) {
            assertTrue(partial.effectiveClosingIntentions)
            assertTrue(partial.effectiveClosingPopeIntention)
            assertTrue(partial.effectiveClosingBishopIntention)
            assertTrue(partial.effectiveClosingDepartedIntention)
            assertEquals(PrayerRunSignatures.rosary(legacy), PrayerRunSignatures.rosary(partial))
            val disabled = partial.withClosingIntentions(false)
            assertFalse(disabled.includeClosingIntentions)
            assertFalse(disabled.effectiveClosingIntentions)
            assertNull(disabled.includeClosingPopeIntention)
            assertNull(disabled.includeClosingBishopIntention)
            assertNull(disabled.includeClosingDepartedIntention)
            assertEquals(PrayerRunSignatures.rosary(RosaryOptions()), PrayerRunSignatures.rosary(disabled))
        }
        val allDisabled = legacy.copy(
            includeClosingPopeIntention = false,
            includeClosingBishopIntention = false,
            includeClosingDepartedIntention = false,
        )
        assertFalse(allDisabled.effectiveClosingIntentions)
        assertEquals(PrayerRunSignatures.rosary(RosaryOptions()), PrayerRunSignatures.rosary(allDisabled))
        assertFalse(RosaryOptions().effectiveClosingIntentions)
        val persistence = File("src/main/java/com/dkaluta/prosary/persistence/PresetEntity.kt").readText()
        val migration = File("src/main/java/com/dkaluta/prosary/persistence/AppDatabase.kt").readText()
        for (name in listOf("Pope", "Bishop", "Departed")) {
            assertTrue(persistence.contains("val includeClosing${name}Intention: Boolean? = null"))
            assertTrue(persistence.contains("includeClosing${name}Intention = prayer.rosary.includeClosing${name}Intention"))
            assertTrue(migration.contains("ADD COLUMN includeClosing${name}Intention INTEGER DEFAULT NULL"))
        }
    }

    @Test fun genericRosaryOptionNormalizationPreservesOtherSettingsAndNullableInheritance() {
        val values = mapOf("antiphon" to "reginaCaeli", "openingFatimaPrayer" to "true")
        assertEquals(values, RosaryOptions.normalizedCustomOptions("rosary", values))
        val legacy = values + mapOf("closingIntentions" to "true", "closingPopeIntention" to "false")
        assertEquals(values + ("closingIntentions" to "true"), RosaryOptions.normalizedCustomOptions("rosary", legacy))
        assertEquals(legacy, RosaryOptions.normalizedCustomOptions("foreignRosary", legacy))
        assertEquals(
            values + ("closingIntentions" to "false"),
            RosaryOptions.normalizedCustomOptions("rosary", values + mapOf("closingPopeIntention" to "invalid")),
        )
        val disabled = RosaryOptions.normalizedCustomOptions("rosary", legacy) + ("closingIntentions" to "false")
        assertEquals(disabled, RosaryOptions.normalizedCustomOptions("rosary", disabled))
    }
}
