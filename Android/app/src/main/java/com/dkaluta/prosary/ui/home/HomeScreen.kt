package com.dkaluta.prosary.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.VolunteerActivism
import androidx.compose.material3.Icon
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.Lifecycle
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.prayerpack.CustomDevotionInfo
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.HomeOrder
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.services.LocalAppServices
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import com.dkaluta.prosary.ui.shared.PrayerCard
import com.dkaluta.prosary.ui.shared.colorForHex
import com.dkaluta.prosary.ui.shared.iconForSystemName
import com.dkaluta.prosary.ui.theme.extraColors

/** One devotion's rendering state for a Home card. See [HomeScreen]'s card list. */
private data class DevotionCard(
    val id: String,
    val icon: ImageVector,
    val iconGlyph: String? = null,
    val title: String,
    val accentColor: Color,
    val subtitle: String,
    val testTag: String,
    val onClick: () -> Unit,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenPrayer: (String) -> Unit,
    onOpenRosaryPicker: () -> Unit,
    onOpenFavorites: () -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
    onOpenCustomDevotion: (String) -> Unit,
) {
    val services = LocalAppServices.current
    val isDarkTheme = isSystemInDarkTheme()

    val todayFeast = remember { TodayInfoStore.feast() }
    val monthIntention = remember { TodayInfoStore.intention() }
    var todayMysteryGroup by remember { mutableStateOf<MysteryGroup?>(null) }
    var defaultRosary by remember { mutableStateOf<Prayer?>(null) }
    var defaultJesusPrayer by remember { mutableStateOf<Prayer?>(null) }
    // One entry per discovered generic devotion (bundle id -> its favorite, if any).
    var defaultCustomDevotions by remember { mutableStateOf<Map<String, Prayer>>(emptyMap()) }

    // Re-runs on every return to this screen (ON_RESUME) so devotions installed on other
    // tabs (Browse/Search) or in Favorites gain their Home card without a relaunch — the
    // generation read here also invalidates the card list built below.
    var refreshGeneration by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) refreshGeneration++
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(refreshGeneration) {
        todayMysteryGroup = services.calendar.mysteryGroupToday()
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        defaultRosary = all.firstOrNull { it.kind == PrayerKind.Rosary && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.Rosary }
        defaultJesusPrayer = all.firstOrNull { it.kind == PrayerKind.JesusPrayer && it.isDefault }
            ?: all.firstOrNull { it.kind == PrayerKind.JesusPrayer }

        defaultCustomDevotions = PrayerPackStore.customDevotionIds().mapNotNull { bundleId ->
            val favorite = all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == bundleId && it.isDefault }
                ?: all.firstOrNull { it.kind == PrayerKind.Custom && it.customDevotionId == bundleId }
            favorite?.let { bundleId to it }
        }.toMap()
    }

    val rosaryAccent = todayMysteryGroup?.color ?: MaterialTheme.colorScheme.primary
    val jesusPrayerAccent = if (isDarkTheme) Color(0xFFC62828) else Color(0xFF8B1A1A)

    val rosarySubtitle = buildString {
        todayMysteryGroup?.let { append("Today: ${it.displayName}") }
        defaultRosary?.let {
            if (isNotEmpty()) append(" • ")
            append(it.name)
        }
    }
    val jesusPrayerSubtitle = defaultJesusPrayer?.let { "${it.name} • ${it.jesusPrayer.targetDisplayName}" } ?: "Tap to set up"

    // Accent color for a generic devotion's card, honoring the manifest's light/dark pair.
    val fallbackAccent = MaterialTheme.colorScheme.primary
    val context = androidx.compose.ui.platform.LocalContext.current

    fun customAccent(info: CustomDevotionInfo): Color {
        val hex = if (isDarkTheme) info.accentColorDarkHex ?: info.accentColorHex else info.accentColorHex
        return colorForHex(hex) ?: fallbackAccent
    }

    // One card per devotion: the Rosary first (the app's namesake), then every generic
    // (bundle-driven) devotion in pack-load order — icon/title/accent read from each bundle's
    // own manifest, nothing hardcoded here — and the Jesus Prayer (the counter-based odd one
    // out) last. Adding a devotion means shipping a bundle; this screen doesn't change.
    val devotionCards = buildList {
        add(
            DevotionCard(
                id = PrayerKind.Rosary.name,
                icon = Icons.Filled.Circle,
                title = PrayerKind.Rosary.displayName,
                accentColor = rosaryAccent,
                subtitle = rosarySubtitle,
                testTag = "rosaryCard",
                onClick = {
                    // The picker handles every case itself (default preset up top, ad-hoc
                    // quick pray, the remaining presets) — including having no presets at all.
                    onOpenRosaryPicker()
                },
            ),
        )

        for (bundleId in PrayerPackStore.customDevotionIds()) {
            val info = PrayerPackStore.info(bundleId) ?: continue
            add(
                DevotionCard(
                    id = "custom.$bundleId",
                    icon = iconForSystemName(info.iconSystemName),
                    iconGlyph = info.iconGlyph,
                    title = info.localizedDisplayName,
                    accentColor = customAccent(info),
                    subtitle = defaultCustomDevotions[bundleId]?.name ?: "Tap to pray",
                    testTag = "${bundleId}Card",
                    onClick = {
                        val prayer = defaultCustomDevotions[bundleId]
                        if (prayer != null) onOpenPrayer(prayer.id) else onOpenCustomDevotion(bundleId)
                    },
                ),
            )
        }

        add(
            DevotionCard(
                id = PrayerKind.JesusPrayer.name,
                icon = Icons.Filled.Favorite,
                title = PrayerKind.JesusPrayer.displayName,
                accentColor = jesusPrayerAccent,
                subtitle = jesusPrayerSubtitle,
                testTag = "jesusPrayerCard",
                onClick = {
                    val prayer = defaultJesusPrayer
                    if (prayer != null) onOpenPrayer(prayer.id) else onOpenJesusPrayerSetup()
                },
            ),
        )
    }

    // The user's personal ordering (v0.7): long-press a card for Move to Top / Edit Order.
    var orderGeneration by remember { mutableIntStateOf(0) }
    var showsOrderEditor by remember { mutableStateOf(false) }
    val orderedCards = remember(devotionCards, orderGeneration) {
        HomeOrder.apply(context, devotionCards) { it.id }
    }

    if (showsOrderEditor) {
        HomeOrderEditor(
            titles = orderedCards.map { it.id to it.title },
            onMove = { ids -> HomeOrder.save(context, ids); orderGeneration++ },
            onReset = { HomeOrder.reset(context); orderGeneration++ },
            onDismiss = { showsOrderEditor = false },
        )
    }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is

    // invisible and scrolled content clips at a dead band around the floating title.

    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(

        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
                title = { Text("Pray") },
                actions = {
                    IconButton(onClick = onOpenFavorites) {
                        Icon(Icons.Filled.Star, contentDescription = "My Favorites")
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = "Settings")
                    }
                    IconButton(onClick = onOpenAbout) {
                        Icon(Icons.Filled.Info, contentDescription = "About")
                    }
                },
            )
        },
    ) { paddingValues ->
        LazyVerticalGrid(
            columns = GridCells.Adaptive(minSize = 300.dp),
            contentPadding = PaddingValues(20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .padding(paddingValues)
                .fillMaxSize(),
        ) {
            // "Today" — the day's feast per the Holy Land (Latin Patriarchate of Jerusalem)
            // calendar and the Pope's monthly prayer intention. Rows hide when the bundled
            // datasets have no entry (ferial days; dates past the generated years).
            if (todayFeast != null || monthIntention != null) {
                item(key = "today", span = { GridItemSpan(maxLineSpan) }) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh)
                        .padding(14.dp),
                ) {
                    if (todayFeast != null) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(
                                Icons.Filled.CalendarMonth, contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    todayFeast.title,
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = if (todayFeast.rank == "Solemnity") FontWeight.Bold else FontWeight.SemiBold,
                                )
                                Text(
                                    todayFeast.rank,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                    if (monthIntention != null) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(
                                Icons.Filled.VolunteerActivism, contentDescription = null,
                                tint = MaterialTheme.colorScheme.primary,
                            )
                            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(
                                    "The Pope\u2019s intention: ${monthIntention.title}",
                                    style = MaterialTheme.typography.titleSmall,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(
                                    monthIntention.text,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    }
                }
                }
            }

            items(orderedCards, key = { it.id }) { card ->
                var cardMenu by remember { mutableStateOf(false) }
                Box {
                    PrayerCard(
                        icon = card.icon,
                        iconGlyph = card.iconGlyph,
                        title = card.title,
                        subtitle = card.subtitle,
                        accentColor = card.accentColor,
                        onClick = card.onClick,
                        onLongClick = { cardMenu = true },
                        modifier = Modifier.testTag(card.testTag),
                    )
                    DropdownMenu(expanded = cardMenu, onDismissRequest = { cardMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("Move to top") },
                            onClick = {
                                cardMenu = false
                                HomeOrder.moveToTop(context, card.id, orderedCards.map { it.id })
                                orderGeneration++
                            },
                        )
                        DropdownMenuItem(
                            text = { Text("Edit order…") },
                            onClick = {
                                cardMenu = false
                                showsOrderEditor = true
                            },
                        )
                    }
                }
            }
        }
    }
}
