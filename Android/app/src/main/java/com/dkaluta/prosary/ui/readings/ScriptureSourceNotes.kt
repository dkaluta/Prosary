package com.dkaluta.prosary.ui.readings

import android.view.View
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.selection.DisableSelection
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.collapse
import androidx.compose.ui.semantics.expand
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.ReadingSourceNote
import java.text.NumberFormat

/** Shared by daily passages and downloaded chapters. Editorial text is excluded from copying. */
@Composable
fun ScriptureSourceNotes(notes: List<ReadingSourceNote>?) {
    if (notes.isNullOrEmpty()) return
    var expanded by remember(notes) { mutableStateOf(false) }
    val configuration = LocalConfiguration.current
    val direction = if (configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL) LayoutDirection.Rtl else LayoutDirection.Ltr
    val formatter = remember(configuration.locales[0]) { NumberFormat.getIntegerInstance(configuration.locales[0]) }
    val uriHandler = LocalUriHandler.current
    DisableSelection {
        CompositionLocalProvider(LocalLayoutDirection provides direction) {
            Column(Modifier.fillMaxWidth()) {
                TextButton(onClick = { expanded = !expanded }, modifier = Modifier.testTag("scriptureSourceNote.${notes.first().id}")
                    .semantics {
                        if (expanded) collapse { expanded = false; true } else expand { expanded = true; true }
                    }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.scripture_source_note))
                        Icon(if (expanded) Icons.Default.ExpandLess else Icons.Default.ExpandMore, contentDescription = null)
                    }
                }
                if (expanded) Surface(color = MaterialTheme.colorScheme.surfaceContainer,
                    shape = MaterialTheme.shapes.medium, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        for (note in notes) Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                            CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
                                Text(note.anchor, modifier = Modifier.fillMaxWidth(), style = MaterialTheme.typography.bodyLarge)
                            }
                            if (note.kind == "restoredLetter") {
                                Text(stringResource(R.string.scripture_source_note_restored_letter,
                                    "\u2067${note.letter}\u2069", note.letterIndex, "\u2067${note.anchor}\u2069"),
                                    style = MaterialTheme.typography.bodyMedium)
                            } else {
                                Text(stringResource(R.string.scripture_source_note_letter, "\u2067${note.letter}\u2069", note.letterIndex),
                                    style = MaterialTheme.typography.bodyMedium)
                                Text(stringResource(if (note.mark == "vowel" || note.mark == "shuruq") R.string.scripture_source_note_vowel else R.string.scripture_source_note_dagesh),
                                    style = MaterialTheme.typography.bodyMedium)
                            }
                            Text(stringResource(R.string.scripture_source_note_pages, note.sourcePages.joinToString(", ") { formatter.format(it) }),
                                style = MaterialTheme.typography.bodySmall)
                            TextButton(onClick = { uriHandler.openUri(note.sourceURL) }) {
                                Text(stringResource(R.string.scripture_source_note_scan))
                            }
                        }
                    }
                }
            }
        }
    }
}
