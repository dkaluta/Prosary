package com.dkaluta.prosary.ui.home

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/** A cancelled picker import keeps the old selection and removes even a just-created copy. */
internal object HomePhotoTransaction {
    suspend fun replace(previous: String, copy: () -> String, commit: (String) -> Unit, remove: (String) -> Unit) {
        var candidate: String? = null
        var failure: Throwable? = null
        try {
            // Record the result inside IO: withContext can discard its return value on cancellation.
            val path = withContext(Dispatchers.IO) { copy().also { candidate = it } }
            commit(path)
            candidate = null
            withContext(NonCancellable + Dispatchers.IO) { remove(previous) }
        } catch (error: Throwable) {
            failure = error
            throw error
        } finally {
            candidate?.let { path ->
                try { withContext(NonCancellable + Dispatchers.IO) { remove(path) } }
                catch (cleanupError: Throwable) {
                    if (failure != null) failure.addSuppressed(cleanupError) else throw cleanupError
                }
            }
        }
    }

    /** Once deletion begins, finish clearing its preference even if Home leaves composition. */
    suspend fun remove(previous: String, delete: (String) -> Unit, clear: () -> Unit) = withContext(NonCancellable) {
        withContext(Dispatchers.IO) { delete(previous) }
        clear()
    }
}
