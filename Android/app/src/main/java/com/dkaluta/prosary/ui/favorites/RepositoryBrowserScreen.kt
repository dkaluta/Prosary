package com.dkaluta.prosary.ui.favorites

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import androidx.compose.ui.platform.LocalContext
import com.dkaluta.prosary.content.repository.RepositoryBundle
import com.dkaluta.prosary.content.repository.RepositoryClient
import com.dkaluta.prosary.content.repository.RepositoryInstallStamps
import com.dkaluta.prosary.models.LanguageCatalog
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/** The in-app browser for prayers.prosary.app: fetches the catalog, filters by search text
 * and tag, and installs through the exact same [PrayerPackStore.installPack] pipeline as a
 * manual file import — so an installed community devotion behaves identically (star row,
 * "Repository" tag, remove affordance). Mirrors iOS's RepositoryBrowserView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RepositoryBrowserScreen(onBack: () -> Unit, showsBackButton: Boolean = true) {
    val scope = rememberCoroutineScope()
    var bundles by remember { mutableStateOf<List<RepositoryBundle>>(emptyList()) }
    var isLoading by remember { mutableStateOf(true) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var searchText by remember { mutableStateOf("") }
    var selectedTag by remember { mutableStateOf<String?>(null) }
    var busyIds by remember { mutableStateOf(setOf<String>()) }
    var installedGeneration by remember { mutableIntStateOf(0) }
    var installError by remember { mutableStateOf<String?>(null) }
    var reloadToken by remember { mutableIntStateOf(0) }

    var isRefreshing by remember { mutableStateOf(false) }

    suspend fun refresh(pulled: Boolean) {
        if (pulled) isRefreshing = true else isLoading = true
        loadError = null
        try {
            bundles = RepositoryClient.fetchCatalog()
        } catch (cancelled: CancellationException) {
            // Leaving the tab (or a superseding refresh) mid-fetch is not a repository
            // outage — swallowing it into runCatching painted "unavailable / cancelled"
            // over a perfectly healthy catalog.
            throw cancelled
        } catch (error: Exception) {
            loadError = error.message ?: "The repository could not be reached."
        } finally {
            isRefreshing = false
            isLoading = false
        }
    }

    LaunchedEffect(reloadToken) { refresh(pulled = false) }

    val allTags = remember(bundles) { bundles.flatMap { it.tags }.distinct().sorted() }
    val filtered = bundles.filter { bundle ->
        (selectedTag == null || selectedTag in bundle.tags) &&
            (searchText.isBlank() ||
                "${bundle.name} ${bundle.author} ${bundle.description} ${bundle.id}"
                    .contains(searchText, ignoreCase = true))
    }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text("Community Devotions") },
                navigationIcon = {
                    if (showsBackButton) {
                        IconButton(onClick = onBack) {
                            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                        }
                    }
                },
            )
        },
    ) { paddingValues ->
        when {
            isLoading -> Box(Modifier.padding(paddingValues).fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator()
            }
            loadError != null -> Column(
                Modifier.padding(paddingValues).fillMaxSize().padding(24.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(loadError ?: "", textAlign = androidx.compose.ui.text.style.TextAlign.Center)
                TextButton(onClick = { reloadToken++ }) { Text("Retry") }
            }
            else -> PullToRefreshBox(
                isRefreshing = isRefreshing,
                onRefresh = { scope.launch { refresh(pulled = true) } },
                modifier = Modifier.padding(paddingValues).fillMaxSize(),
            ) {
                LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "search") {
                    OutlinedTextField(
                        value = searchText,
                        onValueChange = { searchText = it },
                        label = { Text("Search devotions") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (allTags.size > 1) {
                    item(key = "tags") {
                        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            item {
                                FilterChip(
                                    selected = selectedTag == null,
                                    onClick = { selectedTag = null },
                                    label = { Text("All") },
                                )
                            }
                            items(allTags) { tag ->
                                FilterChip(
                                    selected = selectedTag == tag,
                                    onClick = { selectedTag = tag },
                                    label = { Text(tag) },
                                )
                            }
                        }
                    }
                }
                items(filtered, key = { "bundle.$installedGeneration.${it.id}" }) { bundle ->
                    val context = LocalContext.current
                    val isInstalled = bundle.id in PrayerPackStore.customDevotionIds()
                    val hasUpdate = RepositoryInstallStamps.hasUpdate(context, bundle, isInstalled)
                    fun installBundle(replacingExisting: Boolean) {
                        busyIds = busyIds + bundle.id
                        scope.launch {
                            runCatching {
                                val bytes = RepositoryClient.downloadBundle(bundle)
                                // installPack skips id collisions, so an update removes the old
                                // copy first — download succeeded, the pack-less window is tiny.
                                if (replacingExisting) PrayerPackStore.removeInstalledPack(bundle.id)
                                PrayerPackStore.installPack(bytes)
                            }.onSuccess {
                                RepositoryInstallStamps.record(context, bundle.id, bundle.updatedAt)
                                installedGeneration++
                            }.onFailure { error ->
                                installError = error.message ?: "Could not install the devotion."
                            }
                            busyIds = busyIds - bundle.id
                        }
                    }
                    Card {
                        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(bundle.name, style = MaterialTheme.typography.titleMedium)
                                    Text(
                                        "${bundle.author} · ${languageNames(bundle.languages)}",
                                        style = MaterialTheme.typography.bodySmall,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                }
                                Spacer(Modifier.width(8.dp))
                                when {
                                    bundle.id in busyIds -> CircularProgressIndicator(Modifier.width(24.dp))
                                    hasUpdate -> Button(onClick = { installBundle(replacingExisting = true) }) {
                                        Text("Update")
                                    }
                                    isInstalled -> Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Filled.Check, contentDescription = null, tint = MaterialTheme.colorScheme.onSurfaceVariant)
                                        Text(
                                            "Installed",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                    else -> Button(onClick = { installBundle(replacingExisting = false) }) { Text("Install") }
                                }
                            }
                            if (bundle.description.isNotEmpty()) {
                                Text(
                                    bundle.description,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            if (bundle.tags.isNotEmpty()) {
                                Text(
                                    bundle.tags.joinToString(" · "),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.primary,
                                )
                            }
                        }
                    }
                }
                if (filtered.isEmpty()) {
                    item(key = "empty") {
                        Text(
                            "No devotions match.",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(8.dp),
                        )
                    }
                }
                }
            }
        }
    }

    installError?.let { message ->
        AlertDialog(
            onDismissRequest = { installError = null },
            title = { Text("Could Not Install Devotion") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { installError = null }) { Text("OK") } },
        )
    }
}

private fun languageNames(codes: List<String>): String =
    codes.mapNotNull { code -> LanguageCatalog.all.firstOrNull { it.code == code }?.nativeName }
        .joinToString(", ")
