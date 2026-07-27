package com.dkaluta.prosary.ui.jesusprayer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.JesusPrayerTarget

/** UI-only choice for the setup segmented control — collapses into a plain
 * [JesusPrayerTarget.Count]/[JesusPrayerTarget.Unbounded] the moment Begin is tapped, so nothing
 * downstream ever sees "custom" as a distinct runtime value. */
private enum class SetupOption(val displayName: String, val fixedCount: Int?) {
    ThirtyThree("33", 33),
    SixtySix("66", 66),
    NinetyNine("99", 99),
    Custom("Custom", null),
    Unbounded("Unbounded", null),
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun JesusPrayerSetupScreen(onBack: () -> Unit, onBegin: (JesusPrayerTarget) -> Unit) {
    // No persistence here (the whole app has none yet — see MockPresetStore's in-memory-only
    // implementation), so this always starts back at the same default rather than remembering
    // the last session's choice.
    var selection by remember { mutableStateOf(SetupOption.ThirtyThree) }
    var customCountText by remember { mutableStateOf("") }

    val customCount = customCountText.toIntOrNull()?.takeIf { it > 0 }
    val canBegin = selection != SetupOption.Custom || customCount != null
    val resolvedTarget: JesusPrayerTarget = when (selection) {
        SetupOption.Unbounded -> JesusPrayerTarget.Unbounded
        SetupOption.Custom -> JesusPrayerTarget.Count(customCount ?: 1)
        else -> JesusPrayerTarget.Count(selection.fixedCount ?: 1)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("The Jesus Prayer") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { paddingValues ->
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(paddingValues).padding(24.dp).fillMaxWidth(),
        ) {
            Text("How many times?")

            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                SetupOption.entries.forEachIndexed { index, option ->
                    SegmentedButton(
                        selected = selection == option,
                        onClick = { selection = option },
                        shape = SegmentedButtonDefaults.itemShape(index = index, count = SetupOption.entries.size),
                        // 5 segments is tight on a phone-width screen — dropping the default
                        // checkmark icon (which reserves space in every segment, selected or
                        // not, to avoid layout shift) buys back some room; selection is still
                        // clearly shown by the segment's own highlighted background. Even so,
                        // "Unbounded" (the longest label) doesn't reliably fit at any reasonable
                        // size, so it truncates with an ellipsis rather than a raw, typo-looking
                        // clip.
                        icon = {},
                    ) {
                        Text(
                            option.displayName,
                            style = MaterialTheme.typography.labelMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }
            }

            if (selection == SetupOption.Custom) {
                OutlinedTextField(
                    value = customCountText,
                    onValueChange = { customCountText = it.filter(Char::isDigit) },
                    label = { Text("Number of repetitions") },
                    keyboardOptions = androidx.compose.foundation.text.KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            Button(
                onClick = { onBegin(resolvedTarget) },
                enabled = canBegin,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Begin")
            }
        }
    }
}
