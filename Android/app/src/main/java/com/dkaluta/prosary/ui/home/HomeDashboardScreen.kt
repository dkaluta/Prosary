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
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Card
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.HomeWidget
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerReminder
import com.dkaluta.prosary.services.LocalAppServices
import com.dkaluta.prosary.ui.readings.HomeReadingsMode
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
        HomeWidget.PopeIntention -> R.string.home_widgets_pope_intention
        HomeWidget.Calendar -> R.string.home_widgets_calendar
        HomeWidget.Photo -> R.string.home_widgets_photo
        HomeWidget.Reminders -> R.string.home_widgets_reminders
        HomeWidget.Scripture -> R.string.home_widgets_scripture
        HomeWidget.Reflection -> R.string.home_widgets_reflection
        HomeWidget.Feast -> R.string.home_widgets_feast
    }

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
    var handledTodayRequest by rememberSaveable { mutableStateOf(0L) }
    val lifecycle = LocalLifecycleOwner.current
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
    val readings = remember(date, generation, AppSettings.feastCalendarId, AppSettings.easternPaschaStyle, AppSettings.reverseReadingsOrder) {
        com.dkaluta.prosary.content.today.ReadingCitation.displayOrder(TodayInfoStore.readings(lookupDate), AppSettings.reverseReadingsOrder)
    }
    val calendarName = TodayInfoStore.calendars.firstOrNull { it.id == TodayInfoStore.selectedCalendarId }?.displayName.orEmpty()
    val prayers by produceState<List<Prayer>>(initialValue = emptyList(), generation, services) {
        value = withContext(Dispatchers.IO) { services.presetStore.all() }
    }
    val reminders = prayers.flatMap { prayer -> prayer.reminders.filter { it.isEnabled }.map { prayer to it } }
        .sortedWith(compareBy({ it.second.hour }, { it.second.minute }, { it.first.name }))

    fun removePhoto(removeCard: Boolean = false) {
        if (photoBusy) return
        photoBusy = true
        val oldPath = AppSettings.homePhotoPath
        scope.launch {
            try {
                HomePhotoTransaction.remove(oldPath, { HomePhotoStore.remove(context.filesDir, it) }) {
                    AppSettings.homePhotoPath = ""
                    if (removeCard) AppSettings.homeWidgetOrder = AppSettings.homeWidgetOrder - HomeWidget.Photo
                }
            } catch (cancelled: CancellationException) { throw cancelled }
            catch (error: Exception) { photoError = true }
            finally { photoBusy = false }
        }
    }

    val photoPicker = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        if (uri != null) {
            photoBusy = true
            scope.launch {
                val oldPath = AppSettings.homePhotoPath
                try {
                    HomePhotoTransaction.replace(oldPath, { HomePhotoStore.copy(context, uri) },
                        { AppSettings.homePhotoPath = it }, { HomePhotoStore.remove(context.filesDir, it) })
                } catch (cancelled: CancellationException) { throw cancelled }
                catch (error: Exception) { photoError = true }
                finally { photoBusy = false }
            }
        }
    }

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
        CompositionLocalProvider(LocalLayoutDirection provides if (TodayTranslationLanguage.isRightToLeft(language)) LayoutDirection.Rtl else LayoutDirection.Ltr) {
            LazyColumn(Modifier.padding(padding).fillMaxSize().testTag("homeDashboard"),
                contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                item("date") {
                    Text(date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale)),
                        style = MaterialTheme.typography.titleMedium, modifier = Modifier.testTag("homeDate"))
                }
                if (AppSettings.homeWidgetOrder.isEmpty()) item("empty") {
                    Text(stringResource(R.string.home_widgets_empty))
                    TextButton(onClick = { showsCustomization = true }) { Text(stringResource(R.string.home_widgets_add)) }
                }
                items(AppSettings.homeWidgetOrder, key = { it.id }) { widget ->
                    when (widget) {
                        HomeWidget.Readings -> DashboardCard(widget, { onOpenReadings(HomeReadingsMode.Daily) }) {
                            if (readings.isEmpty()) Text(stringResource(R.string.home_widgets_no_readings))
                            else readings.forEachIndexed { index, citation ->
                                Text(citation.localizedFull(language), modifier = Modifier.fillMaxWidth().testTag("homeReading.$index"))
                            }
                        }
                        HomeWidget.PopeIntention -> DashboardCard(widget) {
                            if (intention == null) Text(stringResource(R.string.home_widgets_no_intention))
                            else {
                                Text(intention.localizedTitle(language), style = MaterialTheme.typography.titleSmall)
                                Text(intention.localizedText(language))
                            }
                        }
                        HomeWidget.Calendar -> DashboardCard(widget) {
                            Text(date.format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)))
                            if (calendarName.isNotBlank()) Text(calendarName, style = MaterialTheme.typography.bodyMedium)
                            Text(date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)),
                                style = MaterialTheme.typography.labelMedium)
                            Text(feast?.localizedTitle(language) ?: stringResource(R.string.home_widgets_no_feast))
                            TextButton(onClick = { onOpenReadings(HomeReadingsMode.Calendar) }, modifier = Modifier.testTag("homeOpenCalendar")) {
                                Text(stringResource(R.string.calendar_title))
                            }
                        }
                        HomeWidget.Photo -> DashboardCard(widget) {
                            HomePhoto(AppSettings.homePhotoPath)
                            if (photoBusy) CircularProgressIndicator()
                            Row {
                                TextButton(enabled = !photoBusy, onClick = {
                                    photoPicker.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                                }) { Text(stringResource(R.string.home_widgets_choose_photo)) }
                                if (AppSettings.homePhotoPath.isNotEmpty()) TextButton(enabled = !photoBusy, onClick = { removePhoto() }) {
                                    Text(stringResource(R.string.home_widgets_remove_photo))
                                }
                            }
                        }
                        HomeWidget.Reminders -> DashboardCard(widget) {
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
                        HomeWidget.Scripture -> DashboardCard(widget, { onOpenReadings(HomeReadingsMode.Bible) }) {
                            Text(stringResource(R.string.bible_title))
                        }
                        HomeWidget.Reflection -> DashboardCard(widget) {
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
                        HomeWidget.Feast -> DashboardCard(widget) {
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

    if (showsCustomization) HomeCustomizationDialog(onDismiss = { showsCustomization = false }, photoBusy = photoBusy,
        onRemove = { widget ->
            if (widget != HomeWidget.Photo) AppSettings.homeWidgetOrder = AppSettings.homeWidgetOrder - widget
            else removePhoto(removeCard = true)
        })
    if (photoError) AlertDialog(onDismissRequest = { photoError = false },
        title = { Text(stringResource(R.string.home_widgets_photo_error)) },
        confirmButton = { TextButton(onClick = { photoError = false }) { Text(stringResource(R.string.common_ok)) } })
}

@Composable
private fun DashboardCard(widget: HomeWidget, onClick: (() -> Unit)? = null, content: @Composable ColumnScope.() -> Unit) {
    Card(Modifier.fillMaxWidth().testTag("homeWidget.${widget.id}").then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (widget == HomeWidget.PopeIntention) PapalKeysIcon(Modifier.padding(end = 8.dp))
                Text(stringResource(widget.title), style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                if (onClick != null) Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
            }
            content()
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
private fun HomePhoto(path: String) {
    val context = LocalContext.current
    var failed by remember(path) { mutableStateOf(false) }
    val bitmap by key(path) {
        produceState<ImageBitmap?>(initialValue = null) {
            if (path.isNotEmpty()) withContext(Dispatchers.IO) {
                runCatching { HomePhotoStore.load(context.filesDir, path).asImageBitmap() }
            }.onSuccess { value = it }.onFailure { failed = true }
        }
    }
    bitmap?.let { Image(it, contentDescription = stringResource(R.string.home_widgets_photo_description),
        modifier = Modifier.fillMaxWidth().heightIn(max = 400.dp), contentScale = ContentScale.Fit) }
    if (failed) Text(stringResource(R.string.home_widgets_photo_error), color = MaterialTheme.colorScheme.error)
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
                        IconButton(enabled = widget != HomeWidget.Photo || !photoBusy, onClick = { onRemove(widget) },
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
