package com.dkaluta.prosary.ui.readings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.bible.BibleLibrary
import com.dkaluta.prosary.content.today.ReadingEdition
import com.dkaluta.prosary.content.today.ReadingTextStore
import com.dkaluta.prosary.content.today.TorahPortion
import com.dkaluta.prosary.models.AppSettings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Home uses the appointed Sabbath readings and the same lazy passage owner as Readings. */
@Composable
internal fun TorahPortionCard(portion: TorahPortion?, language: String) {
    val context = LocalContext.current
    val store = remember(context.applicationContext) {
        ReadingTextStore(bibleStore = BibleLibrary.get(context.applicationContext).store) { name ->
            context.applicationContext.assets.open("data/$name.json")
        }
    }
    val editions by produceState<List<ReadingEdition>>(emptyList(), store) {
        value = withContext(Dispatchers.IO) { store.editions }
    }
    val editionId = ReadingTextStore.effectiveEditionId(AppSettings.readingsEditionId, language, editions)
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (portion == null) Text(stringResource(R.string.home_widgets_no_torah), color = MaterialTheme.colorScheme.onSurfaceVariant)
        else {
            Text(portion.localizedTitle(language), style = MaterialTheme.typography.titleSmall)
            portion.allReadings.forEachIndexed { index, citation ->
                key(portion.saturday, index, citation.full) {
                    var expanded by rememberSaveable(portion.saturday, index, citation.full) {
                        mutableStateOf(AppSettings.expandReadingsByDefault)
                    }
                    ReadingCard(citation, language, editions.firstOrNull { it.id == editionId }, editionId,
                        store, isTorah = true, expanded = expanded, onToggleExpanded = { expanded = !expanded })
                }
            }
        }
    }
}
