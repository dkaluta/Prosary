package com.dkaluta.prosary.models

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.io.File
import org.junit.Assert.*
import org.junit.BeforeClass
import org.junit.Test

class BasicPrayerTitleTest {
    companion object {
        @BeforeClass @JvmStatic fun loadPacks() {
            PrayerPackStore.initialize { name ->
                File("src/main/assets/$name.prosaryprayer").takeIf(File::exists)?.inputStream()
            }
        }
    }

    @Test fun everyPrayerLanguageKeepsItsHeadingWithAnOptionalInterfaceSubtitle() {
        val titles = mapOf(
            "la" to "Pater Noster", "en" to "Our Father", "he" to "אבינו שבשמים",
            "he-x-gamliel" to "תפילת האדון", "arc" to "צלותא מרניתא", "ar" to "الأبانا",
            "el" to "Πάτερ ημών", "es" to "Padre nuestro", "ru" to "Отче наш",
            "tl" to "Ama Namin", "fr" to "Notre Père", "it" to "Padre nostro",
            "uk" to "Отче наш",
        )
        assertEquals(LanguageCatalog.all.map { it.code }.toSet(), titles.keys)
        for ((language, expectedOurFather) in titles) for (prayer in BasicPrayerCatalog.all) {
            val title = BasicPrayerCatalog.step(prayer, language).title
            val interfaceTitle = BasicPrayerCatalog.title(prayer, "he")
            for (enabled in listOf(false, true)) {
                val name = BasicPrayerCatalog.cardTitle(prayer, language, "he", enabled)
                assertEquals("${prayer.id}, $language, $enabled", title, name.primary)
                assertEquals(interfaceTitle.takeIf { enabled && it != title }, name.interfaceSubtitle)
                if (prayer.id == "ourFather") assertEquals(expectedOurFather, name.primary)
            }
        }
    }

    @Test fun defaultLanguageChangesRefreshTitlesWithoutChangingAnExplicitOverride() {
        val savedDefault = AppSettings.defaultLanguageCode
        val savedBasic = AppSettings.basicPrayersLanguageCode
        try {
            AppSettings.setBasicPrayersLanguageCode("")
            val prayer = requireNotNull(BasicPrayerCatalog.prayer("ourFather"))
            for ((language, title) in listOf("he-x-gamliel" to "תפילת האדון", "arc" to "צלותא מרניתא")) {
                AppSettings.setDefaultLanguageCode(language)
                val following = BasicPrayerCatalog.cardTitle(prayer, AppSettings.basicPrayersLanguageCode, "he", false)
                assertEquals(title, following.primary)
                assertNull(following.interfaceSubtitle)
                assertEquals("Our Father", BasicPrayerCatalog.cardTitle(prayer, "en", "he", false).primary)
                assertEquals(language, LanguageCatalog.resolve("").code)
            }
        } finally {
            AppSettings.setDefaultLanguageCode(savedDefault)
            AppSettings.setBasicPrayersLanguageCode(savedBasic)
        }
    }

    @Test fun allFourMarianAntiphonsOpenAsTheirOwnSourcedBasicPrayer() {
        val ids = listOf("salveRegina", "almaRedemptorisMater", "aveReginaCaelorum", "reginaCaeli")
        assertEquals(BasicPrayerCatalog.all.size, BasicPrayerCatalog.all.map { it.id }.distinct().size)
        for (id in ids) {
            val prayer = requireNotNull(BasicPrayerCatalog.prayer(id))
            assertEquals("rosary", prayer.bundleId)
            assertEquals("${id}Title", prayer.titleKey)
            assertEquals(id, prayer.bodyKey)
            assertEquals("madonna_and_child", prayer.imageKey)
            for (language in LanguageCatalog.all.map { it.code }) {
                val step = BasicPrayerCatalog.step(prayer, language)
                assertTrue("$id, $language body", step.body.isNotBlank())
                assertNotEquals(prayer.bodyKey, step.body)
                assertNotEquals(prayer.titleKey, step.title)
                assertEquals(PrayerPackStore.resolveBodyText("rosary", language, id), step.body)
                assertEquals(PrayerPackStore.transliteration("rosary", language, id), step.transliteratedBody)
            }
        }
    }
}
