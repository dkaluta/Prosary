package com.dkaluta.prosary.ui.favorites

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.EternalRestPlacement
import com.dkaluta.prosary.models.JesusPrayerOptions
import com.dkaluta.prosary.models.JesusPrayerTarget
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.MarianAntiphonOption
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.MysterySelectionMode
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.presets.OptionPickerField
import kotlinx.coroutines.launch

/** Editor for any kind of saved prayer favorite. Replaces the old Rosary-only preset editor —
 * kind-specific sections appear conditionally based on `prayer.kind`. Mirrors iOS's
 * FavoriteEditorView. [newFavoriteKind] seeds a brand-new favorite's type when [prayerId] is
 * null (Android's route can't carry a whole ad-hoc Prayer object the way iOS's `sheet(item:)`
 * does — see ProsaryApp.kt's route comment). */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoriteEditorScreen(prayerId: String?, newFavoriteKind: PrayerKind = PrayerKind.Rosary, onDone: () -> Unit) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val isNew = prayerId == null

    var prayer by remember { mutableStateOf(Prayer(kind = newFavoriteKind)) }
    var loaded by remember { mutableStateOf(false) }
    // The prayer as originally loaded, reminders untouched by in-editor edits — needed so save()
    // can cancel alarms for reminders the user removed (schedule() only knows how to reconstruct
    // PendingIntents for reminder ids still present in the *new* list, so a deleted reminder's
    // alarm would otherwise never be cancelled).
    var originalPrayer by remember { mutableStateOf<Prayer?>(null) }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

    LaunchedEffect(prayerId) {
        prayer = if (prayerId != null) {
            runCatching { services.presetStore.get(prayerId) }.getOrNull() ?: Prayer(kind = newFavoriteKind)
        } else {
            val existing = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            Prayer(
                name = newFavoriteKind.defaultName,
                kind = newFavoriteKind,
                isDefault = existing.none { it.kind == newFavoriteKind },
            )
        }
        originalPrayer = prayer
        loaded = true
    }

    if (!loaded) return

    fun save() {
        var toSave = prayer
        if (toSave.name.isBlank()) toSave = toSave.copy(name = toSave.kind.defaultName)
        scope.launch {
            val needsPermission = toSave.reminders.any { it.isEnabled } &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                !ReminderScheduler.hasNotificationPermission(context)
            if (needsPermission) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            services.presetStore.save(toSave)
            originalPrayer?.let { ReminderScheduler.cancelAll(context, it) }
            ReminderScheduler.schedule(context, toSave)
            onDone()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isNew) "New Favorite" else "Edit Favorite") },
                navigationIcon = { TextButton(onClick = onDone) { Text("Cancel") } },
                actions = { TextButton(onClick = { save() }) { Text("Save") } },
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
            FormSection(title = null) {
                OutlinedTextField(
                    value = prayer.name,
                    onValueChange = { prayer = prayer.copy(name = it) },
                    label = { Text("Name") },
                    placeholder = { Text("e.g. Morning Rosary") },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow("Set as default for ${prayer.kind.displayName}", prayer.isDefault) {
                    prayer = prayer.copy(isDefault = it)
                }
            }

            FormSection(title = "Prayer Language") {
                val defaultName = LanguageCatalog.resolve(LanguageCatalog.defaultSentinel).nativeName
                val languageOptions = listOf(LanguageCatalog.defaultSentinel) + LanguageCatalog.all.map { it.code }
                OptionPickerField(
                    label = "Language",
                    options = languageOptions,
                    selected = prayer.languageCode,
                    optionLabel = { code ->
                        if (code == LanguageCatalog.defaultSentinel) {
                            "Default — $defaultName"
                        } else {
                            LanguageCatalog.resolve(code).nativeName
                        }
                    },
                    onSelect = { prayer = prayer.copy(languageCode = it) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            if (prayer.kind == PrayerKind.Rosary) {
                FormSection(title = "Which mysteries?") {
                    OptionPickerField(
                        label = "Mysteries",
                        options = MysterySelectionMode.entries,
                        selected = prayer.rosary.mysterySelectionMode,
                        optionLabel = { it.displayName },
                        onSelect = { prayer = prayer.copy(rosary = prayer.rosary.copy(mysterySelectionMode = it)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    if (prayer.rosary.mysterySelectionMode == MysterySelectionMode.Specific) {
                        OptionPickerField(
                            label = "Specific set",
                            options = MysteryGroup.entries,
                            selected = prayer.rosary.specificMysteryGroup,
                            optionLabel = { it.displayName },
                            onSelect = { prayer = prayer.copy(rosary = prayer.rosary.copy(specificMysteryGroup = it)) },
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }

                FormSection(title = "Opening & Decade Prayers") {
                    SwitchRow("Apostles' Creed", prayer.rosary.includeApostlesCreed) {
                        prayer = prayer.copy(rosary = prayer.rosary.copy(includeApostlesCreed = it))
                    }
                    SwitchRow("Opening Our Father & 3 Hail Marys", prayer.rosary.includeOpeningPrayers) {
                        prayer = prayer.copy(rosary = prayer.rosary.copy(includeOpeningPrayers = it))
                    }
                    SwitchRow("Fatima Prayer after each decade", prayer.rosary.includeFatimaPrayer) {
                        prayer = prayer.copy(rosary = prayer.rosary.copy(includeFatimaPrayer = it))
                    }
                    OptionPickerField(
                        label = "For the faithful departed",
                        options = EternalRestPlacement.entries,
                        selected = prayer.rosary.eternalRestForDeceased,
                        optionLabel = { it.displayName },
                        onSelect = { prayer = prayer.copy(rosary = prayer.rosary.copy(eternalRestForDeceased = it)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }

                FormSection(title = "Closing Prayers") {
                    OptionPickerField(
                        label = "Marian antiphon",
                        options = MarianAntiphonOption.entries,
                        selected = prayer.rosary.marianAntiphon,
                        optionLabel = { it.displayName },
                        onSelect = { prayer = prayer.copy(rosary = prayer.rosary.copy(marianAntiphon = it)) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    SwitchRow("St. Michael Prayer", prayer.rosary.includeStMichaelPrayer) {
                        prayer = prayer.copy(rosary = prayer.rosary.copy(includeStMichaelPrayer = it))
                    }
                    SwitchRow("Final Sign of the Cross", prayer.rosary.includeFinalSignOfCross) {
                        prayer = prayer.copy(rosary = prayer.rosary.copy(includeFinalSignOfCross = it))
                    }
                }
            }

            if (prayer.kind == PrayerKind.JesusPrayer) {
                FormSection(title = "Target") {
                    val options = listOf(
                        JesusPrayerTarget.Count(33) to "33",
                        JesusPrayerTarget.Count(66) to "66",
                        JesusPrayerTarget.Count(99) to "99",
                        JesusPrayerTarget.Unbounded to "Unbounded",
                    )
                    SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                        options.forEachIndexed { index, (target, label) ->
                            SegmentedButton(
                                selected = prayer.jesusPrayer.target == target,
                                onClick = { prayer = prayer.copy(jesusPrayer = JesusPrayerOptions(target = target)) },
                                shape = SegmentedButtonDefaults.itemShape(index = index, count = options.size),
                            ) {
                                Text(label)
                            }
                        }
                    }
                }
            }

            RemindersSection(reminders = prayer.reminders, kind = prayer.kind) { prayer = prayer.copy(reminders = it) }
        }
    }
}

@Composable
private fun FormSection(title: String?, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        title?.let {
            Text(it, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
        }
        Card {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(12.dp),
                content = content,
            )
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
