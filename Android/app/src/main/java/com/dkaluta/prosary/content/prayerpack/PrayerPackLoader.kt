package com.dkaluta.prosary.content.prayerpack

import com.dkaluta.prosary.content.MysteryText
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import java.io.InputStream
import java.util.Locale
import java.util.zip.ZipInputStream
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive

@Serializable
private data class PackManifest(
    val id: String,
    val displayName: String,
    val languages: List<String>,
    val hasCatalog: Boolean,
    val accentColorHex: String? = null,
    val accentColorDarkHex: String? = null,
    val iconSystemName: String? = null,
    val displayNameByLanguage: Map<String, String>? = null,
    val reminderBody: Map<String, String>? = null,
    val reminderPresetHours: List<Int>? = null,
    val reminderPresetFooter: Map<String, String>? = null,
)

@Serializable
private data class PackContent(
    val prayers: Map<String, String> = emptyMap(),
    val mysteries: Map<String, MysteryText> = emptyMap(),
)

/** One entry in a generic devotion's `devotion.json` — a step of the flat "steps" type, an
 * opening/closing step of the "rosary" type, or (closing only) a [kind]-tagged special step.
 * [title] is a literal display string (the app-wide convention that step titles are English-only
 * UI labels); [titleKey] is the alternative for devotions whose step titles are themselves
 * translated content (e.g. the Stations' station names). [repeatCount] expands into n steps
 * titled "Title (h of n)" — deliberately without bead fields, matching the hardcoded devotions'
 * closing Hail Marys. */
@Serializable
data class CustomDevotionStep(
    val title: String? = null,
    val titleKey: String? = null,
    val subtitle: String? = null,
    val bodyKey: String? = null,
    val imageKey: String? = null,
    @SerialName("repeat") val repeatCount: Int? = null,
    val isScripture: Boolean? = null,
    /** Gates this entry on one of the bundle's `options.json` options: `"key"` (toggle on),
     * `"!key"` (toggle off), or `"key=caseId"` (choice equals) — see
     * `PrayerEngine.evaluateCondition`. Null = always included. */
    @SerialName("if") val condition: String? = null,
    val kind: SpecialKind? = null,
) {
    @Serializable
    enum class SpecialKind {
        /** The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it stays
         * runtime-composed by the engine's shared antiphon builder rather than data-driven. */
        @SerialName("seasonalMarianAntiphon")
        SeasonalMarianAntiphon,
    }
}

/** One user-configurable setting a bundle declares in its `options.json` — a toggle or a
 * multi-case choice. Entry-level `"if"` expressions gate steps on the resulting values; the
 * favorite's choices persist in `Prayer.customOptions` (only overrides — an absent key means
 * this option's [defaultValue]). Structure is enforced at authoring time by
 * `Shared/tools/validate-devotion.py`. */
@Serializable
data class CustomDevotionOption(
    val key: String,
    val kind: Kind,
    /** English UI label; [nameByLanguage] overrides it per UI localization. */
    val name: String,
    val nameByLanguage: Map<String, String>? = null,
    /** Authored as a JSON boolean (toggle) or case-id string (choice) — see [defaultValue]. */
    @SerialName("default") val default: JsonPrimitive,
    val cases: List<Case>? = null,
) {
    @Serializable
    enum class Kind {
        @SerialName("toggle")
        Toggle,

        @SerialName("choice")
        Choice,
    }

    @Serializable
    data class Case(
        val id: String,
        val name: String,
        val nameByLanguage: Map<String, String>? = null,
    ) {
        val localizedName: String
            get() = nameByLanguage?.get(Locale.getDefault().language) ?: name
    }

    /** Canonical string form of the authored default: "true"/"false" for a toggle, a case id
     * for a choice — the same encoding `Prayer.customOptions` stores. */
    val defaultValue: String
        get() = default.content

    val localizedName: String
        get() = nameByLanguage?.get(Locale.getDefault().language) ?: name
}

@Serializable
private data class PackOptions(
    val options: List<CustomDevotionOption>,
)

/** Parsed `devotion.json` — the complete structural description of a generic devotion.
 * Field validity per type is enforced at authoring time by `Shared/tools/validate-devotion.py`;
 * the decoder is deliberately lenient (all optionals) so the engine can switch on [type] alone. */
