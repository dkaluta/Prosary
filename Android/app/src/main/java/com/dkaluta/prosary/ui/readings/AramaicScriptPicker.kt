package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R

/** Both scripts remain visible, so the current choice is clear before changing it. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AramaicScriptPicker(script: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier) {
    SingleChoiceSegmentedButtonRow(modifier.widthIn(max = 400.dp)) {
        listOf("Hebr" to R.string.settings_script_hebrew, "Syrc" to R.string.settings_script_syriac)
            .forEachIndexed { index, (id, label) ->
                SegmentedButton(selected = script == id, onClick = { onSelect(id) },
                    shape = SegmentedButtonDefaults.itemShape(index, 2),
                    modifier = Modifier.testTag("aramaicScript.$id")) {
                    Text(stringResource(label))
                }
            }
    }
}
