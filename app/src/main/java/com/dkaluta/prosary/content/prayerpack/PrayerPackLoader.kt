package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryText
import com.dkaluta.prosary.content.PrayerKey
import java.io.InputStream
import java.util.zip.ZipInputStream
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
private data class PackManifest(
    val id: String,
    val languages: List<String>,
    val hasCatalog: Boolean,
)

@Serializable
private data class PackContent(
    val prayers: Map<String, String> = emptyMap(),
    val mysteries: Map<String, MysteryText> = emptyMap(),
)

/** Loads the bundled .prosaryprayer packs (currently Rosary + Angelus — see
 * Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content into
 * PrayerTranslations/MysteryTranslations as an override layer. PrayerKey/mystery imageKey entries
 * are a shared pool across devotions (e.g. "our_father" is used by Rosary, Angelus, Franciscan
 * Crown, Seven Sorrows, and Divine Mercy alike), so a pack can only ever add to the hardcoded
 * tables, never replace them wholesale — devotions without a shipped pack keep resolving 100%
 * from hardcoded source, unaffected.
 *
 * Uses `java.util.zip` (JDK-builtin, works in plain JVM unit tests) and kotlinx.serialization
 * (org.json's android.jar stubs throw in plain unit tests without Robolectric, which this module
 * doesn't use). */
object PrayerPackStore {
    private val json = Json { ignoreUnknownKeys = true }

    private val prayerOverrides = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val mysteryOverrides = mutableMapOf<String, MutableMap<String, MysteryText>>()
    private val imageDataByKey = mutableMapOf<String, ByteArray>()
    private var didLoad = false

    fun prayerOverride(languageCode: String, key: PrayerKey): String? =
        prayerOverrides[languageCode]?.get(key)

    fun mysteryOverride(languageCode: String, imageKey: String): MysteryText? =
        mysteryOverrides[languageCode]?.get(imageKey)

    fun imageData(imageKey: String): ByteArray? = imageDataByKey[imageKey]

    /** [openPack] returns a fresh stream for a named pack's bytes (e.g.
     * `context.assets.open("$it.prosaryprayer")` on-device, or a plain `File(...).inputStream()`
     * in tests) — return null for a pack that isn't available. Safe to call more than once; only
     * the first call does any work. */
    fun initialize(openPack: (String) -> InputStream?) {
        if (didLoad) return
        didLoad = true

        for (packName in listOf("rosary", "angelus")) {
            val stream = openPack(packName) ?: continue
            runCatching { load(stream) }
        }
    }

    private fun load(stream: InputStream) {
        val entries = readZipEntries(stream)
        val manifestBytes = entries["manifest.json"] ?: return
        val manifest = json.decodeFromString<PackManifest>(String(manifestBytes, Charsets.UTF_8))

        for (language in manifest.languages) {
            val contentBytes = entries["content/$language.json"] ?: continue
            val content = json.decodeFromString<PackContent>(String(contentBytes, Charsets.UTF_8))

            val prayers = prayerOverrides.getOrPut(language) { mutableMapOf() }
            for ((key, text) in content.prayers) {
                val prayerKey = keyToPrayerKey(key) ?: continue
                prayers[prayerKey] = text
            }

            if (manifest.hasCatalog && content.mysteries.isNotEmpty()) {
                mysteryOverrides.getOrPut(language) { mutableMapOf() }.putAll(content.mysteries)
            }
        }

        for ((name, bytes) in entries) {
            if (name.startsWith("images/")) {
                imageDataByKey[name.removePrefix("images/").removeSuffix(".jpg")] = bytes
            }
        }
    }

    /** Bundle content JSON keys are the camelCase form used across every platform's schema (e.g.
     * "oratioFatimae"); this Kotlin enum's entries are the same names PascalCased (OratioFatimae)
     * per this codebase's usual Swift-to-Kotlin naming convention. */
    private fun keyToPrayerKey(jsonKey: String): PrayerKey? {
        val pascalCase = jsonKey.replaceFirstChar { it.uppercaseChar() }
        return runCatching { PrayerKey.valueOf(pascalCase) }.getOrNull()
    }

    private fun readZipEntries(stream: InputStream): Map<String, ByteArray> {
        val result = mutableMapOf<String, ByteArray>()
        ZipInputStream(stream).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                if (!entry.isDirectory) {
                    result[entry.name] = zip.readBytes()
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return result
    }
}
