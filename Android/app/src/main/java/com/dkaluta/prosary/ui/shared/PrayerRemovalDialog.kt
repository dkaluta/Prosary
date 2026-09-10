package com.dkaluta.prosary.ui.shared

import android.content.Context
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.dkaluta.prosary.R
import com.dkaluta.prosary.content.audio.AudioPlaybackController
import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import com.dkaluta.prosary.models.FavoriteDevotions
import com.dkaluta.prosary.models.MultiDayRuns
import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import com.dkaluta.prosary.models.PrayerRunKeys
import com.dkaluta.prosary.models.PrayerRunProgressStore
import com.dkaluta.prosary.presets.PrayerRemovalService
import com.dkaluta.prosary.reminders.ReminderScheduler
import com.dkaluta.prosary.services.AppServices
import com.dkaluta.prosary.services.LocalAppServices
import kotlinx.coroutines.launch

sealed interface PrayerRemovalRequest {
    data class Saved(val prayer: Prayer) : PrayerRemovalRequest
    data class Download(val id: String) : PrayerRemovalRequest
}

fun prayerRemovalService(context: Context, services: AppServices): PrayerRemovalService {
    val removedDayCounts = mutableMapOf<String, Int>()
    return PrayerRemovalService(
    services.presetStore,
    isInstalled = { it in PrayerPackStore.installedBundleIds() },
    isBuiltIn = PrayerPackStore::isBuiltInBundle,
    removePack = {
        removedDayCounts[it] = PrayerPackStore.definition(it)?.days?.size ?: 0
        PrayerPackStore.removeInstalledPack(it)
    },
    cancelReminders = { prayer ->
        ReminderScheduler.removeAll(context, prayer)
        when (prayer.kind) {
            PrayerKind.Rosary -> PrayerRunProgressStore.clear(context, PrayerRunKeys.rosary(prayer.id))
            PrayerKind.JesusPrayer -> PrayerRunProgressStore.clear(context, PrayerRunKeys.jesus(prayer.id, prayer.jesusPrayer.target))
            PrayerKind.Custom -> Unit // Generic bookmarks can also belong to a surviving copy.
        }
    },
    didRemovePack = {
        FavoriteDevotions.forget(context, it)
        ReminderScheduler.removeSeries(context, it, removedDayCounts.remove(it) ?: 0)
        MultiDayRuns.clear(context, it)
        AudioPlaybackController.removeCachedAudio(context.cacheDir, it)
    },
)
}

@Composable
fun PrayerRemovalDialog(request: PrayerRemovalRequest, onDismiss: () -> Unit, onRemoved: () -> Unit) {
    val context = LocalContext.current
    val services = LocalAppServices.current
    val removal = remember(context, services) { prayerRemovalService(context, services) }
    val scope = rememberCoroutineScope()
    var ready by remember(request) { mutableStateOf(false) }
    var busy by remember(request) { mutableStateOf(false) }
    var removesDownload by remember(request) { mutableStateOf(false) }
    var errorRes by remember(request) { mutableStateOf<Int?>(null) }
    val name = when (request) {
        is PrayerRemovalRequest.Saved -> request.prayer.name
        is PrayerRemovalRequest.Download -> PrayerPackStore.info(request.id)?.localizedDisplayName ?: request.id
    }
    LaunchedEffect(request) {
        runCatching {
            when (request) {
                is PrayerRemovalRequest.Saved -> removesDownload = removal.plan(request.prayer).removesDownload
                is PrayerRemovalRequest.Download -> {
                    if (services.presetStore.all().any { it.kind == PrayerKind.Custom && it.customDevotionId == request.id }) {
                        errorRes = R.string.download_in_use
                    }
                }
            }
        }.onFailure { errorRes = R.string.prayer_removal_error }
        ready = true
    }
    AlertDialog(
        onDismissRequest = { if (!busy) onDismiss() },
        title = { Text(stringResource(if (errorRes != null) R.string.prayer_removal_error_title else when (request) {
            is PrayerRemovalRequest.Saved -> R.string.prayer_delete_title
            is PrayerRemovalRequest.Download -> R.string.download_remove_title
        })) },
        text = {
            Text(if (errorRes != null) stringResource(errorRes!!) else stringResource(when (request) {
                is PrayerRemovalRequest.Saved -> if (removesDownload) R.string.prayer_delete_download_message else R.string.prayer_delete_message
                is PrayerRemovalRequest.Download -> R.string.download_remove_message
            }, name))
        },
        confirmButton = {
            TextButton(enabled = ready && !busy, onClick = {
                if (errorRes != null) onDismiss() else {
                    busy = true
                    scope.launch {
                        runCatching {
                            when (request) {
                                is PrayerRemovalRequest.Saved -> removal.deleteSaved(request.prayer)
                                is PrayerRemovalRequest.Download -> removal.removeDownload(request.id)
                            }
                        }.onSuccess { onRemoved(); onDismiss() }.onFailure { error ->
                            val failure = error as? PrayerRemovalService.Failure
                            errorRes = when {
                                failure?.savedPrayerDeleted == true -> R.string.prayer_removal_partial
                                failure?.downloadRemoved == true -> R.string.download_removal_partial
                                failure?.downloadInUse == true -> R.string.download_in_use
                                else -> R.string.prayer_removal_error
                            }
                            if (failure?.savedPrayerDeleted == true || failure?.downloadRemoved == true) onRemoved()
                        }
                        busy = false
                    }
                }
            }) {
                Text(stringResource(if (errorRes != null) R.string.common_ok else when (request) {
                    is PrayerRemovalRequest.Saved -> R.string.favorites_delete
                    is PrayerRemovalRequest.Download -> R.string.settings_remove_all_confirm
                }),
                    color = if (errorRes == null) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary)
            }
        },
        dismissButton = {
            if (errorRes == null) TextButton(enabled = !busy, onClick = onDismiss) { Text(stringResource(R.string.common_cancel)) }
        },
    )
}
