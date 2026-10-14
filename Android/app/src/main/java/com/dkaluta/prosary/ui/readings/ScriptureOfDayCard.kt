package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.content.today.ScriptureOfDay
import com.dkaluta.prosary.content.today.TodayDateSelection
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import java.time.LocalDate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** The day's sourced appointment, using the same edition and passage reader as Daily Readings. */
@Composable
internal fun ScriptureOfDayCard(date: LocalDate, language: String) {
    val context = LocalContext.current
    val calendar = TodayInfoStore.selectedCalendarId
    val citation = remember(date, calendar, AppSettings.easternPaschaStyle) {
        ScriptureOfDay.citation(TodayInfoStore.readings(TodayDateSelection.lookupDate(date)))
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
    var expanded by rememberSaveable(date.toEpochDay(), calendar, citation?.full) { mutableStateOf(false) }
    Column(Modifier.fillMaxWidth().padding(vertical = 8.dp).testTag("scriptureOfDay"), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(stringResource(R.string.scripture_of_the_day), style = MaterialTheme.typography.titleSmall)
        if (citation == null) Text(stringResource(R.string.home_widgets_no_readings), color = MaterialTheme.colorScheme.onSurfaceVariant)
        else ReadingCard(citation, language, editions.firstOrNull { it.id == editionId }, editionId, store,
            isTorah = false, expanded = expanded, onToggleExpanded = { expanded = !expanded })
    }
}
