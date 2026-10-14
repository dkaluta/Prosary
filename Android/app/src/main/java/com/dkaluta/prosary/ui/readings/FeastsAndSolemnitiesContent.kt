package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.CalendarEvent
import com.dkaluta.prosary.content.today.CalendarEvents
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FeastsAndSolemnitiesContent(browsingDate: TodayBrowsingDate, onSelectDate: () -> Unit) {
    Column {
        SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).testTag("calendar.viewMode")) {
            listOf("list" to R.string.calendar_list_view, "month" to R.string.calendar_month_view).forEachIndexed { index, (id, label) ->
                SegmentedButton(selected = AppSettings.calendarViewMode == id,
                    onClick = { AppSettings.calendarViewMode = id },
                    shape = SegmentedButtonDefaults.itemShape(index, 2)) {
                    Text(stringResource(label))
                }
            }
        }
        Box(Modifier.weight(1f)) {
            if (AppSettings.calendarViewMode == "month") LiturgicalCalendarContent(browsingDate, onSelectDate)
            else FeastList(browsingDate, onSelectDate)
        }
    }
}

@Composable
private fun FeastList(browsingDate: TodayBrowsingDate, onSelectDate: () -> Unit) {
    val context = LocalContext.current
    val locale = LocalConfiguration.current.locales[0]
    val language = TodayTranslationLanguage.resolve(locale.toLanguageTag())
    val date = browsingDate.selectedDate(LocalDate.now())
    val calendarId = TodayInfoStore.selectedCalendarId
    val rows = remember(calendarId, AppSettings.easternPaschaStyle) {
        TodayInfoStore.allCalendarDates().flatMap { (day, feast) -> CalendarEvents.events(day, feast) }
    }
    val firstUpcoming = rows.indexOfFirst { it.date >= date }.takeIf { it >= 0 } ?: rows.lastIndex.coerceAtLeast(0)
    var selectedEvent by remember(calendarId) { mutableStateOf<CalendarEvent?>(null) }
    val state = rememberLazyListState(initialFirstVisibleItemIndex = if (rows.isEmpty()) 0 else firstUpcoming + 1)
    LaunchedEffect(calendarId, AppSettings.easternPaschaStyle) {
        if (rows.isNotEmpty()) state.scrollToItem(firstUpcoming + 1)
    }
    LazyColumn(state = state, modifier = Modifier.testTag("feastsAndSolemnities")) {
        item {
            TextButton(onClick = {
                browsingDate.selectedEpochDay = null
                onSelectDate()
            }, Modifier.padding(horizontal = 16.dp)) {
                Text(stringResource(R.string.home_today_reset))
            }
            Text(TodayInfoStore.calendars.firstOrNull { it.id == TodayInfoStore.selectedCalendarId }?.displayName ?: "",
                Modifier.padding(horizontal = 24.dp, vertical = 8.dp), style = MaterialTheme.typography.labelMedium)
        }
        if (rows.isEmpty()) item {
            Text(stringResource(R.string.calendar_no_feasts), Modifier.padding(24.dp))
        }
        items(rows, key = { it.id }) { event ->
            Column(Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp).testTag("calendarFeast.${event.date}"), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(event.date.format(DateTimeFormatter.ofPattern("EEE d MMM yyyy", locale)),
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                CalendarEventRow(event, language) { selectedEvent = event }
            }
            HorizontalDivider(Modifier.padding(horizontal = 24.dp))
        }
    }
    selectedEvent?.let { event -> CalendarEventDialog(event, language, onDismiss = { selectedEvent = null }, onOpenReadings = {
        browsingDate.selectedEpochDay = event.date.toEpochDay(); selectedEvent = null; onSelectDate()
    }) }
}
