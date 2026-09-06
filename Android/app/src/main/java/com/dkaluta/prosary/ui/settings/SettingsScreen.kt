package com.dkaluta.prosary.ui.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import android.content.Context
import android.text.format.Formatter
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.FileUpload
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.platform.LocalConfiguration
import com.dkaluta.prosary.typography.SystemSansFontProbe
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.content.today.TodayInfoStore
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.HomeOrder
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.ui.home.OrderEditor
import com.dkaluta.prosary.ui.presets.OptionPickerField
import com.dkaluta.prosary.ui.shared.installErrorMessage
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
    var aramaicSignOfCrossForm by remember { mutableStateOf(AppSettings.aramaicSignOfCrossForm) }
    var autoAdvanceSeconds by remember { mutableIntStateOf(AppSettings.autoAdvanceSeconds) }
    var hapticsOnAdvance by remember { mutableStateOf(AppSettings.hapticsOnAdvance) }
    val typographyConfiguration = LocalConfiguration.current
    val systemSansMatches = remember(typographyConfiguration) {
        SystemSansFontProbe.SampleScript.entries.associateWith { SystemSansFontProbe.usesBundledSans(it) }
    }
    val syriacTypeface = AppSettings.syriacTypeface
    val hebrewPrayerTypeface = AppSettings.hebrewPrayerTypeface
    val hebrewScriptureTypeface = AppSettings.hebrewScriptureTypeface
    var showTodayFeast by remember { mutableStateOf(AppSettings.showTodayFeast) }
    var showTodayIntention by remember { mutableStateOf(AppSettings.showTodayIntention) }
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
            val bytes = context.contentResolver.openInputStream(uri)?.use {
                PrayerPackStore.readInstallBytes(it)
            }
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
    var showsLanguageFallbackOrder by remember { mutableStateOf(false) }
    var languageFallbackOrder by remember { mutableStateOf(LanguageCatalog.fallbackOrder) }

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
            OptionPickerField(
                label = stringResource(R.string.settings_default_prayer_language),
                options = LanguageCatalog.publicOptions,
                selected = LanguageCatalog.publicOptions.firstOrNull { it.code == LanguageCatalog.pickerLanguageCode(defaultLanguageCode) }
                    ?: LanguageCatalog.resolve(defaultLanguageCode),
                optionLabel = { it.nativeName },
                onSelect = {
                    defaultLanguageCode = LanguageCatalog.selectingLanguage(it.code, defaultLanguageCode)
                    AppSettings.setDefaultLanguageCode(defaultLanguageCode)
                },
            )

            if (LanguageCatalog.pickerLanguageCode(defaultLanguageCode) == "he") {
                OptionPickerField(
                    label = stringResource(R.string.prayer_tradition),
                    options = listOf("he", "he-x-gamliel"),
                    selected = defaultLanguageCode,
                    optionLabel = { context.getString(if (it == "he") R.string.prayer_tradition_vicariate else R.string.prayer_tradition_mission) },
                    onSelect = { defaultLanguageCode = it; AppSettings.setDefaultLanguageCode(it) },
                )
            }

            OutlinedButton(
                onClick = {
                    languageFallbackOrder = LanguageCatalog.fallbackOrder
                    showsLanguageFallbackOrder = true
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.settings_language_fallback_order)) }

            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.settings_prayer_names_in_prayer_language))
                    Text(stringResource(R.string.settings_prayer_names_in_prayer_language_hint), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = AppSettings.showPrayerNameInPrayerLanguage, onCheckedChange = { AppSettings.showPrayerNameInPrayerLanguage = it })
            }

            if ((LanguageCatalog.baseLanguage(defaultLanguageCode) ?: defaultLanguageCode) == "arc") {
                OptionPickerField(
                    label = stringResource(R.string.settings_aramaic_sign_of_cross),
                    options = listOf(
                        AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_A,
                        AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B,
                    ),
                    selected = aramaicSignOfCrossForm,
                    optionLabel = {
                        context.getString(
                            if (it == AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B) {
                                R.string.settings_aramaic_sign_of_cross_form_b
                            } else {
                                R.string.settings_aramaic_sign_of_cross_form_a
                            },
                        )
                    },
                    onSelect = {
                        aramaicSignOfCrossForm = it
                        AppSettings.setAramaicSignOfCrossForm(it)
                    },
                    modifier = Modifier.fillMaxWidth(),
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

            // Erez's ask: a felt confirmation that the step turned. Off by default.
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_haptics_on_advance),
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = hapticsOnAdvance,
                    onCheckedChange = {
                        hapticsOnAdvance = it
                        AppSettings.setHapticsOnAdvance(it)
                    },
                )
            }

            OutlinedButton(
                onClick = {
                    HomeOrder.reset(context)
                    homeOrderIsCustom = false
                },
                enabled = homeOrderIsCustom,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(stringResource(R.string.settings_reset_home_order)) }

            SectionHeader(stringResource(R.string.settings_typography_header))

            OptionPickerField(
                label = stringResource(R.string.settings_aramaic_default_script),
                options = listOf("Hebr", "Syrc"),
                selected = AppSettings.aramaicDefaultScript,
                optionLabel = { context.getString(if (it == "Syrc") R.string.settings_script_syriac else R.string.settings_script_hebrew) },
                onSelect = { AppSettings.setAramaicDefaultScript(it) },
            )

            OptionPickerField(
                label = stringResource(R.string.settings_syriac_typeface),
                options = listOf(AppSettings.TYPEFACE_DEFAULT, AppSettings.TYPEFACE_WESTERN, AppSettings.TYPEFACE_EASTERN),
                selected = syriacTypeface,
                optionLabel = {
                    context.getString(when (it) {
                        AppSettings.TYPEFACE_WESTERN -> R.string.settings_typeface_western_aramaic
                        AppSettings.TYPEFACE_EASTERN -> R.string.settings_typeface_eastern_aramaic
                        else -> R.string.settings_typeface_default
                    })
                },
                onSelect = { AppSettings.setSyriacTypeface(it) },
            )

            OptionPickerField(
                label = stringResource(R.string.settings_hebrew_prayer_typeface),
                options = buildList {
                    add(AppSettings.TYPEFACE_DEFAULT)
                    add(AppSettings.TYPEFACE_DAVID_LIBRE)
                    if (SystemSansFontProbe.shouldOfferBundledFont(systemSansMatches[SystemSansFontProbe.SampleScript.HEBREW], hebrewPrayerTypeface == AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)) add(AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)
                    add(AppSettings.TYPEFACE_SANS_SERIF)
                },
                selected = hebrewPrayerTypeface,
                optionLabel = {
                    context.getString(when (it) {
                        AppSettings.TYPEFACE_DAVID_LIBRE -> R.string.settings_typeface_david_libre
                        AppSettings.TYPEFACE_SANS_SERIF -> R.string.settings_typeface_sans_serif
                        AppSettings.TYPEFACE_BUNDLED_SANS_SERIF -> R.string.settings_typeface_roboto_noto
                        else -> R.string.settings_typeface_frank_ruhl_libre
                    })
                },
                onSelect = { AppSettings.setHebrewPrayerTypeface(it) },
            )

            OptionPickerField(
                label = stringResource(R.string.settings_hebrew_scripture_typeface),
                options = listOf(AppSettings.TYPEFACE_DEFAULT, AppSettings.TYPEFACE_STAM_ASHKENAZ, AppSettings.TYPEFACE_STAM_SEFARAD, AppSettings.TYPEFACE_RASHI),
                selected = hebrewScriptureTypeface,
                optionLabel = {
                    context.getString(when (it) {
                        AppSettings.TYPEFACE_STAM_ASHKENAZ -> R.string.settings_typeface_stam_ashkenaz
                        AppSettings.TYPEFACE_STAM_SEFARAD -> R.string.settings_typeface_stam_sefarad
                        AppSettings.TYPEFACE_RASHI -> R.string.settings_typeface_rashi
                        else -> R.string.settings_typeface_default
                    })
                },
                onSelect = { AppSettings.setHebrewScriptureTypeface(it) },
            )

            OptionPickerField(
                label = stringResource(R.string.settings_latin_prayer_typeface),
                options = buildList {
                    add(AppSettings.TYPEFACE_DEFAULT)
                    if (SystemSansFontProbe.shouldOfferBundledFont(systemSansMatches[SystemSansFontProbe.SampleScript.LATIN], AppSettings.latinPrayerTypeface == AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)) add(AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)
                    add(AppSettings.TYPEFACE_SANS_SERIF)
                },
                selected = AppSettings.latinPrayerTypeface,
                optionLabel = { context.getString(when (it) {
                    AppSettings.TYPEFACE_SANS_SERIF -> R.string.settings_typeface_sans_serif
                    AppSettings.TYPEFACE_BUNDLED_SANS_SERIF -> R.string.settings_typeface_roboto
                    else -> R.string.settings_typeface_serif
                }) },
                onSelect = { AppSettings.setLatinPrayerTypeface(it) },
            )

            OptionPickerField(
                label = stringResource(R.string.settings_cyrillic_prayer_typeface),
                options = buildList {
                    add(AppSettings.TYPEFACE_DEFAULT)
                    if (SystemSansFontProbe.shouldOfferBundledFont(systemSansMatches[SystemSansFontProbe.SampleScript.CYRILLIC], AppSettings.cyrillicPrayerTypeface == AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)) add(AppSettings.TYPEFACE_BUNDLED_SANS_SERIF)
                    add(AppSettings.TYPEFACE_SANS_SERIF)
                },
                selected = AppSettings.cyrillicPrayerTypeface,
                optionLabel = { context.getString(when (it) {
                    AppSettings.TYPEFACE_SANS_SERIF -> R.string.settings_typeface_sans_serif
                    AppSettings.TYPEFACE_BUNDLED_SANS_SERIF -> R.string.settings_typeface_roboto
                    else -> R.string.settings_typeface_serif
                }) },
                onSelect = { AppSettings.setCyrillicPrayerTypeface(it) },
            )

            // The Home "Today" section (Erez's requests): which of its rows show at all, and
            // which calendar's feasts the feast row prays. The calendar choices come from the
            // bundled calendars.json registry, so adding a calendar is a data drop, never a
            // new case here; the picker hides entirely if the registry ever ships a single
            // calendar. Reads through the store so an unset/unknown stored id shows as the
            // registry default.
            SectionHeader(stringResource(R.string.settings_today_header))

            Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(stringResource(R.string.settings_show_today_torah))
                    Text(stringResource(R.string.settings_show_today_torah_hint), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = AppSettings.showTodayTorahPortion, onCheckedChange = { AppSettings.showTodayTorahPortion = it })
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_show_today_feast),
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = showTodayFeast,
                    onCheckedChange = {
                        showTodayFeast = it
                        AppSettings.showTodayFeast = it
                    },
                )
            }
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_show_today_intention),
                    modifier = Modifier.weight(1f),
                )
                Switch(
                    checked = showTodayIntention,
                    onCheckedChange = {
                        showTodayIntention = it
                        AppSettings.showTodayIntention = it
                    },
                )
            }

            val feastCalendars = TodayInfoStore.calendars
            if (feastCalendars.size > 1) {
                var feastCalendarId by remember { mutableStateOf(TodayInfoStore.selectedCalendarId) }
                OptionPickerField(
                    label = stringResource(R.string.settings_feast_calendar),
                    options = feastCalendars,
                    selected = feastCalendars.firstOrNull { it.id == feastCalendarId }
                        ?: feastCalendars.first(),
                    optionLabel = { it.displayName },
                    onSelect = {
                        feastCalendarId = it.id
                        AppSettings.feastCalendarId = it.id
                    },
                )
                if (feastCalendarId == "ugcc") {
                    OptionPickerField(
                        label = stringResource(R.string.settings_eastern_pascha),
                        options = listOf("julian", "gregorian"),
                        selected = AppSettings.easternPaschaStyle,
                        optionLabel = { context.getString(if (it == "gregorian") R.string.settings_pascha_gregorian else R.string.settings_pascha_julian) },
                        onSelect = { AppSettings.easternPaschaStyle = it },
                    )
                }
                Text(
                    stringResource(R.string.settings_feast_calendar_hint),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

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

    if (showsLanguageFallbackOrder) {
        OrderEditor(
            titles = languageFallbackOrder.map { code ->
                code to if (code == "he-x-gamliel") context.getString(R.string.prayer_tradition_mission)
                else (LanguageCatalog.all.firstOrNull { it.code == code }?.nativeName ?: code)
            },
            dialogTitle = stringResource(R.string.settings_language_fallback_order_title),
            footer = stringResource(R.string.settings_language_fallback_order_footer),
            onMove = { order ->
                languageFallbackOrder = order
                AppSettings.setLanguageFallbackOrder(order)
            },
            onReset = {
                AppSettings.setLanguageFallbackOrder(emptyList())
                languageFallbackOrder = LanguageCatalog.fallbackOrder
            },
            onDismiss = { showsLanguageFallbackOrder = false },
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
