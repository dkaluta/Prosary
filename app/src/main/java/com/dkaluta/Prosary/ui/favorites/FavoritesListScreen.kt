package com.dkaluta.Prosary.ui.favorites

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.Prosary.models.Prayer
import com.dkaluta.Prosary.models.PrayerKind
import com.dkaluta.Prosary.reminders.ReminderScheduler
import com.dkaluta.Prosary.services.LocalAppServices
import kotlinx.coroutines.launch

private fun iconFor(kind: PrayerKind): ImageVector = when (kind) {
    PrayerKind.Rosary -> Icons.Filled.Circle
    PrayerKind.Angelus -> Icons.Filled.Notifications
    PrayerKind.JesusPrayer -> Icons.Filled.Favorite
}

private fun accentFor(kind: PrayerKind): Color = when (kind) {
    PrayerKind.Rosary -> Color(0xFF7A1F3D)
    PrayerKind.Angelus -> Color(0xFF8B6914)
    PrayerKind.JesusPrayer -> Color(0xFF8B1A1A)
}

/** Card-layout list of saved prayer favorites grouped by kind. Replaces the old presets-only
 * list, mirrors iOS's FavoritesListView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesListScreen(
    onPray: (String) -> Unit,
    onEdit: (String) -> Unit,
    onAddNew: (PrayerKind) -> Unit,
    onBack: () -> Unit,
) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var prayers by remember { mutableStateOf<List<Prayer>>(emptyList()) }

    suspend fun reload() {
        prayers = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
    }

    LaunchedEffect(Unit) { reload() }

    // Mirrors reloading the list after the editor screen is popped back to this one.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                scope.launch { reload() }
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Favorites") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(modifier = Modifier.fillMaxSize().padding(padding)) {
            for (kind in PrayerKind.entries) {
                val kindPrayers = prayers.filter { it.kind == kind }

                stickyHeader {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.background)
                            .padding(horizontal = 20.dp, vertical = 12.dp),
                    ) {
                        Icon(iconFor(kind), contentDescription = null, tint = accentFor(kind))
                        Text(kind.displayName, style = MaterialTheme.typography.titleMedium)
                    }
                }

                items(kindPrayers, key = { it.id }) { prayer ->
                    FavoriteCard(
                        prayer = prayer,
                        accentColor = accentFor(kind),
                        onPray = { onPray(prayer.id) },
                        onEdit = { onEdit(prayer.id) },
                        onMakeDefault = {
                            scope.launch {
                                services.presetStore.save(prayer.copy(isDefault = true))
                                reload()
                            }
                        },
                        onDelete = {
                            ReminderScheduler.cancelAll(context, prayer)
                            scope.launch {
                                services.presetStore.delete(prayer)
                                reload()
                            }
                        },
                    )
                }

                item {
                    TextButton(onClick = { onAddNew(kind) }, modifier = Modifier.padding(horizontal = 12.dp)) {
                        Icon(Icons.Filled.Add, contentDescription = null, tint = accentFor(kind))
                        Text("Add ${kind.displayName}", color = accentFor(kind))
                    }
                }
            }
        }
    }
}

@Composable
private fun FavoriteCard(
    prayer: Prayer,
    accentColor: Color,
    onPray: () -> Unit,
    onEdit: () -> Unit,
    onMakeDefault: () -> Unit,
    onDelete: () -> Unit,
) {
    val subtitle = when (prayer.kind) {
        PrayerKind.Rosary -> "${prayer.rosary.mysterySelectionSummary} • ${prayer.languageDisplayName}"
        PrayerKind.Angelus -> prayer.languageDisplayName
        PrayerKind.JesusPrayer -> "${prayer.jesusPrayer.targetDisplayName} • ${prayer.languageDisplayName}"
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(prayer.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            if (prayer.isDefault) {
                Icon(Icons.Filled.Star, contentDescription = null, tint = accentColor, modifier = Modifier.padding(end = 4.dp))
            }
            IconButton(onClick = onEdit) {
                Icon(Icons.Filled.Edit, contentDescription = "Edit ${prayer.name}", tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Delete, contentDescription = "Delete ${prayer.name}", tint = MaterialTheme.colorScheme.error)
            }
        }

        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Button(
                onClick = onPray,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = accentColor),
            ) {
                Text("Pray")
            }

            if (!prayer.isDefault) {
                OutlinedButton(onClick = onMakeDefault, modifier = Modifier.weight(1f)) {
                    Text("Set Default")
                }
            }
        }
    }
}
