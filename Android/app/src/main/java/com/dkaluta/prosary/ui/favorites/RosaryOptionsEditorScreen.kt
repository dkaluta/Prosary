package com.dkaluta.prosary.ui.favorites

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.ui.presets.OptionPickerField

/** The Rosary-specific options, split out of [FavoriteEditorScreen] into their own screen (a
 * "submenu") rather than 4 inline sections in the main editor — those 4 sections made the Rosary
 * editor much longer than every other kind's, for options most sessions never touch. Edits
 * [rosary] via [onRosaryChange] directly; the parent screen's own Save button persists it, this
 * screen has no save/cancel of its own. A plain composable-level screen swap (not a NavHost
 * destination) since [rosary] lives in the parent's local `remember` state, not a shared
 * ViewModel — see FavoriteEditorScreen's own state-ownership comment. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryOptionsEditorScreen(rosary: RosaryOptions, onRosaryChange: (RosaryOptions) -> Unit, onBack: () -> Unit) {
    BackHandler(onBack = onBack)

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text("Rosary Options") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(20.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            FormSection(title = "Which mysteries?") {
                OptionPickerField(
                    label = "Mysteries",
                    options = MysterySelectionMode.entries,
                    selected = rosary.mysterySelectionMode,
                    optionLabel = { it.displayName },
                    onSelect = { onRosaryChange(rosary.copy(mysterySelectionMode = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (rosary.mysterySelectionMode == MysterySelectionMode.Specific ||
                    rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery
                ) {
                    OptionPickerField(
                        label = "Specific set",
                        options = MysteryGroup.entries,
                        selected = rosary.specificMysteryGroup,
                        optionLabel = { it.displayName },
                        onSelect = { onRosaryChange(rosary.copy(specificMysteryGroup = it)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery) {
                    val mysteries = MysteryCatalog.forGroup(rosary.specificMysteryGroup)
                    val selectedMystery = mysteries.firstOrNull { it.order == rosary.specificMysteryOrder } ?: mysteries.first()
                    OptionPickerField(
                        label = "Which mystery",
                        options = mysteries,
                        selected = selectedMystery,
                        optionLabel = { MysteryTranslations.get(languageCode = "en", imageKey = it.imageKey).title },
                        onSelect = { onRosaryChange(rosary.copy(specificMysteryOrder = it.order)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            FormSection(title = "Opening & Decade Prayers") {
                SwitchRow("Apostles' Creed", rosary.includeApostlesCreed) {
                    onRosaryChange(rosary.copy(includeApostlesCreed = it))
                }
                SwitchRow("Opening Our Father & 3 Hail Marys", rosary.includeOpeningPrayers) {
                    onRosaryChange(rosary.copy(includeOpeningPrayers = it))
                }
                SwitchRow("Fatima Prayer after each decade", rosary.includeFatimaPrayer) {
                    onRosaryChange(rosary.copy(includeFatimaPrayer = it))
                }
                OptionPickerField(
                    label = "For the faithful departed",
                    options = EternalRestPlacement.entries,
                    selected = rosary.eternalRestForDeceased,
                    optionLabel = { it.displayName },
                    onSelect = { onRosaryChange(rosary.copy(eternalRestForDeceased = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            FormSection(title = "Display") {
                SwitchRow("Presenter Mode", rosary.presenterMode) {
                    onRosaryChange(rosary.copy(presenterMode = it))
                }
                Text(
                    "Combine each decade's Hail Marys and Glory Be onto one screen — useful when leading a group aloud from memory.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            FormSection(title = "Closing Prayers") {
                OptionPickerField(
                    label = "Marian antiphon",
                    options = MarianAntiphonOption.entries,
                    selected = rosary.marianAntiphon,
                    optionLabel = { it.displayName },
                    onSelect = { onRosaryChange(rosary.copy(marianAntiphon = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow("St. Michael Prayer", rosary.includeStMichaelPrayer) {
                    onRosaryChange(rosary.copy(includeStMichaelPrayer = it))
                }
                SwitchRow("Final Sign of the Cross", rosary.includeFinalSignOfCross) {
                    onRosaryChange(rosary.copy(includeFinalSignOfCross = it))
                }
            }
        }
    }
}
