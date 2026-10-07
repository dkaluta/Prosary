package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.ui.settings.ReadingPresentationSettings
import com.dkaluta.prosary.ui.settings.TodayReminderSettings

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun ReadingSettingsSheet(onDismiss: () -> Unit) {
    val maximumHeight = (LocalConfiguration.current.screenHeightDp - 80).coerceAtLeast(160).dp
    ModalBottomSheet(onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
        Column(Modifier.fillMaxWidth().heightIn(max = maximumHeight)
            .verticalScroll(rememberScrollState()).padding(horizontal = 20.dp, vertical = 12.dp)
            .testTag("readingSettings"), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(stringResource(R.string.reading_settings), style = MaterialTheme.typography.headlineSmall)
            ReadingPresentationSettings()
            TodayReminderSettings(readingsOnly = true)
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) }
        }
    }
}
