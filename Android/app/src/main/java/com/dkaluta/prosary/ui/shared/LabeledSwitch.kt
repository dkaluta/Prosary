package com.dkaluta.prosary.ui.shared

import androidx.compose.material3.Switch
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics

/** A visually adjacent Text is not automatically the accessible name of a Compose switch. */
@Composable
internal fun LabeledSwitch(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    Switch(checked = checked, onCheckedChange = onCheckedChange, enabled = enabled,
        modifier = modifier.semantics { contentDescription = label })
}
