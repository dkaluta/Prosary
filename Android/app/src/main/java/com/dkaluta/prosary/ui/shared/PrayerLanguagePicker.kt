package com.dkaluta.prosary.ui.shared

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Language
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.LanguageCatalog

/** The language menu shared by Basic Prayers, the Rosary and data-driven devotions. Keeping the
 * choices here keeps their app-setting sentinel consistent. Bundle flows expand sourced Hebrew
 * into the Vicariate and Mission uses; Basic Prayers offers the whole language catalog. */
@Composable
fun PrayerLanguagePicker(
    devotionId: String? = null,
    chosenLanguage: String,
    expanded: Boolean,
    onExpandedChange: (Boolean) -> Unit,
    onSelect: (String) -> Unit,
) {
    val options = if (devotionId == null) LanguageCatalog.all else {
        val bundleLanguages = PrayerPackStore.info(devotionId)?.languages.orEmpty()
        if (bundleLanguages.size <= 1 && "he" !in bundleLanguages) return
        LanguageCatalog.availableOptions(bundleLanguages)
    }

    IconButton(onClick = { onExpandedChange(true) }) {
        Icon(Icons.Filled.Language, contentDescription = stringResource(R.string.flow_prayer_language))
    }
    DropdownMenu(expanded = expanded, onDismissRequest = { onExpandedChange(false) }) {
        val choices = listOf(
            LanguageChoice(
                code = LanguageCatalog.defaultSentinel,
                label = stringResource(R.string.flow_app_setting),
            ),
        ) + options.map {
            LanguageChoice(code = it.code, label = it.nativeName)
        }
        for (choice in choices) {
            DropdownMenuItem(
                text = { Text(choice.label) },
                leadingIcon = if (chosenLanguage == choice.code) {
                    { Icon(Icons.Filled.Check, contentDescription = null) }
                } else {
                    null
                },
                onClick = {
                    onExpandedChange(false)
                    onSelect(choice.code)
                },
            )
        }
    }
}

private data class LanguageChoice(val code: String, val label: String)
