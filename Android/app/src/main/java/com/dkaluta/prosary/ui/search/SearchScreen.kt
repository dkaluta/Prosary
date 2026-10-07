package com.dkaluta.prosary.ui.search

import com.dkaluta.prosary.ui.shared.CategoryLabels

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.testTag
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.R
import com.dkaluta.prosary.typography.HebrewDisplayText
import com.dkaluta.prosary.ui.shared.DevotionDirectory
import com.dkaluta.prosary.ui.shared.LaunchTarget

/** Search local prayers and open the community catalogue from the same discovery workspace. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalLayoutApi::class)
@Composable
fun SearchScreen(onLaunch: (LaunchTarget) -> Unit, onOpenCommunity: () -> Unit = {}) {
    val context = LocalContext.current
    var query by rememberSaveable { mutableStateOf("") }
    var selectedCategory by rememberSaveable { mutableStateOf<String?>(null) }
    var generation by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) generation++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    @Suppress("UNUSED_EXPRESSION") generation
    val localListings = DevotionDirectory.all(context)
    val categories = SearchFilter.categories(localListings.map { it.tags })
        .sortedBy { CategoryLabels.label(it, context) }
    val categoryLabel: (String) -> String = { CategoryLabels.label(it, context) }
    val localMatches = localListings.filter { listing ->
        SearchFilter.matches(query, selectedCategory, listing.tags,
            listOfNotNull(listing.title, listing.interfaceTitle), categoryLabel)
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
            item(key = "community") {
                OutlinedButton(onClick = onOpenCommunity, modifier = Modifier.fillMaxWidth().testTag("searchCommunity")) {
                    Text(stringResource(R.string.home_widgets_community))
                }
            }
            item(key = "query") {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    label = { Text(stringResource(R.string.search_hint)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth().testTag("searchQuery"),
                )
            }
            item(key = "categories") {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(stringResource(R.string.tab_categories), style = MaterialTheme.typography.titleSmall)
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        FilterChip(
                            selected = selectedCategory == null,
                            onClick = { selectedCategory = null },
                            label = { Text(stringResource(R.string.search_all_categories)) },
                            modifier = Modifier.testTag("searchCategoryAll"),
                        )
                        // Keep a removed category visible until cleared, rather than silently
                        // broadening a filter when its last local prayer is uninstalled.
                        for (tag in (categories + listOfNotNull(selectedCategory)).distinct()) {
                            FilterChip(
                                selected = selectedCategory == tag,
                                onClick = { selectedCategory = if (selectedCategory == tag) null else tag },
                                label = { Text(categoryLabel(tag)) },
                                modifier = Modifier.testTag("searchCategory.$tag"),
                            )
                        }
                    }
                }
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
                        Column(Modifier.weight(1f)) {
                            Text(HebrewDisplayText.unpoint(listing.title), style = MaterialTheme.typography.bodyLarge)
                            listing.interfaceTitle?.let {
                                Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
            if (localMatches.isEmpty()) {
                item(key = "localEmpty") {
                    Text(stringResource(R.string.search_no_device_match), color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
        }
    }
}
