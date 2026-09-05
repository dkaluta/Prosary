package com.dkaluta.prosary.models

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

/** Resource-level contracts catch silent Android fallback and format-argument crashes. */
class UILocalizationTest {
    private fun strings(directory: String): Map<String, List<String>> {
        val document = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/$directory/strings.xml"))
        val result = linkedMapOf<String, List<String>>()
        val children = document.documentElement.childNodes
        for (index in 0 until children.length) {
            val element = children.item(index) as? Element ?: continue
            when (element.tagName) {
                "string" -> result[element.getAttribute("name")] = listOf(element.textContent)
                "string-array" -> {
                    val items = element.getElementsByTagName("item")
                    result[element.getAttribute("name")] = (0 until items.length).map { items.item(it).textContent }
                }
            }
        }
        return result
    }

    @Test
    fun everyInterfaceLanguageHasEveryStringAndPreservesFormatArguments() {
        val english = strings("values")
        val arguments = Regex("%[0-9]+\\\$[sd]")
        for (directory in listOf("values-iw", "values-ar", "values-ru", "values-tl", "values-b+fil", "values-fr", "values-it")) {
            val localized = strings(directory)
            assertEquals("$directory keys", english.keys, localized.keys)
            for ((key, originals) in english) {
                val translations = localized.getValue(key)
                assertEquals("$directory/$key item count", originals.size, translations.size)
                originals.zip(translations).forEach { (source, translated) ->
                    assertTrue("$directory/$key blank", translated.trim().trim('"').isNotBlank())
                    assertEquals("$directory/$key arguments", arguments.findAll(source).map { it.value }.sorted().toList(), arguments.findAll(translated).map { it.value }.sorted().toList())
                }
            }
        }
        assertEquals("Both Android Tagalog locale spellings must match", strings("values-tl"), strings("values-b+fil"))
    }

    @Test
    fun filipinoAliasesResolveToTagalogContentAndNewPrayerLanguagesStaySelectable() {
        assertEquals("tl", LanguageCatalog.uiLanguageCode("fil"))
        assertEquals("tl-ph", LanguageCatalog.uiLanguageCode("fil_PH"))
        assertEquals("he-il", LanguageCatalog.uiLanguageCode("iw-IL"))
        assertEquals("tl", LanguageCatalog.resolve("fil").code)
        assertEquals("tl", LanguageCatalog.resolve("fil-PH").code)
        assertEquals(listOf("tl-ph", "tl"), LanguageCatalog.fallbackChain("fil-PH").take(2))
        assertEquals("fr", LanguageCatalog.resolve("fr").code)
        assertEquals("it", LanguageCatalog.resolve("it").code)
        assertTrue(LanguageCatalog.resolve("ar").isRightToLeft)
        assertFalse(LanguageCatalog.resolve("it").isRightToLeft)
    }
}
