package com.dkaluta.prosary.ui.shared

import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.PrayerRunProgress

/** A single Continue/Restart prompt for every resumable prayer flow. Dismissing it is treated as
 * Restart so the underlying first step can never remain blocked behind an invisible decision. */
@Composable
fun ResumePrayerDialog(
    progress: PrayerRunProgress,
    totalSteps: Int?,
    onContinue: () -> Unit,
    onRestart: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onRestart,
        title = { Text(stringResource(R.string.flow_resume_title)) },
        text = {
            Text(
                if (totalSteps == null) {
                    stringResource(R.string.flow_resume_unbounded_message, progress.stepIndex + 1)
                } else {
                    stringResource(
                        R.string.flow_resume_message,
                        progress.stepIndex + 1,
                        totalSteps,
                    )
                },
            )
        },
        confirmButton = {
            TextButton(onClick = onContinue) { Text(stringResource(R.string.flow_continue)) }
        },
        dismissButton = {
            TextButton(onClick = onRestart) { Text(stringResource(R.string.flow_restart)) }
        },
    )
}
