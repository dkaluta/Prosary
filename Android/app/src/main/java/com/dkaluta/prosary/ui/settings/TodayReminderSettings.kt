package com.dkaluta.prosary.ui.settings

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.reminders.TodayReminderScheduler

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayReminderSettings() {
    val context = LocalContext.current
    var pendingKind by remember { mutableStateOf<String?>(null) }
    var permissionDenied by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<String?>(null) }
    fun setEnabled(kind: String, enabled: Boolean) {
        if (kind == "readings") AppSettings.readingsReminderEnabled = enabled else AppSettings.saintReminderEnabled = enabled
        TodayReminderScheduler.refresh(context)
    }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        pendingKind?.let { if (granted) setEnabled(it, true) else permissionDenied = true }
        pendingKind = null
    }
    LaunchedEffect(AppSettings.feastCalendarId, AppSettings.easternPaschaStyle) { TodayReminderScheduler.refresh(context) }
    Text(stringResource(R.string.settings_reminders_header), style = MaterialTheme.typography.titleSmall)
    for (kind in listOf("readings", "saints")) {
        val enabled = if (kind == "readings") AppSettings.readingsReminderEnabled else AppSettings.saintReminderEnabled
        val minutes = if (kind == "readings") AppSettings.readingsReminderMinutes else AppSettings.saintReminderMinutes
        Column {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(stringResource(if (kind == "readings") R.string.settings_reminders_readings else R.string.settings_reminders_saints), Modifier.weight(1f))
                Switch(enabled, onCheckedChange = { value ->
                    if (value && !ReminderScheduler.hasNotificationPermission(context)) {
                        pendingKind = kind
                        permission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else setEnabled(kind, value)
                })
            }
            if (enabled) TextButton(onClick = { editing = kind }) {
                Text(stringResource(R.string.settings_reminders_time) + ": " + PrayerReminder(hour = minutes / 60, minute = minutes % 60).formattedTime(context))
            }
        }
    }
    Text(stringResource(R.string.settings_reminders_footer), style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant)
    if (permissionDenied) Text(stringResource(R.string.settings_reminders_permission_body), style = MaterialTheme.typography.bodySmall)
    editing?.let { kind ->
        val minutes = if (kind == "readings") AppSettings.readingsReminderMinutes else AppSettings.saintReminderMinutes
        val state = rememberTimePickerState(minutes / 60, minutes % 60, android.text.format.DateFormat.is24HourFormat(context))
        AlertDialog(onDismissRequest = { editing = null },
            confirmButton = { TextButton(onClick = {
                if (kind == "readings") AppSettings.readingsReminderMinutes = state.hour * 60 + state.minute
                else AppSettings.saintReminderMinutes = state.hour * 60 + state.minute
                TodayReminderScheduler.refresh(context)
                editing = null
            }) { Text(stringResource(R.string.common_ok)) } },
            dismissButton = { TextButton(onClick = { editing = null }) { Text(stringResource(R.string.common_cancel)) } },
            text = { TimePicker(state) })
    }
}
