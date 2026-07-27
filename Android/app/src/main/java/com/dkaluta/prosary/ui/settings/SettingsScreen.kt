package com.dkaluta.prosary.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.ui.presets.OptionPickerField

/** App-wide preferences — currently just the default prayer language, used whenever a favorite's
 * own language is left at "Default" (see [LanguageCatalog.defaultSentinel]). Android's equivalent
 * of iOS's Settings.bundle-based system Settings entry, since Android has no such external
 * settings surface to extend. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    var defaultLanguageCode by remember { mutableStateOf(AppSettings.defaultLanguageCode) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                },
            )
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.fillMaxSize().padding(padding).padding(16.dp),
        ) {
            OptionPickerField(
                label = "Default Prayer Language",
                options = LanguageCatalog.all,
                selected = LanguageCatalog.resolve(defaultLanguageCode),
                optionLabel = { it.nativeName },
                onSelect = {
                    defaultLanguageCode = it.code
                    AppSettings.setDefaultLanguageCode(it.code)
                },
            )
        }
    }
}