@Serializable
data class CustomDevotionDefinition(
    val type: DevotionType,
    // steps type
    val steps: List<CustomDevotionStep>? = null,
    /** Whole-sequence swap during Eastertide (the Angelus → Regina Caeli substitution). */
    val eastertideSteps: List<CustomDevotionStep>? = null,
    /** Alternate step-sets (steps type only), mutually exclusive with [steps]. Null for
     * single-form devotions; the first variant is the default. */
    val variants: List<Variant>? = null,
    // rosary type
    val opening: List<CustomDevotionStep>? = null,
    val decades: Decades? = null,
    val closing: List<CustomDevotionStep>? = null,
    val hasClosingCross: Boolean? = null,
) {
    /** One named alternate step-set of a steps-type devotion (e.g. the Stations' traditional
     * vs. scriptural forms). */
    @Serializable
    data class Variant(
        val id: String,
        /** English UI label (the app-wide step-title convention); [nameByLanguage] overrides it
         * per UI localization, mirroring the manifest's displayNameByLanguage. */
        val name: String,
        val nameByLanguage: Map<String, String>? = null,
        val steps: List<CustomDevotionStep>,
        val eastertideSteps: List<CustomDevotionStep>? = null,
    ) {
        val localizedName: String
            get() = nameByLanguage?.get(Locale.getDefault().language) ?: name
    }

    /** The step lists to build for [variantId] — the matching variant, else the default (first)
     * variant, else the top-level lists (single-form devotions). */
    fun resolvedSteps(variantId: String?): Pair<List<CustomDevotionStep>, List<CustomDevotionStep>?> {
        if (!variants.isNullOrEmpty()) {
            val variant = variants.firstOrNull { it.id == variantId } ?: variants.first()
            return variant.steps to variant.eastertideSteps
        }
        return steps.orEmpty() to eastertideSteps
    }

    @Serializable
    enum class DevotionType {
        /** A flat, fixed step list (Angelus, Stations, Trisagion). */
        @SerialName("steps")
        Steps,

        /** A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine Mercy). */
        @SerialName("rosary")
        Rosary,
    }

    @Serializable
    data class Decades(
        /** "Joy" / "Sorrow" / "Decade" — combined with the engine's ordinal array into "1st Joy"
         * etc. */
        val ordinalNoun: String,
        /** True: each decade opens with an announcement step whose title/body come from the
         * mystery text of that decade's catalog entry (via the merged MysteryTranslations path). */
        val announceMystery: Boolean,
        /** Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
         * [count]+[fixedImageKey] (Divine Mercy). */
        val entries: List<CatalogEntry>? = null,
        val count: Int? = null,
        val fixedImageKey: String? = null,
        val majorStep: FixedStep,
        val minorStep: FixedStep,
        val minorCount: Int,
    ) {
        @Serializable
        data class CatalogEntry(
            val imageKey: String,
            /** Announcement steps are scripture by default; the one traditional non-Gospel scene
             * (the Seven Sorrows' meeting on the way) opts out. */
            val isScripture: Boolean? = null,
        )

        @Serializable
        data class FixedStep(
            val title: String,
            val bodyKey: String,
        )
    }
}

/** Metadata a generic devotion's Home card / Favorites row / reminders need, sourced from its
 * bundle's `manifest.json` rather than any hardcoded per-kind table. */
data class CustomDevotionInfo(
    val displayName: String,
    /** The languages this bundle ships content for (manifest `languages`). */
    val languages: List<String>,
    val accentColorHex: String?,
    val accentColorDarkHex: String?,
    val iconSystemName: String?,
    val displayNameByLanguage: Map<String, String>,
    val reminderBody: Map<String, String>,
    val reminderPresetHours: List<Int>?,
    val reminderPresetFooter: Map<String, String>,
) {
    /** The display name in the device's UI language (falling back to the manifest's base
     * [displayName]) — preserves e.g. the Hebrew devotion names that used to live in
     * strings.xml. */
    val localizedDisplayName: String
        get() = displayNameByLanguage[Locale.getDefault().language] ?: displayName

    val localizedReminderBody: String?
        get() = reminderBody[Locale.getDefault().language] ?: reminderBody["en"]

    val localizedReminderPresetFooter: String?
        get() = reminderPresetFooter[Locale.getDefault().language] ?: reminderPresetFooter["en"]
}

/** Loads the bundled .prosaryprayer packs (Rosary, and every generic bundle-driven devotion —
 * see Shared/ARCHITECTURE.md's "Content bundles" section) and merges their content into
 * PrayerTranslations/MysteryTranslations as an override layer. PrayerKey/mystery imageKey
 * entries are a shared pool across devotions (e.g. "our_father" is used by Rosary and several
 * bundle devotions alike), so a pack can only ever add to the hardcoded tables, never replace
 * them wholesale.
 *
 * A bundle with a `devotion.json` is a *generic devotion*: `PrayerKind.Custom` + a
 * `customDevotionId` are the only engine/model plumbing it needs (see
 * `PrayerEngine.buildCustomDevotionSteps`) — its step sequence (flat "steps" type, or
 * decade/bead-structured "rosary" type) and per-step body text are entirely data-driven from
 * here, via [definition]/[resolveBodyText].
 *
 * Uses `java.util.zip` (JDK-builtin, works in plain JVM unit tests) and kotlinx.serialization
 * (org.json's android.jar stubs throw in plain unit tests without Robolectric, which this module
 * doesn't use). */
