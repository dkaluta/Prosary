package com.dkaluta.prosary.ui.search

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.repository.RepositoryBundle
import com.dkaluta.prosary.content.repository.RepositoryClient
import com.dkaluta.prosary.ui.shared.DevotionDirectory
import com.dkaluta.prosary.ui.shared.LaunchTarget
import kotlinx.coroutines.launch

/** One search across everything prayable: devotions on this device (opened in place) and the
 * prayers.prosary.app catalog (installed in place). The repository half loads once and
 * degrades silently offline, leaving local search fully working. Mirrors iOS's SearchTabView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SearchScreen(onLaunch: (LaunchTarget) -> Unit) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var query by remember { mutableStateOf("") }
    var repoBundles by remember { mutableStateOf<List<RepositoryBundle>>(emptyList()) }
    var busyIds by remember { mutableStateOf(setOf<String>()) }
    var generation by remember { mutableIntStateOf(0) }

    LaunchedEffect(Unit) {
        repoBundles = runCatching { RepositoryClient.fetchCatalog() }.getOrDefault(emptyList())
    }

    @Suppress("UNUSED_EXPRESSION") generation
    val localMatches = DevotionDirectory.all(context).filter { listing ->
        query.isBlank() || listing.title.contains(query, ignoreCase = true) ||
            listing.tags.any { it.contains(query, ignoreCase = true) }
    }
    val installed = PrayerPackStore.customDevotionIds().toSet()
    val communityMatches = repoBundles.filter { bundle ->
        bundle.id !in installed && (
            query.isBlank() ||
                "${bundle.name} ${bundle.author} ${bundle.description} ${bundle.tags.joinToString(" ")}"
                    .contains(query, ignoreCase = true)
            )
    }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is
    // invisible and scrolled content clips at a dead band around the floating title.
    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()
    Scaffold(
        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = { TopAppBar(title = { Text(stringResource(R.string.tab_search)) }, scrollBehavior = topBarScroll) },
    ) { paddingValues ->
        LazyColumn(
            modifier = Modifier.padding(paddingValues).fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item(key = "query") {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text(stringResource(R.string.search_hint)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            item(key = "localHeader") {
                Text(stringResource(R.string.search_on_device), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
            }
            for (listing in localMatches) {
                item(key = "local.${listing.id}") {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(14.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onLaunch(listing.target) }
                            .padding(vertical = 10.dp),
                    ) {
                        if (listing.iconGlyph != null) {
                            Text(listing.iconGlyph, color = listing.accentColor ?: MaterialTheme.colorScheme.primary)
                        } else {
                            Icon(listing.icon, contentDescription = null, tint = listing.accentColor ?: MaterialTheme.colorScheme.primary)
                        }
                        Text(listing.title, style = MaterialTheme.typography.bodyLarge)
                    }
                }
            }
            if (localMatches.isEmpty()) {
                item(key = "localEmpty") {
                    Text(stringResource(R.string.search_no_device_match), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            if (communityMatches.isNotEmpty()) {
                item(key = "communityHeader") {
                    Text(stringResource(R.string.search_from_community), style = MaterialTheme.typography.titleSmall, color = MaterialTheme.colorScheme.primary)
                }
                for (bundle in communityMatches) {
                    item(key = "community.${bundle.id}") {
                        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                            Column(Modifier.weight(1f)) {
                                Text(bundle.name, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    "${bundle.author} · ${bundle.tags.joinToString(" · ")}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            Spacer(Modifier.width(8.dp))
                            if (bundle.id in busyIds) {
                                CircularProgressIndicator(Modifier.width(24.dp))
                            } else {
                                Button(onClick = {
                                    busyIds = busyIds + bundle.id
                                    scope.launch {
                                        runCatching {
                                            PrayerPackStore.installPack(RepositoryClient.downloadBundle(bundle))
                                        }
                                        busyIds = busyIds - bundle.id
                                        generation++
                                    }
                                }) { Text(stringResource(R.string.common_install)) }
                            }
                        }
                    }
                }
            }
        }
    }
}
