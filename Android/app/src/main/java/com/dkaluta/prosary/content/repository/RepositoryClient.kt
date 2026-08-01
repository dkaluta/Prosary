package com.dkaluta.prosary.content.repository

import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
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
)

@Serializable
private data class RepositoryCatalog(
    val prosaryRepository: Int,
    val bundles: List<RepositoryBundle> = emptyList(),
)

/** Fetches the prayers.prosary.app catalog (the versioned /index.json contract — see
 * Shared/ARCHITECTURE.md § Content bundles) and downloads bundles through the same-origin
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

    suspend fun fetchCatalog(): List<RepositoryBundle> = withContext(Dispatchers.IO) {
        parseCatalog(URL("$BASE_URL/index.json").readText())
    }

    suspend fun downloadBundle(bundle: RepositoryBundle): ByteArray = withContext(Dispatchers.IO) {
        URL(BASE_URL + bundle.file).readBytes()
    }
}