object PrayerPackStore {
    private val json = Json { ignoreUnknownKeys = true }

    /** Load order — also the display order of generic-devotion cards/rows (Home, Favorites), so
     * this list is deliberately an ordered array, never a map's unordered keys. The rosary pack
     * loads first so its shared mystery texts/images are the base other bundles build on. */
    private val packNames = listOf(
        "rosary", "angelus", "stationsOfTheCross", "franciscanCrown", "sevenSorrows",
        "divineMercyChaplet", "trisagion",
    )

    private val prayerOverrides = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val mysteryOverrides = mutableMapOf<String, MutableMap<String, MysteryText>>()
    private val imageDataByKey = mutableMapOf<String, ByteArray>()
    /** Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
     * [prayerOverrides], this retains keys with no matching [PrayerKey] case (e.g.
     * "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
     * bundle-local body text. See [resolveBodyText]. */
    private val rawContentByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()
    private val definitionByBundle = mutableMapOf<String, CustomDevotionDefinition>()
    private val optionsByBundle = mutableMapOf<String, List<CustomDevotionOption>>()
    /** Bundle ids with a devotion.json, in pack-load order. */
    private val orderedCustomIds = mutableListOf<String>()
    private val infoByBundle = mutableMapOf<String, CustomDevotionInfo>()
    private var didLoad = false

    fun prayerOverride(languageCode: String, key: PrayerKey): String? =
        prayerOverrides[languageCode]?.get(key)

    fun mysteryOverride(languageCode: String, imageKey: String): MysteryText? =
        mysteryOverrides[languageCode]?.get(imageKey)

    fun imageData(imageKey: String): ByteArray? = imageDataByKey[imageKey]

    /** The parsed `devotion.json` for a generic (bundle-driven) devotion, e.g. "trisagion".
     * Null for any bundle without one (Rosary, which stays override-only). */
    fun definition(bundleId: String): CustomDevotionDefinition? = definitionByBundle[bundleId]

    /** The options a bundle's `options.json` declares, in authored order (the editor's display
     * order). Empty for bundles without one. */
    fun options(bundleId: String): List<CustomDevotionOption> =
        optionsByBundle[bundleId].orEmpty()

    /** Every loaded bundle id that has a `devotion.json` — i.e. every generic devotion discovered
     * at load time, in pack-load order, without hardcoding devotion names anywhere in view code. */
    fun customDevotionIds(): List<String> = orderedCustomIds.toList()

    fun info(bundleId: String): CustomDevotionInfo? = infoByBundle[bundleId]

    /** Resolves a `devotion.json` entry's `bodyKey`/`titleKey` to display text: (1) the bundle's
     * own raw content for this key — the requested language, else the bundle's Latin (mirroring
     * `PrayerTranslations.get`'s Latin fallback, so e.g. the sentinel/unknown language prays in
     * Latin, not raw keys); (2) else, if the key happens to match an existing [PrayerKey] case,
     * the ordinary hardcoded/override lookup — this is how shared "main" keys (e.g. "gloriaPatri")
     * resolve; (3) else the raw key string, matching `PrayerTranslations.get`'s own last resort. */
    fun resolveBodyText(bundleId: String, languageCode: String?, key: String): String {
        if (languageCode != null) {
            rawContentByBundle[bundleId]?.get(languageCode)?.get(key)?.let { return it }
        }
        rawContentByBundle[bundleId]?.get("la")?.get(key)?.let { return it }
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

        for (packName in packNames) {
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
            languages = manifest.languages,
            accentColorHex = manifest.accentColorHex,
            accentColorDarkHex = manifest.accentColorDarkHex,
            iconSystemName = manifest.iconSystemName,
            displayNameByLanguage = manifest.displayNameByLanguage ?: emptyMap(),
            reminderBody = manifest.reminderBody ?: emptyMap(),
            reminderPresetHours = manifest.reminderPresetHours,
            reminderPresetFooter = manifest.reminderPresetFooter ?: emptyMap(),
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

            // Mysteries merge whenever a bundle ships any — `hasCatalog` strictly means "has a
            // catalog.json authoring file" (the Rosary), not "may contribute mystery text":
            // generic rosary-type devotions (Seven Sorrows, Franciscan Crown) ship their
            // per-decade texts in the mysteries map without any catalog.json.
            if (content.mysteries.isNotEmpty()) {
                mysteryOverrides.getOrPut(language) { mutableMapOf() }.putAll(content.mysteries)
            }
        }

        entries["devotion.json"]?.let { definitionBytes ->
            definitionByBundle[manifest.id] =
                json.decodeFromString<CustomDevotionDefinition>(String(definitionBytes, Charsets.UTF_8))
            orderedCustomIds.add(manifest.id)
        }

        entries["options.json"]?.let { optionBytes ->
            optionsByBundle[manifest.id] =
                json.decodeFromString<PackOptions>(String(optionBytes, Charsets.UTF_8)).options
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
