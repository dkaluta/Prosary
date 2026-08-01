package com.dkaluta.prosary.ui.categories

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.compose.runtime.DisposableEffect
import com.dkaluta.prosary.ui.shared.DevotionDirectory
import com.dkaluta.prosary.ui.shared.DevotionListing
import com.dkaluta.prosary.ui.shared.LaunchTarget

/** "View prayers by category": every launchable devotion grouped by its manifest tags —
 * a devotion appears under each of its tags; anything untagged lands under "Other".
 * Mirrors iOS's CategoriesView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CategoriesScreen(onLaunch: (LaunchTarget) -> Unit) {
    // Re-read the directory whenever we come back into view so a bundle installed on
    // another tab appears without a relaunch.
    var generation by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) generation++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val sections = remember(generation) {
        val byTag = mutableMapOf<String, MutableList<DevotionListing>>()
        for (listing in DevotionDirectory.all()) {
            if (listing.tags.isEmpty()) byTag.getOrPut("other") { mutableListOf() }.add(listing)
            for (tag in listing.tags) byTag.getOrPut(tag) { mutableListOf() }.add(listing)
        }
        byTag.toSortedMap().toList()
    }

    Scaffold(topBar = { TopAppBar(title = { Text("Categories") }) }) { paddingValues ->
        LazyColumn(
            modifier = Modifier.padding(paddingValues).fillMaxSize(),
            contentPadding = PaddingValues(vertical = 8.dp),
        ) {
            for ((tag, listings) in sections) {
                item(key = "header.$tag") {
                    Text(
                        tag.replaceFirstChar { it.uppercaseChar() },
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier.padding(horizontal = 20.dp, vertical = 8.dp),
                    )
                }
                items_(listings, tag, onLaunch)
            }
        }
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.items_(
    listings: List<DevotionListing>,
    tag: String,
    onLaunch: (LaunchTarget) -> Unit,
) {
    for (listing in listings) {
        item(key = "row.$tag.${listing.id}") {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onLaunch(listing.target) }
                    .padding(horizontal = 20.dp, vertical = 12.dp),
            ) {
                Icon(
                    listing.icon,
                    contentDescription = null,
                    tint = listing.accentColor ?: MaterialTheme.colorScheme.primary,
                )
                Text(listing.title, style = MaterialTheme.typography.bodyLarge)
            }
        }
    }
}
