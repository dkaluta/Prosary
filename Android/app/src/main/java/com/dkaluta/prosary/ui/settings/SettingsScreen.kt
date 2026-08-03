package com.dkaluta.prosary.ui.settings

import android.content.Context
import android.text.format.Formatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.HomeOrder
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.ui.presets.OptionPickerField
import java.io.File

/** App-wide preferences (v0.7: populated beyond the single language picker — auto-advance,
 * Home order reset, and downloads management, mirroring iOS's SettingsView). Android's
 * equivalent of iOS's in-app Settings sheet, since Android has no external settings surface
 * to extend. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(onBack: () -> Unit) {
    val context = LocalContext.current
    val uriHandler = LocalUriHandler.current

    var defaultLanguageCode by remember { mutableStateOf(AppSettings.defaultLanguageCode) }
    var autoAdvanceSeconds by remember { mutableIntStateOf(AppSettings.autoAdvanceSeconds) }
    var homeOrderIsCustom by remember { mutableStateOf(HomeOrder.saved(context).isNotEmpty()) }
    var installedCount by remember { mutableIntStateOf(PrayerPackStore.installedBundleIds().size) }
    var audioCacheBytes by remember { mutableLongStateOf(SettingsMaintenance.audioCacheSize(context)) }
    var confirmsRemoveAll by remember { mutableStateOf(false) }

    // Tints the pinned bar once content scrolls beneath it — without this the bar is
    // invisible and scrolled content clips at a dead band around the floating title.
    val topBarScroll = TopAppBarDefaults.pinnedScrollBehavior()

    Scaffold(
        modifier = Modifier.nestedScroll(topBarScroll.nestedScrollConnection),
        topBar = {
            TopAppBar(
                scrollBehavior = topBarScroll,
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
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
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

            SectionHeader("Praying")

            // The same app-wide setting the flow toolbars offer — surfaced here so it's
            // discoverable outside a session.
            OptionPickerField(
                label = "Auto-advance",
                options = listOf(0, 3, 5, 10),
                selected = autoAdvanceSeconds,
                optionLabel = { if (it == 0) "Off" else "Every $it seconds" },
                onSelect = {
                    autoAdvanceSeconds = it
                    AppSettings.setAutoAdvanceSeconds(it)
                },
            )

            OutlinedButton(
                onClick = {
                    HomeOrder.reset(context)
                    homeOrderIsCustom = false
                },
                enabled = homeOrderIsCustom,
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Reset Home Order") }

            SectionHeader("Downloads")

            Text(
                "Installed devotions: $installedCount",
                style = MaterialTheme.typography.bodyLarge,
            )

            OutlinedButton(
                onClick = {
                    SettingsMaintenance.clearAudioCache(context)
                    audioCacheBytes = SettingsMaintenance.audioCacheSize(context)
                },
                enabled = audioCacheBytes > 0L,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(
                    if (audioCacheBytes > 0L) {
                        "Clear Audio Cache (${Formatter.formatShortFileSize(context, audioCacheBytes)})"
                    } else {
                        "Clear Audio Cache"
                    },
                )
            }

            OutlinedButton(
                onClick = { confirmsRemoveAll = true },
                enabled = installedCount > 0,
                colors = androidx.compose.material3.ButtonDefaults.outlinedButtonColors(
                    contentColor = MaterialTheme.colorScheme.error,
                ),
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Remove All Downloaded Devotions…") }

            Text(
                "Built-in devotions are never removed. Removing a downloaded devotion also removes its favorite.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            SectionHeader("Links")

            TextButton(onClick = { uriHandler.openUri("https://prayers.prosary.app") }) {
                Text("Community repository")
            }
            TextButton(onClick = { uriHandler.openUri("https://compose.prosary.app") }) {
                Text("Compose a devotion")
            }
            TextButton(onClick = { uriHandler.openUri("https://prosary.app/privacy") }) {
                Text("Privacy policy")
            }
        }
    }

    if (confirmsRemoveAll) {
        AlertDialog(
            onDismissRequest = { confirmsRemoveAll = false },
            title = { Text("Remove all downloaded devotions?") },
            text = { Text("Devotions from the repository can be downloaded again; hand-imported files cannot.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        SettingsMaintenance.removeAllInstalledPacks()
                        installedCount = PrayerPackStore.installedBundleIds().size
                        confirmsRemoveAll = false
                    },
                ) { Text("Remove All", color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { confirmsRemoveAll = false }) { Text("Cancel") }
            },
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 8.dp),
    )
}

/** The downloads-management actions Settings exposes (v0.7) — mirrors iOS's SettingsMaintenance. */
object SettingsMaintenance {
    fun removeAllInstalledPacks() {
        for (bundleId in PrayerPackStore.installedBundleIds()) {
            PrayerPackStore.removeInstalledPack(bundleId)
        }
    }

    private fun audioCacheRoot(context: Context) = File(context.cacheDir, "PrayerAudio")

    fun audioCacheSize(context: Context): Long {
        val root = audioCacheRoot(context)
        if (!root.exists()) return 0L
        return root.walkTopDown().filter { it.isFile }.sumOf { it.length() }
    }

    fun clearAudioCache(context: Context) {
        audioCacheRoot(context).deleteRecursively()
    }
}
