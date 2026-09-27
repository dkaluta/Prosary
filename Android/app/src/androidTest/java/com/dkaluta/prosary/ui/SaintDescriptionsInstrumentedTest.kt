package com.dkaluta.prosary.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.ui.Modifier
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.UriHandler
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.test.junit4.v2.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import com.dkaluta.prosary.content.today.FeastDay
import com.dkaluta.prosary.content.today.FeastObservance
import com.dkaluta.prosary.ui.shared.SaintDescriptionsCard
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.decodeFromJsonElement
import org.junit.Assert.assertTrue
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test

class SaintDescriptionsInstrumentedTest {
    @get:Rule val compose = createAndroidComposeRule<AdaptiveLayoutTestActivity>()

    @Test fun disclosureIsOptInResetsByDateAndLanguageAndKeepsSourceWithItsBody() {
        val date = mutableStateOf("2026-09-30")
        val language = mutableStateOf("en")
        var openedURL: String? = null
        val uriHandler = object : UriHandler { override fun openUri(uri: String) { openedURL = uri } }
        val feast = FeastDay("Saint", "Feast", observances = listOf(FeastObservance("Source name", "saint",
            titleByLanguage = mapOf("en" to "Saint name", "he" to "שם"),
            descriptionByLanguage = mapOf("en" to "First paragraph.\n\nSecond paragraph.", "he" to "תיאור"),
            descriptionSourceByLanguage = mapOf("en" to "https://example.org/saint"),
            descriptionCreditByLanguage = mapOf("en" to "Biography credit"))))
        compose.setContent {
            MaterialTheme {
                CompositionLocalProvider(LocalUriHandler provides uriHandler) {
                    SaintDescriptionsCard(feast.saintDescriptions("syriac", language.value), date.value, language.value)
                }
            }
        }
        compose.onNodeWithTag("saintDescriptionsToggle").assertExists()
        compose.onNodeWithText("First paragraph.").assertDoesNotExist()
        compose.onNodeWithTag("saintDescriptionsToggle").performClick()
        compose.onNodeWithText("Saint name").assertExists()
        compose.onNodeWithText("First paragraph.").assertExists()
        compose.onNodeWithText("Second paragraph.").assertExists()
        compose.onNodeWithText("Biography credit").assertExists()
        compose.onNodeWithText(compose.activity.getString(com.dkaluta.prosary.R.string.readings_source)).performClick()
        compose.runOnIdle { assertEquals("https://example.org/saint", openedURL); date.value = "2026-10-01" }
        compose.onNodeWithText("First paragraph.").assertDoesNotExist()
        compose.onNodeWithTag("saintDescriptionsToggle").performClick()
        compose.runOnIdle { language.value = "he" }
        compose.onNodeWithText("תיאור").assertDoesNotExist()
        compose.onNodeWithTag("saintDescriptionsToggle").performClick()
        compose.onNodeWithText("תיאור").assertExists()
        compose.onNodeWithText("Biography credit").assertDoesNotExist()
        compose.runOnIdle { language.value = "fr" }
        compose.onNodeWithTag("saintDescriptions").assertDoesNotExist()
    }
    @Test fun publishedOctoberFirstBiographiesDecodeAndRemainHebrewOnly() {
        val json = Json { ignoreUnknownKeys = true }
        val dataset = compose.activity.assets.open("data/feasts-syriac.json").bufferedReader().use { it.readText() }
        val day = json.parseToJsonElement(dataset).jsonObject.getValue("days").jsonObject.getValue("2026-10-01")
        val feast = json.decodeFromJsonElement<FeastDay>(day)
        val descriptions = feast.saintDescriptions("syriac", "iw-IL")
        assertEquals(3, descriptions.size)
        assertTrue(descriptions.all { it.text.isNotBlank() && it.sourceURL?.contains("/display-saint/") == true && it.credit?.contains("Urtotho") == true })
        for (language in listOf("en", "ar", "ru", "tl", "fr", "it", "uk")) {
            assertTrue(feast.saintDescriptions("syriac", language).isEmpty())
        }
        assertTrue(feast.saintDescriptions("roman", "he").isEmpty())
        compose.setContent {
            MaterialTheme {
                Column(Modifier.verticalScroll(rememberScrollState())) {
                    SaintDescriptionsCard(descriptions, "2026-10-01", "he")
                }
            }
        }
        for (saint in descriptions) compose.onNodeWithText(saint.title).assertDoesNotExist()
        compose.onNodeWithTag("saintDescriptionsToggle").performClick()
        for (saint in descriptions) compose.onNodeWithText(saint.title).assertExists()
    }

}
