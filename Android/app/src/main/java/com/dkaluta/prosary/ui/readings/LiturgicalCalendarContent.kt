package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.content.today.TodayTranslationLanguage
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.ui.shared.TodayBrowsingDate
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun LiturgicalCalendarContent(browsingDate: TodayBrowsingDate, onSelectDate: () -> Unit) {
    val context = LocalContext.current
    val locale = LocalConfiguration.current.locales[0]
    val language = TodayTranslationLanguage.resolve(locale.toLanguageTag())
    val date = browsingDate.selectedDate(LocalDate.now())
    val start = date.withDayOfMonth(1)
    val rows = remember(start, TodayInfoStore.selectedCalendarId, AppSettings.easternPaschaStyle) {
        (1..start.lengthOfMonth()).mapNotNull { number ->
            val day = start.withDayOfMonth(number)
            TodayInfoStore.feast(TodayDateSelection.lookupDate(day, ZoneId.systemDefault()))?.let { day to it }
        }
    }
    LazyColumn {
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) {
                IconButton(onClick = { browsingDate.selectedEpochDay = start.minusMonths(1).toEpochDay() },
                    enabled = start > TodayDateSelection.earliest.withDayOfMonth(1)) {
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, stringResource(R.string.calendar_previous_month))
                }
                Text(date.format(DateTimeFormatter.ofPattern("LLLL yyyy", locale)),
                    Modifier.padding(top = 12.dp), style = MaterialTheme.typography.titleMedium)
                IconButton(onClick = { browsingDate.selectedEpochDay = start.plusMonths(1).toEpochDay() },
                    enabled = start < TodayDateSelection.latest.withDayOfMonth(1)) {
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, stringResource(R.string.calendar_next_month))
                }
            }
            TextButton(onClick = { browsingDate.selectedEpochDay = null }, Modifier.padding(horizontal = 16.dp)) {
                Text(stringResource(R.string.home_today_reset))
            }
            Text(TodayInfoStore.calendars.firstOrNull { it.id == TodayInfoStore.selectedCalendarId }?.displayName ?: "",
                Modifier.padding(horizontal = 24.dp, vertical = 8.dp), style = MaterialTheme.typography.labelMedium)
        }
        if (rows.isEmpty()) item {
            Text(stringResource(R.string.calendar_no_observances), Modifier.padding(24.dp))
        }
        items(rows, key = { it.first.toEpochDay() }) { (day, feast) ->
            Column(Modifier.fillMaxWidth().clickable {
                browsingDate.selectedEpochDay = day.toEpochDay()
                onSelectDate()
            }.padding(horizontal = 24.dp, vertical = 16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(day.format(DateTimeFormatter.ofPattern("EEE d", locale)),
                    style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(feast.localizedTitle(language), style = MaterialTheme.typography.titleMedium)
                Text(feast.localizedRank(language, context), style = MaterialTheme.typography.bodySmall)
            }
            HorizontalDivider(Modifier.padding(horizontal = 24.dp))
        }
    }
}
