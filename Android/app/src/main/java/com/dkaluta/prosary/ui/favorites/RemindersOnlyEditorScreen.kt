package com.dkaluta.prosary.ui.favorites

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import com.dkaluta.prosary.ui.shared.PrayerRemovalDialog
import com.dkaluta.prosary.ui.shared.PrayerRemovalRequest
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.CustomDevotionOption
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.ui.presets.OptionPickerField
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.typography.HebrewDisplayText
import kotlinx.coroutines.launch

/** Compact editor for an existing [Prayer] row. Generic bundle rows expose their schema-driven
 * `options.json` choices plus reminders; Rosary/Jesus rows use it for reminder-only actions.
 * This screen never creates a row. Bundle reminder presets come from the manifest. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RemindersOnlyEditorScreen(prayerId: String, onDone: () -> Unit) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val draft: PrayerEditorState = viewModel(key = "remindersEditor:$prayerId")

    LaunchedEffect(draft, prayerId) {
        if (draft.initialized) return@LaunchedEffect
        val loaded = runCatching { services.presetStore.get(prayerId) }.getOrNull()
        val normalized = loaded?.let { saved ->
            val bundleId = saved.customDevotionId
            if (saved.kind == PrayerKind.Custom && bundleId != null) {
                saved.copy(customOptions = RosaryOptions.normalizedCustomOptions(
                    bundleId, saved.customOptions,
                ))
            } else saved
        }
        draft.initialize(loaded, normalized)
    }

    val current = draft.prayer ?: return
    var removalRequest by remember { mutableStateOf<PrayerRemovalRequest?>(null) }

    // For .Custom, current.kind.displayName is only a generic fallback (a single PrayerKind
    // case can't carry per-bundle text) — read the real name and reminder presets from the
    // bundle's own manifest.
    val info = if (current.kind == PrayerKind.Custom) {
        current.customDevotionId?.let { PrayerPackStore.info(it) }
    } else {
        null
    }
    val titleText = info?.localizedDisplayName ?: stringResource(current.kind.displayNameRes)

    val saveWithPermission = rememberReminderSavePermission {
        val toSave = current
        scope.launch {
            if (!services.presetStore.updateIfPresent(toSave)) {
                onDone()
                return@launch
            }
            draft.originalPrayer?.let { ReminderScheduler.cancelAll(context, it) }
            ReminderScheduler.schedule(context, toSave)
            onDone()
        }
    }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text(HebrewDisplayText.unpoint(titleText)) },
                navigationIcon = { TextButton(onClick = onDone) { Text(stringResource(R.string.common_cancel)) } },
                actions = { TextButton(onClick = { saveWithPermission(current.reminders.any { it.isEnabled }) }) { Text(stringResource(R.string.common_save)) } },
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
            val declaredOptions = current.customDevotionId?.let { PrayerPackStore.options(it) }.orEmpty()
            val isRosary = current.kind == PrayerKind.Custom && current.customDevotionId == "rosary"
            val options = if (isRosary) {
                declaredOptions.filterNot { it.key in RosaryOptions.legacyClosingIntentionKeys || it.key == "skipFifthDecade" }
            } else declaredOptions
            val needsCombinedClosingOption = isRosary &&
                declaredOptions.any { it.key in RosaryOptions.legacyClosingIntentionKeys } &&
                options.none { it.key == "closingIntentions" }
            val editableValues = if (isRosary) {
                RosaryOptions.normalizedCustomOptions("rosary", current.customOptions)
            } else current.customOptions
            fun setOption(key: String, value: String) {
                draft.prayer = current.copy(customOptions = editableValues + (key to value))
            }
            if (options.isNotEmpty() || needsCombinedClosingOption) {
                FormSection(title = stringResource(R.string.editor_options)) {
                    for (option in options) {
                        // Rows read through to the option's declared default so they show the
                        // effective value even before the user has ever touched them; changes
                        // store an explicit override.
                        val collectRequired = isRosary && option.key == "rosaryCollect" && editableValues["litanyOfLoreto"] == "true"
                        val value = if (collectRequired) "true" else editableValues[option.key] ?: option.defaultValue
                        fun set(newValue: String) {
                            setOption(option.key, newValue)
                        }
                        when (option.kind) {
                            CustomDevotionOption.Kind.Toggle ->
                                SwitchRow(option.localizedName, value == "true",
                                    switchModifier = Modifier.testTag("customOption:${option.key}"), enabled = !collectRequired) {
                                    set(if (it) "true" else "false")
                                }
                            CustomDevotionOption.Kind.Choice ->
                                OptionPickerField(
                                    label = option.localizedName,
                                    options = option.cases.orEmpty().map { it.id },
                                    selected = value,
                                    optionLabel = { id ->
                                        option.cases.orEmpty().firstOrNull { it.id == id }?.localizedName ?: id
                                    },
                                    onSelect = { set(it) },
                                    modifier = Modifier.fillMaxWidth(),
                                )
                        }
                    }
                    if (needsCombinedClosingOption) {
                        SwitchRow(stringResource(R.string.ro_closing_intentions), editableValues["closingIntentions"] == "true") {
                            setOption("closingIntentions", it.toString())
                        }
                    }
                }
            }
            RemindersSection(
                reminders = current.reminders,
                presetHours = info?.reminderPresetHours.orEmpty(),
                presetFooter = info?.localizedReminderPresetFooter,
            ) { draft.prayer = current.copy(reminders = it) }
            TextButton(onClick = { removalRequest = PrayerRemovalRequest.Saved(current) }) {
                Text(stringResource(R.string.prayer_delete_action), color = androidx.compose.material3.MaterialTheme.colorScheme.error)
            }
        }
    }
    removalRequest?.let { request ->
        PrayerRemovalDialog(request, onDismiss = { removalRequest = null }, onRemoved = onDone)
    }
}
