package com.dkaluta.prosary

import android.content.Intent
import androidx.compose.ui.semantics.SemanticsActions
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasContentDescription
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performScrollToNode
import androidx.compose.ui.text.TextLayoutResult
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.testing.PrayerSessionTestActivity
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.typography.PrayerTypography
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

@RunWith(AndroidJUnit4::class)
class AramaicPrayerHeadingInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private var scenario: ActivityScenario<PrayerSessionTestActivity>? = null

    @After fun close() { scenario?.close() }

    @Test fun initialAndToggledHeadingsMatchBodiesInRosaryTrisagionAndBasicPrayer() {
        for (script in listOf("Hebr", "Syrc")) for ((mode, bundle, key) in listOf(
            Triple("rosary", "rosary", "signumCrucisTitle"),
            Triple("trisagion", "trisagion", "trisagionAcclamationTitle"),
            Triple("basic", "rosary", "paterNosterTitle"),
        )) {
            open(mode, script)
            val initialSyriac = script == "Syrc"
            assertHeading(bundle, key, initialSyriac, checkTopTitle = mode == "basic")
            toggle()
            assertHeading(bundle, key, !initialSyriac, checkTopTitle = mode == "basic")
            toggle()
            assertHeading(bundle, key, initialSyriac, checkTopTitle = mode == "basic")
            assertEquals("A session toggle must not rewrite the global script preference", script, AppSettings.aramaicDefaultScript)
        }
    }

    @Test fun repeatedHailMaryChangesItsHeadingAndCounterTogether() {
        open("rosary", "Hebr")
        repeat(3) { compose.onNodeWithText(label(R.string.common_next)).performClick() }
        val hebrew = HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText("rosary", "arc", "aveMariaTitle"))
        val syriac = requireNotNull(PrayerPackStore.transliteration("rosary", "arc", "aveMariaTitle"))
        compose.onNodeWithTag("prayerStepTitle").performScrollTo().assertTextEquals("$hebrew (1 מן 3)")
        toggle()
        compose.onNodeWithTag("prayerStepTitle").performScrollTo().assertTextEquals("$syriac (1 ܡܶܢ 3)")
        requireNotNull(scenario).onActivity { assertEquals(3, it.rosaryIndexForTest().value) }
    }

    @Test fun missingAlternateKeepsHeadingInTheActualBodyScript() {
        open("scriptFallback", "Syrc")
        assertHeading("rosary", "paterNosterTitle", syriac = false, checkTopTitle = true)
        compose.onNodeWithContentDescription(label(R.string.flow_show_transliteration)).assertDoesNotExist()
        assertEquals("Syrc", AppSettings.aramaicDefaultScript)
    }

    private fun open(mode: String, script: String) {
        scenario?.close()
        scenario = ActivityScenario.launch(Intent(instrumentation.targetContext, PrayerSessionTestActivity::class.java)
            .putExtra("runId", UUID.randomUUID().toString()).putExtra("mode", mode)
            .putExtra("prayerLanguage", "arc").putExtra("globalPrayerLanguage", "arc")
            .putExtra("aramaicScript", script))
        compose.onNodeWithText("Open test prayer").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodes(hasTestTag("prayerStepTitle")).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun assertHeading(bundle: String, key: String, syriac: Boolean, checkTopTitle: Boolean) {
        val expected = if (syriac) requireNotNull(PrayerPackStore.transliteration(bundle, "arc", key))
            else HebrewDisplayText.unpoint(PrayerPackStore.resolveBodyText(bundle, "arc", key))
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasTestTag("prayerStepTitle"))
        val heading = compose.onNodeWithTag("prayerStepTitle").performScrollTo().assertTextEquals(expected)
        if (syriac) {
            val layouts = mutableListOf<TextLayoutResult>()
            val action = heading.fetchSemanticsNode().config.getOrNull(SemanticsActions.GetTextLayoutResult)?.action
            assertTrue(requireNotNull(action).invoke(layouts))
            assertEquals(PrayerTypography.styleForText(expected, false).fontFamily, layouts.single().layoutInput.style.fontFamily)
        }
        if (checkTopTitle) compose.onNodeWithTag("prayerFlowTitle").assertTextEquals(expected)
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasTestTag("prayerParagraph:0"))
        val paragraph = compose.onNodeWithTag("prayerParagraph:0", useUnmergedTree = true).performScrollTo()
            .fetchSemanticsNode().config[SemanticsProperties.Text].joinToString { it.text }
        assertEquals(if (syriac) PrayerTypography.Script.Syriac else PrayerTypography.Script.Hebrew,
            PrayerTypography.scriptOf(paragraph))
    }

    private fun toggle() {
        val description = label(R.string.flow_show_transliteration)
        compose.onNodeWithTag("prayerBody").performScrollToNode(hasContentDescription(description))
        compose.onNodeWithContentDescription(description).performClick()
    }

    private fun label(resource: Int): String {
        lateinit var text: String
        requireNotNull(scenario).onActivity { text = it.getString(resource) }
        return text
    }
}
