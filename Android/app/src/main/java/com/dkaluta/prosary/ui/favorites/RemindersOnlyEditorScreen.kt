package com.dkaluta.prosary.ui.favorites

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.dkaluta.prosary.content.prayerpack.CustomDevotionOption
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.ui.presets.OptionPickerField
import com.dkaluta.prosary.services.LocalAppServices
import kotlinx.coroutines.launch

/** The editor for the generic (bundle-driven) devotions — these have no name or language to
 * edit (see FavoritesListScreen), just the bundle's own `options.json` options (schema-driven
 * toggle/choice rows, e.g. the Franciscan Crown's optional closing devotions) and reminders.
 * Reachable from the star row's bell button, and only once the devotion is favorited (a Prayer
 * row must already exist to attach settings to — this screen never creates one). Preset
 * quick-toggle hours and their footer come from the devotion's bundle manifest (the Angelus's
 * bell times). Mirrors iOS's RemindersOnlyEditorView. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RemindersOnlyEditorScreen(prayerId: String, onDone: () -> Unit) {
    val services = LocalAppServices.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var prayer by remember { mutableStateOf<Prayer?>(null) }
    var originalPrayer by remember { mutableStateOf<Prayer?>(null) }

    val notificationPermissionLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

    LaunchedEffect(prayerId) {
        val loaded = runCatching { services.presetStore.get(prayerId) }.getOrNull()
        prayer = loaded
        originalPrayer = loaded
    }

    val current = prayer ?: return

    // For .Custom, current.kind.displayName is only a generic fallback (a single PrayerKind
    // case can't carry per-bundle text) — read the real name and reminder presets from the
    // bundle's own manifest.
    val info = if (current.kind == PrayerKind.Custom) {
        current.customDevotionId?.let { PrayerPackStore.info(it) }
    } else {
        null
    }
    val titleText = info?.localizedDisplayName ?: current.kind.displayName

    fun save() {
        val toSave = current
        scope.launch {
            val needsPermission = toSave.reminders.any { it.isEnabled } &&
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                !ReminderScheduler.hasNotificationPermission(context)
            if (needsPermission) {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            services.presetStore.save(toSave)
            originalPrayer?.let { ReminderScheduler.cancelAll(context, it) }
            ReminderScheduler.schedule(context, toSave)
            onDone()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(titleText) },
                navigationIcon = { TextButton(onClick = onDone) { Text("Cancel") } },
                actions = { TextButton(onClick = { save() }) { Text("Save") } },
            )
        },
    ) { padding ->
        Column(
            verticalArrangement = Arrangement.spacedBy(20.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            val options = current.customDevotionId?.let { PrayerPackStore.options(it) }.orEmpty()
            if (options.isNotEmpty()) {
                FormSection(title = "Options") {
                    for (option in options) {
                        // Rows read through to the option's declared default so they show the
                        // effective value even before the user has ever touched them; changes
                        // store an explicit override.
                        val value = current.customOptions[option.key] ?: option.defaultValue
                        fun set(newValue: String) {
                            prayer = current.copy(customOptions = current.customOptions + (option.key to newValue))
                        }
                        when (option.kind) {
                            CustomDevotionOption.Kind.Toggle ->
                                SwitchRow(option.localizedName, value == "true") {
                                    set(if (it) "true" else "false")
                                }
                            CustomDevotionOption.Kind.Choice ->
                                OptionPickerField(
                                    label = option.localizedName,
                                    options = option.cases.orEmpty().map { it.id },
                                    selected = value,
                                    optionLabel = { id ->
                                        option.cases.orEmpty().firstOrNull { it.id == id }?.localizedName ?: id
                                    },
                                    onSelect = { set(it) },
                                    modifier = Modifier.fillMaxWidth(),
                                )
                        }
                    }
                }
            }
            RemindersSection(
                reminders = current.reminders,
                presetHours = info?.reminderPresetHours.orEmpty(),
                presetFooter = info?.localizedReminderPresetFooter,
            ) { prayer = current.copy(reminders = it) }
        }
    }
}
