package com.dkaluta.prosary.content.prayerpack

import android.content.res.AssetManager
import androidx.annotation.StringRes
import com.dkaluta.prosary.R
import com.dkaluta.prosary.models.AppSettings
import com.dkaluta.prosary.models.LanguageCatalog
import com.dkaluta.prosary.typography.HebrewDisplayText

import com.dkaluta.prosary.content.PrayerKey
import com.dkaluta.prosary.content.PrayerTranslations
import java.io.File
import java.io.InputStream
import java.io.OutputStream
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
     * [PrayerPackStore.customDevotionIds] so the devotion directory does not list it twice. */
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
    val mysteries: Map<String, MysteryTextOverride> = emptyMap(),
    /** Optional reading aid (v0.7): prayer key → the same text in another script. */
    val transliterations: Map<String, String> = emptyMap(),
    /** Optional provenance of specific Hebrew prayer keys; unmarked Hebrew stays generic. */
    @SerialName("\$prayerTraditionByKey") val prayerTraditionByKey: Map<String, String> = emptyMap(),
)

/** A bundle can contribute one sourced field without restating a mystery's other metadata.
 * This is especially important for the Aramaic Rosary: the Peshitta supplies Scripture and a
 * Syriac-script reading aid while its title and fruit continue through the normal language
 * fallback chain. */
@Serializable
data class MysteryTextOverride(
    val title: String? = null,
    val fruit: String? = null,
    val description: String? = null,
    val transliteratedDescription: String? = null,
) {
    /** Packs load in precedence order. Description and transliteration are one provenance pair:
     * replacing the description also replaces (or removes) its reading aid. */
    fun mergedWith(later: MysteryTextOverride): MysteryTextOverride = MysteryTextOverride(
        title = later.title ?: title,
        fruit = later.fruit ?: fruit,
        description = later.description ?: description,
        transliteratedDescription = if (later.description != null) {
            later.transliteratedDescription
        } else {
            transliteratedDescription
        },
    )
}

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
    /** Optional authored position for distinct entries that form one numbered sequence (the
     * Rosary's Faith/Hope/Charity Hail Marys). Paired with [counterTotal]; unlike [repeatCount],
     * this entry still emits exactly one step. */
    val counterIndex: Int? = null,
    val counterTotal: Int? = null,
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
            get() = HebrewDisplayText.unpoint(
                nameByLanguage?.get(LanguageCatalog.uiLanguageCode()) ?: name,
            )
    }

    /** Canonical string form of the authored default: "true"/"false" for a toggle, a case id
     * for a choice — the same encoding `Prayer.customOptions` stores. */
    val defaultValue: String
        get() = default.content

    val localizedName: String
        get() = HebrewDisplayText.unpoint(
            nameByLanguage?.get(LanguageCatalog.uiLanguageCode()) ?: name,
        )
}

@Serializable
private data class PackOptions(
    val options: List<CustomDevotionOption>,
)

