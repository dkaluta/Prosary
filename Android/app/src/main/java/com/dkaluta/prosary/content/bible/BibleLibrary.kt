package com.dkaluta.prosary.content.bible

import android.content.Context
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.UUID
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeout

/** Download work survives tab changes and is shared by app windows; reader position is not. */
class BibleLibrary internal constructor(val store: BibleStore, private val cacheDirectory: File) {
    data class Download(val progress: Float = 0f, val failed: Boolean = false, val removalFailed: Boolean = false)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val jobs = mutableMapOf<String, Job>()
    private val mutation = Mutex()
    private val mutableDownloads = MutableStateFlow<Map<String, Download>>(emptyMap())
    val downloads = mutableDownloads.asStateFlow()
    private val mutableGeneration = MutableStateFlow<Map<String, Int>>(emptyMap())
    val generation = mutableGeneration.asStateFlow()

    @Synchronized fun download(edition: BibleEdition) {
        if (jobs[edition.id]?.isActive == true) return
        mutableDownloads.value = mutableDownloads.value + (edition.id to Download())
        jobs[edition.id] = scope.launch {
            val temporary = File(cacheDirectory, "bible-${UUID.randomUUID()}.zip")
            try {
                BibleStore.validateEdition(edition)
                check(cacheDirectory.mkdirs() || cacheDirectory.isDirectory)
                withTimeout(180_000) {
                    val connection = (URL(edition.downloadURL).openConnection() as HttpURLConnection).apply {
                        connectTimeout = 15_000
                        readTimeout = 20_000
                        instanceFollowRedirects = false
                    }
                    try {
                        require(connection.responseCode == HttpURLConnection.HTTP_OK)
                        require(connection.contentLengthLong == -1L || connection.contentLengthLong == edition.archiveByteCount)
                        connection.inputStream.use { input ->
                            temporary.outputStream().use { output ->
                                val buffer = ByteArray(32 * 1024)
                                var total = 0L
                                while (true) {
                                    currentCoroutineContext().ensureActive()
                                    val count = input.read(buffer)
                                    if (count == -1) break
                                    total += count
                                    require(total <= edition.archiveByteCount && total <= BibleStore.MAX_ARCHIVE_BYTES)
                                    output.write(buffer, 0, count)
                                    update(edition.id, Download(total.toFloat() / edition.archiveByteCount))
                                }
                                require(total == edition.archiveByteCount)
                            }
                        }
                    } finally {
                        connection.disconnect()
                    }
                }
                currentCoroutineContext().ensureActive()
                mutation.withLock {
                    store.install(edition, temporary)
                    mutableGeneration.value = mutableGeneration.value + (edition.id to ((mutableGeneration.value[edition.id] ?: 0) + 1))
                }
                update(edition.id, null)
            } catch (cancelled: CancellationException) {
                // Timeouts are retryable failures; an explicit cancellation just clears progress.
                update(edition.id, if (cancelled is kotlinx.coroutines.TimeoutCancellationException) Download(failed = true) else null)
            } catch (_: Exception) {
                update(edition.id, Download(failed = true))
            } finally {
                temporary.delete()
            }
        }
    }

    @Synchronized fun cancel(id: String) { jobs[id]?.cancel() }

    fun remove(id: String) {
        scope.launch {
            mutation.withLock {
                try {
                    store.remove(id)
                    mutableGeneration.value = mutableGeneration.value + (id to ((mutableGeneration.value[id] ?: 0) + 1))
                    update(id, null)
                } catch (_: Exception) {
                    update(id, Download(failed = true, removalFailed = true))
                }
            }
        }
    }

    @Synchronized private fun update(id: String, download: Download?) {
        mutableDownloads.value = if (download == null) mutableDownloads.value - id else mutableDownloads.value + (id to download)
    }

    companion object {
        @Volatile private var instance: BibleLibrary? = null
        fun get(context: Context): BibleLibrary = instance ?: synchronized(this) {
            instance ?: BibleLibrary(BibleStore(File(context.applicationContext.filesDir, "bibles")),
                context.applicationContext.cacheDir).also { instance = it }
        }
    }
}
