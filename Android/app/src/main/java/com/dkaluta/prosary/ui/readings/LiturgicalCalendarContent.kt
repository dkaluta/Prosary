package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.*
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun CalendarDatePickerDialog(date: LocalDate, onDismiss: () -> Unit, onSelect: (LocalDate) -> Unit, onToday: () -> Unit) {
    var selectedEpochDay by rememberSaveable(date.toEpochDay()) { mutableStateOf(date.toEpochDay()) }
    DatePickerDialog(onDismissRequest = onDismiss,
        confirmButton = { TextButton(onClick = { onSelect(LocalDate.ofEpochDay(selectedEpochDay)) }) { Text(stringResource(R.string.common_ok)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) } }) {
        Column(Modifier.fillMaxWidth().heightIn(max = 480.dp).verticalScroll(rememberScrollState())
            .padding(16.dp).testTag("readingsDatePicker")) {
            TextButton(onClick = onToday, modifier = Modifier.testTag("readingsReset")) { Text(stringResource(R.string.home_today_reset)) }
            CalendarMonthGrid(LocalDate.ofEpochDay(selectedEpochDay)) { selectedEpochDay = it.toEpochDay() }
        }
    }
}

@Composable
fun LiturgicalCalendarContent(browsingDate: TodayBrowsingDate, onSelectDate: () -> Unit) {
    val date = browsingDate.selectedDate(LocalDate.now())
    val language = TodayTranslationLanguage.resolve(LocalConfiguration.current.locales[0].toLanguageTag())
    val events = remember(date, TodayInfoStore.selectedCalendarId, AppSettings.easternPaschaStyle) {
        CalendarEvents.events(date, TodayInfoStore.feast(TodayDateSelection.lookupDate(date)))
    }
    var selectedEvent by remember(date, TodayInfoStore.selectedCalendarId) { mutableStateOf<CalendarEvent?>(null) }
    LazyColumn(Modifier.testTag("calendar.monthPicker"), contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        item {
            CalendarMonthGrid(date, onSelectDate = { browsingDate.selectedEpochDay = it.toEpochDay() })
            TextButton(onClick = { browsingDate.selectedEpochDay = null }) { Text(stringResource(R.string.home_today_reset)) }
            Text(TodayInfoStore.calendars.firstOrNull { it.id == TodayInfoStore.selectedCalendarId }?.displayName.orEmpty(),
                style = MaterialTheme.typography.labelMedium)
        }
        if (events.isEmpty()) item { Text(stringResource(R.string.calendar_no_observances), Modifier.padding(vertical = 16.dp)) }
        items(events, key = { it.id }) { event -> CalendarEventRow(event, language) { selectedEvent = event } }
        item { TextButton(onClick = onSelectDate, modifier = Modifier.testTag("calendarOpenReadings")) { Text(stringResource(R.string.calendar_event_readings)) } }
    }
    selectedEvent?.let { event -> CalendarEventDialog(event, language, onDismiss = { selectedEvent = null }, onOpenReadings = {
        browsingDate.selectedEpochDay = event.date.toEpochDay(); selectedEvent = null; onSelectDate()
    }) }
}

@Composable
internal fun CalendarMonthGrid(date: LocalDate, onSelectDate: (LocalDate) -> Unit) {
    val locale = LocalConfiguration.current.locales[0]
    val start = date.withDayOfMonth(1)
    val days = remember(start) { CalendarEvents.monthCells(start) }
    val counts = remember(start, TodayInfoStore.selectedCalendarId, AppSettings.easternPaschaStyle) {
        days.filterNotNull().associateWith { CalendarEvents.events(it, TodayInfoStore.feast(TodayDateSelection.lookupDate(it))).size }
    }
    val formatter = remember(locale) { java.text.NumberFormat.getIntegerInstance(locale) }
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = { onSelectDate(start.minusMonths(1)) }, enabled = start > TodayDateSelection.earliest.withDayOfMonth(1)) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.calendar_previous_month))
            }
            Text(start.format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)), Modifier.weight(1f), textAlign = TextAlign.Center,
                style = MaterialTheme.typography.titleMedium)
            IconButton(onClick = { onSelectDate(start.plusMonths(1)) }, enabled = start < TodayDateSelection.latest.withDayOfMonth(1)) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.calendar_next_month))
            }
        }
        Row(Modifier.fillMaxWidth()) {
            DayOfWeek.entries.forEach { day -> Text(day.getDisplayName(TextStyle.NARROW_STANDALONE, locale), Modifier.weight(1f),
                textAlign = TextAlign.Center, style = MaterialTheme.typography.labelMedium) }
        }
        days.chunked(7).forEach { week ->
            Row(Modifier.fillMaxWidth()) {
                week.forEach { day ->
                    if (day == null) Spacer(Modifier.weight(1f).height(52.dp))
                    else {
                        val count = counts[day] ?: 0
                        val isSelected = day == date
                        val tint = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary
                        val label = day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.FULL).withLocale(locale)) +
                            ", " + stringResource(R.string.calendar_event_count, count)
                        Column(Modifier.weight(1f).height(52.dp).clip(MaterialTheme.shapes.medium)
                            .background(if (isSelected) MaterialTheme.colorScheme.primary else androidx.compose.ui.graphics.Color.Transparent)
                            .clickable { onSelectDate(day) }.testTag("calendarDate.$day")
                            .semantics { contentDescription = label; selected = isSelected }, horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center) {
                            Text(formatter.format(day.dayOfMonth), color = if (isSelected) tint else MaterialTheme.colorScheme.onSurface,
                                style = MaterialTheme.typography.bodyMedium)
                            Row(Modifier.height(8.dp), horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.CenterVertically) {
                                repeat(count.coerceAtMost(3)) { Spacer(Modifier.size(4.dp).clip(CircleShape).background(tint)) }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
internal fun CalendarEventRow(event: CalendarEvent, language: String, onClick: () -> Unit) {
    val context = LocalContext.current
    val description = event.description(language)
    Card(onClick = onClick, modifier = Modifier.fillMaxWidth().testTag("calendarEvent.${event.id}")) {
        Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(event.title(language), style = MaterialTheme.typography.titleMedium)
                Text(event.day.localizedRank(language, context), style = MaterialTheme.typography.bodySmall)
                description?.text?.let { Text(it, maxLines = 2, overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurfaceVariant, style = MaterialTheme.typography.bodyMedium) }
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null)
        }
    }
}

@Composable
internal fun CalendarEventDialog(event: CalendarEvent, language: String, onDismiss: () -> Unit, onOpenReadings: () -> Unit) {
    val description = event.description(language)
    val locale = LocalConfiguration.current.locales[0]
    val uri = LocalUriHandler.current
    AlertDialog(onDismissRequest = onDismiss,
        title = { Text(event.title(language)) }, text = {
            Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(event.date.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)))
                Text(stringResource(R.string.calendar_event_details), style = MaterialTheme.typography.labelLarge)
                SelectionContainer {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(description?.text ?: stringResource(R.string.calendar_event_no_description))
                        description?.credit?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
                    }
                }
                description?.sourceURL?.let { source -> TextButton(onClick = { uri.openUri(source) }) { Text(stringResource(R.string.readings_source)) } }
            }
        }, confirmButton = { TextButton(onClick = onOpenReadings, modifier = Modifier.testTag("calendarEventReadings")) { Text(stringResource(R.string.calendar_event_readings)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.common_done)) } })
}
