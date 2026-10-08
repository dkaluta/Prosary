package com.dkaluta.prosary.ui.shared

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material3.Card
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.today.SaintDescription

/** The caller supplies only descriptions in the interface language for the Syriac calendar. */
@Composable
fun SaintDescriptionsCard(descriptions: List<SaintDescription>, dateKey: String, language: String,
                          inCard: Boolean = true, parentTitle: String? = null) {
    if (descriptions.isEmpty()) return
    var expanded by rememberSaveable(dateKey, language) { mutableStateOf(false) }
    val uriHandler = LocalUriHandler.current
    val expansionLabel = stringResource(if (expanded) R.string.readings_hide_text else R.string.readings_show_text)
    val content: @Composable () -> Unit = {
        Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            TextButton(onClick = { expanded = !expanded }, modifier = Modifier.fillMaxWidth()
                .testTag("saintDescriptionsToggle").semantics { stateDescription = expansionLabel }) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Text(stringResource(R.string.home_today_about_saints), modifier = Modifier.weight(1f))
                    Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, contentDescription = null)
                }
            }
            if (expanded) descriptions.forEachIndexed { index, saint ->
                if (index > 0) HorizontalDivider()
                SelectionContainer {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        if (saint.shouldShowTitle(beneath = parentTitle)) {
                            Text(saint.title, style = MaterialTheme.typography.titleSmall)
                        }
                        if (saint.sections.isEmpty()) DescriptionParagraphs(saint.text)
                        else saint.sections.forEach { section ->
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.fillMaxWidth().testTag("saintSection.${saint.identity}.${section.id}")) {
                                Text(section.title, style = MaterialTheme.typography.titleSmall,
                                    modifier = Modifier.semantics { heading() })
                                DescriptionParagraphs(section.text)
                            }
                        }
                        saint.credit?.let {
                            Text(it, style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                    }
                }
                saint.sourceURL?.let { url ->
                    TextButton(onClick = { uriHandler.openUri(url) }) { Text(stringResource(R.string.readings_source)) }
                }
            }
        }
    }
    if (inCard) Card(Modifier.fillMaxWidth().testTag("saintDescriptions")) { content() }
    else Column(Modifier.fillMaxWidth().testTag("saintDescriptions")) { content() }
}

@Composable
private fun DescriptionParagraphs(text: String) {
    text.split(Regex("\\n\\s*\\n")).forEach { paragraph ->
        Text(paragraph.trim(), style = MaterialTheme.typography.bodyMedium)
    }
}
