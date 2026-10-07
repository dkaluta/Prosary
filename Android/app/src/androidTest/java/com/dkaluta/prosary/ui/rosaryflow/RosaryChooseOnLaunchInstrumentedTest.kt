package com.dkaluta.prosary.ui.rosaryflow

import android.content.Context
import android.content.ContextWrapper
import android.content.SharedPreferences
import android.graphics.Bitmap
import androidx.compose.material3.Text
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.key
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasClickAction
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onLast
import androidx.compose.ui.test.performClick
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.viewmodel.compose.LocalViewModelStoreOwner
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.RosaryPrayerSession
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.io.FileOutputStream
import java.util.UUID
import kotlinx.coroutines.runBlocking

/** Real flow UI with an in-memory library and isolated preferences; never opens Room. */
@RunWith(AndroidJUnit4::class)
class RosaryChooseOnLaunchInstrumentedTest {
    @get:Rule val compose = createComposeRule()
    private lateinit var isolated: IsolatedContext
    private lateinit var session: RosaryPrayerSession
    private lateinit var presetStore: MockPresetStore
    private lateinit var savedSnapshot: Prayer
    private lateinit var activeOwner: TestViewModelOwner
    private lateinit var reopen: () -> Unit

    private class TestViewModelOwner : ViewModelStoreOwner {
        override val viewModelStore = ViewModelStore()
    }

    private class IsolatedContext(base: Context) : ContextWrapper(base) {
        private val prefix = "choose-on-launch-test-${UUID.randomUUID()}-"
        private val names = mutableSetOf<String>()
        override fun getApplicationContext(): Context = this
        override fun getSharedPreferences(name: String, mode: Int): SharedPreferences {
            val privateName = prefix + name
            names += privateName
            return baseContext.getSharedPreferences(privateName, mode)
        }
        fun cleanup() { names.forEach { baseContext.deleteSharedPreferences(it) } }
    }

    private fun launch(savedPreset: Boolean = false) {
        val target = InstrumentationRegistry.getInstrumentation().targetContext
        PrayerPackStore.initialize(target.assets)
        val prayer = Prayer(name = "Choose mysteries", languageCode = "en", rosary = RosaryOptions(
            mysterySelectionMode = MysterySelectionMode.ChooseOnLaunch,
            specificMysteryCount = 2, includeApostlesCreed = false, includeOpeningPrayers = false,
            includeFatimaPrayer = false, marianAntiphon = MarianAntiphonOption.None,
            includeRosaryCollect = false, includeFinalSignOfCross = false))
        savedSnapshot = prayer.copy(rosary = prayer.rosary.copy())
        presetStore = MockPresetStore(if (savedPreset) listOf(prayer) else emptyList())
        val services = AppServices(presetStore, PrayerEngine(), MockLiturgicalCalendar())
        compose.setContent {
            val base = LocalContext.current
            val context = remember { IsolatedContext(base).also {
                isolated = it
                AppSettings.init(it)
                AppSettings.setInterfaceLanguageCode("en")
                AppSettings.setDefaultLanguageCode("en")
                AppSettings.setAutoAdvanceSeconds(0)
            } }
            var owner by remember { mutableStateOf(TestViewModelOwner()) }
            SideEffect {
                activeOwner = owner
                reopen = { owner.viewModelStore.clear(); owner = TestViewModelOwner() }
            }
            CompositionLocalProvider(LocalContext provides context, LocalAppServices provides services,
                LocalViewModelStoreOwner provides owner) {
                ProsaryTheme {
                    var returned by remember { mutableStateOf(false) }
                    if (returned) Text("Returned to Pray") else {
                        key(owner) {
                            val current: RosaryPrayerSession = viewModel(key = PrayerRunKeys.rosary(prayer.id)) { RosaryPrayerSession(prayer) }
                            SideEffect { session = current }
                            RosaryFlowScreen(prayer, onBack = { returned = true })
                        }
                    }
                }
            }
        }
        compose.onNode(isDialog()).assertIsDisplayed()
        compose.onNodeWithText(target.getString(R.string.flow_choose_mystery)).assertIsDisplayed()
    }

    private fun capture(name: String) {
        compose.waitForIdle()
        // Native popup/window fading is outside Compose's animation clock.
        Thread.sleep(200)
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val bitmap = requireNotNull(instrumentation.uiAutomation.takeScreenshot())
        val directory = File(instrumentation.targetContext.getExternalFilesDir(null), "choose-on-launch-selector-smoke").apply { mkdirs() }
        FileOutputStream(File(directory, "$name.png")).use {
            assertTrue(bitmap.compress(Bitmap.CompressFormat.PNG, 100, it))
        }
        bitmap.recycle()
    }

    private val mysteryChoice = SemanticsMatcher("active mystery choice") {
        it.config.getOrNull(SemanticsProperties.TestTag)
            ?.matches(Regex("chooseMystery\\.(joyful|sorrowful|glorious|luminous)\\.[1-5]")) == true
    }

    private fun chooseGroup(group: MysteryGroup) {
        compose.onNode(hasClickAction() and hasAnyAncestor(hasTestTag("mysterySetSelector"))).performClick()
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        for (candidate in MysteryGroup.entries) {
            compose.onAllNodes(hasText(context.getString(candidate.displayNameRes))).onLast().assertIsDisplayed()
        }
        compose.onAllNodes(hasText(context.getString(group.displayNameRes)) and hasClickAction()).onLast().performClick()
    }

