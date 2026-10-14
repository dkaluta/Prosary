package com.dkaluta.prosary.models

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.ui.shared.CustomDevotionPrayerSession
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.zip.ZipEntry
import java.util.zip.ZipFile
import java.util.zip.ZipOutputStream
import kotlinx.serialization.json.*
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test

class HebrewPrayerTitleRiteTest {
    private lateinit var savedDefault: String
    private lateinit var savedInterface: String
    private var savedFallback = emptyList<String>()
    private var savedNames = false
    private var savedFilioque: Boolean? = null

    @Before fun setUp() {
        savedDefault = AppSettings.defaultLanguageCode
        savedInterface = AppSettings.interfaceLanguageCode
        savedFallback = AppSettings.languageFallbackOrder
        savedNames = AppSettings.showPrayerNameInPrayerLanguage
        savedFilioque = AppSettings.includeFilioqueChoice
        AppSettings.setDefaultLanguageCode("he-x-gamliel")
        AppSettings.setInterfaceLanguageCode("he")
        AppSettings.setLanguageFallbackOrder(listOf("he-x-gamliel", "en", "he", "la"))
        reloadBuiltIns()
    }

    @After fun tearDown() {
        AppSettings.setDefaultLanguageCode(savedDefault)
        AppSettings.setInterfaceLanguageCode(savedInterface)
        AppSettings.setLanguageFallbackOrder(savedFallback)
        AppSettings.showPrayerNameInPrayerLanguage = savedNames
        AppSettings.restoreFilioqueForTesting(savedFilioque)
        reloadBuiltIns()
    }

    @Test fun hebrewBasicPrayerNamesKeepEachRiteWithoutAddingTheOtherRiteAsATranslation() {
        val names = mapOf(
            "ourFather" to ("אבינו שבשמים" to "תפילת האדון"),
            "hailMary" to ("שלום לך" to "שלום לך מרים"),
            "gloryBe" to ("שבח לאב" to "השבח לאב"),
            "creed" to ("אני מאמין" to "מאמינים של ניקאה"),
            "niceneCreed" to ("אני מאמין של ניקיאה" to "מאמינים של ניקאה"),
            "holyGod" to ("קדוש האלהים" to "קדישת"),
        )
        for ((id, pair) in names) {
            val prayer = BasicPrayerCatalog.all.single { it.id == id }
            for ((rite, name) in listOf("he" to pair.first, "he-x-gamliel" to pair.second)) {
                if (!BasicPrayerCatalog.isAvailable(prayer, rite)) {
                    assertNull(BasicPrayerCatalog.prayer(id, rite))
                    continue
                }
                assertEquals("$id $rite reader", name, BasicPrayerCatalog.step(prayer, rite).title)
                for (enabled in listOf(false, true)) {
                    // Cards feed both the Basic Prayers list and pinned Pray cards.
                    assertEquals("$id $rite list/pin", PrayerCardTitle(name),
                        BasicPrayerCatalog.cardTitle(prayer, rite, "he", enabled))
                    assertEquals("$id $rite legacy Hebrew alias", PrayerCardTitle(name),
                        BasicPrayerCatalog.cardTitle(prayer, rite, "iw-IL", enabled))
                }
            }
        }
        val ourFather = requireNotNull(BasicPrayerCatalog.prayer("ourFather"))
        assertEquals(PrayerCardTitle("תפילת האדון", "Our Father"),
            BasicPrayerCatalog.cardTitle(ourFather, "he-x-gamliel", "en", true))
        assertEquals(PrayerCardTitle("תפילת האדון"), BasicPrayerCatalog.cardTitle(ourFather, "", "he", true))
    }

    @Test fun vicariateTrisagionNamesCannotBeReplacedByTheGlobalMissionRite() {
        val info = requireNotNull(PrayerPackStore.info("trisagion"))
        for (enabled in listOf(false, true)) {
            AppSettings.showPrayerNameInPrayerLanguage = enabled
            assertEquals(PrayerCardTitle("טריסאגיון"), info.cardTitle("he", "he"))
            assertEquals(PrayerCardTitle("קדישת"), info.cardTitle("he-x-gamliel", "he"))
            assertEquals("טריסאגיון", info.interfaceDisplayName("he", "he"))
            assertEquals("קדישת", info.localizedDisplayName)
        }
        AppSettings.showPrayerNameInPrayerLanguage = false
        assertEquals(PrayerCardTitle("Trisagion"), info.cardTitle("he-x-gamliel", "en"))
        AppSettings.showPrayerNameInPrayerLanguage = true
        assertEquals(PrayerCardTitle("קדישת", "Trisagion"), info.cardTitle("he-x-gamliel", "en"))
        AppSettings.setInterfaceLanguageCode("en")
        assertEquals("Trisagion", info.localizedDisplayName)
    }

