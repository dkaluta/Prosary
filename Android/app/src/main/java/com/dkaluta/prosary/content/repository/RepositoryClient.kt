package com.dkaluta.prosary.content.repository

import com.dkaluta.prosary.content.prayerpack.PrayerPackStore
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/** One catalog entry from prayers.prosary.app/index.json. [id] is always
 * `repo.<username>.<name>` — the prefix the Favorites rows key their "Repository" tag on. */
@Serializable
data class RepositoryBundle(
    val id: String,
    val name: String,
    val author: String,
    val languages: List<String> = emptyList(),
    val tags: List<String> = emptyList(),
    val description: String = "",
    /** Same-origin download path ("/api/download/<id>") — downloads count server-side. */
    val file: String,
    /** Server-side last-modified stamp; optional so older catalogs (pre-0.6) still parse.
     * The browser keys its "Update" badge on this changing after install. */
    val updatedAt: String? = null,
)

@Serializable
private data class RepositoryCatalog(
    val prosaryRepository: Int,
    val bundles: List<RepositoryBundle> = emptyList(),
)

/** Fetches the prayers.prosary.app catalog (the versioned /index.json contract — see
 * Shared/ARCHITECTURE.markdown § Content bundles) and downloads bundles through the same-origin
 * download path, so server-side counting keeps working and the storage behind it can change
 * without breaking installed apps. */
object RepositoryClient {
    const val BASE_URL = "https://prayers.prosary.app"

    private val json = Json { ignoreUnknownKeys = true }

    class UnsupportedCatalogException :
        Exception("The repository uses a newer catalog format — update Prosary to browse it.")

    /** Split out from the fetch so tests can pin the contract without a network. */
    fun parseCatalog(text: String): List<RepositoryBundle> {
        val catalog = json.decodeFromString<RepositoryCatalog>(text)
        if (catalog.prosaryRepository != 1) throw UnsupportedCatalogException()
        return catalog.bundles
    }

    private fun openConnection(url: String) = (URL(url).openConnection()).apply {
        // A hung route should become a clean error, not an eternal spinner.
        connectTimeout = 15_000
        readTimeout = 15_000
    }

    /** Bounds the WHOLE operation — DNS included, which connect/read timeouts don't cover —
     * and turns the coroutine timeout into an ordinary IOException: the screens rethrow
     * CancellationException (navigation is not an outage), but a timeout very much is one. */
    private suspend fun <T> bounded(block: suspend () -> T): T = try {
        withTimeout(20_000) { block() }
    } catch (timeout: TimeoutCancellationException) {
        throw java.io.IOException("The repository could not be reached.")
    }

    suspend fun fetchCatalog(): List<RepositoryBundle> = bounded {
        withContext(Dispatchers.IO) {
            parseCatalog(openConnection("$BASE_URL/index.json").getInputStream().bufferedReader().readText())
        }
    }

    suspend fun downloadBundle(bundle: RepositoryBundle): ByteArray = bounded {
        withContext(Dispatchers.IO) {
            val connection = openConnection(BASE_URL + bundle.file)
            connection.connect()
            PrayerPackStore.requireInstallByteCount(connection.contentLengthLong)
            connection.getInputStream().use(PrayerPackStore::readInstallBytes)
        }
    }
}

/** Which catalog `updatedAt` each repository bundle was installed at — the whole "update
 * available" feature: a bundle shows Update when the live catalog's stamp differs from the
 * one recorded at install. File-imported bundles have no record and never nag. */
object RepositoryInstallStamps {
    private fun prefs(context: android.content.Context) =
        context.getSharedPreferences("repo_install_stamps", android.content.Context.MODE_PRIVATE)

    fun record(context: android.content.Context, bundleId: String, updatedAt: String?) {
        prefs(context).edit().apply {
            if (updatedAt == null) remove(bundleId) else putString(bundleId, updatedAt)
        }.apply()
    }

    fun hasUpdate(context: android.content.Context, bundle: RepositoryBundle, isInstalled: Boolean): Boolean {
        if (!isInstalled) return false
        val live = bundle.updatedAt ?: return false
        val installed = prefs(context).getString(bundle.id, null) ?: return false
        return live != installed
    }
}
