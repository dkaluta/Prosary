package com.dkaluta.prosary.models

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class UkrainianUiLocalizationTest {
    private fun entries(directory: String): Map<String, String> {
        val document = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/$directory/strings.xml"))
        return buildMap {
            val children = document.documentElement.childNodes
            for (index in 0 until children.length) {
                val node = children.item(index) as? Element ?: continue
                val key = node.getAttribute("name")
                if (node.tagName == "string") put(key, node.textContent)
                else {
                    val items = node.getElementsByTagName("item")
                    for (item in 0 until items.length) put("$key[$item]", items.item(item).textContent)
                }
            }
        }
    }

    @Test
    fun ukrainianCoversEveryInterfaceStringAndAttributionWithoutLosingFormatArguments() {
        val english = entries("values")
        val ukrainian = entries("values-uk")
        assertEquals("Every scalar and ordered attribution item has an authored translation", english.keys.toList(), ukrainian.keys.toList())
        val placeholders = Regex("%\\d+\\$[ds]")
        english.forEach { (key, value) ->
            val translated = ukrainian.getValue(key)
            assertTrue("Empty Ukrainian $key", translated.trim('"').isNotBlank())
            assertEquals(key, placeholders.findAll(value).map { it.value }.sorted().toList(),
                placeholders.findAll(translated).map { it.value }.sorted().toList())
        }
        assertEquals("\"Молитва\"", ukrainian["tab_pray"])
        assertEquals("\"Молитися\"", ukrainian["common_pray"])
        assertEquals("\"Вибрати дату\"", ukrainian["home_today_choose_date"])
        assertEquals("\"День %1\$d із %2\$d\"", ukrainian["multi_day_day_of"])
        assertEquals("\"Власна кількість\"", ukrainian["jp_custom"])
        assertEquals("\"Власні налаштування\"", ukrainian["rosary_custom"])
        assertTrue(ukrainian.getValue("about_calendar_data_body").contains("Української Греко-Католицької Церкви"))
    }

    @Test
    fun systemApplicationLanguagePickerAdvertisesUkrainian() {
        val document = DocumentBuilderFactory.newInstance().newDocumentBuilder()
            .parse(File("src/main/res/xml/locales_config.xml"))
        val locales = document.getElementsByTagName("locale")
        val codes = (0 until locales.length).map {
            (locales.item(it) as Element).getAttribute("android:name")
        }
        assertEquals(1, codes.count { it == "uk" })
    }
}
