package com.dkaluta.prosary.ui.favorites

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.assertIsNotEnabled
import androidx.compose.ui.test.assertIsOff
import androidx.compose.ui.test.assertIsSelected
import androidx.compose.ui.test.assertTextEquals
import androidx.compose.ui.test.hasAnyAncestor
import androidx.compose.ui.test.hasTestTag
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isDialog
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.compose.ui.test.performTextReplacement
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.dkaluta.prosary.R
import com.dkaluta.prosary.calendar.MockLiturgicalCalendar
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.engine.PrayerEngine
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.presets.MockPresetStore
import com.dkaluta.prosary.services.AppServices
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/** ActivityScenario.recreate destroys the Activity and composition, as a fold can do. The
 * harness uses the same navigation-entry scoping as production and no production store. */
@RunWith(AndroidJUnit4::class)
class EditorContinuityInstrumentedTest {
    @get:Rule val compose = createEmptyComposeRule()
    private lateinit var scenario: ActivityScenario<EditorContinuityTestActivity>
    private lateinit var store: MockPresetStore
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private fun label(id: Int) = context.getString(id)

    private fun launch(prayer: Prayer? = null, kind: PrayerKind = PrayerKind.Rosary) {
        store = MockPresetStore(listOfNotNull(prayer))
        EditorContinuityTestActivity.services = AppServices(store, PrayerEngine(), MockLiturgicalCalendar())
        EditorContinuityTestActivity.prayerId = prayer?.id
        EditorContinuityTestActivity.newFavoriteKind = kind
        EditorContinuityTestActivity.lastTarget = null
        scenario = ActivityScenario.launch(EditorContinuityTestActivity::class.java)
    }

    @After fun close() {
        if (::scenario.isInitialized) scenario.close()
        EditorContinuityTestActivity.services = null
        EditorContinuityTestActivity.prayerId = null
        EditorContinuityTestActivity.lastTarget = null
    }

    @Test fun newFavoriteAndRosarySubmenuSurviveRecreationAndSaveOnlyOnce() {
        launch()
        compose.onNodeWithText("Open favorite editor").performClick()
        compose.onNodeWithText(label(R.string.editor_name)).performTextReplacement("Folded Rosary draft")
        compose.onNodeWithText(label(R.string.rosary_options)).performScrollTo().performClick()
        val creedToggle = hasTestTag("rosaryOption:apostlesCreed")
        compose.onNode(creedToggle).performScrollTo().performClick()

        scenario.recreate()

        compose.onNodeWithText(label(R.string.rosary_options)).assertIsDisplayed()
        compose.onNode(creedToggle).assertIsOff()
        compose.onNodeWithContentDescription(label(R.string.common_back)).performClick()
        compose.onNodeWithText(label(R.string.editor_name)).assertTextEquals(label(R.string.editor_name), "Folded Rosary draft")
        assertTrue(runBlocking { store.all() }.isEmpty())
        compose.onNodeWithText(label(R.string.common_save)).performClick()
        compose.onNodeWithText("Open favorite editor").assertIsDisplayed()
        val saved = runBlocking { store.all() }.single()
        assertEquals("Folded Rosary draft", saved.name)
        assertFalse(saved.rosary.includeApostlesCreed)

        // Popping this editor must discard its ViewModel; a new route is a new draft.
        compose.onNodeWithText("Open favorite editor").performClick()
        compose.onNodeWithText("Folded Rosary draft").assertDoesNotExist()
        compose.onNodeWithText(label(R.string.common_cancel)).performClick()
        assertEquals(listOf(saved), runBlocking { store.all() })
    }

    @Test fun existingFavoriteEditsAndReminderPickerSurviveButCancelDiscardsTheDraft() {
        val reminder = PrayerReminder(id = "editor-continuity-reminder", hour = 7, minute = 15, isEnabled = false)
        val original = Prayer(name = "Original favorite", reminders = listOf(reminder))
        launch(original)
        compose.onNodeWithText("Open favorite editor").performClick()
        compose.onNodeWithText(label(R.string.editor_name)).performTextReplacement("Unsaved favorite")
        compose.onNodeWithText(reminder.displayTime).performScrollTo().performClick()

        scenario.recreate()

        compose.onNodeWithText(label(R.string.common_ok)).assertIsDisplayed()
        // Dismiss the time dialog, then the full editor. Neither commits the draft.
        compose.onNode(hasText(label(R.string.common_cancel)) and hasAnyAncestor(isDialog())).performClick()
        compose.onNodeWithText(label(R.string.common_cancel)).performClick()
        assertEquals(original, runBlocking { store.get(original.id) })
        compose.onNodeWithText("Open favorite editor").performClick()
        compose.onNodeWithText(label(R.string.editor_name)).assertTextEquals(label(R.string.editor_name), original.name)
    }

    @Test fun customOptionsAndReminderRemovalSurviveRecreationUntilSave() {
        PrayerPackStore.initialize(context.assets)
        val original = Prayer(
            name = "Custom Rosary", kind = PrayerKind.Custom, customDevotionId = "rosary",
            customOptions = mapOf("apostlesCreed" to "true"),
            reminders = listOf(PrayerReminder(id = "removed-after-fold", hour = 8, isEnabled = false)),
        )
        launch(original)
        compose.onNodeWithText("Open reminder editor").performClick()
        val creedToggle = hasTestTag("customOption:apostlesCreed")
        compose.onNode(creedToggle).performScrollTo().performClick()
        compose.onNodeWithContentDescription(label(R.string.reminders_delete_desc)).performScrollTo().performClick()

        scenario.recreate()

        compose.onNodeWithContentDescription(label(R.string.reminders_delete_desc)).assertDoesNotExist()
        compose.onNode(creedToggle).performScrollTo().assertIsOff()
        assertEquals(original, runBlocking { store.get(original.id) })
        compose.onNodeWithText(label(R.string.common_save)).performClick()
        compose.onNodeWithText("Open reminder editor").assertIsDisplayed()
        val saved = requireNotNull(runBlocking { store.get(original.id) })
        assertEquals("false", saved.customOptions["apostlesCreed"])
        assertTrue(saved.reminders.isEmpty())
    }

    @Test fun customSetupKeepsSelectionAndInvalidThenValidCountAcrossRecreation() {
        launch()
        compose.onNodeWithText("Open Jesus Prayer setup").performClick()
        compose.onNodeWithText(label(R.string.jp_custom)).performClick()
        compose.onNodeWithText(label(R.string.jp_repetitions)).performTextInput("0")
        scenario.recreate()
        compose.onNodeWithText(label(R.string.jp_custom)).assertIsSelected()
        compose.onNodeWithText(label(R.string.jp_begin)).assertIsNotEnabled()
        compose.onNodeWithText(label(R.string.jp_repetitions)).performTextReplacement("137")
        scenario.recreate()
        compose.onNodeWithText(label(R.string.jp_repetitions)).assertTextEquals(label(R.string.jp_repetitions), "137")
        compose.onNodeWithText(label(R.string.jp_begin)).performClick()
        compose.onNodeWithText("Open Jesus Prayer setup").assertIsDisplayed()
        assertEquals(JesusPrayerTarget.Count(137), EditorContinuityTestActivity.lastTarget)

        compose.onNodeWithText("Open Jesus Prayer setup").performClick()
        compose.onNodeWithText("33").assertIsSelected()
    }
}
