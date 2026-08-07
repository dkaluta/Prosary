package com.dkaluta.prosary.ui.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.compose.ui.Alignment
import com.dkaluta.prosary.ui.shared.installErrorMessage
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
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
    // Bumped after an install or a removal so the list below re-reads.
    var installedGeneration by remember { mutableIntStateOf(0) }
    val installedBundleIds = remember(installedGeneration) { PrayerPackStore.installedBundleIds() }
    var importError by remember { mutableStateOf<String?>(null) }

    var exportBundleId by remember { mutableStateOf<String?>(null) }
    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/zip"),
    ) { uri ->
        val id = exportBundleId
        exportBundleId = null
        if (uri != null && id != null) {
            PrayerPackStore.installedPackFile(id)?.let { file ->
                context.contentResolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { it.copyTo(out) }
                }
            }
        }
    }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        runCatching {
            val bytes = context.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                ?: throw PrayerPackStore.InstallException(
                    "This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            PrayerPackStore.installPack(bytes)
        }.onSuccess {
            importError = null
            installedGeneration++
            installedCount = PrayerPackStore.installedBundleIds().size
        }.onFailure { error ->
            importError = installErrorMessage(context, error)
        }
    }
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
                title = { Text(stringResource(R.string.common_settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = stringResource(R.string.common_back))
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
            // The stored code may name a rite ("he-x-gamliel"), so this row shows its base
            // language and the rite row below chooses among that language's uses. Choosing a
            // language keeps its rite when it has one, and drops it otherwise.
            val baseLanguageCode = LanguageCatalog.baseLanguage(defaultLanguageCode) ?: defaultLanguageCode
            OptionPickerField(
                label = stringResource(R.string.settings_default_prayer_language),
                options = LanguageCatalog.all,
                selected = LanguageCatalog.all.firstOrNull { it.code == baseLanguageCode }
                    ?: LanguageCatalog.resolve(defaultLanguageCode),
                optionLabel = { it.nativeName },
                onSelect = {
                    val code = LanguageCatalog.rites(it.code).firstOrNull()?.code ?: it.code
                    defaultLanguageCode = code
                    AppSettings.setDefaultLanguageCode(code)
                },
            )

            // Only for a language prayed in more than one use — everywhere else there is
            // nothing to choose, so nothing is shown.
            val rites = LanguageCatalog.rites(defaultLanguageCode)
            if (rites.size > 1) {
                OptionPickerField(
                    label = stringResource(R.string.settings_rite),
                    options = rites,
                    selected = rites.firstOrNull { it.code == defaultLanguageCode } ?: rites.first(),
                    optionLabel = { it.nativeName },
                    onSelect = {
                        defaultLanguageCode = it.code
                        AppSettings.setDefaultLanguageCode(it.code)
                    },
                )
            }

            SectionHeader(stringResource(R.string.settings_praying))

            // The same app-wide setting the flow toolbars offer — surfaced here so it's
            // discoverable outside a session.
            OptionPickerField(
                label = stringResource(R.string.settings_auto_advance),
                options = listOf(0, 3, 5, 10, 15),
                selected = autoAdvanceSeconds,
                optionLabel = { if (it == 0) context.getString(R.string.auto_advance_off) else context.getString(R.string.auto_advance_every, it) },
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
            ) { Text(stringResource(R.string.settings_reset_home_order)) }

            SectionHeader(stringResource(R.string.settings_downloads))

            Text(
                stringResource(R.string.settings_installed_devotions, installedCount),
                style = MaterialTheme.typography.bodyLarge,
            )

            // Importing, exporting and removing a devotion moved here when the Favorites screen
            // was retired: Downloads is where iOS/Mac keep them too. Round-trip to Compose
            // (Gamaliel item 7) is the export — SAF create-document, then copy the pack's bytes.
            OutlinedButton(
                onClick = { importLauncher.launch(arrayOf("*/*")) },
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.favorites_import)) }

            for (bundleId in installedBundleIds) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        PrayerPackStore.info(bundleId)?.localizedDisplayName ?: bundleId,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f),
                    )
                    IconButton(onClick = {
                        exportBundleId = bundleId
                        exportLauncher.launch("$bundleId.prosaryprayer")
                    }) {
                        Icon(
                            Icons.Filled.FileUpload,
                            contentDescription = stringResource(R.string.favorites_export),
                        )
                    }
                    IconButton(onClick = {
                        PrayerPackStore.removeInstalledPack(bundleId)
                        installedGeneration++
                        installedCount = PrayerPackStore.installedBundleIds().size
                    }) {
                        Icon(
                            Icons.Filled.Delete,
                            contentDescription = stringResource(R.string.favorites_remove_installed),
                        )
                    }
                }
            }

            if (importError != null) {
                Text(
                    importError.orEmpty(),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }

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
                        stringResource(R.string.settings_clear_audio_cache_size, Formatter.formatShortFileSize(context, audioCacheBytes))
                    } else {
                        stringResource(R.string.settings_clear_audio_cache)
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
            ) { Text(stringResource(R.string.settings_remove_all)) }

            Text(
                stringResource(R.string.settings_downloads_footer),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )

            SectionHeader(stringResource(R.string.settings_links))

            TextButton(onClick = { uriHandler.openUri("https://prayers.prosary.app") }) {
                Text(stringResource(R.string.settings_repository_site))
            }
            TextButton(onClick = { uriHandler.openUri("https://compose.prosary.app") }) {
                Text(stringResource(R.string.settings_compose_site))
            }
            TextButton(onClick = { uriHandler.openUri("https://prosary.app/privacy") }) {
                Text(stringResource(R.string.settings_privacy_policy))
            }
        }
    }

    if (confirmsRemoveAll) {
        AlertDialog(
            onDismissRequest = { confirmsRemoveAll = false },
            title = { Text(stringResource(R.string.settings_remove_all_title)) },
            text = { Text(stringResource(R.string.settings_remove_all_message)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        SettingsMaintenance.removeAllInstalledPacks()
                        installedCount = PrayerPackStore.installedBundleIds().size
                        confirmsRemoveAll = false
                    },
                ) { Text(stringResource(R.string.settings_remove_all_confirm), color = MaterialTheme.colorScheme.error) }
            },
            dismissButton = {
                TextButton(onClick = { confirmsRemoveAll = false }) { Text(stringResource(R.string.common_cancel)) }
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
