package com.dkaluta.prosary.ui.favorites

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerReminder

/** The reminders Form section, shared by FavoriteEditorScreen (Rosary/Jesus Prayer's full
 * editor) and RemindersOnlyEditorScreen (the lightweight screen for Angelus/Stations of the
 * Cross/Franciscan Crown/Seven Sorrows/Divine Mercy Chaplet). Extracted so both editors manage
 * reminders identically instead of drifting. Mirrors iOS's RemindersSection. */
@Composable
fun RemindersSection(reminders: List<PrayerReminder>, kind: PrayerKind, onRemindersChange: (List<PrayerReminder>) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Reminders", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
        Card {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(12.dp),
            ) {
                if (kind == PrayerKind.Angelus) {
                    // Traditional Angelus bell times — quick toggles for 6am, noon, 6pm.
                    AngelusTimeToggleRow(hour = 6, label = "6:00 AM", reminders = reminders, onChange = onRemindersChange)
                    AngelusTimeToggleRow(hour = 12, label = "12:00 PM", reminders = reminders, onChange = onRemindersChange)
                    AngelusTimeToggleRow(hour = 18, label = "6:00 PM", reminders = reminders, onChange = onRemindersChange)

                    val angelusPresetHours = setOf(6, 12, 18)
                    val customReminders = reminders.filter { r -> !(angelusPresetHours.contains(r.hour) && r.minute == 0) }
                    for (reminder in customReminders) {
                        ReminderRow(
                            reminder = reminder,
                            onTimeChange = { hour, minute -> onRemindersChange(reminders.withUpdatedReminder(reminder.id, hour, minute)) },
                            onDelete = { onRemindersChange(reminders.withoutReminder(reminder.id)) },
                        )
                    }
                } else {
                    for (reminder in reminders) {
                        ReminderRow(
                            reminder = reminder,
                            onTimeChange = { hour, minute -> onRemindersChange(reminders.withUpdatedReminder(reminder.id, hour, minute)) },
                            onDelete = { onRemindersChange(reminders.withoutReminder(reminder.id)) },
                        )
                    }
                }

                TextButton(onClick = { onRemindersChange(reminders + PrayerReminder(hour = 9, minute = 0)) }) {
                    Icon(Icons.Filled.Add, contentDescription = null)
                    Text("Add Reminder")
                }
            }
        }
    }
}

private fun List<PrayerReminder>.withUpdatedReminder(id: String, hour: Int, minute: Int): List<PrayerReminder> =
    map { if (it.id == id) it.copy(hour = hour, minute = minute) else it }

private fun List<PrayerReminder>.withoutReminder(id: String): List<PrayerReminder> =
    filter { it.id != id }

@Composable
private fun AngelusTimeToggleRow(hour: Int, label: String, reminders: List<PrayerReminder>, onChange: (List<PrayerReminder>) -> Unit) {
    val isOn = reminders.any { it.hour == hour && it.minute == 0 && it.isEnabled }
    SwitchRow(label, isOn) { on ->
        val updated = if (on) {
            if (reminders.none { it.hour == hour && it.minute == 0 }) {
                reminders + PrayerReminder(hour = hour, minute = 0)
            } else {
                reminders.map { if (it.hour == hour && it.minute == 0) it.copy(isEnabled = true) else it }
            }
        } else {
            reminders.filter { !(it.hour == hour && it.minute == 0) }
        }
        onChange(updated)
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
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
