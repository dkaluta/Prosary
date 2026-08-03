package com.dkaluta.prosary.ui.favorites

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.AlertDialog
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
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
import androidx.compose.material.icons.filled.StarBorder
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
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.shared.colorForHex
import com.dkaluta.prosary.ui.shared.iconForSystemName
import kotlinx.coroutines.launch

private fun iconFor(kind: PrayerKind): ImageVector = when (kind) {
    PrayerKind.Rosary -> Icons.Filled.Circle
    PrayerKind.JesusPrayer -> Icons.Filled.Favorite
    // Unreachable in practice — .Custom rows read the bundle's own iconSystemName instead (see
    // the customDevotionIds loop below). Still needed for exhaustiveness.
    PrayerKind.Custom -> Icons.Filled.Star
}

private fun accentFor(kind: PrayerKind): Color = when (kind) {
    PrayerKind.Rosary -> Color(0xFF7A1F3D)
    PrayerKind.JesusPrayer -> Color(0xFF8B1A1A)
    // Unreachable in practice — .Custom rows read the bundle's own accentColorHex instead. Still
    // needed for exhaustiveness.
    PrayerKind.Custom -> Color(0xFF7A1F3D)
}

/** Rosary and Jesus Prayer have real per-favorite options worth naming and saving multiple
 * variants of, so they keep the full card list + editor. Every generic (bundle-driven) devotion
 * has nothing to configure beyond reminders, so it gets a single on/off star row instead — see
 * [SimpleFavoriteRow]. */
private val configurableKinds = listOf(PrayerKind.Rosary, PrayerKind.JesusPrayer)

/** Card-layout list of saved prayer favorites grouped by kind. Replaces the old presets-only
 * list, mirrors iOS's FavoritesListView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FavoritesListScreen(
    onPray: (String) -> Unit,
    onEdit: (String) -> Unit,
    onAddNew: (PrayerKind) -> Unit,
    onEditReminders: (String) -> Unit,
    onBrowseRepository: () -> Unit,
    onBack: () -> Unit,
) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var prayers by remember { mutableStateOf<List<Prayer>>(emptyList()) }
    var importError by remember { mutableStateOf<String?>(null) }
    // Bumped after install/remove so the customDevotionIds list re-evaluates.
    var installedGeneration by remember { mutableStateOf(0) }

    // Round-trip to Compose (Gamaliel item 7): SAF create-document, then copy the installed
    // pack's bytes out — no FileProvider needed.
    var exportBundleId by remember { mutableStateOf<String?>(null) }
    val exportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri ->
        val id = exportBundleId
        exportBundleId = null
        if (uri != null && id != null) {
            PrayerPackStore.installedPackFile(id)?.let { file ->
                context.contentResolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { it.copyTo(out) }
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw PrayerPackStore.InstallException("This file is not a readable .prosaryprayer bundle.")
            PrayerPackStore.installPack(bytes)
        }.onSuccess {
            installedGeneration++
        }.onFailure { error ->
            importError = error.message ?: "Could not import the bundle."
        }
    }

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

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text(stringResource(R.string.favorites_title)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
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
                        Text(stringResource(R.string.favorites_add_kind, stringResource(kind.displayNameRes)), color = accentFor(kind))
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
                    Text(stringResource(R.string.favorites_more_devotions), style = MaterialTheme.typography.titleMedium)
                }
            }

            // Generic (bundle-driven) devotions — one row per discovered bundle, in pack-load
            // order, with no hardcoded PrayerKind case.
            items(PrayerPackStore.customDevotionIds(), key = { "custom.$installedGeneration.$it" }) { bundleId ->
                val info = PrayerPackStore.info(bundleId)
                if (info != null) {
                    val favorite = prayers.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == bundleId }
                    SimpleFavoriteRow(
                        title = info.localizedDisplayName,
                        icon = iconForSystemName(info.iconSystemName),
                        accentColor = colorForHex(info.accentColorHex) ?: MaterialTheme.colorScheme.primary,
                        isFavorited = favorite != null,
                        badge = if (bundleId.startsWith("repo.")) stringResource(R.string.favorites_repository_badge) else null,
                        onToggleFavorite = {
                            scope.launch {
                                if (favorite != null) {
                                    ReminderScheduler.cancelAll(context, favorite)
                                    services.presetStore.delete(favorite)
                                } else {
                                    services.presetStore.save(
                                        Prayer(
                                            name = info.localizedDisplayName,
                                            kind = PrayerKind.Custom,
                                            isDefault = true,
                                            languageCode = LanguageCatalog.defaultSentinel,
                                            customDevotionId = bundleId,
                                        ),
                                    )
                                }
                                reload()
                            }
                        },
                        onEditReminders = { favorite?.let { onEditReminders(it.id) } },
                        onExportInstalled = if (bundleId in PrayerPackStore.installedBundleIds()) {
                            {
                                exportBundleId = bundleId
                                exportLauncher.launch("$bundleId.prosaryprayer")
                            }
                        } else {
                            null
                        },
                        onRemoveInstalled = if (bundleId in PrayerPackStore.installedBundleIds()) {
                            {
                                scope.launch {
                                    favorite?.let {
                                        ReminderScheduler.cancelAll(context, it)
                                        services.presetStore.delete(it)
                                    }
                                    PrayerPackStore.removeInstalledPack(bundleId)
                                    installedGeneration++
                                    reload()
                                }
                            }
                        } else {
                            null
                        },
                    )
                }
            }

            // Anyone can author a .prosaryprayer bundle (see Shared/ARCHITECTURE.md) — imported
            // devotions get the same star row as the shipped ones.
            item(key = "importBundle") {
                TextButton(
                    onClick = { importLauncher.launch(arrayOf("*/*")) },
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    Icon(Icons.Filled.Download, contentDescription = null)
                    Text(stringResource(R.string.favorites_import), modifier = Modifier.padding(start = 8.dp))
                }
            }

            // The other half of importing: browse prayers.prosary.app's catalog in place and
            // install with one tap — same installPack pipeline, no file juggling.
            item(key = "browseRepository") {
                TextButton(
                    onClick = onBrowseRepository,
                    modifier = Modifier.padding(horizontal = 16.dp),
                ) {
                    Icon(Icons.Filled.Language, contentDescription = null)
                    Text(stringResource(R.string.favorites_get_community), modifier = Modifier.padding(start = 8.dp))
                }
            }
        }
    }

    importError?.let { message ->
        AlertDialog(
            onDismissRequest = { importError = null },
            title = { Text(stringResource(R.string.favorites_import_error_title)) },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { importError = null }) { Text(stringResource(R.string.common_ok)) } },
        )
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
        Text(stringResource(kind.displayNameRes), style = MaterialTheme.typography.titleMedium)
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
    val rowContext = LocalContext.current
    val subtitle = when (prayer.kind) {
        PrayerKind.Rosary -> "${prayer.rosary.mysterySelectionSummary(rowContext)} • ${prayer.languageDisplayName(rowContext)}"
        PrayerKind.JesusPrayer -> "${prayer.jesusPrayer.targetDisplayName(rowContext)} • ${prayer.languageDisplayName(rowContext)}"
        // Unreachable in practice — .Custom favorites render via SimpleFavoriteRow, never
        // FavoriteCard (see configurableKinds above). Still needed for exhaustiveness.
        PrayerKind.Custom -> prayer.languageDisplayName(rowContext)
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
                Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.favorites_edit_desc, prayer.name), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Delete, contentDescription = stringResource(R.string.favorites_delete_desc, prayer.name), tint = MaterialTheme.colorScheme.error)
            }
        }

        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
            Button(
                onClick = onPray,
                modifier = Modifier.weight(1f),
                colors = ButtonDefaults.buttonColors(containerColor = accentColor),
            ) {
                Text(stringResource(R.string.common_pray))
            }

            if (!prayer.isDefault) {
                OutlinedButton(onClick = onMakeDefault, modifier = Modifier.weight(1f)) {
                    Text(stringResource(R.string.favorites_set_default))
                }
            }
        }
    }
}

