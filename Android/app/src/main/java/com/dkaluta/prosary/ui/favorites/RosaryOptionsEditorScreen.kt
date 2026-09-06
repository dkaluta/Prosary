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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.MysteryTranslations
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryCatalog
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysteryImageStyle
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
fun RosaryOptionsEditorScreen(
    rosary: RosaryOptions,
    onRosaryChange: (RosaryOptions) -> Unit,
    onBack: () -> Unit,
    languageCode: String = LanguageCatalog.resolve(null).code,
) {
    BackHandler(onBack = onBack)
    val context = LocalContext.current

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text(stringResource(R.string.rosary_options)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
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
            FormSection(title = stringResource(R.string.ro_which_mysteries)) {
                OptionPickerField(
                    label = stringResource(R.string.ro_mysteries),
                    options = MysterySelectionMode.entries,
                    selected = rosary.mysterySelectionMode,
                    optionLabel = { context.getString(it.displayNameRes) },
                    onSelect = { onRosaryChange(rosary.copy(mysterySelectionMode = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (rosary.mysterySelectionMode == MysterySelectionMode.Specific ||
                    rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery
                ) {
                    OptionPickerField(
                        label = stringResource(R.string.ro_specific_set),
                        options = MysteryGroup.entries,
                        selected = rosary.specificMysteryGroup,
                        optionLabel = { context.getString(it.displayNameRes) },
                        onSelect = { onRosaryChange(rosary.copy(specificMysteryGroup = it)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (rosary.mysterySelectionMode == MysterySelectionMode.SingleMystery) {
                    val mysteries = MysteryCatalog.forGroup(rosary.specificMysteryGroup)
                    val selectedMystery = mysteries.firstOrNull { it.order == rosary.specificMysteryOrder } ?: mysteries.first()
                    OptionPickerField(
                        label = stringResource(R.string.ro_which_mystery),
                        options = mysteries,
                        selected = selectedMystery,
                        // The mystery is named in the UI language, like the group row above it — the
                        // hardcoded "en" left an all-Hebrew editor naming mysteries in English
                        // (Erez, 2026-08-08).
                        optionLabel = { MysteryTranslations.get(languageCode = LanguageCatalog.uiLanguageCode(), imageKey = it.imageKey).title },
                        onSelect = { onRosaryChange(rosary.copy(specificMysteryOrder = it.order)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            FormSection(title = stringResource(R.string.ro_opening_section)) {
                SwitchRow(stringResource(R.string.ro_apostles_creed), rosary.includeApostlesCreed) {
                    onRosaryChange(rosary.copy(includeApostlesCreed = it))
                }
                SwitchRow(stringResource(R.string.ro_opening_prayers), rosary.includeOpeningPrayers) {
                    onRosaryChange(rosary.copy(includeOpeningPrayers = it))
                }
                SwitchRow(stringResource(R.string.ro_opening_fatima), rosary.includeOpeningFatimaPrayer) {
                    onRosaryChange(rosary.copy(includeOpeningFatimaPrayer = it))
                }
                SwitchRow(stringResource(R.string.ro_fatima), rosary.includeFatimaPrayer) {
                    onRosaryChange(rosary.copy(includeFatimaPrayer = it))
                }
                OptionPickerField(
                    label = stringResource(R.string.ro_faithful_departed),
                    options = EternalRestPlacement.entries,
                    selected = rosary.eternalRestForDeceased,
                    optionLabel = { context.getString(it.displayNameRes) },
                    onSelect = { onRosaryChange(rosary.copy(eternalRestForDeceased = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            FormSection(title = stringResource(R.string.ro_display_section)) {
                OptionPickerField(
                    label = stringResource(R.string.ro_mystery_artwork),
                    options = MysteryImageStyle.entries,
                    selected = rosary.mysteryImageStyle,
                    optionLabel = { context.getString(it.displayNameRes) },
                    onSelect = { onRosaryChange(rosary.copy(mysteryImageStyle = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow(stringResource(R.string.ro_presenter_mode), rosary.presenterMode) {
                    onRosaryChange(rosary.copy(presenterMode = it))
                }
                Text(
                    stringResource(R.string.ro_presenter_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            FormSection(title = stringResource(R.string.ro_closing_section)) {
                OptionPickerField(
                    label = stringResource(R.string.ro_marian_antiphon),
                    options = MarianAntiphonOption.entries,
                    selected = rosary.marianAntiphon,
                    optionLabel = { it.displayName(context, languageCode) },
                    onSelect = { onRosaryChange(rosary.copy(marianAntiphon = it)) },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow(stringResource(R.string.ro_closing_pope_intention), rosary.effectiveClosingPopeIntention) {
                    onRosaryChange(rosary.copy(includeClosingPopeIntention = it))
                }
                SwitchRow(stringResource(R.string.ro_closing_bishop_intention), rosary.effectiveClosingBishopIntention) {
                    onRosaryChange(rosary.copy(includeClosingBishopIntention = it))
                }
                SwitchRow(stringResource(R.string.ro_closing_departed_intention), rosary.effectiveClosingDepartedIntention) {
                    onRosaryChange(rosary.copy(includeClosingDepartedIntention = it))
                }
                SwitchRow(stringResource(R.string.ro_st_michael), rosary.includeStMichaelPrayer) {
                    onRosaryChange(rosary.copy(includeStMichaelPrayer = it))
                }
                SwitchRow(stringResource(R.string.ro_final_sign), rosary.includeFinalSignOfCross) {
                    onRosaryChange(rosary.copy(includeFinalSignOfCross = it))
                }
            }
        }
    }
}
