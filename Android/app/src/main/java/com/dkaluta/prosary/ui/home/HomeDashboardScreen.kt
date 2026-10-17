package com.dkaluta.prosary.ui.home

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.annotation.StringRes
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.semantics.selected
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.AppColor
import com.dkaluta.prosary.models.HomeWidget
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.readings.HomeReadingsMode
import com.dkaluta.prosary.ui.readings.CalendarMonthGrid
import com.dkaluta.prosary.ui.readings.CalendarEventRow
import com.dkaluta.prosary.ui.readings.CalendarEventDialog
import com.dkaluta.prosary.content.today.CalendarEvents
import com.dkaluta.prosary.content.today.CalendarEvent
import com.dkaluta.prosary.ui.shared.SaintDescriptionsCard
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import com.dkaluta.prosary.ui.shared.PapalKeysIcon
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

@get:StringRes
private val HomeWidget.title: Int
    get() = when (this) {
        HomeWidget.Readings -> R.string.home_widgets_readings
        HomeWidget.Torah -> R.string.home_widgets_torah
        HomeWidget.PopeIntention -> R.string.home_widgets_pope_intention
        HomeWidget.Calendar -> R.string.home_widgets_calendar
        HomeWidget.Photo -> R.string.home_widgets_photo
        HomeWidget.Reminders -> R.string.home_widgets_reminders
        HomeWidget.Scripture -> R.string.home_widgets_scripture
        HomeWidget.Reflection -> R.string.home_widgets_reflection
        HomeWidget.Feast -> R.string.home_widgets_feast
    }

private data class HomeGraphicActions(val choose: (HomeWidget) -> Unit, val remove: (HomeWidget) -> Unit, val busy: Boolean)
private val LocalHomeGraphicActions = staticCompositionLocalOf { HomeGraphicActions({}, {}, false) }

