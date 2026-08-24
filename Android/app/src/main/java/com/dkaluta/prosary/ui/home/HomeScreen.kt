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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.VolunteerActivism
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.CustomDevotionInfo
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.FavoriteDevotions
import com.dkaluta.prosary.models.HomeOrder
import com.dkaluta.prosary.models.MultiDayStatus
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
    /** The id the pin list uses — "rosary", "jesusPrayer" or a bundle id — as distinct from
     * [id], which is the ordering key. */
    val devotionId: String,
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
    /** Opens the preset editor for a new preset of this kind — the + menu's "Add …" items. */
    onAddPreset: (PrayerKind) -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
    onOpenCustomDevotion: (String) -> Unit,
    onOpenBasicPrayers: () -> Unit,
) {
    val services = LocalAppServices.current
    val isDarkTheme = isSystemInDarkTheme()

    // Keyed on the Settings choices so returning from Settings re-resolves under the new
    // calendar (or drops a row its toggle switched off).
    val todayFeast = remember(AppSettings.feastCalendarId, AppSettings.showTodayFeast) {
        if (AppSettings.showTodayFeast) TodayInfoStore.feast() else null
    }
    val monthIntention = remember(AppSettings.showTodayIntention) {
        if (AppSettings.showTodayIntention) TodayInfoStore.intention() else null
    }
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

    val context = androidx.compose.ui.platform.LocalContext.current
    val todayLine = todayMysteryGroup?.let { stringResource(R.string.home_today, stringResource(it.displayNameRes)) }
    val rosarySubtitle = buildString {
        todayLine?.let { append(it) }
        defaultRosary?.let {
            if (isNotEmpty()) append(" • ")
            append(it.name)
        }
    }
    val jesusPrayerSubtitle = defaultJesusPrayer?.let { "${it.name} • ${it.jesusPrayer.targetDisplayName(context)}" }
        ?: stringResource(R.string.home_tap_to_set_up)

    // Accent color for a generic devotion's card, honoring the manifest's light/dark pair.
    val fallbackAccent = MaterialTheme.colorScheme.primary

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
                devotionId = "rosary",
                icon = Icons.Filled.Circle,
                title = PrayerKind.Rosary.displayName(context),
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
                    devotionId = bundleId,
                    icon = iconForSystemName(info.iconSystemName),
                    iconGlyph = info.iconGlyph,
                    title = info.localizedDisplayName,
                    accentColor = customAccent(info),
                    subtitle = MultiDayStatus.subtitle(context, bundleId)
                        ?: defaultCustomDevotions[bundleId]?.name
                        ?: stringResource(R.string.home_tap_to_pray),
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
                devotionId = "jesusPrayer",
                icon = Icons.Filled.Favorite,
                title = PrayerKind.JesusPrayer.displayName(context),
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

    // Pray is the pinned list: a devotion appears here because you put it here (or, on a fresh
    // install, because it already had a preset). Everything installed stays reachable on
    // Categories and Search, so unpinning hides a card without losing anything.
    var pinGeneration by remember { mutableIntStateOf(0) }
    val impliedPinned = buildList {
        add("rosary")
        addAll(defaultCustomDevotions.keys)
        if (defaultJesusPrayer != null) add("jesusPrayer")
    }
    val pinnedCards = remember(devotionCards, pinGeneration, impliedPinned) {
        devotionCards.filter { FavoriteDevotions.contains(context, it.devotionId, impliedPinned) }
    }
    val unpinnedCards = devotionCards.filter { card -> pinnedCards.none { it.id == card.id } }

    // The user's personal ordering (v0.7): long-press a card for Move to Top / Edit Order.
    var orderGeneration by remember { mutableIntStateOf(0) }
    var showsOrderEditor by remember { mutableStateOf(false) }
    val orderedCards = remember(pinnedCards, orderGeneration) {
        HomeOrder.apply(context, pinnedCards) { it.id }
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
                title = { Text(stringResource(R.string.tab_pray)) },
                actions = {
                    // The same menu iOS/Mac and Windows open: an ad-hoc Rosary, a new preset of
                    // either configurable kind, then anything currently off the Pray list —
                    // without that last part, unpinning the Rosary would hide it for good.
                    var addMenu by remember { mutableStateOf(false) }
                    IconButton(onClick = { addMenu = true }) {
                        Icon(
                            Icons.Filled.Add,
                            contentDescription = stringResource(R.string.home_add_devotion),
                        )
                    }
                    DropdownMenu(expanded = addMenu, onDismissRequest = { addMenu = false }) {
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.home_pray_any_rosary)) },
                            onClick = { addMenu = false; onOpenRosaryPicker() },
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.home_add_rosary)) },
                            onClick = { addMenu = false; onAddPreset(PrayerKind.Rosary) },
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.home_add_jesus_prayer)) },
                            onClick = { addMenu = false; onAddPreset(PrayerKind.JesusPrayer) },
                        )
                        if (unpinnedCards.isNotEmpty()) {
                            HorizontalDivider()
                            Text(
                                stringResource(R.string.home_add_to_pray),
                                style = MaterialTheme.typography.labelMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                            )
                            for (card in unpinnedCards) {
                                DropdownMenuItem(
                                    text = { Text(card.title) },
                                    onClick = {
                                        addMenu = false
                                        FavoriteDevotions.pin(context, card.devotionId, impliedPinned)
                                        pinGeneration++
                                    },
                                )
                            }
                        }
                    }
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Filled.Settings, contentDescription = stringResource(R.string.common_settings))
                    }
                    IconButton(onClick = onOpenAbout) {
                        Icon(Icons.Filled.Info, contentDescription = stringResource(R.string.common_about))
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
                                    // Each calendar's top rank gets the bold: "Solemnity"
                                    // (Roman), "1st Class" (1962), "Great Feast" (Byzantine).
                                    fontWeight = if (todayFeast.rank in setOf("Solemnity", "1st Class", "Great Feast")) FontWeight.Bold else FontWeight.SemiBold,
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
                                    stringResource(R.string.home_pope_intention, monthIntention.title),
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
                            text = { Text(stringResource(R.string.home_move_to_top)) },
                            onClick = {
                                cardMenu = false
                                HomeOrder.moveToTop(context, card.id, orderedCards.map { it.id })
                                orderGeneration++
                            },
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.home_edit_order)) },
                            onClick = {
                                cardMenu = false
                                showsOrderEditor = true
                            },
                        )
                        DropdownMenuItem(
                            text = { Text(stringResource(R.string.home_remove_from_pray)) },
                            onClick = {
                                cardMenu = false
                                FavoriteDevotions.toggle(context, card.devotionId, impliedPinned)
                                pinGeneration++
                            },
                        )
                    }
                }
            }

            // The basic prayers on their own (Erez, 2026-08-07) — a fixed quiet row below the
            // cards, not a pinnable card: a reference shelf, not a devotion, so it neither
            // reorders nor unpins. Always present, which is the point of the ask.
            item(key = "basicPrayers", span = { GridItemSpan(maxLineSpan) }) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.5f))
                        .clickable { onOpenBasicPrayers() }
                        .padding(horizontal = 16.dp, vertical = 14.dp)
                        .testTag("basicPrayersRow"),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null)
                    Spacer(Modifier.width(12.dp))
                    Text(stringResource(R.string.basic_prayers_title), modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
                }
            }
        }
    }
}
