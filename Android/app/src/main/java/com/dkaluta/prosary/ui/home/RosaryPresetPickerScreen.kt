package com.dkaluta.prosary.ui.home

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.RosaryOptions
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.favorites.RosaryOptionsEditorScreen
import kotlinx.coroutines.launch

/** Home → Rosary lands here instead of launching a session directly: the default preset up
 * top (one tap to pray), then "Pray any Rosary" (ad-hoc options seeded from the default
 * preset, with a save-as-preset affordance), then the remaining presets. Preset management
 * (rename/delete/set-default) stays in Favorites. Mirrors iOS's RosaryPresetPickerView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryPresetPickerScreen(
    onPrayPreset: (String) -> Unit,
    onPrayAdHoc: (Prayer) -> Unit,
    onOpenFavorites: () -> Unit,
    onBack: () -> Unit,
) {
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()

    var presets by remember { mutableStateOf<List<Prayer>>(emptyList()) }
    var options by remember { mutableStateOf(RosaryOptions()) }
    var didSeedOptions by remember { mutableStateOf(false) }
    var showingOptionsEditor by remember { mutableStateOf(false) }
    var showingSaveDialog by remember { mutableStateOf(false) }
    var presetName by remember { mutableStateOf("") }

    suspend fun reload() {
        presets = services.presetStore.all().filter { it.kind == PrayerKind.Rosary }
        if (!didSeedOptions) {
            didSeedOptions = true
            presets.firstOrNull { it.isDefault }?.let { options = it.rosary }
        }
    }

    LaunchedEffect(Unit) { reload() }

    if (showingOptionsEditor) {
        RosaryOptionsEditorScreen(
            rosary = options,
            onRosaryChange = { options = it },
            onBack = { showingOptionsEditor = false },
        )
        return
    }

    BackHandler(onBack = onBack)

    val defaultPreset = presets.firstOrNull { it.isDefault }
    val otherPresets = presets.filter { !it.isDefault }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text("The Holy Rosary") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = { TextButton(onClick = onOpenFavorites) { Text("Manage") } },
            )
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(10.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            defaultPreset?.let { preset ->
                Text("Default Preset", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                PresetCard(preset, prominent = true) { onPrayPreset(preset.id) }
            }

            Text("Custom", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                    .padding(14.dp),
            ) {
                Text("Pray any Rosary", style = MaterialTheme.typography.titleMedium)
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showingOptionsEditor = true },
                ) {
                    Text("Rosary Options", modifier = Modifier.weight(1f))
                    Text(
                        options.mysterySelectionSummary,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                    Button(
                        onClick = { onPrayAdHoc(Prayer(kind = PrayerKind.Rosary, rosary = options)) },
                        modifier = Modifier.weight(1f),
                    ) { Text("Pray") }
                    OutlinedButton(
                        onClick = { showingSaveDialog = true },
                        modifier = Modifier.weight(1f),
                    ) { Text("Save as Preset") }
                }
            }

            if (otherPresets.isNotEmpty()) {
                Text("Presets", style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                for (preset in otherPresets) {
                    PresetCard(preset, prominent = false) { onPrayPreset(preset.id) }
                }
            }
        }
    }

    if (showingSaveDialog) {
        AlertDialog(
            onDismissRequest = { showingSaveDialog = false },
            title = { Text("Save as Preset") },
            text = {
                OutlinedTextField(
                    value = presetName,
                    onValueChange = { presetName = it },
                    label = { Text("Preset name") },
                    singleLine = true,
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    showingSaveDialog = false
                    scope.launch {
                        services.presetStore.save(
                            Prayer(
                                name = presetName.trim().ifEmpty { PrayerKind.Rosary.defaultName },
                                kind = PrayerKind.Rosary,
                                // Never steal the default slot unless it's the first preset.
                                isDefault = presets.isEmpty(),
                                rosary = options,
                            ),
                        )
                        presetName = ""
                        reload()
                    }
                }) { Text("Save") }
            },
            dismissButton = { TextButton(onClick = { showingSaveDialog = false }) { Text("Cancel") } },
        )
    }
}

@Composable
private fun PresetCard(preset: Prayer, prominent: Boolean, onPray: () -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(6.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(14.dp),
    ) {
        Text(
            preset.name,
            style = if (prominent) MaterialTheme.typography.titleLarge else MaterialTheme.typography.titleMedium,
        )
        Text(
            "${preset.rosary.mysterySelectionSummary} • ${preset.languageDisplayName}",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Button(onClick = onPray, modifier = Modifier.fillMaxWidth()) { Text("Pray") }
    }
}
