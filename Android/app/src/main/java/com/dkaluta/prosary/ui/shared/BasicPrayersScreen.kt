package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.PushPin
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.outlined.PushPin
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.BasicPrayerCatalog
import com.dkaluta.prosary.models.BasicPrayersOrder
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.PrayerCardTitle
import com.dkaluta.prosary.ui.home.HomeOrderEditor
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.runtime.CompositionLocalProvider

/**
 * The basic prayers on their own, outside any devotion (Erez, 2026-08-07) — a plain list from
 * [BasicPrayerCatalog], each row opening its prayer as a single step in the shared flow chrome.
 * Row titles resolve in the prayer language through the same chains the flows use, so the list
 * itself reads in the rite being prayed. Mirrors iOS's BasicPrayersView.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BasicPrayersScreen(onOpen: (String) -> Unit, onNavigateUp: () -> Unit) {
    val chosenLanguage = AppSettings.basicPrayersLanguageCode
    val language = LanguageCatalog.resolve(chosenLanguage)
    var languageMenuExpanded by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val interfaceLanguage = com.dkaluta.prosary.content.today.TodayTranslationLanguage.resolve(context.resources.configuration.locales[0].toLanguageTag())
    // The order lives in BasicPrayersOrder, not in view state; the generation bump just makes
    // this composition re-derive after the editor saves (the HomeOrder pattern, Erez
    // 2026-08-08).
    var orderGeneration by remember { mutableIntStateOf(0) }
    var showsOrderEditor by remember { mutableStateOf(false) }
    val ordered = remember(orderGeneration) {
        BasicPrayersOrder.apply(context, BasicPrayerCatalog.all)
    }
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.basic_prayers_title)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateUp) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
                    }
                },
                actions = {
                    PrayerLanguagePicker(
                        chosenLanguage = chosenLanguage,
                        expanded = languageMenuExpanded,
                        onExpandedChange = { languageMenuExpanded = it },
                        onSelect = AppSettings::setBasicPrayersLanguageCode,
                    )
                    IconButton(onClick = { showsOrderEditor = true }) {
                        Icon(Icons.Filled.SwapVert, contentDescription = stringResource(R.string.prayer_order_title))
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.padding(padding),
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            items(ordered, key = { it.id }) { prayer ->
                val cardTitle = PrayerCardTitle.resolve(BasicPrayerCatalog.title(prayer, interfaceLanguage), BasicPrayerCatalog.title(prayer, language.code))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onOpen(prayer.id) }
                        .padding(horizontal = 20.dp, vertical = 12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    MysteryImage(
                        imageKey = prayer.imageKey,
                        modifier = Modifier
                            .size(44.dp)
                            .clip(RoundedCornerShape(8.dp)),
                    )
                    CompositionLocalProvider(
                        LocalLayoutDirection provides
                            if (AppSettings.showPrayerNameInPrayerLanguage && language.isRightToLeft ||
                                !AppSettings.showPrayerNameInPrayerLanguage && interfaceLanguage in setOf("he", "ar")) LayoutDirection.Rtl else LayoutDirection.Ltr,
                    ) {
                        Column(Modifier.weight(1f)) {
                            Text(cardTitle.primary, style = MaterialTheme.typography.titleMedium)
                            cardTitle.interfaceSubtitle?.let {
                                Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                    IconButton(onClick = {
                        AppSettings.toggleFavoriteBasicPrayer(prayer.id)
                        orderGeneration++
                    }) {
                        val isFavorite = prayer.id in AppSettings.favoriteBasicPrayerIds
                        Icon(
                            if (isFavorite) Icons.Filled.PushPin else Icons.Outlined.PushPin,
                            contentDescription = stringResource(
                                if (isFavorite) R.string.basic_prayers_unpin
                                else R.string.basic_prayers_pin,
                            ),
                        )
                    }
                }
            }
        }
    }
    if (showsOrderEditor) {
        // The same generic drag-handle editor Home uses; titles resolve in the prayer
        // language, so the dialog reads exactly like the list behind it.
        HomeOrderEditor(
            titles = BasicPrayersOrder.apply(context, BasicPrayerCatalog.all).map {
                it.id to PrayerCardTitle.resolve(BasicPrayerCatalog.title(it, interfaceLanguage), BasicPrayerCatalog.title(it, language.code)).primary
            },
            onMove = { ids ->
                BasicPrayersOrder.save(context, ids)
                orderGeneration++
            },
            onReset = {
                BasicPrayersOrder.reset(context)
                orderGeneration++
            },
            onDismiss = { showsOrderEditor = false },
        )
    }
}

/** One basic prayer as a bounded single-step flow — "Finish" is its only footer action. */
@Composable
fun BasicPrayerFlowScreen(prayerId: String, onNavigateUp: () -> Unit) {
    val prayer = BasicPrayerCatalog.prayer(prayerId) ?: run { onNavigateUp(); return }
    val chosenLanguage = AppSettings.basicPrayersLanguageCode
    val language = LanguageCatalog.resolve(chosenLanguage)
    var languageMenuExpanded by remember { mutableStateOf(false) }
    val step = remember(prayerId, language.code) { BasicPrayerCatalog.step(prayer, language.code) }
    PrayerStepFlowScreen(
        title = step.title,
        step = step,
        currentIndex = 0,
        totalSteps = 1,
        seasonColor = Color.Transparent,
        isRightToLeft = language.isRightToLeft,
        languageCode = language.code,
        canGoBack = false,
        onBack = {},
        onNext = onNavigateUp,
        onNavigateUp = onNavigateUp,
        topBarActions = {
            PrayerLanguagePicker(
                chosenLanguage = chosenLanguage,
                expanded = languageMenuExpanded,
                onExpandedChange = { languageMenuExpanded = it },
                onSelect = AppSettings::setBasicPrayersLanguageCode,
            )
        },
    )
}