    @Test fun mandatorySetSelectorShowsFiveChoicesThenStartsOpeningAndTwoSequentialMysteries() {
        try {
            launch()
            compose.onAllNodes(mysteryChoice).assertCountEquals(0)
            capture("picker-select-set-first")
            for (group in MysteryGroup.entries) {
                chooseGroup(group)
                compose.onNodeWithTag("chooseMystery.entireSet").assertIsDisplayed()
                compose.onAllNodes(mysteryChoice).assertCountEquals(5)
                for (mystery in MysteryCatalog.forGroup(group)) {
                    compose.onNodeWithTag("chooseMystery.${group.name.lowercase()}.${mystery.order}").assertIsDisplayed()
                }
                MysteryGroup.entries.filter { it != group }.forEach { hidden ->
                    MysteryCatalog.forGroup(hidden).forEach { mystery ->
                        compose.onNodeWithTag("chooseMystery.${hidden.name.lowercase()}.${mystery.order}").assertDoesNotExist()
                    }
                }
                capture("picker-${group.name.lowercase()}-five-choices")
            }
            val first = MysteryCatalog.luminous[3]
            val second = MysteryCatalog.luminous[4]
            val firstTitle = MysteryTranslations.get("en", first.imageKey).title
            compose.onNodeWithTag("chooseMystery.luminous.4").performClick()
            compose.onNode(isDialog()).assertDoesNotExist()
            compose.onNodeWithTag("prayerParagraph:0")
                .assertTextEquals(PrayerTranslations.get("en", PrayerKey.SignumCrucis)).assertIsDisplayed()
            compose.runOnIdle {
                assertEquals(0, session.currentIndex.intValue)
                assertEquals(listOf(first, second), session.steps.value.mapNotNull { it.mystery }.distinct())
            }
            capture("opening-sign-of-cross")
            val nextMystery = InstrumentationRegistry.getInstrumentation().targetContext.getString(R.string.flow_next_mystery)
            compose.onNodeWithContentDescription(nextMystery).performClick()
            compose.onNodeWithTag("prayerStepTitle").assertTextEquals(firstTitle).assertIsDisplayed()
            capture("first-selected-mystery")
            compose.onNodeWithContentDescription(nextMystery).performClick()
            compose.onNodeWithTag("prayerStepTitle")
                .assertTextEquals(MysteryTranslations.get("en", second.imageKey).title).assertIsDisplayed()
            capture("second-sequential-mystery")
        } finally { cleanup() }
    }

    @Test fun cancellingTheRequiredChoiceReturnsWithoutStartingPrayer() {
        try {
            launch()
            chooseGroup(MysteryGroup.Joyful)
            compose.onNodeWithText(InstrumentationRegistry.getInstrumentation().targetContext.getString(R.string.common_cancel))
                .assertIsDisplayed().performClick()
            compose.onNodeWithText("Returned to Pray").assertIsDisplayed()
            compose.onNode(isDialog()).assertDoesNotExist()
            compose.runOnIdle { assertTrue(session.steps.value.isEmpty()) }
        } finally { cleanup() }
    }

    @Test fun entireSetStartsAllFiveAndRestoresCheckpointWithoutChangingTheSavedPreset() {
        try {
            launch(savedPreset = true)
            chooseGroup(MysteryGroup.Glorious)
            compose.onNodeWithTag("chooseMystery.entireSet").assertIsDisplayed()
            capture("picker-glorious-entire-set-option")
            compose.onNodeWithTag("chooseMystery.entireSet").performClick()
            compose.onNode(isDialog()).assertDoesNotExist()
            compose.onNodeWithTag("prayerParagraph:0")
                .assertTextEquals(PrayerTranslations.get("en", PrayerKey.SignumCrucis)).assertIsDisplayed()
            compose.runOnIdle {
                assertEquals(0, session.currentIndex.intValue)
                assertEquals(MysteryCatalog.glorious, session.steps.value.mapNotNull { it.mystery }.distinct())
                assertEquals(savedSnapshot, runBlocking { presetStore.get(savedSnapshot.id) })
            }
            capture("entire-set-opening-sign-of-cross")
            val next = InstrumentationRegistry.getInstrumentation().targetContext.getString(R.string.flow_next_mystery)
            MysteryCatalog.glorious.forEach { mystery ->
                compose.onNodeWithContentDescription(next).performClick()
                compose.onNodeWithTag("prayerStepTitle")
                    .assertTextEquals(MysteryTranslations.get("en", mystery.imageKey).title).assertIsDisplayed()
            }
            capture("entire-set-fifth-sequential-mystery")
            compose.runOnIdle {
                val bookmark = requireNotNull(PrayerRunProgressStore.progress(isolated, PrayerRunKeys.rosary(savedSnapshot.id)))
                assertEquals("glorious", bookmark.rosaryNavigationGroup)
                assertEquals(null, bookmark.rosaryNavigationOrder)
                assertEquals(session.currentIndex.intValue, bookmark.stepIndex)
                assertEquals(savedSnapshot, runBlocking { presetStore.get(savedSnapshot.id) })
                reopen()
            }
            compose.onNodeWithText(InstrumentationRegistry.getInstrumentation().targetContext.getString(R.string.flow_continue))
                .assertIsDisplayed().performClick()
            compose.onNodeWithTag("prayerStepTitle")
                .assertTextEquals(MysteryTranslations.get("en", MysteryCatalog.glorious.last().imageKey).title).assertIsDisplayed()
            compose.runOnIdle {
                assertEquals(MysteryCatalog.glorious, session.steps.value.mapNotNull { it.mystery }.distinct())
                assertEquals(savedSnapshot, runBlocking { presetStore.get(savedSnapshot.id) })
            }
            capture("entire-set-checkpoint-restored")
        } finally { cleanup() }
    }

    private fun cleanup() {
        if (::activeOwner.isInitialized) compose.runOnIdle { activeOwner.viewModelStore.clear() }
        if (::isolated.isInitialized) isolated.cleanup()
    }
}