/** A personal reference dashboard, independent of pinned prayers and their running sessions. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeDashboardScreen(
    browsingDate: TodayBrowsingDate,
    onOpenReadings: (HomeReadingsMode) -> Unit,
    onOpenSettings: () -> Unit,
    onOpenReminders: (String) -> Unit,
    todayWidgetRequest: Long = 0,
) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current
    val services = LocalAppServices.current
    val scope = rememberCoroutineScope()
    val language = TodayTranslationLanguage.resolve(LocalConfiguration.current.locales[0].toLanguageTag())
    val locale = Locale.forLanguageTag(language)
    var today by remember { mutableStateOf(LocalDate.now()) }
    var generation by remember { mutableIntStateOf(0) }
    var showsCustomization by rememberSaveable { mutableStateOf(false) }
    var photoBusy by remember { mutableStateOf(false) }
    var photoError by remember { mutableStateOf(false) }
    var photoTarget by rememberSaveable { mutableStateOf(HomeWidget.Photo) }
    var handledTodayRequest by rememberSaveable { mutableStateOf(0L) }
    val lifecycle = LocalLifecycleOwner.current
    val gridState = rememberLazyGridState()
    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) { today = LocalDate.now(); generation++ }
        }
        lifecycle.lifecycle.addObserver(observer)
        onDispose { lifecycle.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(Unit) {
        while (true) { today = LocalDate.now(); delay(30_000) }
    }
    LaunchedEffect(todayWidgetRequest) {
        if (todayWidgetRequest != 0L && todayWidgetRequest != handledTodayRequest) {
            handledTodayRequest = todayWidgetRequest
            browsingDate.selectedEpochDay = null
            today = LocalDate.now()
        }
    }
    val date = browsingDate.selectedDate(today)
    val lookupDate = TodayDateSelection.lookupDate(date)
    val feast = remember(date, generation, AppSettings.feastCalendarId, AppSettings.easternPaschaStyle) {
        TodayInfoStore.feast(lookupDate)
    }
    val intention = remember(date, generation) { TodayInfoStore.intention(lookupDate) }
    val torah = remember(date, generation) { TodayInfoStore.torahPortion(lookupDate) }
    var selectedCalendarEvent by remember(date, AppSettings.feastCalendarId) { mutableStateOf<CalendarEvent?>(null) }
    val sourceReadings = remember(date, generation, AppSettings.feastCalendarId, AppSettings.easternPaschaStyle) {
        TodayInfoStore.readings(lookupDate)
    }
    val readings = remember(sourceReadings, AppSettings.reverseReadingsOrder) {
        com.dkaluta.prosary.content.today.ReadingCitation.displayOrder(sourceReadings, AppSettings.reverseReadingsOrder)
    }
    val calendarName = TodayInfoStore.calendars.firstOrNull { it.id == TodayInfoStore.selectedCalendarId }?.displayName.orEmpty()
    val prayers by produceState<List<Prayer>>(initialValue = emptyList(), generation, services) {
        value = withContext(Dispatchers.IO) { services.presetStore.all() }
    }
    val reminders = prayers.flatMap { prayer -> prayer.reminders.filter { it.isEnabled }.map { prayer to it } }
        .sortedWith(compareBy({ it.second.hour }, { it.second.minute }, { it.first.name }))

    fun removePhoto(widget: HomeWidget = HomeWidget.Photo, removeCard: Boolean = false) {
        if (photoBusy) return
        photoBusy = true
        val oldPath = if (widget == HomeWidget.Photo) AppSettings.homePhotoPath else AppSettings.homeWidgetGraphicPath(widget)
        scope.launch {
            try {
                HomePhotoTransaction.remove(oldPath, { HomePhotoStore.remove(context.filesDir, it) }) {
                    if (widget == HomeWidget.Photo) AppSettings.homePhotoPath = ""
                    else AppSettings.setHomeWidgetGraphicPath(widget, "")
                    if (removeCard) AppSettings.homeWidgetOrder = AppSettings.homeWidgetOrder - widget
                }
            } catch (cancelled: CancellationException) { throw cancelled }
            catch (error: Exception) { photoError = true }
            finally { photoBusy = false }
        }
    }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null && photoTarget in AppSettings.homeWidgetOrder) {
            val widget = photoTarget
            photoBusy = true
            scope.launch {
                val oldPath = if (widget == HomeWidget.Photo) AppSettings.homePhotoPath else AppSettings.homeWidgetGraphicPath(widget)
                try {
                    HomePhotoTransaction.replace(oldPath, { HomePhotoStore.copy(context, uri) },
                        {
                            if (widget !in AppSettings.homeWidgetOrder) throw CancellationException("The image's card was removed")
                            if (widget == HomeWidget.Photo) AppSettings.homePhotoPath = it else AppSettings.setHomeWidgetGraphicPath(widget, it)
                        },
                        { HomePhotoStore.remove(context.filesDir, it) })
                } catch (cancelled: CancellationException) { throw cancelled }
                catch (error: Exception) { photoError = true }
                finally { photoBusy = false }
            }
        }
    }

    HomeFoldSafePane {
    Scaffold(topBar = {
        TopAppBar(title = { Text(stringResource(R.string.home_widgets_title)) }, actions = {
            IconButton(onClick = { showsCustomization = true }, modifier = Modifier.testTag("homeCustomize")) {
                Icon(Icons.Filled.Edit, contentDescription = stringResource(R.string.home_widgets_customize))
            }
            IconButton(onClick = onOpenSettings) {
                Icon(Icons.Filled.Settings, contentDescription = stringResource(R.string.common_settings))
            }
        })
    }) { padding ->
        CompositionLocalProvider(LocalLayoutDirection provides if (TodayTranslationLanguage.isRightToLeft(language)) LayoutDirection.Rtl else LayoutDirection.Ltr,
            LocalHomeGraphicActions provides HomeGraphicActions(
                choose = { widget -> photoTarget = widget; photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)) },
                remove = { widget -> removePhoto(widget) }, busy = photoBusy)) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.TopCenter) {
            LazyVerticalGrid(columns = GridCells.Adaptive(340.dp),
                state = gridState,
                modifier = Modifier.padding(padding).widthIn(max = 1200.dp).fillMaxSize().testTag("homeDashboard"),
                contentPadding = PaddingValues(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item("date", span = { GridItemSpan(maxLineSpan) }) {
                    Text(date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale)),
                        style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("homeDate"))
                }
                if (AppSettings.homeWidgetOrder.isEmpty()) item("empty", span = { GridItemSpan(maxLineSpan) }) {
                    Column {
                        Text(stringResource(R.string.home_widgets_empty))
                        TextButton(onClick = { showsCustomization = true }) { Text(stringResource(R.string.home_widgets_add)) }
                    }
                }
                items(AppSettings.homeWidgetOrder, key = { it.id }) { widget ->
                    when (widget) {
                        HomeWidget.Readings -> DashboardCard(widget, { onOpenReadings(HomeReadingsMode.Daily) },
                            summary = sourceReadings.firstOrNull { it.type == "gospel" }?.localizedShort(language)
                                ?: readings.takeIf { it.isNotEmpty() }?.joinToString(" · ") { it.localizedShort(language) }
                                ?: stringResource(R.string.home_widgets_no_readings)) {
                            if (readings.isEmpty()) Text(stringResource(R.string.home_widgets_no_readings))
                            else readings.forEachIndexed { index, citation ->
                                Text(citation.localizedFull(language), modifier = Modifier.fillMaxWidth().testTag("homeReading.$index"))
                            }
                        }
                        HomeWidget.Torah -> DashboardCard(widget, summary = torah?.localizedTitle(language) ?: stringResource(R.string.home_widgets_no_torah)) {
                            com.dkaluta.prosary.ui.readings.TorahPortionCard(torah, language)
                        }
                        HomeWidget.PopeIntention -> DashboardCard(widget, summary = intention?.localizedTitle(language) ?: stringResource(R.string.home_widgets_no_intention)) {
                            if (intention == null) Text(stringResource(R.string.home_widgets_no_intention))
                            else {
                                Text(intention.localizedTitle(language), style = MaterialTheme.typography.titleSmall)
                                Text(intention.localizedText(language))
                            }
                        }
                        HomeWidget.Calendar -> DashboardCard(widget, { onOpenReadings(HomeReadingsMode.Calendar) },
                            summary = feast?.localizedTitle(language) ?: stringResource(R.string.home_widgets_no_feast)) {
                            if (calendarName.isNotBlank()) Text(calendarName, style = MaterialTheme.typography.bodyMedium)
                            CalendarMonthGrid(date) { browsingDate.selectedEpochDay = it.toEpochDay() }
                            CalendarEvents.events(date, feast).forEach { event -> CalendarEventRow(event, language) { selectedCalendarEvent = event } }
                            if (feast == null) Text(stringResource(R.string.home_widgets_no_feast))
                            TextButton(onClick = { onOpenReadings(HomeReadingsMode.Calendar) }, modifier = Modifier.testTag("homeOpenCalendar")) {
                                Text(stringResource(R.string.calendar_event_calendar))
                            }
                        }
                        HomeWidget.Photo -> DashboardCard(widget, summary = stringResource(if (AppSettings.homePhotoPath.isEmpty())
                            R.string.home_widgets_choose_photo else R.string.home_widgets_photo_description)) {
                            HomePhoto(AppSettings.homePhotoPath)
                            if (photoBusy) CircularProgressIndicator()
                            Row {
                                TextButton(enabled = !photoBusy, onClick = {
                                    photoTarget = HomeWidget.Photo
                                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                                }) { Text(stringResource(R.string.home_widgets_choose_photo)) }
                                if (AppSettings.homePhotoPath.isNotEmpty()) TextButton(enabled = !photoBusy, onClick = { removePhoto() }) {
                                    Text(stringResource(R.string.home_widgets_remove_photo))
                                }
                            }
                        }
                        HomeWidget.Reminders -> DashboardCard(widget, { onOpenSettings() }, summary = reminders.firstOrNull()?.first?.name
                            ?: stringResource(if (AppSettings.readingsReminderEnabled) R.string.settings_reminders_readings
                            else if (AppSettings.saintReminderEnabled) R.string.settings_reminders_saints else R.string.home_widgets_no_reminders)) {
                            if (reminders.isEmpty() && !AppSettings.readingsReminderEnabled && !AppSettings.saintReminderEnabled)
                                Text(stringResource(R.string.home_widgets_no_reminders))
                            if (AppSettings.readingsReminderEnabled) ReminderLink(stringResource(R.string.settings_reminders_readings),
                                PrayerReminder(hour = AppSettings.readingsReminderMinutes / 60, minute = AppSettings.readingsReminderMinutes % 60), onOpenSettings)
                            if (AppSettings.saintReminderEnabled) ReminderLink(stringResource(R.string.settings_reminders_saints),
                                PrayerReminder(hour = AppSettings.saintReminderMinutes / 60, minute = AppSettings.saintReminderMinutes % 60), onOpenSettings)
                            reminders.forEach { (prayer, reminder) ->
                                ReminderLink(prayer.name, reminder) { onOpenReminders(prayer.id) }
                            }
                            TextButton(onClick = onOpenSettings) { Text(stringResource(R.string.home_widgets_manage_reminders)) }
                        }
                        HomeWidget.Scripture -> DashboardCard(widget, { onOpenReadings(HomeReadingsMode.Bible) },
                            summary = com.dkaluta.prosary.content.today.ScriptureOfDay.citation(TodayInfoStore.readings(lookupDate))?.localizedFull(language)
                                ?: stringResource(R.string.home_widgets_no_readings)) {
                            com.dkaluta.prosary.ui.readings.ScriptureOfDayCard(date, language)
                        }
                        HomeWidget.Reflection -> DashboardCard(widget, summary = feast?.reflections(language)?.firstOrNull()?.title
                            ?: stringResource(R.string.home_widgets_reflection_pending)) {
                            val reflections = feast?.reflections(language).orEmpty()
                            if (reflections.isEmpty()) Text(stringResource(R.string.home_widgets_reflection_pending),
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                            reflections.forEachIndexed { index, reflection ->
                                if (index > 0) HorizontalDivider()
                                SelectionContainer {
                                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Text(reflection.title, style = MaterialTheme.typography.titleSmall)
                                        Text(reflection.text, modifier = Modifier.testTag("homeReflection.$index"))
                                        reflection.credit?.let { credit ->
                                            Text(credit, style = MaterialTheme.typography.bodySmall,
                                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                                        }
                                    }
                                }
                                reflection.sourceURL?.let { url ->
                                    TextButton(onClick = { uriHandler.openUri(url) }) { Text(stringResource(R.string.readings_source)) }
                                }
                            }
                        }
                        HomeWidget.Feast -> DashboardCard(widget, summary = feast?.localizedTitle(language) ?: stringResource(R.string.home_widgets_no_feast)) {
                            if (feast == null) Text(stringResource(R.string.home_widgets_no_feast))
                            else {
                                Text(feast.localizedTitle(language), style = MaterialTheme.typography.titleSmall)
                                Text(feast.localizedRank(language, context), style = MaterialTheme.typography.bodyMedium)
                                val descriptions = feast.saintDescriptions(TodayInfoStore.selectedCalendarId, language)
                                if (descriptions.isEmpty()) Text(stringResource(R.string.home_widgets_no_feast_description),
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                                else SaintDescriptionsCard(descriptions, "$date:${TodayInfoStore.selectedCalendarId}", language,
                                    inCard = false, parentTitle = feast.localizedTitle(language))
                            }
                        }
                    }
                }
            }
            }
        }
    }
    }

    if (showsCustomization) HomeCustomizationDialog(onDismiss = { showsCustomization = false }, photoBusy = photoBusy,
        onRemove = { widget ->
            if (!photoBusy) {
                if (widget != HomeWidget.Photo && AppSettings.homeWidgetGraphicPath(widget).isEmpty()) AppSettings.homeWidgetOrder = AppSettings.homeWidgetOrder - widget
                else removePhoto(widget, removeCard = true)
            }
        })
    selectedCalendarEvent?.let { event -> CalendarEventDialog(event, language, onDismiss = { selectedCalendarEvent = null }, onOpenReadings = {
        browsingDate.selectedEpochDay = event.date.toEpochDay(); selectedCalendarEvent = null; onOpenReadings(HomeReadingsMode.Daily)
    }) }
    if (photoError) AlertDialog(onDismissRequest = { photoError = false },
        title = { Text(stringResource(R.string.home_widgets_photo_error)) },
        confirmButton = { TextButton(onClick = { photoError = false }) { Text(stringResource(R.string.common_ok)) } })
}

@Composable
private fun DashboardCard(widget: HomeWidget, onClick: (() -> Unit)? = null, summary: String = "", content: @Composable ColumnScope.() -> Unit) {
    val expanded = !AppSettings.isHomeWidgetCollapsed(widget)
    val sizeLabel = stringResource(if (expanded) R.string.home_widget_large else R.string.home_widget_small)
    val actionLabel = stringResource(if (expanded) R.string.home_widget_collapse else R.string.home_widget_expand)
    val graphics = LocalHomeGraphicActions.current
    val graphicPath = AppSettings.homeWidgetGraphicPath(widget)
    val color = AppSettings.homeWidgetColor(widget)
    val defaultColors = CardDefaults.cardColors()
    val palette = AppColor.resolve(color)
    val accent = Color(if (MaterialTheme.colorScheme.surface.luminance() < 0.5f) palette.dark else palette.light)
    val containerColor = if (color == "default") defaultColors.containerColor
        else accent.copy(alpha = 0.12f).compositeOver(defaultColors.containerColor)
    Card(Modifier.fillMaxWidth().testTag("homeWidget.${widget.id}").then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier),
        colors = CardDefaults.cardColors(containerColor = containerColor, contentColor = MaterialTheme.colorScheme.onSurface)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (widget == HomeWidget.PopeIntention) PapalKeysIcon(Modifier.padding(end = 8.dp))
                Text(stringResource(widget.title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                IconButton(onClick = { AppSettings.setHomeWidgetCollapsed(widget, expanded) },
                    modifier = Modifier.testTag("homeWidgetSize.${widget.id}").semantics { stateDescription = sizeLabel }) {
                    Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, contentDescription = actionLabel)
                }
                HomeCardColorMenu(widget)
                if (onClick != null) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
            }
            if (expanded) {
                if (widget != HomeWidget.Photo && widget != HomeWidget.Feast && graphicPath.isNotEmpty()) HomePhoto(graphicPath, Modifier.testTag("homeWidgetGraphicImage.${widget.id}"))
                content()
                if (widget != HomeWidget.Photo && widget != HomeWidget.Feast) Row {
                    TextButton(enabled = !graphics.busy, onClick = { graphics.choose(widget) }, modifier = Modifier.testTag("homeWidgetGraphic.${widget.id}")) {
                        Text(stringResource(if (graphicPath.isEmpty()) R.string.home_widget_add_graphic else R.string.home_widget_change_graphic))
                    }
                    if (graphicPath.isNotEmpty()) TextButton(enabled = !graphics.busy, onClick = { graphics.remove(widget) },
                        modifier = Modifier.testTag("homeWidgetGraphicRemove.${widget.id}")) {
                        Text(stringResource(R.string.home_widget_remove_graphic))
                    }
                }
            } else if (summary.isNotBlank()) Text(summary, maxLines = 2, overflow = TextOverflow.Ellipsis,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun HomeCardColorMenu(widget: HomeWidget) {
    var expanded by rememberSaveable(widget.id) { mutableStateOf(false) }
    var choosingColor by rememberSaveable(widget.id) { mutableStateOf(false) }
    val selectedColor = AppSettings.homeWidgetColor(widget)
    Box {
        IconButton(onClick = { choosingColor = false; expanded = true }, modifier = Modifier.testTag("homeWidgetColor.${widget.id}")) {
            Icon(Icons.Filled.Palette, contentDescription = "${stringResource(R.string.home_widgets_set_accent_color)}: ${stringResource(widget.title)}")
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false; choosingColor = false }) {
            if (choosingColor) {
                AppSettings.todayCardColors.filter { it != "default" }.forEach { color ->
                    val label = stringResource(AppColor.resolve(color).labelRes)
                    DropdownMenuItem(text = {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                            Text(label, modifier = Modifier.weight(1f))
                            if (selectedColor == color) Icon(Icons.Filled.Check, contentDescription = null)
                        }
                    }, onClick = { AppSettings.setHomeWidgetColor(widget, color); expanded = false; choosingColor = false },
                        modifier = Modifier.testTag("homeWidgetColor.${widget.id}.$color").semantics { selected = selectedColor == color })
                }
            } else {
                DropdownMenuItem(text = { Text(stringResource(R.string.home_widgets_set_accent_color)) },
                    trailingIcon = { Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null) },
                    onClick = { choosingColor = true }, modifier = Modifier.testTag("homeWidgetSetAccent.${widget.id}"))
                if (selectedColor != "default") {
                    HorizontalDivider()
                    DropdownMenuItem(text = { Text(stringResource(R.string.home_widgets_remove_accent_color)) },
                        onClick = { AppSettings.setHomeWidgetColor(widget, "default"); expanded = false },
                        modifier = Modifier.testTag("homeWidgetRemoveAccent.${widget.id}"))
                }
            }
        }
    }
}

@Composable
private fun ReminderLink(title: String, reminder: PrayerReminder, onClick: () -> Unit) {
    val context = LocalContext.current
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.fillMaxWidth()) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(reminder.formattedTime(context) + if (reminder.isEnabled) "" else " · ${stringResource(R.string.auto_advance_off)}",
                style = MaterialTheme.typography.bodyMedium)
        }
    }
}

@Composable
private fun HomePhoto(path: String, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    var failed by remember(path) { mutableStateOf(false) }
    val bitmap by key(path) {
        produceState<ImageBitmap?>(initialValue = null) {
            if (path.isNotEmpty()) withContext(Dispatchers.IO) {
                runCatching { HomePhotoStore.load(context.filesDir, path).asImageBitmap() }
            }.onSuccess { value = it }.onFailure { failed = true }
        }
    }
    if (path.isNotEmpty()) Box(modifier.fillMaxWidth().height(200.dp), contentAlignment = Alignment.Center) {
        bitmap?.let { Image(it, contentDescription = stringResource(R.string.home_widgets_photo_description),
            modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit) }
        if (failed) Text(stringResource(R.string.home_widgets_photo_error), color = MaterialTheme.colorScheme.error)
        else if (bitmap == null) CircularProgressIndicator()
    }
}

@Composable
private fun HomeCustomizationDialog(photoBusy: Boolean, onRemove: (HomeWidget) -> Unit, onDismiss: () -> Unit) {
    val selected = AppSettings.homeWidgetOrder
    AlertDialog(onDismissRequest = onDismiss, title = { Text(stringResource(R.string.home_widgets_customize)) },
        text = {
            Column(Modifier.heightIn(max = 520.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.home_widgets_selected), style = MaterialTheme.typography.titleSmall)
                selected.forEachIndexed { index, widget ->
                    val label = stringResource(widget.title)
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text(label, modifier = Modifier.weight(1f))
                        IconButton(enabled = index > 0, onClick = { AppSettings.moveHomeWidget(widget, -1) }) {
                            Icon(Icons.Filled.ArrowUpward, "${stringResource(R.string.home_widgets_move_up)}: $label")
                        }
                        IconButton(enabled = index < selected.lastIndex, onClick = { AppSettings.moveHomeWidget(widget, 1) }) {
                            Icon(Icons.Filled.ArrowDownward, "${stringResource(R.string.home_widgets_move_down)}: $label")
                        }
                        IconButton(enabled = !photoBusy, onClick = { onRemove(widget) },
                            modifier = Modifier.testTag("homeWidgetRemove.${widget.id}")) {
                            Icon(Icons.Filled.Delete, "${stringResource(R.string.home_widgets_remove)}: $label")
                        }
                    }
                }
                if (selected.size < HomeWidget.entries.size) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                    Text(stringResource(R.string.home_widgets_available), style = MaterialTheme.typography.titleSmall)
                    HomeWidget.entries.filter { it !in selected }.forEach { widget ->
                        val label = stringResource(widget.title)
                        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                            Text(label, modifier = Modifier.weight(1f))
                            IconButton(onClick = { AppSettings.addHomeWidget(widget) }, modifier = Modifier.testTag("homeWidgetAdd.${widget.id}")) {
                                Icon(Icons.Filled.Add, "${stringResource(R.string.home_widgets_add)}: $label")
                            }
                        }
                    }
                }
            }
        }, confirmButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) } })
}
