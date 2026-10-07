package com.dkaluta.prosary.ui.favorites

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.reminders.ReminderScheduler

/** Keep the editor alive for the permission result instead of silently closing beneath it. */
@Composable
internal fun rememberReminderSavePermission(onSave: () -> Unit): (Boolean) -> Unit {
    val context = LocalContext.current
    val save by rememberUpdatedState(onSave)
    var requesting by remember { mutableStateOf(false) }
    var showsBlocked by remember { mutableStateOf(false) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        requesting = false
        if (granted && ReminderScheduler.notificationsEnabled(context)) save()
        else showsBlocked = true
    }
    if (showsBlocked) {
        AlertDialog(onDismissRequest = { showsBlocked = false },
            title = { Text(stringResource(R.string.settings_reminders_permission_title)) },
            text = { Text(stringResource(R.string.reminders_permission_body)) },
            confirmButton = { TextButton(onClick = {
                showsBlocked = false
                context.startActivity(ReminderScheduler.notificationSettingsIntent(context))
            }) { Text(stringResource(R.string.settings_reminders_system)) } },
            dismissButton = { TextButton(onClick = {
                showsBlocked = false
                save()
            }) { Text(stringResource(R.string.reminders_save_without_notifications)) } })
    }
    return { hasEnabledReminders ->
        if (!requesting) {
            when {
                !hasEnabledReminders || ReminderScheduler.notificationsEnabled(context) -> save()
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && !ReminderScheduler.hasNotificationPermission(context) -> {
                    requesting = true
                    launcher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
                else -> showsBlocked = true
            }
        }
    }
}