/** One narrated recording a bundle declares in its `audio.json` (an optional bundle file, staged
 * by both packers like options.json — see Shared/ARCHITECTURE.markdown's "Audio").
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
        get() = nameByLanguage?.get(LanguageCatalog.uiLanguageCode()) ?: name
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
            get() = HebrewDisplayText.unpoint(
                nameByLanguage?.get(LanguageCatalog.uiLanguageCode()) ?: name,
            )
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
        /** Exact prayer-language codes (rites included) whose sessions open in this variant when
         * the favorite carries no explicit choice — the Mission of St. Gamaliel's rite opening
         * the Trisagion in its Syriac form. Exact match only: choosing a rite is deliberate, and
         * the base language keeps the bundle's ordinary (first-variant) default. */
        val defaultForLanguages: List<String>? = null,
        // rosary type
        val opening: List<CustomDevotionStep>? = null,
        val decades: Decades? = null,
        val closing: List<CustomDevotionStep>? = null,
        val hasClosingCross: Boolean? = null,
    ) {
        val localizedName: String
            get() = HebrewDisplayText.unpoint(
                nameByLanguage?.get(LanguageCatalog.uiLanguageCode()) ?: name,
            )
    }

    /** The variant a session with no explicit choice opens in: the explicit [variantId] when
     * given, else the variant that names the resolved prayer language among its
     * defaultForLanguages, else null — which every resolver reads as the first variant. All
     * callers that pass a possibly-null variant id route through this so a rite's native form
     * wins everywhere (engine, variant menu, closing cross) without any per-rite code. */
    fun effectiveVariantId(variantId: String?, languageCode: String?): String? {
        if (variantId != null) return variantId
        if (variants.isNullOrEmpty() || languageCode == null) return null
        return variants.firstOrNull { it.defaultForLanguages?.contains(languageCode) == true }?.id
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
         * progress is a planned follow-up (see ARCHITECTURE.markdown's "Multi-day devotions") —
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
    /** Interface metadata follows the interface language. Prayer-language card names are an
     * explicit display preference; they must not leak into Settings, reminders, or editors. */
    val localizedDisplayName: String
        get() = displayNameIn(LanguageCatalog.uiLanguageCode())

    fun displayNameIn(languageCode: String): String {
        val code = LanguageCatalog.uiLanguageCode(languageCode)
        return HebrewDisplayText.unpoint(
            displayNameByLanguage[code]?.takeIf(String::isNotBlank)
                ?: LanguageCatalog.baseLanguage(code)?.let { displayNameByLanguage[it]?.takeIf(String::isNotBlank) }
                ?: displayName,
        )
    }

    fun cardTitle(
        prayerLanguage: String = LanguageCatalog.resolve(null).code,
        interfaceLanguage: String = LanguageCatalog.uiLanguageCode(),
    ) = com.dkaluta.prosary.models.PrayerCardTitle.resolve(
        displayNameIn(interfaceLanguage), displayNameIn(prayerLanguage),
    )

    val localizedReminderBody: String?
        get() = reminderBody[LanguageCatalog.uiLanguageCode()] ?: reminderBody["en"]

    val localizedReminderPresetFooter: String?
        get() = reminderPresetFooter[LanguageCatalog.uiLanguageCode()] ?: reminderPresetFooter["en"]
}

/** Loads the bundled .prosaryprayer packs (Rosary, and every generic bundle-driven devotion —
 * see Shared/ARCHITECTURE.markdown's "Content bundles" section) and merges their content into
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
 * Uses the platform file APIs plus `java.util.zip` (JDK-builtin, works in plain JVM unit tests)
 * and kotlinx.serialization (org.json's android.jar stubs throw in plain unit tests without
 * Robolectric, which this module doesn't use). */
object PrayerPackStore {
    private const val MAX_CONTROL_ENTRY_BYTES = 8L * 1024L * 1024L
    private const val MAX_CONTROL_TOTAL_BYTES = 32L * 1024L * 1024L
    private const val MAX_IMAGE_ENTRY_BYTES = 64L * 1024L * 1024L
    private const val MAX_MEDIA_ENTRY_BYTES = 256L * 1024L * 1024L
    private const val MAX_PACK_ENTRY_COUNT = 4_096
    private val json = Json { ignoreUnknownKeys = true }
    private val validBundleId = Regex("[A-Za-z0-9][A-Za-z0-9._-]*")

    private data class PackImageSource(
        val bundleId: String,
        val entryName: String,
    )

    private data class LoadedPack(
        val id: String,
        val images: Map<String, String>,
        val source: PackSource,
    )

    /** The production implementations are central-directory indexed and seek directly to a
     * member. The stream implementation remains only for plain-JVM fixtures and callers that
     * genuinely cannot provide a seekable source. */
    private interface PackSource {
        fun readControlPlane(): PackArchive
        fun openEntry(name: String, maxBytes: Long): SeekableZipArchive.EntryReader?
        fun entryFingerprint(name: String): String?
    }

    private class IndexedPackSource(
        private val zip: SeekableZipArchive,
    ) : PackSource {
        override fun readControlPlane(): PackArchive {
            val runtimeNames = zip.entryNames.filter(::isRuntimeJson)
            return PackArchive(
                entries = zip.read(
                    names = runtimeNames,
                    maxEntryBytes = MAX_CONTROL_ENTRY_BYTES,
                    maxTotalBytes = MAX_CONTROL_TOTAL_BYTES,
                ),
                images = zip.entryNames.mapNotNull { name ->
                    imageKey(name)?.let { key -> key to name }
                }.toMap(),
            )
        }

        override fun openEntry(name: String, maxBytes: Long): SeekableZipArchive.EntryReader? =
            zip.openEntry(name, maxBytes)

        override fun entryFingerprint(name: String): String? = zip.entryFingerprint(name)
    }

    private class StreamingPackSource(
        private val open: () -> InputStream?,
    ) : PackSource {
        override fun readControlPlane(): PackArchive {
            val stream = open() ?: error("Prayer pack is unavailable")
            return readPackArchive(stream)
        }

        override fun openEntry(name: String, maxBytes: Long): SeekableZipArchive.EntryReader? {
            val stream = open() ?: return null
            return object : SeekableZipArchive.EntryReader {
                override fun read(): ByteArray =
                    readZipEntry(stream, name, maxBytes)
                        ?: throw java.io.IOException("ZIP entry is missing")

                override fun close() = stream.close()
            }
        }

        // This exceptional compatibility source has no persistent central-directory index.
        // Its caller rewrites the fallback cache entry on every load instead of trusting a key.
        override fun entryFingerprint(name: String): String? = null
    }

    /** Immutable winner captured under [imageSourceLock]. Reading revalidates that generation
     * and acquires its owned descriptor under the same lock, so remove/reinstall cannot redirect
     * stale offsets to a replacement file. */
    internal data class ImageRequest(
        val cacheKey: String,
        val read: () -> ByteArray?,
    )

    /** Load order — also the display order of generic-devotion cards/rows (Home, Favorites), so
     * this list is deliberately an ordered array, never a map's unordered keys. The rosary pack
     * loads first so its shared mystery texts/images are the base other bundles build on. */
    private val packNames = listOf(
        "rosary", "angelus", "stationsOfTheCross", "viaLucis", "franciscanCrown", "sevenSorrows",
        "divineMercyChaplet", "trisagion", "oAntiphons", "litanyOfLoreto",
    )

    private val prayerOverrides = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val prayerTransliterations = mutableMapOf<String, MutableMap<PrayerKey, String>>()
    private val sharedPrayerTitleKeys = setOf(
        "signumCrucisTitle", "symbolumApostolorumTitle", "paterNosterTitle", "aveMariaTitle", "gloriaPatriTitle",
    )
    private val mysteryOverrides = mutableMapOf<String, MutableMap<String, MysteryTextOverride>>()
    /** Image payloads are the overwhelming majority of every pack. Keep only their zip-entry
     * locations here; [imageData] reopens the owning pack for the one image the flow needs.
     * The UI owns a small decoded-bitmap LRU, so startup never retains every shipped JPEG. */
    private val imageSourcesByKey = mutableMapOf<String, MutableList<PackImageSource>>()
    private val imageRevisionByKey = mutableMapOf<String, Long>()
    private val imageSourceLock = Any()
    private var nextImageRevision = 0L
    /** Unfiltered per-bundle content, keyed bundleId -> language -> raw key -> text — unlike
     * [prayerOverrides], this retains keys with no matching [PrayerKey] case (e.g.
     * "trisagionAcclamation"), which is how a generic devotion's `devotion.json` resolves
     * bundle-local body text. See [resolveBodyText]. */
    private val rawContentByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()
    /** Actual nonempty prayer/mystery buckets, distinct from advertised picker languages. */
    private val contentLanguagesByBundle = mutableMapOf<String, MutableSet<String>>()

    /** bundleId → language → prayer key → transliterated text (v0.7 reading aid). */
    private val transliterationsByBundle = mutableMapOf<String, MutableMap<String, Map<String, String>>>()
    private val definitionByBundle = mutableMapOf<String, CustomDevotionDefinition>()
    private val optionsByBundle = mutableMapOf<String, List<CustomDevotionOption>>()
    private val audioTracksByBundle = mutableMapOf<String, List<DevotionAudioTrack>>()
    /** Each loaded bundle's indexed pack source — image and audio payloads are addressed by
     * central-directory offset and re-read on demand instead of being retained at startup. */
    private val packSourceByBundle = mutableMapOf<String, PackSource>()
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

    fun prayerOverride(languageCode: String, key: PrayerKey): String? {
        if (
            key == PrayerKey.SignumCrucis &&
            (LanguageCatalog.baseLanguage(languageCode) ?: languageCode) == "arc" &&
            AppSettings.usesSystemWideAramaicSignOfCrossForm &&
            AppSettings.aramaicSignOfCrossForm == AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B
        ) {
            rawContentByBundle["rosary"]?.get("arc")?.get("signumCrucisFormB")?.let { return it }
        }
        return prayerOverrides[languageCode]?.get(key)
    }

    fun mysteryOverride(languageCode: String, imageKey: String): MysteryTextOverride? =
        mysteryOverrides[languageCode]?.get(imageKey)

    fun imageData(imageKey: String): ByteArray? {
        return imageRequest(imageKey)?.read?.invoke()
    }

    /** Cheap existence check used before decoding and by parity tests. Unlike [imageData], this
     * does not reopen or inflate a pack. */
    internal fun hasImage(imageKey: String): Boolean = synchronized(imageSourceLock) {
        imageSourcesByKey[imageKey]?.isNotEmpty() == true
    }

    /** Captures the current last-loaded-wins source and its revision without holding a lock
     * during zip I/O. [cacheKey] changes whenever that winner changes, so decoded-image caches
     * cannot serve a stale pre-install or pre-removal bitmap. */
    internal fun imageRequest(imageKey: String): ImageRequest? = synchronized(imageSourceLock) {
        val source = imageSourcesByKey[imageKey]?.lastOrNull() ?: return@synchronized null
        val packSource = packSourceByBundle[source.bundleId] ?: return@synchronized null
        val revision = imageRevisionByKey.getValue(imageKey)
        ImageRequest(cacheKey = "$imageKey@$revision") {
            val reader = runCatching {
                synchronized(imageSourceLock) {
                    val winner = imageSourcesByKey[imageKey]?.lastOrNull()
                    val currentPackSource = packSourceByBundle[source.bundleId]
                    if (winner != source || currentPackSource !== packSource) null
                    else packSource.openEntry(source.entryName, MAX_IMAGE_ENTRY_BYTES)
                }
            }.getOrNull() ?: return@ImageRequest null
            runCatching { reader.use { it.read() } }.getOrNull()
        }
    }

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
     * bundles without audio (see Shared/ARCHITECTURE.markdown's "Audio"). */
    fun audioTracks(bundleId: String): List<DevotionAudioTrack> =
        audioTracksByBundle[bundleId].orEmpty()

    /** Content identity for a declared recording, read from the indexed ZIP directory without
     * inflating it. Null is deliberate for the streaming compatibility path: its caller must
     * atomically refresh rather than treating a basename as a durable cache hit. */
    fun audioCacheKey(bundleId: String, file: String): String? = synchronized(imageSourceLock) {
        if (audioTracksByBundle[bundleId]?.any { it.file == file } != true) return@synchronized null
        packSourceByBundle[bundleId]?.entryFingerprint(file)
    }

    /** The raw Ogg Opus bytes of one of a bundle's *declared* audio files
     * ([DevotionAudioTrack.file]), re-read from the pack on demand. Null for a file no track
     * declares. Kept as a byte-level compatibility/test seam; playback uses [writeAudioTo] so it
     * never needs a whole-recording extraction buffer. */
    fun audioData(bundleId: String, file: String): ByteArray? {
        if (audioTracksByBundle[bundleId]?.any { it.file == file } != true) return null
        val reader = runCatching {
            synchronized(imageSourceLock) {
                packSourceByBundle[bundleId]?.openEntry(file, MAX_MEDIA_ENTRY_BYTES)
            }
        }.getOrNull() ?: return null
        return runCatching { reader.use { it.read() } }.getOrNull()
    }

    /** Streams a declared recording into a caller-owned staged file. Indexed sources use fixed
     * buffers for both stored and DEFLATE entries and verify the ZIP CRC before returning; the
     * non-seekable fixture fallback remains bounded by [MAX_MEDIA_ENTRY_BYTES]. */
    fun writeAudioTo(bundleId: String, file: String, output: OutputStream): Boolean {
        if (audioTracksByBundle[bundleId]?.any { it.file == file } != true) return false
        val reader = runCatching {
            synchronized(imageSourceLock) {
                packSourceByBundle[bundleId]?.openEntry(file, MAX_MEDIA_ENTRY_BYTES)
            }
        }.getOrNull() ?: return false
        return runCatching { reader.use { it.copyTo(output) } }.isSuccess
    }

    fun info(bundleId: String): CustomDevotionInfo? = infoByBundle[bundleId]

    /** Advertised languages remain eligible; Hebrew's two traditions also require actual
     * content in their specific/generic bucket. An undeclared Greek overlay cannot promote
     * Greek into a whole session, while Mission overlays still serve a declared Hebrew pack. */
    fun effectiveLanguage(bundleId: String, chosen: String?): String {
        val resolved = LanguageCatalog.resolve(chosen ?: LanguageCatalog.defaultSentinel).code
        val available = info(bundleId)?.languages.orEmpty()
        if (available.isEmpty()) return resolved
        val buckets = contentLanguagesByBundle[bundleId].orEmpty()
        for (probe in LanguageCatalog.contentFallbackChain(resolved)) {
            val eligible = when (probe) {
                LanguageCatalog.hebrewVicariateContentCode -> "he" in available && probe in buckets
                "he-x-gamliel" -> ("he" in available || probe in available) && probe in buckets
                "he" -> ("he" in available || "he-x-gamliel" in available) && probe in buckets
                else -> probe in available
            }
            if (eligible) return LanguageCatalog.selectionForContentProbe(probe, resolved)
        }
        return available.first()
    }

    private data class ResolvedPrayerContent(val text: String, val readingAid: String?)

    private fun localPrayerContent(bundleId: String, probe: String, key: String): ResolvedPrayerContent? =
        rawContentByBundle[bundleId]?.get(probe)?.get(key)?.let { text ->
            ResolvedPrayerContent(text, transliterationsByBundle[bundleId]?.get(probe)?.get(key))
        }

    /** Resolve text and its reading aid together, with the same precedence at every probe:
     * bundle-local content, the Rosary's shared headings, then shared overrides/native text. */
    private fun resolvePrayerContent(bundleId: String, languageCode: String?, key: String): ResolvedPrayerContent? {
        val prayerKey = if (key == "signumCrucisFormB") PrayerKey.SignumCrucis else keyToPrayerKey(key)
        for (probe in LanguageCatalog.contentFallbackChain(languageCode)) {
            // The explicit system-wide Aramaic form changes the formula at the Aramaic
            // probe only; it cannot jump ahead of a higher-priority language.
            val usesFormB = probe == "arc" && prayerKey == PrayerKey.SignumCrucis &&
                AppSettings.usesSystemWideAramaicSignOfCrossForm &&
                AppSettings.aramaicSignOfCrossForm == AppSettings.ARAMAIC_SIGN_OF_CROSS_FORM_B
            if (usesFormB) {
                localPrayerContent("rosary", probe, "signumCrucisFormB")?.let { return it }
            }
            localPrayerContent(bundleId, probe, key)?.let { return it }
            if (key in sharedPrayerTitleKeys) {
                localPrayerContent("rosary", probe, key)?.let { return it }
            }
            if (probe == "he-x-gamliel" && key == "paterNosterTitle") {
                return ResolvedPrayerContent("תפילת האדון", null)
            }
            if (prayerKey != null) {
                prayerOverride(probe, prayerKey)?.let { text ->
                    return ResolvedPrayerContent(text, prayerTransliterations[probe]?.get(prayerKey))
                }
                PrayerTranslations.byLanguage[probe]?.get(prayerKey)?.let { text ->
                    return ResolvedPrayerContent(text, null)
                }
            }
        }
        return null
    }

    /** A missing aid at the selected source remains missing; never borrow another wording's aid. */
    fun transliteration(bundleId: String, languageCode: String?, key: String): String? =
        resolvePrayerContent(bundleId, languageCode, key)?.readingAid

    fun resolveBodyText(bundleId: String, languageCode: String?, key: String): String =
        resolvePrayerContent(bundleId, languageCode, key)?.text ?: key

    /** Production entry point. `noCompress` makes each built-in pack an uncompressed Android
     * asset, so `openFd` exposes its bounded region inside the installed APK and the central
     * directory can be indexed without copying or inflating the outer asset. */
    fun initialize(assets: AssetManager) {
        initializeSources { packName ->
            val assetName = "$packName.prosaryprayer"
            runCatching {
                IndexedPackSource(SeekableZipArchive.fromAsset(assets, assetName))
            }.getOrElse {
                // Preserve feature completeness on a malformed third-party APK/repack that lost
                // noCompress. The instrumentation test and release-artifact check keep official
                // builds on the seekable path; this fallback is deliberately exceptional.
                StreamingPackSource { runCatching { assets.open(assetName) }.getOrNull() }
            }
        }
    }

    /** Stream fallback for plain-JVM fixtures and genuinely non-seekable callers. Production
     * Android startup uses [initialize] with an [AssetManager]. [openPack] must return a fresh
     * stream each time, or null when that fixture is unavailable. */
    fun initialize(openPack: (String) -> InputStream?) {
        initializeSources { packName -> StreamingPackSource { openPack(packName) } }
    }

    /** Isolate synthetic source/provenance fixtures from the process-wide built-in catalog. */
    internal fun resetForTesting() {
        didLoad = false
        installedPacksDirectory = null
        prayerOverrides.clear()
        prayerTransliterations.clear()
        mysteryOverrides.clear()
        rawContentByBundle.clear()
        contentLanguagesByBundle.clear()
        transliterationsByBundle.clear()
        definitionByBundle.clear()
        optionsByBundle.clear()
        audioTracksByBundle.clear()
        infoByBundle.clear()
        orderedCustomIds.clear()
        installedIdsList.clear()
        synchronized(imageSourceLock) {
            imageSourcesByKey.clear()
            imageRevisionByKey.clear()
            packSourceByBundle.clear()
            nextImageRevision = 0L
        }
    }

    private fun initializeSources(sourceForPack: (String) -> PackSource) {
        if (didLoad) return
        didLoad = true

        for (packName in packNames) {
            runCatching { load(sourceForPack(packName)) }.getOrNull()?.let(::registerPackSource)
        }

        // User-installed bundles load after the built-ins (so shipped content always wins the
        // shared merges) and are skipped on id collision with anything already loaded.
        val installedDir = installedPacksDirectory
        val installedFiles = installedDir?.listFiles { f -> f.extension == "prosaryprayer" }
            ?.sortedBy { it.name }.orEmpty()
        for (file in installedFiles) {
            val id = file.nameWithoutExtension
            val expectedFile = installedDir?.let { installedPackTarget(it, id) }
            if (expectedFile == null || expectedFile != runCatching { file.canonicalFile }.getOrNull()) continue
            if (infoByBundle.containsKey(id)) continue
            val pack = runCatching {
                load(IndexedPackSource(SeekableZipArchive.fromFile(file)), expectedId = id)
            }.getOrNull()
            if (pack != null) {
                installedIdsList.add(pack.id)
                registerPackSource(pack)
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
        return installedPackTarget(dir, bundleId)?.takeIf { it.exists() }
    }

    fun installPack(bytes: ByteArray): String {
        requireInstallByteCount(bytes.size.toLong())
        val dir = installedPacksDirectory
            ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        dir.mkdirs()
        val staged = runCatching { File.createTempFile(".prosary-import-", ".tmp", dir) }
            .getOrNull()
            ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
        var destination: File? = null
        try {
            staged.outputStream().use { it.write(bytes) }
            val stagedSource = IndexedPackSource(SeekableZipArchive.fromFile(staged))
            val entries = stagedSource.readControlPlane().entries
            val manifest = runCatching {
                json.decodeFromString<PackManifest>(String(entries["manifest.json"]!!, Charsets.UTF_8))
            }.getOrNull()
                ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            val hasDevotion = runCatching {
                json.decodeFromString<CustomDevotionDefinition>(String(entries["devotion.json"]!!, Charsets.UTF_8))
            }.isSuccess
            if (!hasDevotion || manifest.builtinKind != null) {
                throw InstallException("This bundle does not contain a devotion.", R.string.pack_error_not_devotion)
            }
            if (!validBundleId.matches(manifest.id)) {
                throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            }
            for (language in manifest.languages) {
                runCatching {
                    json.decodeFromString<PackContent>(String(entries["content/$language.json"]!!, Charsets.UTF_8))
                }.getOrNull()
                    ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            }
            // Validate optional and overlay control-plane files before the staged file becomes
            // durable. Images/audio remain lazy and may fail independently at point of use.
            entries.filterKeys { it.startsWith("content/") }.values.forEach { contentBytes ->
                runCatching {
                    json.decodeFromString<PackContent>(String(contentBytes, Charsets.UTF_8))
                }.getOrElse {
                    throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
                }
            }
            entries["options.json"]?.let { optionBytes ->
                runCatching {
                    json.decodeFromString<PackOptions>(String(optionBytes, Charsets.UTF_8))
                }.getOrElse {
                    throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
                }
            }
            entries["audio.json"]?.let { audioBytes ->
                runCatching {
                    json.decodeFromString<PackAudio>(String(audioBytes, Charsets.UTF_8))
                }.getOrElse {
                    throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
                }
            }
            if (infoByBundle.containsKey(manifest.id)) {
                throw InstallException("A devotion named \"${manifest.id}\" is already installed.", R.string.pack_error_duplicate, manifest.id)
            }
            val target = installedPackTarget(dir, manifest.id)
                ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            if (target.exists() || !staged.renameTo(target)) {
                if (target.exists()) {
                    throw InstallException("A devotion named \"${manifest.id}\" is already installed.", R.string.pack_error_duplicate, manifest.id)
                }
                throw InstallException("This file could not be installed.", R.string.pack_error_unreadable)
            }
            destination = target
            val pack = load(
                IndexedPackSource(SeekableZipArchive.fromFile(target)),
                expectedId = manifest.id,
            )
                ?: throw InstallException("This file is not a readable .prosaryprayer bundle.", R.string.pack_error_unreadable)
            installedIdsList.add(manifest.id)
            registerPackSource(pack)
            return manifest.id
        } catch (error: InstallException) {
            destination?.delete()
            throw error
        } catch (_: Exception) {
            destination?.delete()
            throw InstallException(
                "This file is not a readable .prosaryprayer bundle.",
                R.string.pack_error_unreadable,
            )
        } finally {
            staged.delete()
        }
    }

    fun requireInstallByteCount(byteCount: Long) {
        if (byteCount >= 0 && byteCount > SeekableZipArchive.MAX_ARCHIVE_BYTES) {
            throw InstallException(
                "This file is not a readable .prosaryprayer bundle.",
                R.string.pack_error_unreadable,
            )
        }
    }

    /** Reads at most one complete import budget plus a sentinel byte, so file pickers and HTTP
     * callers cannot allocate an arbitrarily large response before [installPack] sees it. */
    fun readInstallBytes(input: InputStream): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(32 * 1024)
        var total = 0L
        while (true) {
            val count = input.read(buffer)
            if (count < 0) break
            if (count == 0) continue
            total += count
            if (total > SeekableZipArchive.MAX_ARCHIVE_BYTES) {
                throw InstallException(
                    "This file is not a readable .prosaryprayer bundle.",
                    R.string.pack_error_unreadable,
                )
            }
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    /** Deletes an installed bundle and unregisters its devotion/media sources. Merged prayer
     * text overrides stay in memory until the next launch; no remaining devotion references
     * them, while image winners immediately fall back to the prior source. */
    fun removeInstalledPack(id: String) {
        if (id !in installedIdsList) return
        installedIdsList.remove(id)
        orderedCustomIds.remove(id)
        definitionByBundle.remove(id)
        infoByBundle.remove(id)
        optionsByBundle.remove(id)
        audioTracksByBundle.remove(id)
        rawContentByBundle.remove(id)
        contentLanguagesByBundle.remove(id)
        transliterationsByBundle.remove(id)
        synchronized(imageSourceLock) {
            packSourceByBundle.remove(id)
            val iterator = imageSourcesByKey.iterator()
            while (iterator.hasNext()) {
                val (imageKey, sources) = iterator.next()
                val winningSource = sources.lastOrNull()
                sources.removeAll { it.bundleId == id }
                if (sources.isEmpty()) iterator.remove()
                if (winningSource?.bundleId == id) {
                    imageRevisionByKey[imageKey] = ++nextImageRevision
                }
            }
            // Deletion shares the source lock with request descriptor acquisition. A request
            // that won the race owns an open descriptor to the old inode; a later one observes
            // the unregistered source and cannot reopen a replacement at the same pathname.
            installedPacksDirectory?.let { dir -> installedPackTarget(dir, id)?.delete() }
        }
    }

    /** Returns the loaded bundle plus its stable indexed source (null for a ZIP with no
     * manifest) so callers can atomically register image/audio lookups. */
    private fun load(source: PackSource, expectedId: String? = null): LoadedPack? {
        val archive = source.readControlPlane()
        val entries = archive.entries
        val manifestBytes = entries["manifest.json"] ?: return null
        val manifest = json.decodeFromString<PackManifest>(String(manifestBytes, Charsets.UTF_8))
        if (!validBundleId.matches(manifest.id)) return null
        if (expectedId != null && manifest.id != expectedId) return null

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
            val bucketLanguages = contentLanguagesByBundle.getOrPut(manifest.id) { mutableSetOf() }
            val prayersByProbe = content.prayers.entries.groupBy { (key, _) ->
                if (language == "he" && content.prayerTraditionByKey[key] == "vicariate") {
                    LanguageCatalog.hebrewVicariateContentCode
                } else language
            }
            for ((probe, entriesForProbe) in prayersByProbe) {
                val localPrayers = entriesForProbe.associate { it.key to it.value }
                bundleRawContent[probe] = localPrayers
                bucketLanguages.add(probe)
                val localAids = content.transliterations.filterKeys { it in localPrayers }
                transliterationsByBundle.getOrPut(manifest.id) { mutableMapOf() }[probe] = localAids
                val prayers = prayerOverrides.getOrPut(probe) { mutableMapOf() }
                val readingAids = prayerTransliterations.getOrPut(probe) { mutableMapOf() }
                for ((key, text) in localPrayers) {
                    val prayerKey = keyToPrayerKey(key) ?: continue
                    prayers[prayerKey] = text
                    val readingAid = localAids[key]
                    if (readingAid != null) readingAids[prayerKey] = readingAid else readingAids.remove(prayerKey)
                }
            }
            if (content.mysteries.isNotEmpty()) bucketLanguages.add(language)

            // Mysteries merge whenever a bundle ships any — `hasCatalog` strictly means "has a
            // catalog.json authoring file" (the Rosary), not "may contribute mystery text":
            // generic rosary-type devotions (Seven Sorrows, Franciscan Crown) ship their
            // per-decade texts in the mysteries map without any catalog.json.
            if (content.mysteries.isNotEmpty()) {
                val languageOverrides = mysteryOverrides.getOrPut(language) { mutableMapOf() }
                for ((imageKey, later) in content.mysteries) {
                    languageOverrides[imageKey] = languageOverrides[imageKey]
                        ?.mergedWith(later)
                        ?: later
                }
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

        return LoadedPack(manifest.id, archive.images, source)
    }

    /** Adds a pack's lazy image entries and indexed source atomically. A key may have multiple sources:
     * the last loaded pack wins, and removing it reveals the previous built-in source. */
    private fun registerPackSource(pack: LoadedPack) {
        synchronized(imageSourceLock) {
            packSourceByBundle[pack.id] = pack.source
            for ((imageKey, entryName) in pack.images) {
                val sources = imageSourcesByKey.getOrPut(imageKey) { mutableListOf() }
                sources.removeAll { it.bundleId == pack.id }
                sources.add(PackImageSource(pack.id, entryName))
                imageRevisionByKey[imageKey] = ++nextImageRevision
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

    /** Maps an imported id to exactly one direct child of the installed-pack directory. The
     * cross-platform bundle-id contract deliberately allows dotted repository ids while
     * excluding separators, control characters, empty ids, and `.`/`..`. */
    private fun installedPackTarget(directory: File, id: String): File? {
        if (!validBundleId.matches(id)) return null
        return runCatching {
            val canonicalDirectory = directory.canonicalFile
            File(canonicalDirectory, "$id.prosaryprayer").canonicalFile
                .takeIf { it.parentFile == canonicalDirectory }
        }.getOrNull()
    }

    private data class PackArchive(
        val entries: Map<String, ByteArray>,
        val images: Map<String, String>,
    )

    /** Non-seekable fixture fallback. Production Android and installed packs use
     * [SeekableZipArchive], because even closing a skipped `ZipInputStream` member can inflate it
     * while advancing to the next header. */
    private fun readPackArchive(stream: InputStream): PackArchive {
        val entries = mutableMapOf<String, ByteArray>()
        val images = mutableMapOf<String, String>()
        val seenNames = mutableSetOf<String>()
        var entryCount = 0
        var controlBytes = 0L
        ZipInputStream(stream).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                entryCount += 1
                if (entryCount > MAX_PACK_ENTRY_COUNT) {
                    throw java.io.IOException("Prayer pack contains too many entries")
                }
                if (!seenNames.add(entry.name)) {
                    throw java.io.IOException("Prayer pack contains duplicate entries")
                }
                if (!entry.isDirectory) {
                    val key = imageKey(entry.name)
                    when {
                        key != null -> images[key] = entry.name
                        isRuntimeJson(entry.name) -> {
                            val bytes = zip.readBytesLimited(MAX_CONTROL_ENTRY_BYTES)
                            controlBytes += bytes.size
                            if (controlBytes > MAX_CONTROL_TOTAL_BYTES) {
                                throw java.io.IOException("Prayer-pack metadata is too large")
                            }
                            entries[entry.name] = bytes
                        }
                    }
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return PackArchive(entries, images)
    }

    private fun InputStream.readBytesLimited(limit: Long): ByteArray {
        val output = java.io.ByteArrayOutputStream()
        val buffer = ByteArray(32 * 1024)
        var total = 0L
        while (true) {
            val count = read(buffer)
            if (count < 0) break
            total += count
            if (total > limit) throw java.io.IOException("Prayer-pack entry is too large")
            output.write(buffer, 0, count)
        }
        return output.toByteArray()
    }

    private fun isRuntimeJson(name: String): Boolean =
        name == "manifest.json" ||
            name == "devotion.json" ||
            name == "options.json" ||
            name == "audio.json" ||
            (name.startsWith("content/") && name.endsWith(".json"))

    private fun imageKey(name: String): String? {
        if (!name.startsWith("images/")) return null
        val filename = name.removePrefix("images/")
        if ('/' in filename) return null
        val extension = filename.substringAfterLast('.', missingDelimiterValue = "").lowercase(Locale.ROOT)
        if (extension !in setOf("jpg", "jpeg", "png", "webp")) return null
        return filename.substringBeforeLast('.')
    }

    /** Non-seekable fixture fallback for one payload. */
    private fun readZipEntry(stream: InputStream, wantedName: String, limit: Long): ByteArray? {
        ZipInputStream(stream).use { zip ->
            var entry = zip.nextEntry
            while (entry != null) {
                if (!entry.isDirectory && entry.name == wantedName) {
                    return zip.readBytesLimited(limit)
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
        return null
    }
}