/** One row per non-configurable devotion — a star toggle and, once favorited, a reminders
 * button. No name/language editing and no "+ Add another" — see [FavoritesListScreen]. [title]/
 * [icon] are passed in rather than derived from a [PrayerKind] so this same row can render either
 * one of the 5 hardcoded simplified kinds or a generic bundle-driven devotion. */
@Composable
private fun SimpleFavoriteRow(
    title: String,
    icon: ImageVector,
    accentColor: Color,
    isFavorited: Boolean,
    onToggleFavorite: () -> Unit,
    onEditReminders: () -> Unit,
    /** Non-null only for user-imported bundles — shows the trailing remove button. */
    onExportInstalled: (() -> Unit)? = null,
    onRemoveInstalled: (() -> Unit)? = null,
    /** Small capsule after the title — "Repository" for bundles installed from
     * prayers.prosary.app (ids prefixed "repo.", see ARCHITECTURE.md). Null hides it. */
    badge: String? = null,
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
                contentDescription = if (isFavorited) stringResource(R.string.favorites_remove_favorite_desc, title) else stringResource(R.string.favorites_add_favorite_desc, title),
                tint = if (isFavorited) accentColor else MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Icon(icon, contentDescription = null, tint = accentColor)
        Text(title, style = MaterialTheme.typography.titleMedium)
        if (badge != null) {
            Text(
                badge,
                style = MaterialTheme.typography.labelSmall,
                color = accentColor,
                modifier = Modifier
                    .clip(RoundedCornerShape(999.dp))
                    .background(accentColor.copy(alpha = 0.15f))
                    .padding(horizontal = 6.dp, vertical = 2.dp),
            )
        }
        Spacer(modifier = Modifier.weight(1f))

        if (isFavorited) {
            IconButton(onClick = onEditReminders) {
                Icon(Icons.Filled.Notifications, contentDescription = stringResource(R.string.favorites_reminders_desc, title), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        if (onExportInstalled != null) {
            // Round-trip to Compose: save the .prosaryprayer, edit it at compose.prosary.app,
            // re-import (or republish) — Gamaliel item 7.
            IconButton(onClick = onExportInstalled) {
                Icon(Icons.Filled.Share, contentDescription = stringResource(R.string.favorites_export_desc, title), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        if (onRemoveInstalled != null) {
            IconButton(onClick = onRemoveInstalled) {
                Icon(Icons.Filled.Delete, contentDescription = stringResource(R.string.favorites_remove_imported_desc, title), tint = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