    @Test fun soleAuthoredRiteControlsHebrewNamesBeforeAnInterveningEnglishFallback() {
        for ((source, selected, expected) in listOf(
            Triple("he", "he-x-gamliel", "טריסאגיון"),
            Triple("he-x-gamliel", "he", "קדישת"),
        )) {
            loadSoleRite(source)
            val info = requireNotNull(PrayerPackStore.info("titleFixture"))
            assertEquals(source, PrayerPackStore.effectiveLanguage(info.bundleId, selected))
            assertEquals(expected, info.interfaceDisplayName(selected, "he"))
            for (enabled in listOf(false, true)) {
                AppSettings.showPrayerNameInPrayerLanguage = enabled
                assertEquals(PrayerCardTitle(expected), info.cardTitle(selected, "he"))
            }
        }
    }

    @Test fun missingExactRiteManifestNameUsesTheExistingGenericHebrewName() {
        val info = requireNotNull(PrayerPackStore.info("trisagion"))
            .copy(displayNameByLanguage = mapOf("he" to "טריסאגיון"))
        AppSettings.showPrayerNameInPrayerLanguage = true
        assertEquals(PrayerCardTitle("טריסאגיון"), info.cardTitle("he-x-gamliel", "he"))
    }

    @Test fun nonHebrewPrayerLanguageDoesNotChangeTheHebrewInterfaceName() {
        val info = requireNotNull(PrayerPackStore.info("trisagion"))
        AppSettings.showPrayerNameInPrayerLanguage = false
        assertEquals(PrayerCardTitle("טריסאגיון"), info.cardTitle("en", "he"))
        assertEquals("טריסאגיון", info.interfaceDisplayName("en", "he"))
    }

    @Test fun sparseNonHebrewTitlesRemainAuthoredEvenWhenTheBodyUsesAnotherLanguage() {
        val sourcedUkrainianTitle = requireNotNull(PrayerPackStore.info("trisagion")).displayNameIn("uk")
        loadSoleRite("he")
        val info = requireNotNull(PrayerPackStore.info("titleFixture"))
            .copy(displayNameByLanguage = mapOf("uk" to sourcedUkrainianTitle, "en" to "Trisagion"))
        assertNotEquals("uk", PrayerPackStore.effectiveLanguage(info.bundleId, "uk"))
        AppSettings.showPrayerNameInPrayerLanguage = true
        assertEquals(PrayerCardTitle(sourcedUkrainianTitle, "Trisagion"), info.cardTitle("uk", "en"))
    }

    @Test fun initialReaderNameUsesItsExplicitPresetOrEntryLanguageBeforeLoading() {
        val preset = Prayer(kind = PrayerKind.Custom, customDevotionId = "trisagion", languageCode = "he")
        val vicariate = CustomDevotionPrayerSession("trisagion", preset, null, null)
        assertEquals("טריסאגיון", vicariate.displayName.value)
        val mission = CustomDevotionPrayerSession("trisagion", preset, null, "he-x-gamliel")
        assertEquals("קדישת", mission.displayName.value)
        assertEquals("he-x-gamliel", AppSettings.defaultLanguageCode)
    }

    private fun reloadBuiltIns() {
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream() }
    }

    private fun loadSoleRite(source: String) {
        // Use the shipped prayer and its sourced headings unchanged; only the fixture's
        // availability differs, as with an imported pack that contains one Hebrew rite.
        val content = ZipFile(File("src/main/assets/trisagion.prosaryprayer")).use { zip ->
            zip.getInputStream(zip.getEntry("content/$source.json")).use { it.readBytes().toString(Charsets.UTF_8) }
        }
        val bytes = ByteArrayOutputStream()
        ZipOutputStream(bytes).use { zip ->
            fun add(name: String, text: String) {
                zip.putNextEntry(ZipEntry(name)); zip.write(text.toByteArray()); zip.closeEntry()
            }
            add("manifest.json", buildJsonObject {
                put("schemaVersion", 1); put("id", "titleFixture"); put("kind", "titleFixture")
                put("displayName", "Trisagion"); put("languages", JsonArray(listOf(JsonPrimitive("he"))))
                put("hasCatalog", false)
                put("displayNameByLanguage", buildJsonObject {
                    put("he", "טריסאגיון"); put("he-x-gamliel", "קדישת")
                })
            }.toString())
            add("devotion.json", """{"type":"steps","steps":[{"titleKey":"trisagionAcclamationTitle","bodyKey":"trisagionAcclamation"}]}""")
            add("content/$source.json", content)
        }
        PrayerPackStore.resetForTesting()
        PrayerPackStore.initialize { name -> if (name == "rosary") bytes.toByteArray().inputStream() else null }
    }
}
