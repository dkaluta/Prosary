package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.typography.PrayerTypography

/** One script control for prayers and Scripture, with covering fonts and spoken script names. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AramaicScriptPicker(script: String, onSelect: (String) -> Unit, modifier: Modifier = Modifier) {
    Box(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        SingleChoiceSegmentedButtonRow(Modifier.widthIn(min = 144.dp, max = 400.dp)) {
            listOf("Syrc" to R.string.settings_script_syriac, "Hebr" to R.string.settings_script_hebrew)
                .forEachIndexed { index, (id, label) ->
                    val name = stringResource(label)
                    val glyph = if (id == "Syrc") "ܐ" else "א"
                    SegmentedButton(
                        selected = script == id,
                        onClick = { onSelect(id) },
                        shape = SegmentedButtonDefaults.itemShape(index, 2),
                        modifier = Modifier.heightIn(min = 48.dp).widthIn(min = 64.dp)
                            .testTag("aramaicScript.$id").semantics { contentDescription = name },
                    ) {
                        Text(glyph, style = MaterialTheme.typography.titleLarge.copy(
                            fontFamily = PrayerTypography.styleForText(glyph, isScripture = false).fontFamily,
                            fontSize = 24.sp, lineHeight = 32.sp,
                        ))
                    }
                }
        }
    }
}
