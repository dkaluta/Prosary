package com.dkaluta.prosary.ui.readings

import androidx.annotation.StringRes
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberModalBottomSheetState
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onPreviewKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.today.ReadingCitation
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingPassage
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import com.dkaluta.prosary.ui.shared.SaintDescriptionsCard
import com.dkaluta.prosary.ui.shared.AramaicScriptPicker
import com.dkaluta.prosary.ui.shared.rememberTodayBrowsingDate
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.typography.PrayerTypography
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.util.Locale
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/** Daily appointments share Home's date and keep their own settings inside the sheet. */
@Composable
fun ReadingsScreen(browsingDate: TodayBrowsingDate = rememberTodayBrowsingDate(),
    onDismiss: (() -> Unit)? = null) {
    var showsReadingSettings by rememberSaveable { mutableStateOf(false) }
    if (showsReadingSettings) ReadingSettingsSheet { showsReadingSettings = false }
    Scaffold(topBar = {
        ScriptureToolbar(R.string.tab_readings, onOpenSettings = { showsReadingSettings = true }, onDismiss = onDismiss)
    }) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            DailyReadingsContent(browsingDate)
        }
    }
}

/** The full Bible retains its reader and offline-download state as a primary destination. */
@Composable
internal fun BibleTabScreen() {
    val chrome = LocalBibleReadingChrome.current
    val chromeHidden = chrome?.value == true
    androidx.activity.compose.BackHandler(enabled = chromeHidden) { chrome?.value = false }
    val owner = androidx.compose.ui.platform.LocalContext.current
    androidx.compose.runtime.DisposableEffect(chromeHidden, owner) {
        var candidate: android.content.Context? = owner
        while (candidate is android.content.ContextWrapper && candidate !is android.app.Activity) candidate = candidate.baseContext
        val activity = candidate as? android.app.Activity
        val controller = activity?.let { androidx.core.view.WindowCompat.getInsetsController(it.window, it.window.decorView) }
        if (chromeHidden) {
            controller?.systemBarsBehavior = androidx.core.view.WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            controller?.hide(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        } else controller?.show(androidx.core.view.WindowInsetsCompat.Type.systemBars())
        onDispose { controller?.show(androidx.core.view.WindowInsetsCompat.Type.systemBars()) }
    }
    var showsReadingSettings by rememberSaveable { mutableStateOf(false) }
    if (showsReadingSettings) ReadingSettingsSheet { showsReadingSettings = false }
    Scaffold(topBar = {
        if (!chromeHidden) ScriptureToolbar(R.string.bible_title, onOpenSettings = { showsReadingSettings = true })
    }) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) { BibleScreen() }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ScriptureToolbar(@StringRes title: Int, onOpenSettings: () -> Unit, onDismiss: (() -> Unit)? = null) {
    TopAppBar(title = { Text(stringResource(title)) }, actions = {
        IconButton(onClick = onOpenSettings, modifier = Modifier.testTag("readingsSettingsButton")) {
            Icon(Icons.Filled.Settings, contentDescription = stringResource(R.string.reading_settings))
        }
        if (onDismiss != null) TextButton(onClick = onDismiss, modifier = Modifier.testTag("readingsDone")) {
            Text(stringResource(R.string.common_done))
        }
    })
}

/** The same modal owner replaces Calendar with Daily Readings without stacking references. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun HomeReferenceSheet(mode: HomeReadingsMode, browsingDate: TodayBrowsingDate,
    onDismiss: () -> Unit, onOpenReadings: () -> Unit) {
    if (mode == HomeReadingsMode.Daily) {
        val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
        ModalBottomSheet(onDismissRequest = onDismiss,
            sheetState = sheetState, modifier = Modifier.testTag("homeReference.daily")) {
            val focusRequester = remember { FocusRequester() }
            var hasContentFocus by remember { mutableStateOf(false) }
            LaunchedEffect(sheetState.isVisible) {
                if (sheetState.isVisible && !hasContentFocus) focusRequester.requestFocus()
            }
            Box(Modifier.fillMaxSize().focusRequester(focusRequester)
                .onFocusChanged { hasContentFocus = it.hasFocus }
                .onPreviewKeyEvent { event ->
                    if (event.key == Key.Escape) {
                        if (event.type == KeyEventType.KeyUp) onDismiss()
                        true
                    } else false
                }.focusable()) {
                ReadingsScreen(browsingDate, onDismiss)
            }
        }
        return
    }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(modifier = Modifier.fillMaxSize().testTag("homeReference.${mode.id}"), topBar = {
            TopAppBar(title = { Text(stringResource(if (mode == HomeReadingsMode.Bible) R.string.bible_title else R.string.calendar_event_calendar)) },
                actions = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) } })
        }) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                if (mode == HomeReadingsMode.Bible) BibleScreen()
                else FeastsAndSolemnitiesContent(browsingDate, onSelectDate = onOpenReadings)
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DailyReadingsContent(browsingDate: TodayBrowsingDate) {
    val context = LocalContext.current
    val language = TodayTranslationLanguage.resolve(LocalConfiguration.current.locales[0].toLanguageTag())
    var currentDate by remember { mutableStateOf(LocalDate.now()) }
    var currentZone by remember { mutableStateOf(ZoneId.systemDefault()) }
    var generation by remember { mutableIntStateOf(0) }
    var showsDatePicker by rememberSaveable { mutableStateOf(false) }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                currentDate = LocalDate.now()
                currentZone = ZoneId.systemDefault()
                generation++
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    LaunchedEffect(Unit) {
        while (true) {
            currentDate = LocalDate.now()
            currentZone = ZoneId.systemDefault()
            delay(30_000)
        }
    }
    val selectedDate = browsingDate.selectedDate(currentDate)
    val lookupDate = TodayDateSelection.lookupDate(selectedDate, currentZone)
    val calendarId = TodayInfoStore.selectedCalendarId
    // Only explicit choices override the default. Keep them outside lazy cards so edition
    // changes, scrolling and same-date foreground refreshes preserve the reader's choice.
    var expansionOverrides by remember(selectedDate, calendarId, AppSettings.easternPaschaStyle,
        AppSettings.expandReadingsByDefault) { mutableStateOf(emptyMap<String, Boolean>()) }
    val readings = remember(lookupDate, calendarId, AppSettings.easternPaschaStyle, generation) {
        TodayInfoStore.readings(lookupDate)
    }
    val displayedReadings = ReadingCitation.indexedDisplayOrder(readings, AppSettings.reverseReadingsOrder)
    val saints = remember(lookupDate, calendarId, language, AppSettings.showTodayFeast, generation) {
        if (AppSettings.showTodayFeast) TodayInfoStore.feast(lookupDate)?.saintDescriptions(calendarId, language).orEmpty()
        else emptyList()
    }
    val torah = remember(lookupDate, AppSettings.showTodayTorahPortion, generation) {
        if (AppSettings.showTodayTorahPortion) TodayInfoStore.torahPortion(lookupDate) else null
    }
    val store = remember(context.applicationContext) {
        ReadingTextStore(bibleStore = BibleLibrary.get(context.applicationContext).store) { name ->
            context.applicationContext.assets.open("data/$name.json")
        }
    }
    val editions by produceState<List<ReadingEdition>>(emptyList(), store) {
        value = withContext(Dispatchers.IO) { store.editions }
    }
    val editionId = ReadingTextStore.effectiveEditionId(AppSettings.readingsEditionId, language, editions)
    val edition = editions.firstOrNull { it.id == editionId }
    var showsEditions by remember { mutableStateOf(false) }
    val dateLabel = selectedDate.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG)
        .withLocale(Locale.forLanguageTag(if (language == "tl") "fil" else language)))

    CompositionLocalProvider(LocalLayoutDirection provides
        if (TodayTranslationLanguage.isRightToLeft(language)) LayoutDirection.Rtl else LayoutDirection.Ltr) {
        if (showsDatePicker) {
            CalendarDatePickerDialog(selectedDate, onDismiss = { showsDatePicker = false }, onSelect = {
                browsingDate.selectedEpochDay = it.toEpochDay(); showsDatePicker = false
            }, onToday = {
                browsingDate.selectedEpochDay = null; currentDate = LocalDate.now(); showsDatePicker = false
            })
        }
            LazyColumn(
                modifier = Modifier.fillMaxSize().testTag("readingsList"),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(key = "date") {
                    Surface(
                        modifier = Modifier.fillMaxWidth(),
                        shape = RoundedCornerShape(28.dp),
                        color = MaterialTheme.colorScheme.surfaceContainer.copy(alpha = 0.82f),
                        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f)),
                        tonalElevation = 3.dp,
                        shadowElevation = 2.dp,
                    ) {
                        Row(Modifier.fillMaxWidth().padding(4.dp).height(IntrinsicSize.Min), verticalAlignment = Alignment.CenterVertically) {
                            IconButton(onClick = { browsingDate.selectedEpochDay = selectedDate.minusDays(1).toEpochDay() },
                                enabled = selectedDate > TodayDateSelection.earliest,
                                modifier = Modifier.heightIn(min = 48.dp).fillMaxHeight().testTag("readingsPrevious")) {
                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.home_today_yesterday))
                            }
                            TextButton(onClick = { showsDatePicker = true },
                                modifier = Modifier.weight(1f).heightIn(min = 48.dp).fillMaxHeight().testTag("readingsChooseDate")) {
                                Text(dateLabel, textAlign = TextAlign.Center)
                            }
                            IconButton(onClick = { browsingDate.selectedEpochDay = selectedDate.plusDays(1).toEpochDay() },
                                enabled = selectedDate < TodayDateSelection.latest,
                                modifier = Modifier.heightIn(min = 48.dp).fillMaxHeight().testTag("readingsNext")) {
                                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.home_today_tomorrow))
                            }
                        }
                    }
                }
                item(key = "calendar") {
                    TodayInfoStore.calendars.firstOrNull { it.id == calendarId }?.let {
                        Text(it.displayName, style = MaterialTheme.typography.titleSmall)
                    }
                    Box {
                        TextButton(onClick = { showsEditions = true }, modifier = Modifier.testTag("readingsEdition")) {
                            Text("${stringResource(R.string.readings_edition)}: ${edition?.name ?: stringResource(R.string.readings_choose_edition)}")
                        }
                        DropdownMenu(expanded = showsEditions, onDismissRequest = { showsEditions = false }) {
                            DropdownMenuItem(text = { Text(stringResource(R.string.readings_follow_interface)) }, onClick = {
                                AppSettings.readingsEditionId = ""
                                showsEditions = false
                            })
                            for (available in editions) {
                                DropdownMenuItem(text = { Text(available.name) }, onClick = {
                                    AppSettings.readingsEditionId = available.id
                                    showsEditions = false
                                })
                            }
                        }
                    }
                }
                if (saints.isNotEmpty()) item(key = "saints") {
                    SaintDescriptionsCard(saints, selectedDate.toString(), language)
                }
                if (readings.isEmpty()) item(key = "empty") {
                    Text(stringResource(R.string.readings_empty), color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.testTag("readingsEmpty"))
                }
                for ((displayIndex, indexedCitation) in displayedReadings.withIndex()) {
                    val (index, citation) = indexedCitation
                    val group = citation.sourceGroup
                    if (!group.isNullOrBlank() && (displayIndex == 0 || displayedReadings[displayIndex - 1].value.sourceGroup != group)) {
                        item(key = "group.$selectedDate.$calendarId.$index") {
                            Text(group, style = MaterialTheme.typography.titleSmall,
                                modifier = Modifier.semantics { heading() })
                        }
                    }
                    val passageKey = "daily.$index.${citation.full}"
                    item(key = "daily.$selectedDate.$calendarId.$index.${citation.full}") {
                        ReadingCard(citation, language, edition, editionId, store, false,
                            expanded = expansionOverrides[passageKey] ?: AppSettings.expandReadingsByDefault,
                            onToggleExpanded = {
                                expansionOverrides = expansionOverrides +
                                    (passageKey to !(expansionOverrides[passageKey] ?: AppSettings.expandReadingsByDefault))
                            })
                    }
                }
                if (torah != null) {
                    item(key = "torah") {
                        Text(stringResource(if (torah.isHoliday) R.string.home_today_torah_festival else R.string.home_today_torah),
                            style = MaterialTheme.typography.titleSmall)
                        Text(torah.localizedTitle(language), style = MaterialTheme.typography.titleMedium)
                    }
                    for ((index, citation) in torah.allReadings.withIndex()) {
                        val passageKey = "torah.$index.${citation.full}"
                        item(key = "torah.$selectedDate.$index.${citation.full}") {
                            ReadingCard(citation, language, edition, editionId, store, true,
                                expanded = expansionOverrides[passageKey] ?: AppSettings.expandReadingsByDefault,
                                onToggleExpanded = {
                                    expansionOverrides = expansionOverrides +
                                        (passageKey to !(expansionOverrides[passageKey] ?: AppSettings.expandReadingsByDefault))
                                })
                        }
                    }
                }
            }
    }
}

private data class ReadingCardText(
    val isLoaded: Boolean = false,
    val passage: ReadingPassage? = null,
    val availableEditions: List<ReadingEdition> = emptyList(),
)

@Composable
internal fun ReadingCard(citation: ReadingCitation, language: String, edition: ReadingEdition?,
    editionId: String?, store: ReadingTextStore, isTorah: Boolean, expanded: Boolean,
    onToggleExpanded: () -> Unit) {
    val uriHandler = LocalUriHandler.current
    val context = LocalContext.current
    // A local reading aid survives collapse/lazy recycling; the setting applies until a choice.
    var scriptOverride by rememberSaveable(citation.full, citation.readingDatasetId, editionId, isTorah) { mutableStateOf<String?>(null) }
    var showsAvailableEditions by remember(citation.full, citation.readingDatasetId, editionId, isTorah) { mutableStateOf(false) }
    val readingScript = scriptOverride ?: AppSettings.aramaicDefaultScript
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(stringResource(when (citation.type) {
                "gospel" -> R.string.readings_type_gospel
                "psalm" -> R.string.readings_type_psalm
                "haftarah" -> R.string.readings_type_haftarah
                "haftarahSephardic" -> R.string.readings_type_haftarah_sephardic
                else -> R.string.readings_type_reading
            }), style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary)
            SelectionContainer { Text(citation.localizedFull(language), style = MaterialTheme.typography.titleMedium) }
            TextButton(onClick = onToggleExpanded,
                modifier = Modifier.testTag("readingExpand.${if (isTorah) "torah" else "daily"}.${citation.full}")) {
                Text(stringResource(if (expanded) R.string.readings_hide_text else R.string.readings_show_text))
            }
            if (expanded) {
                // Only expansion loads the passage corpus, off the main thread. The edition
                // picker reads a small metadata companion. No localized string is a key.
                // Give each edition its own state immediately, so a previous edition's
                // text is never displayed under the new edition's name or source credit.
                val result by key(store, citation.full, citation.readingDatasetId, editionId, isTorah) {
                    produceState(ReadingCardText()) {
                        value = withContext(Dispatchers.IO) {
                            val passage = if (edition == null || editionId == null) null else store.passage(citation, editionId, isTorah)
                            ReadingCardText(true, passage,
                                if (passage == null) store.availableEditions(citation, isTorah) else emptyList())
                        }
                    }
                }
                val passage = result.passage
                Text(stringResource(R.string.readings_bible_passage), style = MaterialTheme.typography.labelLarge)
                if (!result.isLoaded) {
                    CircularProgressIndicator()
                } else if (passage == null) {
                    Text(stringResource(R.string.readings_unavailable), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    if (result.availableEditions.isNotEmpty()) {
                        Box {
                            TextButton(onClick = { showsAvailableEditions = true },
                                modifier = Modifier.testTag("readingAvailableEditions.${if (isTorah) "torah" else "daily"}.${citation.full}")) {
                                Text(stringResource(R.string.readings_edition))
                            }
                            DropdownMenu(expanded = showsAvailableEditions, onDismissRequest = { showsAvailableEditions = false }) {
                                for (available in result.availableEditions) {
                                    DropdownMenuItem(text = { Text(available.name) }, onClick = {
                                        AppSettings.readingsEditionId = available.id
                                        showsAvailableEditions = false
                                    })
                                }
                            }
                        }
                    }
                } else {
                    if (edition?.hasAramaicScripts == true) {
                        AramaicScriptPicker(readingScript, onSelect = { scriptOverride = it },
                            modifier = Modifier.testTag("readingScript.${if (isTorah) "torah" else "daily"}.${citation.full}"))
                    }
                    if (passage.includesWholeVerses) {
                        Text(stringResource(R.string.readings_whole_verses_notice),
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    if (passage.source?.isComplete == false) {
                        Text(stringResource(R.string.bible_partial_chapter),
                            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.testTag("readingPartialSource"))
                    }
                    val bodyScript = PrayerTypography.scriptOf(passage.verses.first().displayedText(edition, readingScript))
                    CompositionLocalProvider(LocalLayoutDirection provides
                        if (bodyScript in listOf(PrayerTypography.Script.Hebrew, PrayerTypography.Script.Arabic,
                                PrayerTypography.Script.Syriac)) LayoutDirection.Rtl else LayoutDirection.Ltr) {
                        SelectionContainer {
                            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                var displayedChapter: Int? = null
                                for (item in passage.displayItems) {
                                    val verse = item.primary
                                    val chapter = verse?.chapter ?: displayedChapter ?: passage.verses.first().chapter
                                    if (displayedChapter != chapter) {
                                        Text(ReadingChapterHeading.label(context, chapter, edition?.languageCode ?: "en", readingScript),
                                            style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold,
                                            fontStyle = FontStyle.Normal,
                                            modifier = Modifier.fillMaxWidth())
                                        displayedChapter = chapter
                                    }
                                    val visibleText = verse?.displayedText(edition, readingScript) ?: item.block.text.orEmpty()
                                    Column(Modifier.testTag("readingBlock.${item.id}")) {
                                        when (item.block.kind) {
                                            "heading" -> DisableSelection {
                                                Text(visibleText, style = PrayerTypography.styleForText(visibleText, isScripture = true),
                                                    fontWeight = FontWeight.Bold, modifier = Modifier.fillMaxWidth())
                                            }
                                            "colophon" -> DisableSelection {
                                                Text(visibleText, style = MaterialTheme.typography.bodySmall,
                                                    color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.fillMaxWidth())
                                            }
                                            else -> {
                                                val label = verse?.verseLabel ?: item.block.printedLabel
                                                val display = if (label == null) visibleText else "\u2066$label\u2069  $visibleText"
                                                Text(display, style = PrayerTypography.styleForText(visibleText, isScripture = true),
                                                    modifier = Modifier.fillMaxWidth())
                                                if (verse != null) item.block.printedLabel?.let { printed -> DisableSelection {
                                                    Text(stringResource(R.string.bible_printed_label, "\u2068$printed\u2069"),
                                                        style = MaterialTheme.typography.labelMedium)
                                                } }
                                            }
                                        }
                                        ScriptureSourceNotes(item.sourceNotes)
                                    }
                                }
                            }
                        }
                    }
                }
                if (edition != null) {
                    Text(edition.name, style = MaterialTheme.typography.labelLarge)
                    val source = passage?.source
                    source?.let { Text(it.name, style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier.testTag("readingSourceName")) }
                    Text(source?.attribution ?: edition.attribution, style = MaterialTheme.typography.bodySmall)
                    val sourceURL = source?.sourceURL ?: edition.sourceURL
                    if (sourceURL.startsWith("https://")) TextButton(onClick = { uriHandler.openUri(sourceURL) }) {
                        Text(stringResource(R.string.readings_source))
                    }
                }
            }
        }
    }
}
