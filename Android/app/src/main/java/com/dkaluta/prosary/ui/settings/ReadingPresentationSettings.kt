package com.dkaluta.prosary.ui.settings

import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.shared.LabeledSwitch

/** Both settings entry points edit the same persisted reading-presentation preferences. */
@Composable
internal fun ReadingPresentationSettings() {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        val label = stringResource(R.string.settings_reverse_readings_order)
        Text(label, Modifier.weight(1f))
        LabeledSwitch(label, AppSettings.reverseReadingsOrder, { AppSettings.reverseReadingsOrder = it },
            Modifier.testTag("reverseReadingsOrder"))
    }
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        val label = stringResource(R.string.settings_expand_readings)
        Text(label, Modifier.weight(1f))
        LabeledSwitch(label, AppSettings.expandReadingsByDefault, { AppSettings.expandReadingsByDefault = it },
            Modifier.testTag("expandReadingsByDefault"))
    }
}
