package com.dkaluta.prosary.presets

import com.dkaluta.prosary.models.Prayer
import com.dkaluta.prosary.models.PrayerKind
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

/** Deleting a saved configuration and removing an unused download are separate operations.
 * File cleanup only follows a successful database deletion and a fresh sibling query. */
class PrayerRemovalService(
    private val store: PresetStore,
    private val isInstalled: (String) -> Boolean,
    private val isBuiltIn: (String) -> Boolean,
    private val removePack: (String) -> Unit,
    private val cancelReminders: (Prayer) -> Unit,
    private val didRemovePack: (String) -> Unit = {},
) {
    data class Plan(val prayer: Prayer, val removesDownload: Boolean)
    class Failure(
        val savedPrayerDeleted: Boolean = false,
        val downloadInUse: Boolean = false,
        val downloadRemoved: Boolean = false,
        cause: Throwable? = null,
    ) :
        Exception("Prayer removal could not be completed", cause)

    suspend fun plan(prayer: Prayer): Plan {
        val current = store.get(prayer.id) ?: throw Failure()
        val id = current.customDevotionId
        val removesDownload = current.kind == PrayerKind.Custom && id != null &&
            isInstalled(id) && !isBuiltIn(id) &&
            store.all().none { it.id != current.id && it.kind == PrayerKind.Custom && it.customDevotionId == id }
        return Plan(current, removesDownload)
    }

    suspend fun deleteSaved(prayer: Prayer) = mutex.withLock { withContext(NonCancellable) {
        val current = store.get(prayer.id) ?: throw Failure()
        var downloadRemoved = false
        try {
            store.delete(current)
        } catch (error: Exception) {
            throw Failure(cause = error)
        }
        try {
            cancelReminders(current)
            val id = current.customDevotionId
            if (current.kind == PrayerKind.Custom && id != null && isInstalled(id) && !isBuiltIn(id)) {
                val remaining = store.all()
                if (remaining.none { it.kind == PrayerKind.Custom && it.customDevotionId == id }) {
                    removePack(id)
                    downloadRemoved = true
                    didRemovePack(id)
                }
            }
        } catch (error: Exception) {
            throw Failure(savedPrayerDeleted = true, downloadRemoved = downloadRemoved, cause = error)
        }
    } }

    suspend fun removeDownload(id: String) = mutex.withLock { withContext(NonCancellable) {
        if (isBuiltIn(id) || !isInstalled(id)) throw Failure()
        if (store.all().any { it.kind == PrayerKind.Custom && it.customDevotionId == id }) {
            throw Failure(downloadInUse = true)
        }
        var downloadRemoved = false
        try {
            removePack(id)
            downloadRemoved = true
            didRemovePack(id)
        } catch (error: Exception) {
            throw Failure(downloadRemoved = downloadRemoved, cause = error)
        }
    } }

    companion object {
        private val mutex = Mutex()
    }
}
