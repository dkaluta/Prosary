package com.dkaluta.Prosary.ui.favorites

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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberTimePickerState
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
import com.dkaluta.Prosary.models.EternalRestPlacement
import com.dkaluta.Prosary.models.JesusPrayerOptions
import com.dkaluta.Prosary.models.JesusPrayerTarget
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.MarianAntiphonOption
import com.dkaluta.Prosary.models.MysteryGroup
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.models.PrayerReminder
import com.dkaluta.Prosary.reminders.ReminderScheduler
import com.dkaluta.Prosary.services.LocalAppServices
import com.dkaluta.Prosary.ui.presets.OptionPickerField
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

            FormSection(title = "Reminders") {
                if (prayer.kind == PrayerKind.Angelus) {
                    // Traditional Angelus bell times — quick toggles for 6am, noon, 6pm.
                    AngelusTimeToggleRow(hour = 6, label = "6:00 AM", prayer = prayer, onChange = { prayer = it })
                    AngelusTimeToggleRow(hour = 12, label = "12:00 PM", prayer = prayer, onChange = { prayer = it })
                    AngelusTimeToggleRow(hour = 18, label = "6:00 PM", prayer = prayer, onChange = { prayer = it })

                    val angelusPresetHours = setOf(6, 12, 18)
                    val customReminders = prayer.reminders.filter { r -> !(angelusPresetHours.contains(r.hour) && r.minute == 0) }
                    for (reminder in customReminders) {
                        ReminderRow(
                            reminder = reminder,
                            onTimeChange = { hour, minute -> prayer = prayer.withUpdatedReminder(reminder.id, hour, minute) },
                            onDelete = { prayer = prayer.withoutReminder(reminder.id) },
                        )
                    }
                } else {
                    for (reminder in prayer.reminders) {
                        ReminderRow(
                            reminder = reminder,
                            onTimeChange = { hour, minute -> prayer = prayer.withUpdatedReminder(reminder.id, hour, minute) },
                            onDelete = { prayer = prayer.withoutReminder(reminder.id) },
                        )
                    }
                }

                TextButton(onClick = { prayer = prayer.copy(reminders = prayer.reminders + PrayerReminder(hour = 9, minute = 0)) }) {
                    Icon(Icons.Filled.Add, contentDescription = null)
                    Text("Add Reminder")
                }
            }
        }
    }
}

private fun Prayer.withUpdatedReminder(id: String, hour: Int, minute: Int): Prayer =
    copy(reminders = reminders.map { if (it.id == id) it.copy(hour = hour, minute = minute) else it })

private fun Prayer.withoutReminder(id: String): Prayer =
    copy(reminders = reminders.filter { it.id != id })

@Composable
private fun AngelusTimeToggleRow(hour: Int, label: String, prayer: Prayer, onChange: (Prayer) -> Unit) {
    val isOn = prayer.reminders.any { it.hour == hour && it.minute == 0 && it.isEnabled }
    SwitchRow(label, isOn) { on ->
        val updated = if (on) {
            if (prayer.reminders.none { it.hour == hour && it.minute == 0 }) {
                prayer.reminders + PrayerReminder(hour = hour, minute = 0)
            } else {
                prayer.reminders.map { if (it.hour == hour && it.minute == 0) it.copy(isEnabled = true) else it }
            }
        } else {
            prayer.reminders.filter { !(it.hour == hour && it.minute == 0) }
        }
        onChange(prayer.copy(reminders = updated))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReminderRow(reminder: PrayerReminder, onTimeChange: (Int, Int) -> Unit, onDelete: () -> Unit) {
    var showPicker by remember { mutableStateOf(false) }

    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        TextButton(onClick = { showPicker = true }, modifier = Modifier.weight(1f)) {
            Text(reminder.displayTime)
        }
        IconButton(onClick = onDelete) {
            Icon(Icons.Filled.Delete, contentDescription = "Delete reminder", tint = MaterialTheme.colorScheme.error)
        }
    }

    if (showPicker) {
        val state = rememberTimePickerState(initialHour = reminder.hour, initialMinute = reminder.minute, is24Hour = false)
        AlertDialog(
            onDismissRequest = { showPicker = false },
            confirmButton = {
                TextButton(onClick = {
                    onTimeChange(state.hour, state.minute)
                    showPicker = false
                }) { Text("OK") }
            },
            dismissButton = { TextButton(onClick = { showPicker = false }) { Text("Cancel") } },
            text = { TimePicker(state = state) },
        )
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
