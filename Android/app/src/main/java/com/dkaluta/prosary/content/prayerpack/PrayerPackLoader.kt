package com.dkaluta.prosary.content.prayerpack

import androidx.annotation.StringRes
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.LanguageCatalog

import com.dkaluta.prosary.content.MysteryText
import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import java.io.File
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
    /** Set ("rosary") when this bundle's devotion.json backs a dedicated PrayerKind rather
     * than a generic Custom devotion — the definition loads, but the bundle stays out of
     * [PrayerPackStore.customDevotionIds] so Home/Favorites don't list it twice. */
    val builtinKind: String? = null,
    val displayName: String,
    val languages: List<String>,
    val hasCatalog: Boolean,
    val accentColorHex: String? = null,
    val accentColorDarkHex: String? = null,
    val iconSystemName: String? = null,
    /** One grapheme (letter or emoji) drawn instead of [iconSystemName] — Compose's "your
     * own" icon (v0.7, Gamaliel item 6). */
    val iconGlyph: String? = null,
    val displayNameByLanguage: Map<String, String>? = null,
    val reminderBody: Map<String, String>? = null,
    val reminderPresetHours: List<Int>? = null,
    val reminderPresetFooter: Map<String, String>? = null,
    val tags: List<String>? = null,
)

@Serializable
private data class PackContent(
    val prayers: Map<String, String> = emptyMap(),
    val mysteries: Map<String, MysteryText> = emptyMap(),
    /** Optional reading aid (v0.7): prayer key → the same text in another script. */
    val transliterations: Map<String, String> = emptyMap(),
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
    /** Resolved like [bodyKey]; emitted as the step's regular-typeface acclamation above the
     * body (the Stations' versicle/response). */
    val acclamationKey: String? = null,
    val imageKey: String? = null,
    @SerialName("repeat") val repeatCount: Int? = null,
    val isScripture: Boolean? = null,
    /** Per-language override of [isScripture] — for bodies that are quoted scripture in some
     * languages but composed prose in others (the traditional Stations: Liguori meditations in
     * la/en, scripture meditations in ar/he/ru/tl). */
    val isScriptureByLanguage: Map<String, Boolean>? = null,
    /** Gates this entry on one of the bundle's `options.json` options: `"key"` (toggle on),
     * `"!key"` (toggle off), or `"key=caseId"` (choice equals) — see
     * `PrayerEngine.evaluateCondition`. Null = always included. */
    @SerialName("if") val condition: String? = null,
    /** Like [titleKey] for the subtitle — for subtitles that are themselves translated content
     * (the Rosary's opening Hail Marys "for Faith/Hope/Charity"). Mutually exclusive with the
     * literal [subtitle]. */
    val subtitleKey: String? = null,
    val kind: SpecialKind? = null,
    /** For [SpecialKind.MarianAntiphon]: the choice option whose value names the antiphon to
     * build ("seasonal" resolves via the liturgical calendar, "none" drops the step). */
    val optionKey: String? = null,
) {
    @Serializable
    enum class SpecialKind {
        /** The seasonal Marian antiphon (Franciscan Crown) — calendar-dependent, so it stays
         * runtime-composed by the engine's shared antiphon builder rather than data-driven. */
        @SerialName("seasonalMarianAntiphon")
        SeasonalMarianAntiphon,

        /** An option-selected Marian antiphon (the Rosary) — [CustomDevotionStep.optionKey]
         * names a choice option whose cases are antiphon ids plus "seasonal" and "none". */
        @SerialName("marianAntiphon")
        MarianAntiphon,
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

/** One narrated recording a bundle declares in its `audio.json` (an optional bundle file, staged
 * by both packers like options.json — see Shared/ARCHITECTURE.md's "Audio").
 * AudioPlaybackController plays these through the prayer flow's transport bar — metadata loads
 * eagerly here, bytes are served on demand via [PrayerPackStore.audioData] and extracted to a
 * cache file at load. Files are Ogg Opus (RFC 7845, `.opus`) under the bundle's `audio/` directory;
 * structure is enforced at authoring time by `Shared/tools/validate-devotion.py`. */
@Serializable
data class DevotionAudioTrack(
    /** Unique within the bundle — what a persisted playback position would key against (persistence itself is future work). */
    val id: String,
    /** The single language this recording is in (one of the manifest's languages). */
    val language: String,
    /** Bundle-relative path, always `audio/<name>.opus`. */
    val file: String,
    /** The steps-type variant this recording follows (a traditional vs. scriptural Stations
     * recording differ). Null for single-form devotions. */
    val variantId: String? = null,
    /** English UI label; [nameByLanguage] overrides it per UI localization. Null = platforms
     * label the track by its language. */
    val name: String? = null,
    val nameByLanguage: Map<String, String>? = null,
    val chapters: List<Chapter>,
) {
    /** One seek point. [start] is seconds from the track's beginning (the first chapter starts
     * at 0, starts strictly increase); [title] XOR [titleKey] per the step-entry convention
     * ([titleKey] resolves through the track language's ordinary content chain); [stepIndex] is
     * an *advisory* link into the built default-options step sequence — the built sequence is
     * option/calendar-dependent, so the playback UI treats it as a step-syncing hint,
     * never an invariant. */
    @Serializable
    data class Chapter(
        val start: Double,
        val title: String? = null,
        val titleKey: String? = null,
        val stepIndex: Int? = null,
    )

    val localizedName: String?
        get() = nameByLanguage?.get(Locale.getDefault().language) ?: name
}

@Serializable
private data class PackAudio(
    val tracks: List<DevotionAudioTrack>,
)

/** Parsed `devotion.json` — the complete structural description of a generic devotion.
 * Field validity per type is enforced at authoring time by `Shared/tools/validate-devotion.py`;
 * the decoder is deliberately lenient (all optionals) so the engine can switch on [type] alone. */
@Serializable
data class CustomDevotionDefinition(
    val type: DevotionType,
    // days type
    val days: List<Day>? = null,
    /** How the days relate: a series is worked through on consecutive days (a novena, a
     * triduum, a 33-day consecration) and gets a tracked run; "free" days are a set to pick
     * from, like a prayer for each day of the week. Absent means series. */
    val dayProgression: String? = null,
    /** Advisory "HH:mm" for the daily reminder; the user's own times always win. */
    val suggestedReminderTime: String? = null,
    /** Annual "MM-DD" the series traditionally begins on, so a pinned devotion can announce
     * itself before its first day. Advisory — starting it any day always works. */
    val suggestedStart: String? = null,
    /** A devotion to offer once the last day is prayed. May name one this device does not
     * have — resolved at runtime and quietly dropped when it cannot be. */
    val suggestedNext: String? = null,
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
    /** One day of a days-type devotion. */
    @Serializable
    data class Day(
        /** English UI label ("Day 1"); [nameByLanguage] overrides it per UI localization. */
        val name: String,
        val nameByLanguage: Map<String, String>? = null,
        /** Optional grouping label for the Montfort-style structure ("First Week: Knowledge
         * of Self"), shown as period context by the day picker. */
        val period: String? = null,
        val steps: List<CustomDevotionStep>,
    ) {
        val localizedName: String
            get() = nameByLanguage?.get(java.util.Locale.getDefault().language) ?: name
    }

    /** One named alternate form of a devotion — the Stations' traditional vs. scriptural sets,
     * or a chaplet's shorter and fuller recensions. The first variant is the default.
     *
     * A steps-type variant carries [steps]; a rosary-type one carries the same four fields a
     * single-form rosary devotion has. Which pair is populated follows the devotion's type, and
     * the validator enforces it — the decoders stay lenient so the engines can switch on type
     * alone. */
    @Serializable
    data class Variant(
        val id: String,
        /** English UI label (the app-wide step-title convention); [nameByLanguage] overrides it
         * per UI localization, mirroring the manifest's displayNameByLanguage. */
        val name: String,
        val nameByLanguage: Map<String, String>? = null,
        val steps: List<CustomDevotionStep>? = null,
        val eastertideSteps: List<CustomDevotionStep>? = null,
        // rosary type
        val opening: List<CustomDevotionStep>? = null,
        val decades: Decades? = null,
        val closing: List<CustomDevotionStep>? = null,
        val hasClosingCross: Boolean? = null,
    ) {
        val localizedName: String
            get() = nameByLanguage?.get(Locale.getDefault().language) ?: name
    }

    /** The step lists to build for [variantId] — the matching variant, else the default (first)
     * variant, else the top-level lists (single-form devotions). */
    fun resolvedSteps(variantId: String?): Pair<List<CustomDevotionStep>, List<CustomDevotionStep>?> {
        if (!variants.isNullOrEmpty()) {
            val variant = variants.firstOrNull { it.id == variantId } ?: variants.first()
            return variant.steps.orEmpty() to variant.eastertideSteps
        }
        return steps.orEmpty() to eastertideSteps
    }

    /** One rosary-type form: the matching variant, else the default (first) one, else the
     * top-level fields. Mirrors [resolvedSteps] so both types pick a form the same way. */
    data class RosaryForm(
        val opening: List<CustomDevotionStep>,
        val decades: Decades?,
        val closing: List<CustomDevotionStep>,
        val hasClosingCross: Boolean,
    )

    fun resolvedRosary(variantId: String?): RosaryForm {
        if (!variants.isNullOrEmpty()) {
            val variant = variants.firstOrNull { it.id == variantId } ?: variants.first()
            return RosaryForm(
                variant.opening.orEmpty(), variant.decades, variant.closing.orEmpty(),
                variant.hasClosingCross ?: false,
            )
        }
        return RosaryForm(opening.orEmpty(), decades, closing.orEmpty(), hasClosingCross ?: false)
    }

    @Serializable
    enum class DevotionType {
        /** A flat, fixed step list (Angelus, Stations, Trisagion). */
        @SerialName("steps")
        Steps,

        /** A decade/bead-structured devotion (Franciscan Crown, Seven Sorrows, Divine Mercy). */
        @SerialName("rosary")
        Rosary,

        /** A multi-day devotion (novenas, the 33-day Montfort consecration): one step list per
         * day, with optional shared opening/closing prayed every day. Per-favorite day
         * progress is a planned follow-up (see ARCHITECTURE.md's "Multi-day devotions") —
         * until it lands, sessions pray day 1. */
        @SerialName("days")
        Days,
    }

    @Serializable
    data class Decades(
        /** "Joy" / "Sorrow" / "Decade" — combined with the engine's ordinal array into "1st Joy"
         * etc. */
        /** The noun a decade is counted in — a literal, or a key so it reads in the
         * language being prayed ("Mystery" / "רז" / "Тайна"). */
        val ordinalNoun: String? = null,
        val ordinalNounKey: String? = null,
        /** True: each decade opens with an announcement step whose title/body come from the
         * mystery text of that decade's catalog entry (via the merged MysteryTranslations path). */
        val announceMystery: Boolean,
        /** "mysteryGroups" (the Rosary): the decade catalog is resolved at build time from the
         * engine's mystery-group machinery (RosaryOptions selection mode + liturgical calendar)
         * instead of [entries]/[count] — steps carry real [com.dkaluta.prosary.models.Mystery]
         * values so the flow renders exactly as the hardcoded builder did. Null for
         * bundle-cataloged devotions. */
        val source: String? = null,
        /** Per-decade catalog (Franciscan Crown/Seven Sorrows). Mutually exclusive with
         * [count]+[fixedImageKey] (Divine Mercy) and with [source]. */
        val entries: List<CatalogEntry>? = null,
        val count: Int? = null,
        val fixedImageKey: String? = null,
        val majorStep: FixedStep,
        val minorStep: FixedStep,
        val minorCount: Int,
        /** Entries emitted after each decade's minors, carrying the decade's subtitle/index
         * (the Rosary's Glory Be / Fatima Prayer / per-decade eternal rest), usually gated. */
        /** Emitted before each decade's announcement — the Servite chaplet's invocation
         * to Our Lady before each sorrow is named. Not beads: they carry the decade's
         * subtitle but no decadeIndex. */
        val preAnnouncement: List<CustomDevotionStep>? = null,
        val postMinor: List<CustomDevotionStep>? = null,
        /** Presenter-mode alternate decade tail: the minors collapse into one combined step
         * with `hailMaryIndexInDecade = minorCount` so the bead track still renders a full
         * decade. */
        val presenter: Presenter? = null,
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
            /** A decade's Our Father/Hail Mary heading — carries a literal title or a translatable titleKey, exactly like every other step,
             * so it reads in the language being prayed. */
            val title: String? = null,
            val titleKey: String? = null,
            val bodyKey: String,
            /** Fixed illustration for this step (the Rosary's Our Father icon between
             * mystery-specific images). Null = the decade's own image. */
            val imageKey: String? = null,
        )

        @Serializable
        data class Presenter(
            val combinedTitle: String? = null,
            val combinedTitleKey: String? = null,
            /** Bodies joined with a blank line (Hail Mary + Glory Be). */
            val bodyKeys: List<String>,
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
    /** One grapheme (letter or emoji) drawn instead of [iconSystemName] — Compose's "your
     * own" icon (v0.7, Gamaliel item 6). */
    val iconGlyph: String?,
    val displayNameByLanguage: Map<String, String>,
    val reminderBody: Map<String, String>,
    val reminderPresetHours: List<Int>?,
    val reminderPresetFooter: Map<String, String>,
    /** Lowercase category labels from the manifest ("marian", "passion") — what the
     * Categories tab groups by. */
    val tags: List<String> = emptyList(),
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
        "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
        "divineMercyChaplet", "trisagion", "oAntiphons",
    )

    private val prayerOverrides = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val mysteryOverrides = mutableMapOf<String, MutableMap<String, MysteryText>>()
    private val imageDataByKey = mutableMapOf<String, ByteArray>()
    /** Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
     * [prayerOverrides], this retains keys with no matching [PrayerKey] case (e.g.
     * "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
     * bundle-local body text. See [resolveBodyText]. */
    private val rawContentByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()

    /** bundleId → language → prayer key → transliterated text (v0.7 reading aid). */
    private val transliterationsByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()
    private val definitionByBundle = mutableMapOf<String, CustomDevotionDefinition>()
    private val optionsByBundle = mutableMapOf<String, List<CustomDevotionOption>>()
    private val audioTracksByBundle = mutableMapOf<String, List<DevotionAudioTrack>>()
    /** Each loaded bundle's re-openable pack source — audio bytes are re-read from here on
     * demand rather than held in the load-time cache the way images are (a recording dwarfs
     * every other bundle asset). See [audioData]. */
    private val packSourceByBundle = mutableMapOf<String, () -> InputStream?>()
    /** Bundle ids with a devotion.json, in pack-load order. */
    private val orderedCustomIds = mutableListOf<String>()
    private val infoByBundle = mutableMapOf<String, CustomDevotionInfo>()
    /** Bundle ids installed by the user (files in [installedPacksDir]), in load order. */
    private val installedIdsList = mutableListOf<String>()
    /** Where user-imported .prosaryprayer files live — scanned (sorted by filename) after the
     * built-in packs on every load, so installs survive restarts. Set before [initialize]
     * (AppServices; tests may point it at a temp dir). */
    var installedPacksDirectory: File? = null
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

    /** The narrated recordings a bundle's `audio.json` declares, in authored order. Empty for
     * bundles without audio (see Shared/ARCHITECTURE.md's "Audio"). */
    fun audioTracks(bundleId: String): List<DevotionAudioTrack> =
        audioTracksByBundle[bundleId].orEmpty()

    /** The raw Ogg Opus bytes of one of a bundle's *declared* audio files
     * ([DevotionAudioTrack.file]), re-read from the pack on demand. Null for a file no track
     * declares. The playback milestone will extract to a cache file for the OS player rather
     * than keep whole recordings in memory; this byte-level accessor is the seam it builds on. */
    fun audioData(bundleId: String, file: String): ByteArray? {
        if (audioTracksByBundle[bundleId]?.any { it.file == file } != true) return null
        val stream = packSourceByBundle[bundleId]?.invoke() ?: return null
        return readZipEntries(stream)[file]
    }

    fun info(bundleId: String): CustomDevotionInfo? = infoByBundle[bundleId]

    /** The language a session actually prays a bundle in: the chosen (or app-default) language
     * when the bundle ships it, else the bundle's own first (manifest-order) language — never a
     * language the bundle lacks, which would degrade bundle-local text into fallback chains or
     * raw keys. */
    fun effectiveLanguage(bundleId: String, chosen: String?): String {
        val resolved = LanguageCatalog.resolve(chosen ?: LanguageCatalog.defaultSentinel).code
        val available = info(bundleId)?.languages.orEmpty()
        if (available.isEmpty() || resolved in available) return resolved
        // A community variant keeps its code when the bundle ships its base language —
        // bundle text falls back per key.
        LanguageCatalog.baseLanguage(resolved)?.let { if (it in available) return resolved }
        return available.first()
    }

    /** Resolves a `devotion.json` entry's `bodyKey`/`titleKey` to display text: (1) the bundle's
     * own raw content for this key — the requested language, else the bundle's Latin (mirroring
     * `PrayerTranslations.get`'s Latin fallback, so e.g. the sentinel/unknown language prays in
     * Latin, not raw keys); (2) else, if the key happens to match an existing [PrayerKey] case,
     * the ordinary hardcoded/override lookup — this is how shared "main" keys (e.g. "gloriaPatri")
     * resolve; (3) else the raw key string, matching `PrayerTranslations.get`'s own last resort. */
    /** The v0.7 reading aid: this key's text transliterated into another script, if the
     * bundle's language file carries one. No fallback chain — a transliteration belongs to
     * exactly the language it transliterates. */
    fun transliteration(bundleId: String, languageCode: String?, key: String): String? =
        languageCode?.let { transliterationsByBundle[bundleId]?.get(it)?.get(key) }

    fun resolveBodyText(bundleId: String, languageCode: String?, key: String): String {
        if (languageCode != null) {
            rawContentByBundle[bundleId]?.get(languageCode)?.get(key)?.let { return it }
            LanguageCatalog.baseLanguage(languageCode)
                ?.let { base -> rawContentByBundle[bundleId]?.get(base)?.get(key) }
                ?.let { return it }
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
            // openPack is documented re-callable with a fresh stream, which is what lets audio
            // bytes be re-read on demand instead of cached at load — see [audioData].
            runCatching { load(stream) }.getOrNull()?.let { id ->
                packSourceByBundle[id] = { openPack(packName) }
            }
        }

        // User-installed bundles load after the built-ins (so shipped content always wins the
        // shared merges) and are skipped on id collision with anything already loaded.
        val installedFiles = installedPacksDirectory?.listFiles { f -> f.extension == "prosaryprayer" }
            ?.sortedBy { it.name }.orEmpty()
        for (file in installedFiles) {
            val id = file.nameWithoutExtension
            if (infoByBundle.containsKey(id)) continue
            if (runCatching { load(file.inputStream()) }.getOrNull() != null) {
                installedIdsList.add(id)
                packSourceByBundle[id] = { file.inputStream() }
            }
        }
    }

    /** Bundle ids the user has imported (subset of [customDevotionIds]), in load order. */
    fun installedBundleIds(): List<String> = installedIdsList.toList()

    /** Carries a string resource so the UI can show the failure in the app language; the
     * English [message] stays for logs. */
    class InstallException(
        message: String,
        @param:StringRes val messageRes: Int,
        val formatArg: String? = null,
    ) : Exception(message)

    /** Imports a user-provided bundle: validates it (readable zip, parseable manifest +
     * devotion.json, content for every declared language, not a builtin-kind pack, no id
     * collision), copies it into the installed-packs directory, and loads it live. Returns the
     * installed bundle id. */
    /** The on-disk .prosaryprayer file of an *installed* bundle — the export seam: sharing
     * this file is how a devotion travels back to Compose for editing (v0.7, Gamaliel
     * item 7). Null for shipped bundles, whose packs live in the app's assets. */
    fun installedPackFile(bundleId: String): java.io.File? {
        if (bundleId !in installedIdsList) return null
        val dir = installedPacksDirectory ?: return null
        return java.io.File(dir, "$bundleId.prosaryprayer").takeIf { it.exists() }
    }

    fun installPack(bytes: ByteArray): String {
        val entries = runCatching { readZipEntries(bytes.inputStream()) }.getOrNull()
            ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        val manifest = runCatching {
            json.decodeFromString<PackManifest>(String(entries["manifest.json"]!!, Charsets.UTF_8))
        }.getOrNull() ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        val hasDevotion = runCatching {
            json.decodeFromString<CustomDevotionDefinition>(String(entries["devotion.json"]!!, Charsets.UTF_8))
        }.isSuccess
        if (!hasDevotion || manifest.builtinKind != null) {
            throw InstallException("This bundle does not contain a devotion.", R.string.pack_error_not_devotion)
        }
        for (language in manifest.languages) {
            runCatching {
                json.decodeFromString<PackContent>(String(entries["content/$language.json"]!!, Charsets.UTF_8))
            }.getOrNull() ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        }
        if (infoByBundle.containsKey(manifest.id)) {
            throw InstallException("A devotion named \"${manifest.id}\" is already installed.", R.string.pack_error_duplicate, manifest.id)
        }
        val dir = installedPacksDirectory
            ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        dir.mkdirs()
        val destination = File(dir, "${manifest.id}.prosaryprayer")
        destination.writeBytes(bytes)
        load(destination.inputStream())
        installedIdsList.add(manifest.id)
        packSourceByBundle[manifest.id] = { destination.inputStream() }
        return manifest.id
    }

    /** Deletes an installed bundle's file and unregisters its devotion. Its merged
     * prayer/image content stays in memory until the next launch — harmless, since nothing
     * references it once the devotion is gone from [customDevotionIds]. */
    fun removeInstalledPack(id: String) {
        if (id !in installedIdsList) return
        installedPacksDirectory?.let { File(it, "$id.prosaryprayer").delete() }
        installedIdsList.remove(id)
        orderedCustomIds.remove(id)
        definitionByBundle.remove(id)
        infoByBundle.remove(id)
        optionsByBundle.remove(id)
        audioTracksByBundle.remove(id)
        transliterationsByBundle.remove(id)
        packSourceByBundle.remove(id)
    }

    /** Returns the loaded bundle's id (null for a zip with no manifest) so callers can register
     * a re-openable pack source for it — see [audioData]. */
    private fun load(stream: InputStream): String? {
        val entries = readZipEntries(stream)
        val manifestBytes = entries["manifest.json"] ?: return null
        val manifest = json.decodeFromString<PackManifest>(String(manifestBytes, Charsets.UTF_8))

        infoByBundle[manifest.id] = CustomDevotionInfo(
            displayName = manifest.displayName,
            languages = manifest.languages,
            accentColorHex = manifest.accentColorHex,
            accentColorDarkHex = manifest.accentColorDarkHex,
            iconSystemName = manifest.iconSystemName,
            iconGlyph = manifest.iconGlyph,
            displayNameByLanguage = manifest.displayNameByLanguage ?: emptyMap(),
            reminderBody = manifest.reminderBody ?: emptyMap(),
            reminderPresetHours = manifest.reminderPresetHours,
            reminderPresetFooter = manifest.reminderPresetFooter ?: emptyMap(),
            tags = manifest.tags ?: emptyList(),
        )

        // Declared languages are what the bundle *offers*; any other content/<code>.json it
        // carries is an overlay resolved key by key — how a community variant ("he-x-gamliel")
        // ships its own wording for a few prayers without owing a complete translation.
        val overlayLanguages = entries.keys
            .filter { it.startsWith("content/") && it.endsWith(".json") }
            .map { it.removePrefix("content/").removeSuffix(".json") }
            .filterNot { it in manifest.languages }

        for (language in manifest.languages + overlayLanguages) {
            val contentBytes = entries["content/$language.json"] ?: continue
            val content = json.decodeFromString<PackContent>(String(contentBytes, Charsets.UTF_8))

            val bundleRawContent = rawContentByBundle.getOrPut(manifest.id) { mutableMapOf() }
            bundleRawContent[language] = content.prayers
            if (content.transliterations.isNotEmpty()) {
                transliterationsByBundle.getOrPut(manifest.id) { mutableMapOf() }[language] = content.transliterations
            }

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
            if (manifest.builtinKind == null) {
                orderedCustomIds.add(manifest.id)
            }
        }

        entries["options.json"]?.let { optionBytes ->
            optionsByBundle[manifest.id] =
                json.decodeFromString<PackOptions>(String(optionBytes, Charsets.UTF_8)).options
        }

        entries["audio.json"]?.let { audioBytes ->
            audioTracksByBundle[manifest.id] =
                json.decodeFromString<PackAudio>(String(audioBytes, Charsets.UTF_8)).tracks
        }

        for ((name, bytes) in entries) {
            if (name.startsWith("images/")) {
                imageDataByKey[name.removePrefix("images/").removeSuffix(".jpg")] = bytes
            }
        }
        return manifest.id
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
