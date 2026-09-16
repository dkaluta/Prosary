package com.dkaluta.prosary

import android.content.Intent
import androidx.appcompat.app.AppCompatDelegate
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.core.os.LocaleListCompat
import androidx.test.core.app.ActivityScenario
import androidx.test.espresso.Espresso.pressBack
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.InterfaceLanguage
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.PrayerRunSignatures
import com.dkaluta.prosary.testing.PrayerSessionTestActivity
import org.junit.After
import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/** Changes the native app locale while the same navigation-owned prayer is in progress. */
@RunWith(AndroidJUnit4::class)
class PrayerLanguageContinuityInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private var scenario: ActivityScenario<PrayerSessionTestActivity>? = null
    private var originalLocales: String? = null

    @After fun close() {
        originalLocales?.let { original ->
            scenario?.onActivity {
                AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(original))
            }
            instrumentation.waitForIdleSync()
        }
        scenario?.close()
    }

    @Test fun inheritedTextRefreshesAcrossNativeLocaleRecreationWithoutLosingTheLiveStep() {
        for (mode in listOf("rosary", "jesus", "custom")) {
            open(mode, prayerLanguage = "", globalLanguage = "")
            advance(mode)
            val before = snapshot()
            val body = body()
            changeLocale("he")
            compose.waitUntil(10_000) { snapshot().language == "he" }
            val after = snapshot()
            assertEquals("$mode keeps its navigation-owned session", before.identity, after.identity)
            assertEquals("$mode keeps its step/repetition", before.index, after.index)
            assertEquals("The inherited choice stays inherited", "", after.chosenLanguage)
            assertTrue(after.ready)
            assertNotEquals("$mode renders the newly inherited Hebrew body", body, body())
            assertNoResumePrompt()
        }
    }

    @Test fun explicitGlobalAramaicSurvivesInterfaceChangesInEveryFlow() {
        verifyFixedPrayerLanguage(prayerLanguage = "", globalLanguage = "arc", expected = "arc")
    }

    @Test fun explicitPrayerEnglishSurvivesInterfaceChangesInEveryFlow() {
        verifyFixedPrayerLanguage(prayerLanguage = "en", globalLanguage = "", expected = "en")
    }

    @Test fun inheritedFormChangeFreezesActualLanguageAndBookmarkUntilAnExplicitSwitch() {
        open("trisagion", prayerLanguage = "", globalLanguage = "arc")
        advance("trisagion")
        val before = snapshot()
        val body = body()
        val definition = requireNotNull(PrayerPackStore.definition("trisagion"))
        assertNotEquals(definition.effectiveVariantId(null, "arc"), definition.effectiveVariantId(null, "en"))
        requireNotNull(scenario).onActivity { AppSettings.setDefaultLanguageCode("") }
        compose.waitUntil(10_000) { snapshot().frozenLanguage == "arc" }
        changeLocale("he")
        assertEquals(before.identity, snapshot().identity)
        assertEquals(before.index, snapshot().index)
        assertEquals("arc", snapshot().language)
        assertEquals("", snapshot().chosenLanguage)
        assertEquals("", AppSettings.defaultLanguageCode)
        assertEquals(body, body())
        assertNoResumePrompt()
        requireNotNull(scenario).onActivity {
            val bookmark = requireNotNull(it.customBookmarkForTest())
            assertEquals(before.index, bookmark.stepIndex)
            assertEquals("arc", bookmark.languageCode)
            assertEquals(PrayerRunSignatures.custom("trisagion", definition.effectiveVariantId(null, "arc"), 0, emptyMap()),
                bookmark.configurationSignature)
        }
        pressBack()
        compose.onNodeWithText("Open test prayer").performClick()
        compose.onNodeWithText(label(R.string.flow_continue)).performClick()
        assertEquals(before.index, snapshot().index)
        assertEquals("arc", snapshot().language)
        assertEquals(body, body())
        // Hebrew interface/default text must not expose a Hebrew-tradition control for this
        // still-Aramaic prayer. Explicit language selection retains the existing restart policy.
        compose.onNodeWithContentDescription(label(R.string.prayer_tradition)).assertDoesNotExist()
        compose.onNodeWithContentDescription(label(R.string.flow_prayer_language)).performClick()
        compose.onNodeWithText(LanguageCatalog.pickerLanguageName("en")).performScrollTo().performClick()
        assertEquals(0, snapshot().index)
        assertEquals("en", snapshot().language)
        assertNull(snapshot().frozenLanguage)
        assertTrue(snapshot().ready)
    }

    @Test fun finishingAFrozenFormLetsTheNextRunFollowTheNewAppLanguage() {
        open("trisagion", prayerLanguage = "", globalLanguage = "arc")
        advance("trisagion")
        requireNotNull(scenario).onActivity { AppSettings.setDefaultLanguageCode("") }
        compose.waitUntil(10_000) { snapshot().frozenLanguage == "arc" }
        changeLocale("he")
        val frozen = snapshot()
        compose.onNodeWithText(label(R.string.common_next)).performClick()
        compose.onNodeWithText(label(R.string.common_finish)).performClick()
        requireNotNull(scenario).onActivity { assertNull(it.customBookmarkForTest()) }
        compose.onNodeWithText("Open test prayer").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodes(hasTestTag("prayerProgress")).fetchSemanticsNodes().isNotEmpty()
        }
        compose.waitUntil(10_000) { snapshot().ready }
        assertNotEquals(frozen.identity, snapshot().identity)
        assertEquals(0, snapshot().index)
        assertEquals("he", snapshot().language)
        assertEquals("", snapshot().chosenLanguage)
        assertNull(snapshot().frozenLanguage)
        assertNoResumePrompt()
    }

    private fun verifyFixedPrayerLanguage(prayerLanguage: String, globalLanguage: String, expected: String) {
        for (mode in listOf("rosary", "jesus", "custom")) {
            open(mode, prayerLanguage, globalLanguage)
            advance(mode)
            val before = snapshot()
            val body = body()
            changeLocale("he")
            assertEquals("$mode keeps its entire live session", before, snapshot())
            // Angelus has no Aramaic text; its normal bundle-aware fallback stays fixed too.
            val effective = if (mode == "custom") PrayerPackStore.effectiveLanguage("angelus", expected) else expected
            assertEquals(effective, snapshot().language)
            assertEquals(body, body())
            assertEquals(globalLanguage, AppSettings.defaultLanguageCode)
            assertNoResumePrompt()
        }
    }

    private fun open(mode: String, prayerLanguage: String, globalLanguage: String) {
        scenario?.close()
        scenario = ActivityScenario.launch(Intent(instrumentation.targetContext, PrayerSessionTestActivity::class.java)
            .putExtra("runId", UUID.randomUUID().toString())
            .putExtra("mode", mode)
            .putExtra("prayerLanguage", prayerLanguage)
            .putExtra("globalPrayerLanguage", globalLanguage))
        requireNotNull(scenario).onActivity {
            if (originalLocales == null) originalLocales = AppCompatDelegate.getApplicationLocales().toLanguageTags()
        }
        changeLocale("en")
        compose.onNodeWithText("Open test prayer").performClick()
        compose.waitUntil(10_000) {
            compose.onAllNodes(hasTestTag("prayerProgress")).fetchSemanticsNodes().isNotEmpty()
        }
    }

    private fun advance(mode: String) {
        repeat(2) {
            compose.onNodeWithText(label(if (mode == "jesus") R.string.common_pray else R.string.common_next))
                .performClick()
        }
        assertEquals(2, snapshot().index)
    }

    private fun changeLocale(code: String) {
        requireNotNull(scenario).onActivity {
            // Bypass our Settings controller so synchronization must come from recreation,
            // just as when Android's system per-app language setting changes.
            AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(code))
        }
        instrumentation.waitForIdleSync()
        compose.waitUntil(10_000) {
            var ready = false
            requireNotNull(scenario).onActivity {
                ready = InterfaceLanguage.normalized(it.resources.configuration.locales[0].toLanguageTag()) == code &&
                    AppSettings.effectiveInterfaceLanguageCode == code
            }
            ready
        }
        compose.waitForIdle()
    }

    private fun snapshot(): PrayerSessionTestActivity.SessionSnapshot {
        lateinit var snapshot: PrayerSessionTestActivity.SessionSnapshot
        requireNotNull(scenario).onActivity { snapshot = it.sessionForTest() }
        return snapshot
    }

    private fun body(): List<String> {
        // The Jesus Prayer places its interface heading and Pray action inside the reader;
        // those should translate even when the prayer text has an explicit language.
        val interfaceLabels = setOf(label(R.string.kind_jesus_prayer), label(R.string.common_pray))
        return compose.onAllNodes(
            hasAnyAncestor(hasTestTag("prayerBody")), useUnmergedTree = true,
        ).fetchSemanticsNodes().flatMap { node ->
            node.config.getOrNull(SemanticsProperties.Text).orEmpty().map { it.text }
        }.filterNot { it in interfaceLabels }.also { assertTrue(it.isNotEmpty()) }
    }

    private fun label(resource: Int): String {
        lateinit var value: String
        requireNotNull(scenario).onActivity { value = it.getString(resource) }
        return value
    }

    private fun assertNoResumePrompt() = compose.onNodeWithText(label(R.string.flow_resume_title)).assertDoesNotExist()
}
