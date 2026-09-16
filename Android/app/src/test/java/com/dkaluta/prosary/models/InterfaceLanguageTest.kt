package com.dkaluta.prosary.models

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.*
import org.junit.Test
import org.w3c.dom.Element

class InterfaceLanguageTest {
    @Test fun interfaceCatalogMatchesTheAdvertisedAndroidLanguages() {
        val document = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/xml/locales_config.xml"))
        val entries = document.getElementsByTagName("locale")
        val advertised = (0 until entries.length).map {
            InterfaceLanguage.normalized((entries.item(it) as Element).getAttribute("android:name"))
        }
        assertEquals(setOf("en", "he", "ar", "ru", "tl", "fr", "it", "uk"), advertised.toSet())
        assertEquals(InterfaceLanguage.codes.toSet(), advertised.toSet())
        assertEquals(advertised.size, advertised.toSet().size)
    }

    @Test fun aliasesRegionsAndUnsupportedSystemLanguagesResolveToShippedResources() {
        assertEquals("he", InterfaceLanguage.normalized("iw-IL"))
        assertEquals("tl", InterfaceLanguage.normalized("fil-PH"))
        assertEquals("fil", InterfaceLanguage.platformCode("tl"))
        assertEquals("uk", InterfaceLanguage.normalized("uk_UA"))
        assertEquals("", InterfaceLanguage.normalized(""))
        assertEquals("", InterfaceLanguage.normalized("la"))
        assertEquals("", InterfaceLanguage.normalized("arc"))
        assertEquals("fr", InterfaceLanguage.effective(listOf("de-DE", "fr-CA")))
        assertEquals("en", InterfaceLanguage.effective(listOf("de-DE", "es-ES")))
        assertEquals("en", InterfaceLanguage.effective(emptyList()))
    }

    @Test fun appLanguageChangesOnlyInheritedPrayerSelections() {
        val saved = AppSettings.interfaceLanguageCode
        val previousEffective = AppSettings.effectiveInterfaceLanguageCode
        val savedPrayer = AppSettings.defaultLanguageCode
        try {
            AppSettings.setDefaultLanguageCode("")
            val inherited = Prayer()
            val explicit = listOf("la", "arc", "he-x-gamliel", "en").map { Prayer(languageCode = it) }
            for (code in InterfaceLanguage.codes) {
                AppSettings.setInterfaceLanguageCode(code)
                assertEquals(code, inherited.resolvedLanguageCode)
                assertEquals("", inherited.languageCode)
                explicit.forEach { assertEquals(it.languageCode, it.resolvedLanguageCode) }
            }
            AppSettings.setInterfaceLanguageCode("")
            AppSettings.updateEffectiveInterfaceLanguage(listOf("iw-IL"))
            assertEquals("", AppSettings.interfaceLanguageCode)
            assertEquals("he", inherited.resolvedLanguageCode)
            AppSettings.updateEffectiveInterfaceLanguage(listOf("fil-PH"))
            assertEquals("tl", inherited.resolvedLanguageCode)
        } finally {
            AppSettings.updateEffectiveInterfaceLanguage(listOf(previousEffective))
            AppSettings.setInterfaceLanguageCode(saved)
            AppSettings.setDefaultLanguageCode(savedPrayer)
        }
    }

    @Test fun explicitGlobalPrayerLanguageSurvivesInterfaceChangesAndCanReturnToFollowing() {
        val saved = AppSettings.interfaceLanguageCode
        val savedPrayer = AppSettings.defaultLanguageCode
        try {
            val inherited = Prayer()
            val explicit = Prayer(languageCode = "fr")
            for (global in listOf("arc", "la", "he-x-gamliel")) {
                AppSettings.setDefaultLanguageCode(global)
                for (ui in listOf("en", "he", "uk")) {
                    AppSettings.setInterfaceLanguageCode(ui)
                    assertEquals(ui, LanguageCatalog.uiLanguageCode())
                    assertEquals(global, AppSettings.defaultLanguageCode)
                    assertEquals(global, inherited.resolvedLanguageCode)
                    assertEquals("fr", explicit.resolvedLanguageCode)
                }
            }
            AppSettings.setDefaultLanguageCode("")
            assertEquals("uk", inherited.resolvedLanguageCode)
            assertEquals("fr", explicit.resolvedLanguageCode)
        } finally {
            AppSettings.setInterfaceLanguageCode(saved)
            AppSettings.setDefaultLanguageCode(savedPrayer)
        }
    }

    @Test fun everyInterfaceLocaleHasTheAppLanguageAndInheritanceLabels() {
        for (directory in listOf("values", "values-iw", "values-ar", "values-ru", "values-tl", "values-b+fil", "values-fr", "values-it", "values-uk")) {
            val document = DocumentBuilderFactory.newInstance().newDocumentBuilder()
                .parse(File("src/main/res/$directory/strings.xml"))
            val strings = document.getElementsByTagName("string")
            val values = (0 until strings.length).associate {
                val element = strings.item(it) as Element
                element.getAttribute("name") to element.textContent.trim('"')
            }
            val label = values.getValue("settings_app_language")
            assertTrue(directory, label.isNotBlank())
            assertTrue(directory, values.getValue("settings_language_system_default").isNotBlank())
            assertTrue(directory, values.getValue("settings_app_language_hint").isNotBlank())
            assertEquals(directory, "$label (%1\$s)", values.getValue("settings_follow_app_language"))
            assertTrue(directory, values.getValue("settings_prayer_language").isNotBlank())
            assertTrue(directory, values.getValue("language_default_parenthesized").contains("%1\$s"))
            if (directory == "values-iw") assertEquals("שפת היישומון", label)
        }
    }
}
