package com.dkaluta.prosary.ui.home

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.Icon
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
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
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.CustomDevotionInfo
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.ui.shared.SaintDescriptionsCard
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import com.dkaluta.prosary.ui.shared.rememberTodayBrowsingDate
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.BasicPrayerCatalog
import com.dkaluta.prosary.models.FavoriteDevotions
import com.dkaluta.prosary.models.HomeOrder
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.models.MultiDayStatus
import com.dkaluta.prosary.models.MysteryGroup
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerCardTitle
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import com.dkaluta.prosary.services.LocalAppServices
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
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
import com.dkaluta.prosary.ui.shared.PrayerRemovalDialog
import com.dkaluta.prosary.ui.shared.PrayerRemovalRequest
import com.dkaluta.prosary.ui.shared.colorForHex
import com.dkaluta.prosary.ui.shared.iconForSystemName
import com.dkaluta.prosary.ui.theme.extraColors
import com.dkaluta.prosary.typography.HebrewDisplayText

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
    val basicPrayerId: String? = null,
    val interfaceTitle: String? = null,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onOpenPrayer: (String) -> Unit,
    onOpenReminders: (String) -> Unit,
    onOpenRosaryPicker: () -> Unit,
    /** Opens the preset editor for a new preset of this kind — the + menu's "Add …" items. */
    onAddPreset: (PrayerKind) -> Unit,
    onOpenAbout: () -> Unit,
    onOpenSettings: () -> Unit,
    onOpenJesusPrayerSetup: () -> Unit,
    onOpenCustomDevotion: (String) -> Unit,
    onOpenBasicPrayers: () -> Unit,
    onOpenBasicPrayer: (String) -> Unit,
    todayWidgetRequest: Long = 0,
    browsingDate: TodayBrowsingDate = rememberTodayBrowsingDate(),
) {
    val services = LocalAppServices.current
    val reminderScope = androidx.compose.runtime.rememberCoroutineScope()
    val isDarkTheme = isSystemInDarkTheme()

    // A null selection follows the current day, including midnight and returning to the app.
    // An explicit date stays where the reader put it until Today is tapped.
    var currentDate by remember { mutableStateOf(LocalDate.now()) }
    val selectedDate = browsingDate.selectedDate(currentDate)
    // Rebuild the instant in the current zone on resume; an explicitly selected civil date
    // must stay that date even after the device changes time zone.
    val lookupDate = TodayDateSelection.lookupDate(selectedDate)
    var showsDatePicker by remember { mutableStateOf(false) }
    val gridState = rememberLazyGridState()
    var handledTodayWidgetRequest by rememberSaveable { mutableStateOf(0L) }
    LaunchedEffect(todayWidgetRequest) {
        if (todayWidgetRequest != 0L && todayWidgetRequest != handledTodayWidgetRequest) {
            handledTodayWidgetRequest = todayWidgetRequest
            browsingDate.selectedEpochDay = null
            currentDate = LocalDate.now()
            showsDatePicker = false
            gridState.scrollToItem(0)
        }
    }
    LaunchedEffect(Unit) {
        while (true) {
            currentDate = LocalDate.now()
            delay(30_000)
        }
    }

    // Keyed on the Settings choices so returning from Settings re-resolves under the new
    // calendar (or drops a row its toggle switched off).
    val todayFeast = remember(lookupDate, AppSettings.feastCalendarId, AppSettings.easternPaschaStyle, AppSettings.showTodayFeast) {
        if (AppSettings.showTodayFeast) TodayInfoStore.feast(lookupDate) else null
    }
    val monthIntention = remember(lookupDate, AppSettings.showTodayIntention) {
        if (AppSettings.showTodayIntention) TodayInfoStore.intention(lookupDate) else null
    }
    val liturgicalDayInfo = remember(lookupDate, AppSettings.feastCalendarId) {
        if (TodayInfoStore.shouldShowLiturgicalDay(lookupDate)) TodayInfoStore.liturgicalDayInfo(lookupDate) else null
    }
    val todayReadings = remember(lookupDate, AppSettings.feastCalendarId, AppSettings.easternPaschaStyle, AppSettings.showTodayReadings) {
        if (AppSettings.showTodayReadings) TodayInfoStore.readings(lookupDate) else emptyList()
    }
    val torahPortion = remember(lookupDate, AppSettings.showTodayTorahPortion) {
        if (AppSettings.showTodayTorahPortion) TodayInfoStore.torahPortion(lookupDate) else null
    }
    val defaultLanguageCode = AppSettings.defaultLanguageCode
    val context = LocalContext.current
    val appLanguage = LocalConfiguration.current.locales[0].toLanguageTag()
    val todayLanguage = TodayTranslationLanguage.resolve(appLanguage)
    val todayContext = remember(context, todayLanguage) { TodayTranslationLanguage.localizedContext(context, todayLanguage) }
    val dateLabel = remember(selectedDate, appLanguage) {
        selectedDate.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(Locale.forLanguageTag(appLanguage)))
    }
    val todayReadingsTitle = todayContext.getString(R.string.home_today_readings)
    var todayMysteryGroup by remember { mutableStateOf<MysteryGroup?>(null) }
    var defaultRosary by remember { mutableStateOf<Prayer?>(null) }
    var defaultJesusPrayer by remember { mutableStateOf<Prayer?>(null) }
    var savedPrayers by remember { mutableStateOf<List<Prayer>>(emptyList()) }
    var removalRequest by remember { mutableStateOf<PrayerRemovalRequest?>(null) }
    // One entry per discovered generic devotion (bundle id -> its favorite, if any).
    var defaultCustomDevotions by remember { mutableStateOf<Map<String, Prayer>>(emptyMap()) }

    // Re-runs on every return to this screen (ON_RESUME) so devotions installed on other
    // tabs (Browse/Search) or in Favorites gain their Home card without a relaunch — the
    // generation read here also invalidates the card list built below.
    var refreshGeneration by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                currentDate = LocalDate.now()
                refreshGeneration++
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(refreshGeneration) {
        todayMysteryGroup = services.calendar.mysteryGroupToday()
        val all = runCatching { services.presetStore.all() }.getOrDefault(emptyList())
        savedPrayers = all
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
                title = PrayerKind.Rosary.cardTitle(context, LanguageCatalog.resolve(defaultRosary?.languageCode).code).primary,
                interfaceTitle = PrayerKind.Rosary.cardTitle(context, LanguageCatalog.resolve(defaultRosary?.languageCode).code).interfaceSubtitle,
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
            val cardTitle = info.cardTitle(LanguageCatalog.resolve(defaultCustomDevotions[bundleId]?.languageCode).code, appLanguage)
            add(
                DevotionCard(
                    id = "custom.$bundleId",
                    devotionId = bundleId,
                    icon = iconForSystemName(info.iconSystemName),
                    iconGlyph = info.iconGlyph,
                    title = cardTitle.primary,
                    interfaceTitle = cardTitle.interfaceSubtitle,
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
                title = PrayerKind.JesusPrayer.cardTitle(context, LanguageCatalog.resolve(defaultJesusPrayer?.languageCode).code).primary,
                interfaceTitle = PrayerKind.JesusPrayer.cardTitle(context, LanguageCatalog.resolve(defaultJesusPrayer?.languageCode).code).interfaceSubtitle,
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
    val pinnedBasicCards = BasicPrayerCatalog.all.filter { it.id in AppSettings.pinnedBasicPrayerIds }.map { prayer ->
        val cardTitle = BasicPrayerCatalog.cardTitle(prayer, AppSettings.basicPrayersLanguageCode, todayLanguage)
        DevotionCard(
            id = "basic:${prayer.id}", devotionId = "basic:${prayer.id}",
            icon = Icons.AutoMirrored.Filled.MenuBook,
            title = cardTitle.primary, interfaceTitle = cardTitle.interfaceSubtitle,
            accentColor = fallbackAccent, subtitle = stringResource(R.string.basic_prayers_title),
            testTag = "basicPrayerCard:${prayer.id}", onClick = { onOpenBasicPrayer(prayer.id) },
            basicPrayerId = prayer.id,
        )
    }
    val pinnedCards = remember(devotionCards, pinnedBasicCards, pinGeneration, impliedPinned) {
        devotionCards.filter { FavoriteDevotions.contains(context, it.devotionId, impliedPinned) } + pinnedBasicCards
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

    if (showsDatePicker) {
        val datePickerState = rememberDatePickerState(
            initialSelectedDateMillis = TodayDateSelection.pickerMillis(selectedDate),
            yearRange = TodayDateSelection.earliest.year..TodayDateSelection.latest.year,
        )
        DatePickerDialog(
            onDismissRequest = { showsDatePicker = false },
            confirmButton = {
                TextButton(
                    enabled = datePickerState.selectedDateMillis != null,
                    onClick = {
                        datePickerState.selectedDateMillis?.let {
                            browsingDate.selectedEpochDay = TodayDateSelection.fromPickerMillis(it).toEpochDay()
                        }
                        showsDatePicker = false
                    },
                ) { Text(stringResource(R.string.common_ok)) }
            },
            dismissButton = { TextButton(onClick = { showsDatePicker = false }) { Text(stringResource(R.string.common_cancel)) } },
        ) {
            DatePicker(
                state = datePickerState,
                modifier = Modifier.testTag("todayDatePicker"),
                title = {
                    TextButton(
                        onClick = { currentDate = LocalDate.now(); browsingDate.selectedEpochDay = null; showsDatePicker = false },
                        modifier = Modifier.padding(horizontal = 12.dp).testTag("todayReset"),
                    ) { Text(stringResource(R.string.home_today_reset)) }
                },
            )
        }
    }

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
                                    text = { Text(HebrewDisplayText.unpoint(card.title)) },
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
            state = gridState,
            columns = GridCells.Adaptive(minSize = 300.dp),
            contentPadding = PaddingValues(20.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier
                .padding(paddingValues)
                .fillMaxSize()
                .testTag("prayCards"),
        ) {
            item(key = "todayNavigation", span = { GridItemSpan(maxLineSpan) }) {
                Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min), verticalAlignment = Alignment.CenterVertically) {
                    IconButton(
                        onClick = { browsingDate.selectedEpochDay = selectedDate.minusDays(1).toEpochDay() },
                        enabled = selectedDate > TodayDateSelection.earliest,
                        modifier = Modifier.heightIn(min = 48.dp).fillMaxHeight().testTag("todayYesterday"),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, contentDescription = stringResource(R.string.home_today_yesterday))
                    }
                    TextButton(onClick = { showsDatePicker = true },
                        modifier = Modifier.weight(1f).heightIn(min = 48.dp).fillMaxHeight().testTag("todayChooseDate")) {
                        Text(dateLabel, textAlign = TextAlign.Center)
                    }
                    IconButton(
                        onClick = { browsingDate.selectedEpochDay = selectedDate.plusDays(1).toEpochDay() },
                        enabled = selectedDate < TodayDateSelection.latest,
                        modifier = Modifier.heightIn(min = 48.dp).fillMaxHeight().testTag("todayTomorrow"),
                    ) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = stringResource(R.string.home_today_tomorrow))
                    }
                }
            }
            if (liturgicalDayInfo != null || todayReadings.isNotEmpty() || torahPortion != null)
            item(key = "today", span = { GridItemSpan(maxLineSpan) }) {
                CompositionLocalProvider(
                    LocalLayoutDirection provides if (TodayTranslationLanguage.isRightToLeft(todayLanguage)) LayoutDirection.Rtl else LayoutDirection.Ltr,
                ) {
                    Column(
                        verticalArrangement = Arrangement.spacedBy(10.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(todayCardBackground())
                            .padding(14.dp),
                    ) {
                        if (liturgicalDayInfo != null) Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.testTag("todayLiturgicalDay")) {
                            Icon(Icons.Filled.CalendarMonth, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Text(
                                liturgicalDayInfo.localized(todayLanguage),
                                style = MaterialTheme.typography.titleSmall,
                                fontWeight = FontWeight.SemiBold,
                                modifier = Modifier.weight(1f),
                            )

                        }
                        if (todayReadings.isNotEmpty()) {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.testTag("todayReadings")) {
                                Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
                                    Text(todayReadingsTitle, style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                                    todayReadings.forEach { citation ->
                                        Text(
                                            citation.localizedFull(todayLanguage),
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                                        )
                                    }
                                }
                            }
                        }
                        if (torahPortion != null) {
                            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.testTag("todayTorahPortion")) {
                                Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                                Column(verticalArrangement = Arrangement.spacedBy(2.dp), modifier = Modifier.weight(1f)) {
                                    Text(
                                        todayContext.getString(if (torahPortion.isHoliday) R.string.home_today_torah_festival else R.string.home_today_torah),
                                        style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold,
                                    )
                                    Text(torahPortion.localizedTitle(todayLanguage), style = MaterialTheme.typography.bodyMedium)
                                    torahPortion.readings.forEach { citation ->
                                        Text(citation.localizedFull(todayLanguage), style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if (todayFeast != null) item(key = "todaySaints", span = { GridItemSpan(maxLineSpan) }) {
                CompositionLocalProvider(LocalLayoutDirection provides
                    if (TodayTranslationLanguage.isRightToLeft(todayLanguage)) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(14.dp)
                        .testTag("todaySaints"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Filled.CalendarMonth, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                                Text(todayFeast.localizedTitle(todayLanguage), style = MaterialTheme.typography.titleSmall,
                                    fontWeight = if (todayFeast.rank in setOf("Solemnity", "1st Class", "Great Feast")) FontWeight.Bold else FontWeight.SemiBold)
                                Text(todayFeast.localizedRank(todayLanguage, todayContext), style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        SaintDescriptionsCard(todayFeast.saintDescriptions(TodayInfoStore.selectedCalendarId, todayLanguage),
                            selectedDate.toString(), todayLanguage, inCard = false)
                    }
                }
            }
            if (monthIntention != null) item(key = "popeIntention", span = { GridItemSpan(maxLineSpan) }) {
                CompositionLocalProvider(LocalLayoutDirection provides
                    if (TodayTranslationLanguage.isRightToLeft(todayLanguage)) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                    Row(Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                        .background(MaterialTheme.colorScheme.surfaceContainerHigh).padding(14.dp)
                        .testTag("popeIntention"), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        PapalKeysIcon()
                        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(todayContext.getString(R.string.home_pope_intention, monthIntention.localizedTitle(todayLanguage)),
                                style = MaterialTheme.typography.titleSmall, fontWeight = FontWeight.SemiBold)
                            Text(monthIntention.localizedText(todayLanguage), style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
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
                        interfaceTitle = card.interfaceTitle,
                        accentColor = card.accentColor,
                        onClick = card.onClick,
                        onLongClick = { cardMenu = true },
                        modifier = Modifier.testTag(card.testTag),
                    )
                    DropdownMenu(expanded = cardMenu, onDismissRequest = { cardMenu = false }) {
                        if (card.basicPrayerId == null) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.reminders_title)) },
                                onClick = {
                                    cardMenu = false
                                    reminderScope.launch {
                                        val existing = when (card.devotionId) {
                                            "rosary" -> defaultRosary
                                            "jesusPrayer" -> defaultJesusPrayer
                                            else -> defaultCustomDevotions[card.devotionId]
                                        }
                                        val prayer = existing ?: Prayer(name = card.title, isDefault = true,
                                            kind = when (card.devotionId) {
                                                "rosary" -> PrayerKind.Rosary
                                                "jesusPrayer" -> PrayerKind.JesusPrayer
                                                else -> PrayerKind.Custom
                                            }, customDevotionId = card.devotionId.takeUnless { it in setOf("rosary", "jesusPrayer") })
                                        runCatching { if (existing == null) services.presetStore.save(prayer) }
                                            .onSuccess { onOpenReminders(prayer.id) }
                                            .onFailure { android.widget.Toast.makeText(context, it.localizedMessage, android.widget.Toast.LENGTH_LONG).show() }
                                    }
                                },
                                modifier = Modifier.testTag("reminders.${card.devotionId}"),
                            )
                        }
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
                                if (card.basicPrayerId != null) AppSettings.setBasicPrayerPinned(card.basicPrayerId, false)
                                else FavoriteDevotions.toggle(context, card.devotionId, impliedPinned)
                                pinGeneration++
                            },
                        )
                        if (card.basicPrayerId == null && card.devotionId in PrayerPackStore.installedBundleIds()
                            && !PrayerPackStore.isBuiltInBundle(card.devotionId)) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.download_remove_action), color = MaterialTheme.colorScheme.error) },
                                onClick = {
                                    cardMenu = false
                                    removalRequest = PrayerRemovalRequest.Download(card.devotionId)
                                },
                                modifier = Modifier.testTag("removeDownload.${card.devotionId}"),
                            )
                        }
                        if (card.basicPrayerId == null && card.devotionId != "rosary") {
                            val copies = savedPrayers.filter {
                                if (card.devotionId == "jesusPrayer") it.kind == PrayerKind.JesusPrayer
                                else it.kind == PrayerKind.Custom && it.customDevotionId == card.devotionId
                            }
                            for (copy in copies) {
                                DropdownMenuItem(
                                    text = { Text(if (copies.size == 1) stringResource(R.string.prayer_delete_action)
                                        else stringResource(R.string.favorites_delete_desc, copy.name), color = MaterialTheme.colorScheme.error) },
                                    onClick = { cardMenu = false; removalRequest = PrayerRemovalRequest.Saved(copy) },
                                )
                            }
                        }
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
    removalRequest?.let { request ->
        PrayerRemovalDialog(request, onDismiss = { removalRequest = null }, onRemoved = { refreshGeneration++; pinGeneration++ })
    }
}

