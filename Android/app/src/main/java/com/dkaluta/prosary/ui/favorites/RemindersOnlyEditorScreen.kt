package com.dkaluta.prosary.ui.favorites

import android.Manifest
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
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
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.LocalAppServices
import kotlinx.coroutines.launch

/** Lightweight reminders editor for the 5 non-configurable devotion kinds (Angelus, Stations of
 * the Cross, Franciscan Crown, Seven Sorrows, Divine Mercy Chaplet) — these have no name,
 * language, or per-favorite options to edit (see FavoritesListScreen), just reminders. Reachable
 * from the star row's bell button, and only once the kind is favorited (a Prayer row must
 * already exist to attach reminders to — this screen never creates one). Mirrors iOS's
 * RemindersOnlyEditorView. */
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
                title = { Text(current.kind.displayName) },
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
            RemindersSection(reminders = current.reminders, kind = current.kind) { prayer = current.copy(reminders = it) }
        }
    }
}
