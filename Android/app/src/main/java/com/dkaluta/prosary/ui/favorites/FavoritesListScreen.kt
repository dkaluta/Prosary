package com.dkaluta.prosary.ui.favorites

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
import androidx.compose.material.icons.automirrored.filled.DirectionsWalk
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.WaterDrop
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material.icons.filled.WorkspacePremium
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
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.LocalAppServices
import kotlinx.coroutines.launch

private fun iconFor(kind: PrayerKind): ImageVector = when (kind) {
    PrayerKind.Rosary -> Icons.Filled.Circle
    PrayerKind.Angelus -> Icons.Filled.Notifications
    PrayerKind.JesusPrayer -> Icons.Filled.Favorite
    PrayerKind.StationsOfTheCross -> Icons.AutoMirrored.Filled.DirectionsWalk
    PrayerKind.FranciscanCrown -> Icons.Filled.WorkspacePremium
    PrayerKind.SevenSorrows -> Icons.Filled.WaterDrop
    PrayerKind.DivineMercyChaplet -> Icons.Filled.WbSunny
}

private fun accentFor(kind: PrayerKind): Color = when (kind) {
    PrayerKind.Rosary -> Color(0xFF7A1F3D)
    PrayerKind.Angelus -> Color(0xFF8B6914)
    PrayerKind.JesusPrayer -> Color(0xFF8B1A1A)
    PrayerKind.StationsOfTheCross -> Color(0xFF5C2D91)
    PrayerKind.FranciscanCrown -> Color(0xFF6B4226)
    PrayerKind.SevenSorrows -> Color(0xFF6B0F1A)
    PrayerKind.DivineMercyChaplet -> Color(0xFFC41E3A)
}

/** Rosary and Jesus Prayer have real per-favorite options worth naming and saving multiple
 * variants of, so they keep the full card list + editor. The other 5 kinds have nothing to
 * configure beyond reminders, so they get a single on/off star row instead — see
 * [SimpleFavoriteRow]. */
private val configurableKinds = listOf(PrayerKind.Rosary, PrayerKind.JesusPrayer)
private val simplifiedKinds = listOf(
    PrayerKind.Angelus,
    PrayerKind.StationsOfTheCross,
    PrayerKind.FranciscanCrown,
    PrayerKind.SevenSorrows,
    PrayerKind.DivineMercyChaplet,
)

/** Card-layout list of saved prayer favorites grouped by kind. Replaces the old presets-only
 * list, mirrors iOS's FavoritesListView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesListScreen(
    onPray: (String) -> Unit,
    onEdit: (String) -> Unit,
    onAddNew: (PrayerKind) -> Unit,
    onEditReminders: (String) -> Unit,
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
            for (kind in configurableKinds) {
                val kindPrayers = prayers.filter { it.kind == kind }

                stickyHeader { KindHeader(kind) }

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

            stickyHeader {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.background)
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                ) {
                    Icon(Icons.Filled.Star, contentDescription = null)
                    Text("More Devotions", style = MaterialTheme.typography.titleMedium)
                }
            }

            items(simplifiedKinds, key = { it.name }) { kind ->
                val favorite = prayers.firstOrNull { it.kind == kind }
                SimpleFavoriteRow(
                    kind = kind,
                    accentColor = accentFor(kind),
                    isFavorited = favorite != null,
                    onToggleFavorite = {
                        scope.launch {
                            if (favorite != null) {
                                ReminderScheduler.cancelAll(context, favorite)
                                services.presetStore.delete(favorite)
                            } else {
                                services.presetStore.save(
                                    Prayer(
                                        name = kind.defaultName,
                                        kind = kind,
                                        isDefault = true,
                                        languageCode = LanguageCatalog.defaultSentinel,
                                    ),
                                )
                            }
                            reload()
                        }
                    },
                    onEditReminders = { favorite?.let { onEditReminders(it.id) } },
                )
            }
        }
    }
}

@Composable
private fun KindHeader(kind: PrayerKind) {
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
        PrayerKind.StationsOfTheCross -> prayer.languageDisplayName
        PrayerKind.FranciscanCrown -> prayer.languageDisplayName
        PrayerKind.SevenSorrows -> prayer.languageDisplayName
        PrayerKind.DivineMercyChaplet -> prayer.languageDisplayName
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

/** One row per non-configurable devotion kind — a star toggle and, once favorited, a reminders
 * button. No name/language editing and no "+ Add another" — see [FavoritesListScreen]. */
@Composable
private fun SimpleFavoriteRow(
    kind: PrayerKind,
    accentColor: Color,
    isFavorited: Boolean,
    onToggleFavorite: () -> Unit,
    onEditReminders: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(MaterialTheme.colorScheme.surfaceContainerHigh)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    ) {
        IconButton(onClick = onToggleFavorite) {
            Icon(
                if (isFavorited) Icons.Filled.Star else Icons.Filled.StarBorder,
                contentDescription = if (isFavorited) "Remove ${kind.displayName} from Favorites" else "Add ${kind.displayName} to Favorites",
                tint = if (isFavorited) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Icon(iconFor(kind), contentDescription = null, tint = accentColor)
        Text(kind.displayName, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))

        if (isFavorited) {
            IconButton(onClick = onEditReminders) {
                Icon(Icons.Filled.Notifications, contentDescription = "Edit ${kind.displayName} reminders", tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
