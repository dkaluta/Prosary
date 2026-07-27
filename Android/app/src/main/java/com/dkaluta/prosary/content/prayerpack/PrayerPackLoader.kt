package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryText
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import java.io.InputStream
import java.util.zip.ZipInputStream
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

@Serializable
private data class PackManifest(
    val id: String,
    val displayName: String,
    val languages: List<String>,
    val hasCatalog: Boolean,
    val accentColorHex: String? = null,
    val iconSystemName: String? = null,
)

@Serializable
private data class PackContent(
    val prayers: Map<String, String> = emptyMap(),
    val mysteries: Map<String, MysteryText> = emptyMap(),
)

/** One entry in a generic (bundle-driven) devotion's `steps.json` — see
 * Shared/ARCHITECTURE.md's "Content bundles" section. [title] is a literal display string, not a
 * translation key, matching the existing convention that every devotion's step titles are
 * English-only UI labels. [bodyKey]/[imageKey] are resolved via [PrayerPackStore.resolveBodyText]
 * / the ordinary image-override lookup, exactly like a hardcoded devotion's step. */
@Serializable
data class CustomDevotionStep(
    val title: String,
    val bodyKey: String,
    val imageKey: String,
)

@Serializable
private data class PackSteps(
    val steps: List<CustomDevotionStep> = emptyList(),
)

/** Metadata a generic devotion's Home card / Favorites row needs, sourced from its bundle's
 * manifest.json rather than any hardcoded per-kind table. */
data class CustomDevotionInfo(
    val displayName: String,
    val accentColorHex: String?,
    val iconSystemName: String?,
)

/** Loads the bundled .prosaryprayer packs (Rosary, Angelus, and any generic bundle-driven
 * devotion such as Trisagion — see Shared/ARCHITECTURE.md's "Content bundles" section) and merges
 * their content into PrayerTranslations/MysteryTranslations as an override layer. PrayerKey/
 * mystery imageKey entries are a shared pool across devotions (e.g. "our_father" is used by
 * Rosary, Angelus, Franciscan Crown, Seven Sorrows, and Divine Mercy alike), so a pack can only
 * ever add to the hardcoded tables, never replace them wholesale — devotions without a shipped
 * pack keep resolving 100% from hardcoded source, unaffected.
 *
 * A bundle with a `steps.json` is a *generic devotion*: `PrayerKind.CUSTOM` + a `customDevotionId`
 * are the only engine/model plumbing it needs (see `PrayerEngine.buildCustomDevotionSteps`) — its
 * actual step sequence and per-step body text are entirely data-driven from here, via
 * [steps]/[resolveBodyText].
 *
 * Uses `java.util.zip` (JDK-builtin, works in plain JVM unit tests) and kotlinx.serialization
 * (org.json's android.jar stubs throw in plain unit tests without Robolectric, which this module
 * doesn't use). */
object PrayerPackStore {
    private val json = Json { ignoreUnknownKeys = true }

    private val prayerOverrides = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val mysteryOverrides = mutableMapOf<String, MutableMap<String, MysteryText>>()
    private val imageDataByKey = mutableMapOf<String, ByteArray>()
    /** Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
     * [prayerOverrides], this retains keys with no matching [PrayerKey] case (e.g.
     * "trisagionAcclamation"), which is how a generic devotion's `steps.json` resolves
     * bundle-local body text. See [resolveBodyText]. */
    private val rawContentByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()
    private val stepsByBundle = mutableMapOf<String, List<CustomDevotionStep>>()
    private val infoByBundle = mutableMapOf<String, CustomDevotionInfo>()
    private var didLoad = false

    fun prayerOverride(languageCode: String, key: PrayerKey): String? =
        prayerOverrides[languageCode]?.get(key)

    fun mysteryOverride(languageCode: String, imageKey: String): MysteryText? =
        mysteryOverrides[languageCode]?.get(imageKey)

    fun imageData(imageKey: String): ByteArray? = imageDataByKey[imageKey]

    /** The ordered step sequence for a generic (bundle-driven) devotion, e.g. "trisagion". Empty
     * for any bundle with no `steps.json` (Rosary/Angelus, which stay hardcoded). */
    fun steps(bundleId: String): List<CustomDevotionStep> = stepsByBundle[bundleId] ?: emptyList()

    /** Every loaded bundle id that has a `steps.json` — i.e. every generic devotion discovered at
     * load time, without hardcoding devotion names anywhere in view code. */
    fun customDevotionIds(): List<String> = stepsByBundle.keys.toList()

    fun info(bundleId: String): CustomDevotionInfo? = infoByBundle[bundleId]

    /** Resolves a `steps.json` entry's `bodyKey` to display text: (1) the bundle's own raw
     * content for this key, if present — this is how bundle-local-only keys (e.g.
     * "trisagionAcclamation") resolve; (2) else, if the key happens to match an existing
     * [PrayerKey] case, the ordinary hardcoded/override lookup — this is how shared "main" keys
     * (e.g. "gloriaPatri") resolve; (3) else the raw key string, matching
     * `PrayerTranslations.get`'s own last-resort fallback. */
    fun resolveBodyText(bundleId: String, languageCode: String?, key: String): String {
        if (languageCode != null) {
            rawContentByBundle[bundleId]?.get(languageCode)?.get(key)?.let { return it }
        }
        val prayerKey = keyToPrayerKey(key)
        if (prayerKey != null) {
            return PrayerTranslations.get(languageCode, prayerKey)
        }
        return key
    }

    /** [openPack] returns a fresh stream for a named pack's bytes (e.g.
     * `context.assets.open("$it.prosaryprayer")` on-device, or a plain `File(...).inputStream()`
     * in tests) — return null for a pack that isn't available. Safe to call more than once; only
     * the first call does any work. */
    fun initialize(openPack: (String) -> InputStream?) {
        if (didLoad) return
        didLoad = true

        for (packName in listOf("rosary", "angelus", "trisagion")) {
            val stream = openPack(packName) ?: continue
            runCatching { load(stream) }
        }
    }

    private fun load(stream: InputStream) {
        val entries = readZipEntries(stream)
        val manifestBytes = entries["manifest.json"] ?: return
        val manifest = json.decodeFromString<PackManifest>(String(manifestBytes, Charsets.UTF_8))

        infoByBundle[manifest.id] = CustomDevotionInfo(
            displayName = manifest.displayName,
            accentColorHex = manifest.accentColorHex,
            iconSystemName = manifest.iconSystemName,
        )

        for (language in manifest.languages) {
            val contentBytes = entries["content/$language.json"] ?: continue
            val content = json.decodeFromString<PackContent>(String(contentBytes, Charsets.UTF_8))

            val bundleRawContent = rawContentByBundle.getOrPut(manifest.id) { mutableMapOf() }
            bundleRawContent[language] = content.prayers

            val prayers = prayerOverrides.getOrPut(language) { mutableMapOf() }
            for ((key, text) in content.prayers) {
                val prayerKey = keyToPrayerKey(key) ?: continue
                prayers[prayerKey] = text
            }

            if (manifest.hasCatalog && content.mysteries.isNotEmpty()) {
                mysteryOverrides.getOrPut(language) { mutableMapOf() }.putAll(content.mysteries)
            }
        }

        entries["steps.json"]?.let { stepsBytes ->
            val packSteps = json.decodeFromString<PackSteps>(String(stepsBytes, Charsets.UTF_8))
            stepsByBundle[manifest.id] = packSteps.steps
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
