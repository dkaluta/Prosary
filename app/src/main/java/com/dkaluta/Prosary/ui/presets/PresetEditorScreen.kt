package com.dkaluta.Prosary.ui.presets

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dkaluta.Prosary.models.EternalRestPlacement
import com.dkaluta.Prosary.models.LanguageCatalog
import com.dkaluta.Prosary.models.MarianAntiphonOption
import com.dkaluta.Prosary.models.MysteryGroup
import com.dkaluta.Prosary.models.MysterySelectionMode
import com.dkaluta.Prosary.models.RosaryConfig
import com.dkaluta.Prosary.services.LocalAppServices
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PresetEditorScreen(configId: String?, onDone: () -> Unit) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()
    val isNew = configId == null

    var config by remember { mutableStateOf(RosaryConfig()) }
    var loaded by remember { mutableStateOf(false) }

    LaunchedEffect(configId) {
        config = if (configId != null) {
            runCatching { services.presetStore.get(configId) }.getOrNull() ?: RosaryConfig()
        } else {
            val existing = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
            RosaryConfig(isDefault = existing.isEmpty())
        }
        loaded = true
    }

    if (!loaded) return

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isNew) "New Preset" else "Edit Preset") },
                navigationIcon = {
                    TextButton(onClick = onDone) { Text("Cancel") }
                },
                actions = {
                    TextButton(onClick = {
                        val toSave = if (config.name.isBlank()) config.copy(name = "My Rosary") else config
                        scope.launch {
                            services.presetStore.save(toSave)
                            onDone()
                        }
                    }) { Text("Save") }
                },
            )
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(20.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            FormSection(title = null) {
                OutlinedTextField(
                    value = config.name,
                    onValueChange = { config = config.copy(name = it) },
                    label = { Text("Name") },
                    placeholder = { Text("e.g. Morning Rosary") },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow(label = "Use as my default preset", checked = config.isDefault) {
                    config = config.copy(isDefault = it)
                }
            }

            FormSection(title = "Prayer Language") {
                OptionPickerField(
                    label = "Language",
                    options = LanguageCatalog.all,
                    selected = LanguageCatalog.resolve(config.languageCode),
                    optionLabel = { it.nativeName },
                    onSelect = { config = config.copy(languageCode = it.code) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            FormSection(title = "Which mysteries?") {
                OptionPickerField(
                    label = "Mysteries",
                    options = MysterySelectionMode.entries,
                    selected = config.mysterySelectionMode,
                    optionLabel = { it.displayName },
                    onSelect = { config = config.copy(mysterySelectionMode = it) },
                    modifier = Modifier.fillMaxWidth(),
                )
                if (config.mysterySelectionMode == MysterySelectionMode.Specific) {
                    OptionPickerField(
                        label = "Specific set",
                        options = MysteryGroup.entries,
                        selected = config.specificMysteryGroup,
                        optionLabel = { it.displayName },
                        onSelect = { config = config.copy(specificMysteryGroup = it) },
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
            }

            FormSection(title = "Opening & Decade Prayers") {
                SwitchRow("Apostles' Creed", config.includeApostlesCreed) {
                    config = config.copy(includeApostlesCreed = it)
                }
                SwitchRow("Opening Our Father & 3 Hail Marys", config.includeOpeningPrayers) {
                    config = config.copy(includeOpeningPrayers = it)
                }
                SwitchRow("Fatima Prayer after each decade", config.includeFatimaPrayer) {
                    config = config.copy(includeFatimaPrayer = it)
                }
                OptionPickerField(
                    label = "For the faithful departed",
                    options = EternalRestPlacement.entries,
                    selected = config.eternalRestForDeceased,
                    optionLabel = { it.displayName },
                    onSelect = { config = config.copy(eternalRestForDeceased = it) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }

            FormSection(title = "Closing Prayers") {
                OptionPickerField(
                    label = "Marian antiphon",
                    options = MarianAntiphonOption.entries,
                    selected = config.marianAntiphon,
                    optionLabel = { it.displayName },
                    onSelect = { config = config.copy(marianAntiphon = it) },
                    modifier = Modifier.fillMaxWidth(),
                )
                SwitchRow("St. Michael Prayer", config.includeStMichaelPrayer) {
                    config = config.copy(includeStMichaelPrayer = it)
                }
                SwitchRow("Final Sign of the Cross", config.includeFinalSignOfCross) {
                    config = config.copy(includeFinalSignOfCross = it)
                }
            }
        }
    }
}

@Composable
private fun FormSection(title: String?, content: @Composable ColumnScope.() -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        title?.let {
            Text(it, style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
        }
        Card {
            Column(
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(12.dp),
                content = content,
            )
        }
    }
}

@Composable
private fun SwitchRow(label: String, checked: Boolean, onCheckedChange: (Boolean) -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}