@Composable
private fun todayCardBackground(): Color {
    val surface = MaterialTheme.colorScheme.surfaceContainerHigh
    val tint = when (AppSettings.todayCardColor) {
        "blue" -> Color(0xFF4285D4)
        "green" -> Color(0xFF388C64)
        "gold" -> Color(0xFFD5A72D)
        "rose" -> Color(0xFFC96682)
        else -> return surface
    }
    return lerp(surface, tint, if (isSystemInDarkTheme()) 0.22f else 0.14f)
}

/** The crossed keys identify the papal intention without tying it to one pontificate. */
@Composable
private fun PapalKeysIcon() {
    val tint = MaterialTheme.colorScheme.primary
    Canvas(Modifier.size(24.dp)) {
        val unit = size.width / 24f
        val stroke = 1.8f * unit
        fun point(x: Float, y: Float) = Offset(x * unit, y * unit)
        for (mirrored in listOf(false, true)) {
            fun x(value: Float) = if (mirrored) 24f - value else value
            drawCircle(tint, 3f * unit, point(x(6f), 5f), style = Stroke(stroke))
            drawLine(tint, point(x(8f), 7f), point(x(19f), 21f), stroke, StrokeCap.Round)
            drawLine(tint, point(x(15.5f), 18f), point(x(18f), 16f), stroke, StrokeCap.Round)
            drawLine(tint, point(x(19f), 21f), point(x(21.5f), 19f), stroke, StrokeCap.Round)
        }
    }
}
