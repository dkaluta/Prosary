package com.dkaluta.prosary.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.lifecycleScope
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.ui.theme.ProsaryTheme
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Launcher-owned selection, also offered by the launcher's Edit widget action. */
class SavedPrayerWidgetConfigurationActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID ||
            AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider != ComponentName(this, SavedPrayerWidgetProvider::class.java)) {
            finish()
            return
        }
        AppSettings.init(this)
        enableEdgeToEdge()
        setContent {
            var prayers by remember { mutableStateOf<List<Prayer>?>(null) }
            var failed by remember { mutableStateOf(false) }
            var selecting by remember { mutableStateOf(false) }
            LaunchedEffect(Unit) {
                runCatching { withContext(Dispatchers.IO) { AppServices.create(applicationContext).presetStore.all() } }
                    .onSuccess { prayers = it }
                    .onFailure { failed = true }
            }
            ProsaryTheme {
                Scaffold { insets ->
                    Column(Modifier.fillMaxSize().padding(insets).padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(stringResource(R.string.widget_choose_prayer), style = MaterialTheme.typography.headlineSmall)
                        Text(stringResource(R.string.widget_saved_description), style = MaterialTheme.typography.bodyMedium)
                        when {
                            failed -> Text(stringResource(R.string.widget_load_failed))
                            prayers == null || selecting -> CircularProgressIndicator()
                            prayers!!.isEmpty() -> Text(stringResource(R.string.widget_saved_empty))
                            else -> LazyColumn(Modifier.weight(1f)) {
                                items(prayers!!, key = { it.id }) { prayer ->
                                    ListItem(headlineContent = { Text(prayer.name) },
                                        supportingContent = { Text(prayer.languageDisplayName(this@SavedPrayerWidgetConfigurationActivity)) },
                                        modifier = Modifier.fillMaxWidth().clickable(enabled = !selecting) {
                                            selecting = true
                                            lifecycleScope.launch {
                                                runCatching {
                                                    withContext(Dispatchers.IO) {
                                                        SavedPrayerWidgetStore.select(applicationContext, widgetId, prayer.id)
                                                        WidgetUpdates.updateAll(applicationContext)
                                                    }
                                                }.onSuccess {
                                                    setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                                                    finish()
                                                }.onFailure { failed = true; selecting = false }
                                            }
                                        })
                                }
                            }
                        }
                        TextButton(onClick = { finish() }) { Text(stringResource(R.string.common_cancel)) }
                    }
                }
            }
        }
    }
}
